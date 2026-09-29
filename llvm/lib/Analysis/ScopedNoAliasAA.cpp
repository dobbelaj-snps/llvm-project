//===- ScopedNoAliasAA.cpp - Scoped No-Alias Alias Analysis ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the ScopedNoAlias alias-analysis pass, which implements
// metadata-based scoped no-alias support.
//
// Alias-analysis scopes are defined by an id (which can be a string or some
// other metadata node), a domain node, and an optional descriptive string.
// A domain is defined by an id (which can be a string or some other metadata
// node), and an optional descriptive string.
//
// !dom0 =   metadata !{ metadata !"domain of foo()" }
// !scope1 = metadata !{ metadata !scope1, metadata !dom0, metadata !"scope 1" }
// !scope2 = metadata !{ metadata !scope2, metadata !dom0, metadata !"scope 2" }
//
// Loads and stores can be tagged with an alias-analysis scope, and also, with
// a noalias tag for a specific scope:
//
// ... = load %ptr1, !alias.scope !{ !scope1 }
// ... = load %ptr2, !alias.scope !{ !scope1, !scope2 }, !noalias !{ !scope1 }
//
// When evaluating an aliasing query, if one of the instructions is associated
// has a set of noalias scopes in some domain that is a superset of the alias
// scopes in that domain of some other instruction, then the two memory
// accesses are assumed not to alias.
//
//===----------------------------------------------------------------------===//

#include "llvm/Analysis/ScopedNoAliasAA.h"
#include "llvm/ADT/SetOperations.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Analysis/CaptureTracking.h"
#include "llvm/Analysis/MemoryLocation.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/ConstantFold.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"

using namespace llvm;

#define DEBUG_TYPE "scoped-noalias"

// A handy option for disabling scoped no-alias functionality. The same effect
// can also be achieved by stripping the associated metadata tags from IR, but
// this option is sometimes more convenient.
static cl::opt<bool>
    EnableScopedNoAlias("enable-scoped-noalias", cl::init(true), cl::Hidden,
                        cl::desc("Enable use of scoped-noalias metadata"));

static cl::opt<int>
    MaxNoAliasDepth("scoped-noalias-max-depth", cl::init(12), cl::Hidden,
                    cl::desc("Maximum depth for noalias intrinsic search"));

static cl::opt<int> MaxNoAliasPointerCaptureDepth(
    "scoped-noalias-max-pointer-capture-check", cl::init(320), cl::Hidden,
    cl::desc("Maximum depth for noalias pointer capture search"));

// Helpers:
static const IntrinsicInst *isNoAliasIntrinsic(const Value *V) {
  if (auto *II = dyn_cast<IntrinsicInst>(V))
    if (II->getIntrinsicID() == Intrinsic::provenance_noalias ||
        II->getIntrinsicID() == Intrinsic::noalias)
      return II;
  return nullptr;
}

static const Metadata *getNoAliasObjectScope(const IntrinsicInst *II) {
  assert(II->getIntrinsicID() == Intrinsic::provenance_noalias ||
         II->getIntrinsicID() == Intrinsic::noalias);
  unsigned ScopeArg = II->getIntrinsicID() == Intrinsic::provenance_noalias
                          ? Intrinsic::ProvenanceNoAliasScopeArg
                          : Intrinsic::NoAliasScopeArg;
  return cast<MetadataAsValue>(II->getOperand(ScopeArg))->getMetadata();
}

static bool hasNoAliasObjectUnknownScope(const IntrinsicInst *II) {
  MDNode *NoAliasUnknownScopeMD =
      II->getParent()->getParent()->getMetadata("noalias");
  return NoAliasUnknownScopeMD &&
         getNoAliasObjectScope(II) == NoAliasUnknownScopeMD;
}

static uint64_t getNoAliasObjectObjId(const IntrinsicInst *II) {
  assert(II->getIntrinsicID() == Intrinsic::provenance_noalias ||
         II->getIntrinsicID() == Intrinsic::noalias);
  unsigned IdentifyPObjIdArg =
      II->getIntrinsicID() == Intrinsic::provenance_noalias
          ? Intrinsic::ProvenanceNoAliasIdentifyPObjIdArg
          : Intrinsic::NoAliasIdentifyPObjIdArg;
  return cast<ConstantInt>(II->getOperand(IdentifyPObjIdArg))->getZExtValue();
}

static Value *getNoAliasObjectP(const IntrinsicInst *II) {
  assert(II->getIntrinsicID() == Intrinsic::provenance_noalias ||
         II->getIntrinsicID() == Intrinsic::noalias);
  unsigned IdentifyPArg = II->getIntrinsicID() == Intrinsic::provenance_noalias
                              ? Intrinsic::ProvenanceNoAliasIdentifyPArg
                              : Intrinsic::NoAliasIdentifyPArg;
  return II->getOperand(IdentifyPArg);
}

static Value *getNoAliasObjectPtrProvenance(const IntrinsicInst *II) {
  assert(II->getIntrinsicID() == Intrinsic::provenance_noalias ||
         II->getIntrinsicID() == Intrinsic::noalias);
  if (II->getIntrinsicID() == Intrinsic::provenance_noalias) {
    auto *P =
        II->getOperand(Intrinsic::ProvenanceNoAliasIdentifyPProvenanceArg);
    if (!isa<UndefValue>(P))
      return P;
  }
  return nullptr;
}

// A 'Undef'as 'NoAliasProvenance'  means 'no known extra information' about
// the pointer provenance. In that case, we need to follow the real pointer
// as it might contain extrainformation provided through llvm.experimental.ptr.provenance.
// A absent (nullptr) 'NoAliasProvenance', indicates that this access does not
// contain noalias provenance info.
static const Value *selectMemoryProvenance(const MemoryLocation &Loc) {
  return Loc.AATags.PtrProvenance && !isa<UndefValue>(Loc.AATags.PtrProvenance)
             ? Loc.AATags.PtrProvenance
             : Loc.Ptr;
}

AliasResult ScopedNoAliasAAResult::alias(const MemoryLocation &LocA,
                                         const MemoryLocation &LocB,
                                         AAQueryInfo &AAQI,
                                         const Instruction *) {
  if (!EnableScopedNoAlias)
    return AliasResult::MayAlias;

  // Get the attached MDNodes.
  const MDNode *AScopes = LocA.AATags.Scope, *BScopes = LocB.AATags.Scope;

  const MDNode *ANoAlias = LocA.AATags.NoAlias, *BNoAlias = LocB.AATags.NoAlias;

  if (!mayAliasInScopes(AScopes, BNoAlias))
    return AliasResult::NoAlias;

  if (!mayAliasInScopes(BScopes, ANoAlias))
    return AliasResult::NoAlias;

  LLVM_DEBUG(llvm::dbgs() << "ScopedNoAliasAAResult::alias\n");
  if (noAliasByIntrinsic(ANoAlias, selectMemoryProvenance(LocA), BNoAlias,
                         selectMemoryProvenance(LocB), AAQI))
    return AliasResult::NoAlias;

  return AliasResult::MayAlias;
}

ModRefInfo ScopedNoAliasAAResult::getModRefInfo(const CallBase *Call,
                                                const MemoryLocation &Loc,
                                                AAQueryInfo &AAQI) {
  if (!EnableScopedNoAlias)
    return ModRefInfo::ModRef;

  const MDNode *CSNoAlias = Call->getMetadata(LLVMContext::MD_noalias);
  if (!mayAliasInScopes(Loc.AATags.Scope, CSNoAlias))
    return ModRefInfo::NoModRef;

  const MDNode *CSScopes = Call->getMetadata(LLVMContext::MD_alias_scope);
  if (!mayAliasInScopes(CSScopes, Loc.AATags.NoAlias))
    return ModRefInfo::NoModRef;

  LLVM_DEBUG(llvm::dbgs() << "ScopedNoAliasAAResult::getModRefInfo - 1\n");
  auto ME = getMemoryEffects(Call, AAQI);
  if (ME.onlyAccessesArgPointees()) {
    SmallVector<const Value *, 8> Args;
    for (const Value *Arg : Call->args())
      if (Arg->getType()->isPointerTy())
        Args.push_back(Arg);
    if (noAliasByIntrinsic(Loc.AATags.NoAlias, selectMemoryProvenance(Loc),
                           CSNoAlias, Args, AAQI))
      return ModRefInfo::NoModRef;
  } else {
    if (noAliasByIntrinsic(Loc.AATags.NoAlias, selectMemoryProvenance(Loc),
                           CSNoAlias, Call))
      return ModRefInfo::NoModRef;
  }

  return ModRefInfo::ModRef;
}

ModRefInfo ScopedNoAliasAAResult::getModRefInfo(const CallBase *Call1,
                                                const CallBase *Call2,
                                                AAQueryInfo &AAQI) {
  if (!EnableScopedNoAlias)
    return ModRefInfo::ModRef;

  const MDNode *CS1Scopes = Call1->getMetadata(LLVMContext::MD_alias_scope);
  const MDNode *CS2Scopes = Call2->getMetadata(LLVMContext::MD_alias_scope);
  const MDNode *CS1NoAlias = Call1->getMetadata(LLVMContext::MD_noalias);
  const MDNode *CS2NoAlias = Call2->getMetadata(LLVMContext::MD_noalias);
  if (!mayAliasInScopes(CS1Scopes, Call2->getMetadata(LLVMContext::MD_noalias)))
    return ModRefInfo::NoModRef;

  if (!mayAliasInScopes(CS2Scopes, Call1->getMetadata(LLVMContext::MD_noalias)))
    return ModRefInfo::NoModRef;

  auto ME1 = getMemoryEffects(Call1, AAQI);
  SmallVector<const Value *, 8> Args1;
  if (ME1.onlyAccessesArgPointees()) {
    for (const Value *Arg : Call1->args())
      if (Arg->getType()->isPointerTy())
        Args1.push_back(Arg);
  }
  auto ME2 = getMemoryEffects(Call2, AAQI);
  SmallVector<const Value *, 8> Args2;
  if (ME2.onlyAccessesArgPointees()) {
    for (const Value *Arg : Call2->args())
      if (Arg->getType()->isPointerTy())
        Args2.push_back(Arg);
  }
  if (ME1.onlyAccessesArgPointees()) {
    if (ME2.onlyAccessesArgPointees()) {
      if (noAliasByIntrinsic(CS1NoAlias, Args1, CS2NoAlias, Args2, AAQI))
        return ModRefInfo::NoModRef;
    } else {
      if (noAliasByIntrinsic(CS1NoAlias, Args1, CS2NoAlias, Call2))
        return ModRefInfo::NoModRef;
    }
  } else if (ME2.onlyAccessesArgPointees()) {
    if (noAliasByIntrinsic(CS2NoAlias, Args2, CS1NoAlias, Call1))
      return ModRefInfo::NoModRef;
  }

  return ModRefInfo::ModRef;
}

static void collectMDInDomain(const MDNode *List, const MDNode *Domain,
                              SmallPtrSetImpl<const MDNode *> &Nodes) {
  for (const MDOperand &MDOp : List->operands())
    if (const MDNode *MD = dyn_cast<MDNode>(MDOp))
      if (AliasScopeNode(MD).getDomain() == Domain)
        Nodes.insert(MD);
}

/// Collect the set of scoped domains relevant to the noalias scopes.
void ScopedNoAliasAAResult::collectScopedDomains(
    const MDNode *NoAlias, SmallPtrSetImpl<const MDNode *> &Domains) {
  if (!NoAlias)
    return;
  assert(Domains.empty() && "Domains should be empty");
  for (const MDOperand &MDOp : NoAlias->operands())
    if (const MDNode *NAMD = dyn_cast<MDNode>(MDOp))
      if (const MDNode *Domain = AliasScopeNode(NAMD).getDomain())
        Domains.insert(Domain);
}

bool ScopedNoAliasAAResult::mayAliasInScopes(const MDNode *Scopes,
                                             const MDNode *NoAlias) {
  if (!Scopes || !NoAlias)
    return true;

  // Collect the set of scope domains relevant to the noalias scopes.
  SmallPtrSet<const MDNode *, 16> Domains;
  collectScopedDomains(NoAlias, Domains);

  // We alias unless, for some domain, the set of noalias scopes in that domain
  // is a superset of the set of alias scopes in that domain.
  for (const MDNode *Domain : Domains) {
    SmallPtrSet<const MDNode *, 16> ScopeNodes;
    collectMDInDomain(Scopes, Domain, ScopeNodes);
    if (ScopeNodes.empty())
      continue;

    SmallPtrSet<const MDNode *, 16> NANodes;
    collectMDInDomain(NoAlias, Domain, NANodes);

    // To not alias, all of the nodes in ScopeNodes must be in NANodes.
    if (llvm::set_is_subset(ScopeNodes, NANodes))
      return false;
  }

  return true;
}

static bool isKnownDifferentNoaliasObject(const IntrinsicInst *AI,
                                          const IntrinsicInst *BI,
                                          AAQueryInfo &AAQI) {
  // Shortcut
  if (AI == BI)
    return false;

  if (!hasNoAliasObjectUnknownScope(AI) && !hasNoAliasObjectUnknownScope(BI)) {
    if (getNoAliasObjectScope(AI) != getNoAliasObjectScope(BI) ||
        getNoAliasObjectObjId(AI) != getNoAliasObjectObjId(BI))
      return true;
  }

  const Value *AP = getNoAliasObjectP(AI), *BP = getNoAliasObjectP(BI);
  // Shortcut
  if (AP == BP)
    return false;

  // The noalias object is either in memory or not
  if (isa<ConstantPointerNull>(AP) != isa<ConstantPointerNull>(BP))
    return true;

  // Can we rule out that A and B alias? (check with 1 unit)
  MemoryLocation AML(AP, 1ull, AI->getAAMetadata());
  MemoryLocation BML(BP, 1ull, BI->getAAMetadata());
  AML.AATags.PtrProvenance = getNoAliasObjectPtrProvenance(AI);
  BML.AATags.PtrProvenance = getNoAliasObjectPtrProvenance(BI);
  if (AAQI.AAR.alias(AML, BML, AAQI) == AliasResult::NoAlias)
    return true;

  return false;
}

static bool NoAliasObjectMayHaveEscaped(const IntrinsicInst *AII,
                                        const Instruction *BInst,
                                        DominatorTree *DT) {
  assert(!hasNoAliasObjectUnknownScope(AII));
  // We need to find all noalias intrinsics that reference the noalias
  // object of A, and see where they first escape. If this is not before
  // BInst, it cannot be based on A.

  // If the noalias object is still in memory, we must be certain this
  // does not escape; or there could be an intrinsic that is not visible to us
  const Value *ObjectP = getNoAliasObjectP(AII);
  if (!isa<ConstantPointerNull>(ObjectP)) {
    SmallVector<const Value *, 4> Objs;
    getUnderlyingObjects(ObjectP, Objs);
    for (const Value* V : Objs) {
      // If this is not some local function object, this is too dangerous: abort
      if (!isIdentifiedFunctionLocal(V))
        return true;
      // Detect escape
      if (PointerMayBeCapturedBefore(V, /*ReturnCaptures=*/false, BInst, DT,
                                     /*IncludeI=*/true,
                                     MaxNoAliasPointerCaptureDepth))
        return true;
    }
  }

  // To find all the intrinsics, we take a shortcut: the MetadataAsValue
  // for the scope arg is uniqued and it has a use list.
  // NOTE: this assumes that the noalias object will no longer be
  // referenced using an unknown scope (elsewhere).
  unsigned ScopeArg = AII->getIntrinsicID() == Intrinsic::provenance_noalias
                          ? Intrinsic::ProvenanceNoAliasScopeArg
                          : Intrinsic::NoAliasScopeArg;
  auto *MV = cast<MetadataAsValue>(AII->getOperand(ScopeArg));
  for (const User *U : MV->users()) {
    if (auto *II = dyn_cast<IntrinsicInst>(U)) {
      if (II->getParent()->getParent() != AII->getParent()->getParent() ||
          (II->getIntrinsicID() != Intrinsic::provenance_noalias &&
           II->getIntrinsicID() != Intrinsic::noalias))
        continue;
      if (PointerMayBeCapturedBefore(II, /*ReturnCaptures=*/false, BInst, DT,
                                     /*IncludeI=*/true,
                                     MaxNoAliasPointerCaptureDepth))
        return true;
    }
  }
  return false;
}

bool ScopedNoAliasAAResult::noAliasByIntrinsic(const MDNode *ANoAlias,
                                               ArrayRef<const Value *> APtrs,
                                               const MDNode *BNoAlias,
                                               ArrayRef<const Value *> BPtrs,
                                               AAQueryInfo &AAQI) {
  if (!ANoAlias || !BNoAlias)
    return false;

  auto IsCompatibleNoaliasScope = [ANoAlias, BNoAlias](const MDNode *Scope) {
    return !mayAliasInScopes(Scope, ANoAlias) &&
           !mayAliasInScopes(Scope, BNoAlias);
  };

  // Determine the (compatible) noalias provenance
  SmallVector<const Value *, 4> AObjs;
  SmallVector<const Value *, 4> BObjs;
  for (const Value *APtr : APtrs)
    llvm::getUnderlyingObjects(APtr, AObjs, /*LI=*/nullptr, /*MaxLookup=*/0,
                               /*FollowProvenance=*/true,
                               IsCompatibleNoaliasScope);
  for (const Value *BPtr : BPtrs)
    llvm::getUnderlyingObjects(BPtr, BObjs, /*LI=*/nullptr, /*MaxLookup=*/0,
                               /*FollowProvenance=*/true,
                               IsCompatibleNoaliasScope);

  // If any AObj could match any BObj, we must assume it may alias; otherwise
  // they cannot alias
  for (const Value *AObj : AObjs)
    for (const Value *BObj : BObjs)
      if (!isNoAliasByIntrinsic(AObj, BObj, AAQI))
        return false;
  return true;
}

bool ScopedNoAliasAAResult::noAliasByIntrinsic(const MDNode *ANoAlias,
                                               ArrayRef<const Value *> APtrs,
                                               const MDNode *BNoAlias,
                                               const Instruction *BInst) {
  if (!ANoAlias || !BNoAlias)
    return false;

  auto IsCompatibleNoaliasScope = [ANoAlias, BNoAlias](const MDNode *Scope) {
    return !mayAliasInScopes(Scope, ANoAlias) &&
           !mayAliasInScopes(Scope, BNoAlias);
  };

  // Determine the (compatible) noalias provenance
  SmallVector<const Value *, 4> AObjs;
  for (const Value *APtr : APtrs)
    llvm::getUnderlyingObjects(APtr, AObjs, /*LI=*/nullptr, /*MaxLookup=*/0,
                               /*FollowProvenance=*/true,
                               IsCompatibleNoaliasScope);

  for (const Value *AObj : AObjs) {
    const IntrinsicInst *AII = isNoAliasIntrinsic(AObj);
    if (!AII)
      return false;

    if (hasNoAliasObjectUnknownScope(AII))
      return false;

    if (NoAliasObjectMayHaveEscaped(AII, BInst, DT))
      return false;
  }
  return true;
}

bool ScopedNoAliasAAResult::isNoAliasByIntrinsic(const Value *AObj,
                                                 const Value *BObj,
                                                 AAQueryInfo &AAQI) {
  const IntrinsicInst *AII = isNoAliasIntrinsic(AObj);
  const IntrinsicInst *BII = isNoAliasIntrinsic(BObj);

  // We only conclude noalias by intrinsic here
  if (!AII && !BII)
    return false;

  if (AII && BII) {
    // Both sides use a noalias object; we can conclude NoAlias if we know they
    // use a different noalias object
    if (isKnownDifferentNoaliasObject(AII, BII, AAQI))
      return true;

    // FIXME: if isKnownSameNoaliasObject(AII, BII), we could strip off
    // (repeatedly) any intrinsics involving that noalias object and try again
    // higher up

    return false;
  } else {
    // One side uses a noalias object; make sure this is side A
    if (!AII) {
      assert(BII);
      std::swap(AII, BII);
      std::swap(AObj, BObj);
    }

    // We can only conclude NoAlias if we know that BObj is not based on the
    // noalias object of AObj

    // Unknown provenance trumps everything
    if (isa<UnknownProvenance>(BObj))
      return false;

    // A direct memory reference is not based on any noalias object
    if (isIdentifiedObject(BObj) || isa<ConstantPointerNull>(BObj))
      return true;

    if (!hasNoAliasObjectUnknownScope(AII)) {
      // For a known scope we can assume that all noalias intrinsics are inside
      // of this function body

      // A value from outside of the function cannot refer to this noalias
      // object
      if (isa<Argument>(BObj))
        return true;

      auto *BInst = dyn_cast<Instruction>(BObj);
      if (BInst && isEscapeSource(BInst)) {
        if (!NoAliasObjectMayHaveEscaped(AII, BInst, DT))
          return true;
      }
    }

    return false;
  }
}

AnalysisKey ScopedNoAliasAA::Key;

bool ScopedNoAliasAAResult::invalidate(
    Function &F, const PreservedAnalyses &PA,
    FunctionAnalysisManager::Invalidator &Inv) {
  if (Inv.invalidate<DominatorTreeAnalysis>(F, PA))
    return true;

  return false;
}

ScopedNoAliasAAResult ScopedNoAliasAA::run(Function &F,
                                           FunctionAnalysisManager &AM) {
  return ScopedNoAliasAAResult(&AM.getResult<DominatorTreeAnalysis>(F));
}

char ScopedNoAliasAAWrapperPass::ID = 0;

INITIALIZE_PASS_BEGIN(ScopedNoAliasAAWrapperPass, "scoped-noalias-aa",
                      "Scoped NoAlias Alias Analysis", false, true)
INITIALIZE_PASS_DEPENDENCY(DominatorTreeWrapperPass)
INITIALIZE_PASS_END(ScopedNoAliasAAWrapperPass, "scoped-noalias-aa",
                    "Scoped NoAlias Alias Analysis", false, true)

ImmutablePass *llvm::createScopedNoAliasAAWrapperPass() {
  return new ScopedNoAliasAAWrapperPass();
}

ScopedNoAliasAAWrapperPass::ScopedNoAliasAAWrapperPass() : ImmutablePass(ID) {}

bool ScopedNoAliasAAWrapperPass::doInitialization(Module &M) {
  Result.reset(new ScopedNoAliasAAResult(nullptr));
  return false;
}

bool ScopedNoAliasAAWrapperPass::doFinalization(Module &M) {
  Result.reset();
  return false;
}

void ScopedNoAliasAAWrapperPass::setDT() {
  if (auto *DTWP = getAnalysisIfAvailable<DominatorTreeWrapperPass>())
    Result->setDT(&DTWP->getDomTree());
}

void ScopedNoAliasAAWrapperPass::getAnalysisUsage(AnalysisUsage &AU) const {
  AU.setPreservesAll();
  AU.addUsedIfAvailable<AAResultsWrapperPass>();
}

//===-- NoAliasUtils.cpp - NoAlias Utility functions ----------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines common noalias metadatt and intrinsic utility functions.
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Utils/NoAliasUtils.h"
#include "llvm/ADT/MapVector.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/MDBuilder.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

#define DEBUG_TYPE "noalias-utils"

bool llvm::propagateAndConnectNoAliasDecl(Function *F) {
  auto *UnknownFunctionScope = F->getMetadata("noalias");
  if (UnknownFunctionScope == nullptr)
    return false;

  SmallVector<IntrinsicInst *, 8> InterestingNoalias;
  SmallMapVector<const AllocaInst *, IntrinsicInst *, 8> KnownAllocaNoAliasDecl;

  auto TrackIfIsUnknownFunctionScope = [&](IntrinsicInst *I, unsigned Index) {
    auto V = I->getOperand(Index);
    if (cast<MetadataAsValue>(V)->getMetadata() == UnknownFunctionScope) {
      InterestingNoalias.push_back(I);
    }
  };

  for (Instruction &I : llvm::instructions(*F)) {
    if (IntrinsicInst *II = dyn_cast<IntrinsicInst>(&I)) {
      switch (II->getIntrinsicID()) {
      case Intrinsic::noalias: {
        TrackIfIsUnknownFunctionScope(II, Intrinsic::NoAliasScopeArg);
        break;
      }
      case Intrinsic::provenance_noalias: {
        TrackIfIsUnknownFunctionScope(II, Intrinsic::ProvenanceNoAliasScopeArg);
        break;
      }
      case Intrinsic::noalias_copy_guard: {
        TrackIfIsUnknownFunctionScope(II, Intrinsic::NoAliasCopyGuardScopeArg);
        break;
      }
      case Intrinsic::noalias_decl: {
        auto *depAlloca = dyn_cast<AllocaInst>(II->getOperand(0));
        if (depAlloca) {
          KnownAllocaNoAliasDecl[depAlloca] = II;
        }
        break;
      }
      default:
        break;
      }
    }
  }

  if (KnownAllocaNoAliasDecl.empty() || InterestingNoalias.empty())
    return false;

  bool Changed = false;
  for (auto *II : InterestingNoalias) {
    SmallVector<const Value *, 4> UO;
    unsigned Index =
        (II->getIntrinsicID() == Intrinsic::noalias
             ? 0
             : (II->getIntrinsicID() == Intrinsic::provenance_noalias ? 1 : 2));
    const int IdentifyPArg[] = {Intrinsic::NoAliasIdentifyPArg,
                                Intrinsic::ProvenanceNoAliasIdentifyPArg,
                                Intrinsic::NoAliasCopyGuardIdentifyPBaseObject};
    const int ScopeArg[] = {Intrinsic::NoAliasScopeArg,
                            Intrinsic::ProvenanceNoAliasScopeArg,
                            Intrinsic::NoAliasCopyGuardScopeArg};
    const int NoAliasDeclArg[] = {Intrinsic::NoAliasNoAliasDeclArg,
                                  Intrinsic::ProvenanceNoAliasNoAliasDeclArg,
                                  Intrinsic::NoAliasCopyGuardNoAliasDeclArg};
    const int ObjIdArg[] = {Intrinsic::NoAliasIdentifyPObjIdArg,
                            Intrinsic::ProvenanceNoAliasIdentifyPObjIdArg, -1};

    llvm::getUnderlyingObjects(II->getOperand(IdentifyPArg[Index]), UO);
    if (UO.size() != 1) {
      // Multiple objects possible - It would be nice to propagate, but we do
      // not do it yet. That is ok as the unknown function scope assumes more
      // aliasing.
      LLVM_DEBUG(llvm::dbgs()
                 << "WARNING: no llvm.noalias.decl reconnect accross "
                    "PHI/select - YET ("
                 << UO.size() << " underlying objects)\n");
      continue;
    }

    if (auto *UA = dyn_cast<AllocaInst>(UO[0])) {
      auto it = KnownAllocaNoAliasDecl.find(UA);
      if (it != KnownAllocaNoAliasDecl.end()) {
        Instruction *Decl = it->second;
        // found a simple matching declaration - propagate
        II->setOperand(ScopeArg[Index],
                       Decl->getOperand(Intrinsic::NoAliasDeclScopeArg));
        II->setOperand(NoAliasDeclArg[Index], Decl);

        auto ObjIdIndex = ObjIdArg[Index];
        if (ObjIdIndex != -1) {
          II->setOperand(ObjIdIndex,
                         Decl->getOperand(Intrinsic::NoAliasDeclObjIdArg));
        }
        Changed = true;
      } else if (UnknownFunctionScope && isa<AllocaInst>(UA)) {
        if (cast<MetadataAsValue>(II->getOperand(ScopeArg[Index]))
                ->getMetadata() == UnknownFunctionScope) {
          // we have an alloca, but no llvm.noalias.decl and we have unknown
          // function scope This is an indication of a temporary that (through a
          // pointer or reference to a restrict pointer) introduces restrict.
          // - the unknown scope is too broad for these cases
          // - conceptually, the scope should be the lifetime of the local, but
          // we don't have that information
          // - the real restrictness should have been brought in through the
          // 'depends on' relationship
          // -> so we fall back on the 'depends on' and remove the restrictness
          // information at this level.
          LLVM_DEBUG(
              llvm::dbgs()
              << "- Temporary noalias object (without llvm.noalias.decl) "
                 "detected. Ignore restrictness: "
              << *II << "\n");
          II->replaceAllUsesWith(II->getOperand(0));
          II->eraseFromParent();
          Changed = true;
        }
      }
    } else {
#if !defined(NDEBUG)
      if (isa<SelectInst>(UO[0]) || isa<PHINode>(UO[0])) {
        // Multiple objects possible - It would be nice to propagate, but we do
        // not do it yet. That is ok as the unknown function scope assumes more
        // aliasing.
        LLVM_DEBUG(llvm::dbgs()
                   << "WARNING: no llvm.noalias.decl reconnect accross "
                      "PHI/select - YET: "
                   << *UO[0] << "\n");
      }
#endif
    }
  }
  return Changed;
}

void llvm::cloneNoAliasDeclIntoExit(Loop *L) {
  // We have loop local llvm.noalias.decl. If they are used by code that is
  // considered to be outside the loop, the must go through the latch block.
  // We duplicate the llvm.noalias.decl to the latch block, so that migrated
  // code can still locally benefit from the noalias information. But it will
  // get disconnected from the information inside the loop body itself.
  SmallVector<BasicBlock *, 4> UniqueExitBlocks;
  L->getUniqueExitBlocks(UniqueExitBlocks);
  for (auto *EB : UniqueExitBlocks) {
    SmallVector<std::pair<Instruction *, PHINode *>, 6> ClonedNoAlias;

    for (auto &PN : EB->phis()) {
      Value *V = PN.getIncomingValue(0);
      while (true) {
        if (IntrinsicInst *II = dyn_cast<IntrinsicInst>(V)) {
          if (II->getIntrinsicID() == Intrinsic::noalias_decl) {
            ClonedNoAlias.emplace_back(II->clone(), &PN);
          }
        } else if (PHINode *PN2 = dyn_cast<PHINode>(V)) {
          if (PN2->getNumIncomingValues() == 1) {
            // look through phi ( phi (.. ) ) in case of nested loops
            V = PN2->getIncomingValue(0);
            continue;
          }
        }
        break;
      }
    }

    auto IP = EB->getFirstInsertionPt();
    for (auto P : ClonedNoAlias) {
      EB->getInstList().insert(IP, P.first);
    }
    for (auto P : ClonedNoAlias) {
      P.second->replaceAllUsesWith(P.first);
    }
  }
}

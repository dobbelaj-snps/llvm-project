//===- ScopedNoAliasAA.h - Scoped No-Alias Alias Analysis -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
/// \file
/// This is the interface for a metadata-based scoped no-alias analysis.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_ANALYSIS_SCOPEDNOALIASAA_H
#define LLVM_ANALYSIS_SCOPEDNOALIASAA_H

#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Pass.h"
#include "llvm/Support/Compiler.h"
#include <memory>

namespace llvm {
class DominatorTree;

class Function;
class MDNode;
class MemoryLocation;

/// A simple AA result which uses scoped-noalias metadata to answer queries.
class ScopedNoAliasAAResult : public AAResultBase {
public:
  ScopedNoAliasAAResult(DominatorTree *DT) : AAResultBase(), DT(DT) {}

  /// Handle invalidation events from the new pass manager.
  ///
  /// By definition, this result is stateless and so remains valid.
  bool invalidate(Function &F, const PreservedAnalyses &PA,
                  FunctionAnalysisManager::Invalidator &Inv);

  LLVM_ABI AliasResult alias(const MemoryLocation &LocA,
                             const MemoryLocation &LocB, AAQueryInfo &AAQI,
                             const Instruction *CtxI);
  LLVM_ABI ModRefInfo getModRefInfo(const CallBase *Call,
                                    const MemoryLocation &Loc,
                                    AAQueryInfo &AAQI);
  LLVM_ABI ModRefInfo getModRefInfo(const CallBase *Call1,
                                    const CallBase *Call2, AAQueryInfo &AAQI);

  LLVM_ABI static void
  collectScopedDomains(const MDNode *NoAlias,
                       SmallPtrSetImpl<const MDNode *> &Domains);

  LLVM_ABI static bool mayAliasInScopes(const MDNode *Scopes,
                                        const MDNode *NoAlias);

  // FIXME: This interface can be removed once the legacy-pass-manager support
  // is removed.
  void setDT(DominatorTree *DT) { this->DT = DT; }

private:
  // Auxiliary method: for the given two (most recent compatible) noalias
  // provenances, can we rule out that they alias?
  bool isNoAliasByIntrinsic(const Value *AObj, const Value *BObj,
                            AAQueryInfo &AAQI);
  // The main method to query for non-aliasing based on noalias intrinsics in
  // the provenance of pointer values between sides A and B.
  bool noAliasByIntrinsic(const MDNode *ANoAlias, ArrayRef<const Value *> APtrs,
                          const MDNode *BNoAlias, ArrayRef<const Value *> BPtrs,
                          AAQueryInfo &AAQI);
  // A simplified (less powerful) method where we do not know the pointer values
  // used by side B, we just know the instruction where the memory access.
  bool noAliasByIntrinsic(const MDNode *ANoAlias, ArrayRef<const Value *> APtrs,
                          const MDNode *BNoAlias, const Instruction *BInst);

  DominatorTree *DT;
};

/// Analysis pass providing a never-invalidated alias analysis result.
class ScopedNoAliasAA : public AnalysisInfoMixin<ScopedNoAliasAA> {
  friend AnalysisInfoMixin<ScopedNoAliasAA>;

  LLVM_ABI static AnalysisKey Key;

public:
  using Result = ScopedNoAliasAAResult;

  LLVM_ABI ScopedNoAliasAAResult run(Function &F, FunctionAnalysisManager &AM);
};

/// Legacy wrapper pass to provide the ScopedNoAliasAAResult object.
class LLVM_ABI ScopedNoAliasAAWrapperPass : public ImmutablePass {
  std::unique_ptr<ScopedNoAliasAAResult> Result;

public:
  static char ID;

  ScopedNoAliasAAWrapperPass();

  ScopedNoAliasAAResult &getResult() {
    setDT();
    return *Result;
  }
  const ScopedNoAliasAAResult &getResult() const { return *Result; }

  bool doInitialization(Module &M) override;
  bool doFinalization(Module &M) override;
  void getAnalysisUsage(AnalysisUsage &AU) const override;

private:
  void setDT();
};

//===--------------------------------------------------------------------===//
//
// createScopedNoAliasAAWrapperPass - This pass implements metadata-based
// scoped noalias analysis.
//
LLVM_ABI ImmutablePass *createScopedNoAliasAAWrapperPass();

} // end namespace llvm

#endif // LLVM_ANALYSIS_SCOPEDNOALIASAA_H

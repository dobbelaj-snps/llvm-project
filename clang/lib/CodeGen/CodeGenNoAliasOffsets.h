//===--- CodeGenNoAliasOffsets.h --------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This class manages the NoAlias Copyguard offset information, that tracks the
// locations of noalias (restrict) pointers in a struct.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_CLANG_LIB_CODEGEN_CODEGENNOALIASOFFSETS_H
#define LLVM_CLANG_LIB_CODEGEN_CODEGENNOALIASOFFSETS_H

#include "clang/AST/Type.h"
#include "clang/Basic/LLVM.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/PointerIntPair.h"
#include "llvm/IR/MDBuilder.h"
#include "llvm/IR/Metadata.h"

namespace clang {
class ASTContext;

namespace CodeGen {
/// CodeGenNoAliasOffsets - This class organizes the cross-module state that is
/// used while lowering AST types to LLVM types.
class CodeGenNoAliasOffsets {
  ASTContext &Context;

  // MDHelper - Helper for creating metadata.
  llvm::MDBuilder MDHelper;

  using Key = llvm::PointerIntPair<const Type *, 1, bool>;
  /// NoAliasOffsetsMetadataCache - This maps clang::Types to llvm::MDNodes
  /// describing them for struct assignments.
  llvm::DenseMap<Key, llvm::MDNode *> NoAliasOffsetsMetadataCache;

public:
  CodeGenNoAliasOffsets(ASTContext &Ctx, llvm::Module &M);
  ~CodeGenNoAliasOffsets();

  /// getMDNoAliasOffsets - Get metadata used to describe the locations of
  /// restrict pointers in structs/unions/arrays.
  llvm::MDNode *getMDNoAliasOffsets(QualType QTy);
  llvm::MDNode *getMDNoAliasOffsets(const Type *Ty, bool IsRestrict);
};

} // end namespace CodeGen
} // end namespace clang
#endif

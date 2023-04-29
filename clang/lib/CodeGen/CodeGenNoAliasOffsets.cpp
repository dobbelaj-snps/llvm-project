//===--- CodeGenNoAliasOffsets.cpp ------------------------------*- C++ -*-===//
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

#include "CodeGenNoAliasOffsets.h"
#include "clang/AST/ASTContext.h"
#include "clang/AST/Attr.h"
#include "clang/AST/Mangle.h"
#include "clang/AST/RecordLayout.h"
#include "clang/Basic/CodeGenOptions.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Type.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"

#define DEBUG_TYPE "CodeGenNoAliasOffsets"
using namespace clang;
using namespace CodeGen;

using NoAliasOffsetsField = llvm::MDBuilder::NoAliasOffsetsField;

class NoAliasOffsets {
public:
  NoAliasOffsets(int64_t GlobalSize) : GlobalSize(GlobalSize) {}

  void add(NoAliasOffsetsField Rhs);
  bool empty() const { return Items.empty(); }

  int64_t GlobalSize = 0;
  SmallVector<NoAliasOffsetsField, 4> Items;
};

void NoAliasOffsets::add(NoAliasOffsetsField Rhs) {
  if (!Rhs.isValid())
    return;

  // Try to simplify the dependency.
  while (Rhs.tryPullUp())
    ;

  // Now, let's try to merge the new field with the last available field.
  if (!Items.empty())
    if (Items.back().tryMerge(Rhs))
      return;

  Items.push_back(Rhs);
}

CodeGenNoAliasOffsets::CodeGenNoAliasOffsets(ASTContext &Ctx, llvm::Module &M)
    : Context(Ctx), MDHelper(M.getContext()) {}

CodeGenNoAliasOffsets::~CodeGenNoAliasOffsets() {}

llvm::MDNode *CodeGenNoAliasOffsets::getMDNoAliasOffsets(QualType QTy) {
  return getMDNoAliasOffsets(Context.getCanonicalType(QTy).getTypePtr(),
                             QTy.isRestrictQualified());
}

llvm::MDNode *CodeGenNoAliasOffsets::getMDNoAliasOffsets(const Type *Ty,
                                                         bool IsRestrict) {
  Key K(Ty, IsRestrict);
  //@ FIXME: should we check the cache after handling the restrict ?
  // Or should we add the restrict bool ?
  {
    auto It = NoAliasOffsetsMetadataCache.find(K);
    if (It != NoAliasOffsetsMetadataCache.end()) {
      return It->second;
    }
  }

  int64_t Size = Context.getTypeSizeInChars(Ty).getQuantity();
  NoAliasOffsets TheOffsets(Size);

  if (const auto *RecTy = Ty->getAs<RecordType>()) {
    RecordDecl *RD = RecTy->getDecl();
    const ASTRecordLayout &ARL = Context.getASTRecordLayout(RD);

    // FIXME: should we recurse into all structures or only those that
    // contain restrict ?
    for (FieldDecl *FD : RD->fields()) {
      auto FieldDelta = ARL.getFieldOffset(FD->getFieldIndex()) / 8;
      TheOffsets.add(NoAliasOffsetsField(
          FieldDelta, getMDNoAliasOffsets(FD->getType()), 1));
    }
  } else if (isa<PointerType>(Ty)) {
    if (IsRestrict) {
      int64_t PtrSize = Context.getTypeSizeInChars(Ty).getQuantity();
      TheOffsets.add(NoAliasOffsetsField(0, PtrSize, 1));
    }
  } else if (auto *ATy = dyn_cast<ArrayType>(Ty)) {
    int64_t Count = 0; // Unbounded array
    if (auto CATy = dyn_cast<ConstantArrayType>(Ty))
      Count = CATy->getSize().getSExtValue(); // 0 means unbounded

    auto *ElemTy = ATy->getElementType().getCanonicalType().getTypePtr();
    TheOffsets.add(
        NoAliasOffsetsField(0, getMDNoAliasOffsets(ElemTy, IsRestrict), Count));
  } else {
    // not something we are interested in
  }

  auto *MD =
      MDHelper.createNoAliasOffsets(TheOffsets.GlobalSize, TheOffsets.Items);
  return NoAliasOffsetsMetadataCache[K] = MD;
}

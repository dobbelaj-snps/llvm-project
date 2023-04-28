//===- llvm/Transforms/Utils/NoAliasUtils.h - NoAlias utilities -*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines utilities for noalias metadata and intrinsics.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_UTILS_NOALIASUTILS_H
#define LLVM_TRANSFORMS_UTILS_NOALIASUTILS_H

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"

namespace llvm {
class Function;
class Loop;

/// Connect llvm.noalias.decl to noalias/provenance.noalias intrinsics that are
/// associated with the unknown function scope and based on the same alloca.
/// At the same time, propagate the p.addr, p.objId and p.scope.
bool propagateAndConnectNoAliasDecl(Function *F);

/// Clone the llvm.noalias.decl intrinsics that are defined inside the loop
/// and used outside the loop into the exit blocks.
void cloneNoAliasDeclIntoExit(Loop *L);
} // end namespace llvm

#endif // LLVM_TRANSFORMS_UTILS_NOALIASUTILS_H

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

namespace llvm {
class Function;

/// Connect llvm.noalias.decl to noalias/provenance.noalias intrinsics that are
/// associated with the unknown function scope and based on the same alloca.
/// At the same time, propagate the p.addr, p.objId and p.scope.
bool propagateAndConnectNoAliasDecl(Function *F);
} // end namespace llvm

#endif // LLVM_TRANSFORMS_UTILS_NOALIASUTILS_H

//===---- llvm/MDBuilder.h - Builder for LLVM metadata ----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the MDBuilder class, which is used as a convenient way to
// create LLVM metadata with a consistent and simplified interface.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_IR_MDBUILDER_H
#define LLVM_IR_MDBUILDER_H

#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/GlobalValue.h"
#include "llvm/Support/DataTypes.h"
#include <utility>

namespace llvm {

class APInt;
template <typename T> class ArrayRef;
class LLVMContext;
class Constant;
class ConstantAsMetadata;
class MDNode;
class MDString;
class Metadata;

class MDBuilder {
  LLVMContext &Context;

public:
  MDBuilder(LLVMContext &context) : Context(context) {}

  /// Return the given string as metadata.
  MDString *createString(StringRef Str);

  /// Return the given constant as metadata.
  ConstantAsMetadata *createConstant(Constant *C);

  //===------------------------------------------------------------------===//
  // FPMath metadata.
  //===------------------------------------------------------------------===//

  /// Return metadata with the given settings.  The special value 0.0
  /// for the Accuracy parameter indicates the default (maximal precision)
  /// setting.
  MDNode *createFPMath(float Accuracy);

  //===------------------------------------------------------------------===//
  // Prof metadata.
  //===------------------------------------------------------------------===//

  /// Return metadata containing two branch weights.
  MDNode *createBranchWeights(uint32_t TrueWeight, uint32_t FalseWeight);

  /// Return metadata containing a number of branch weights.
  MDNode *createBranchWeights(ArrayRef<uint32_t> Weights);

  /// Return metadata specifying that a branch or switch is unpredictable.
  MDNode *createUnpredictable();

  /// Return metadata containing the entry \p Count for a function, a boolean
  /// \Synthetic indicating whether the counts were synthetized, and the
  /// GUIDs stored in \p Imports that need to be imported for sample PGO, to
  /// enable the same inlines as the profiled optimized binary
  MDNode *createFunctionEntryCount(uint64_t Count, bool Synthetic,
                                   const DenseSet<GlobalValue::GUID> *Imports);

  /// Return metadata containing the section prefix for a function.
  MDNode *createFunctionSectionPrefix(StringRef Prefix);

  /// Return metadata containing the pseudo probe descriptor for a function.
  MDNode *createPseudoProbeDesc(uint64_t GUID, uint64_t Hash, Function *F);

  //===------------------------------------------------------------------===//
  // Range metadata.
  //===------------------------------------------------------------------===//

  /// Return metadata describing the range [Lo, Hi).
  MDNode *createRange(const APInt &Lo, const APInt &Hi);

  /// Return metadata describing the range [Lo, Hi).
  MDNode *createRange(Constant *Lo, Constant *Hi);

  //===------------------------------------------------------------------===//
  // Callees metadata.
  //===------------------------------------------------------------------===//

  /// Return metadata indicating the possible callees of indirect
  /// calls.
  MDNode *createCallees(ArrayRef<Function *> Callees);

  //===------------------------------------------------------------------===//
  // Callback metadata.
  //===------------------------------------------------------------------===//

  /// Return metadata describing a callback (see llvm::AbstractCallSite).
  MDNode *createCallbackEncoding(unsigned CalleeArgNo, ArrayRef<int> Arguments,
                                 bool VarArgsArePassed);

  /// Merge the new callback encoding \p NewCB into \p ExistingCallbacks.
  MDNode *mergeCallbackEncodings(MDNode *ExistingCallbacks, MDNode *NewCB);

  //===------------------------------------------------------------------===//
  // AA metadata.
  //===------------------------------------------------------------------===//

protected:
  /// Return metadata appropriate for a AA root node (scope or TBAA).
  /// Each returned node is distinct from all other metadata and will never
  /// be identified (uniqued) with anything else.
  MDNode *createAnonymousAARoot(StringRef Name = StringRef(),
                                MDNode *Extra = nullptr);

public:
  /// Return metadata appropriate for a TBAA root node. Each returned
  /// node is distinct from all other metadata and will never be identified
  /// (uniqued) with anything else.
  MDNode *createAnonymousTBAARoot() {
    return createAnonymousAARoot();
  }

  /// Return metadata appropriate for an alias scope domain node.
  /// Each returned node is distinct from all other metadata and will never
  /// be identified (uniqued) with anything else.
  MDNode *createAnonymousAliasScopeDomain(StringRef Name = StringRef()) {
    return createAnonymousAARoot(Name);
  }

  /// Return metadata appropriate for an alias scope root node.
  /// Each returned node is distinct from all other metadata and will never
  /// be identified (uniqued) with anything else.
  MDNode *createAnonymousAliasScope(MDNode *Domain,
                                    StringRef Name = StringRef()) {
    return createAnonymousAARoot(Name, Domain);
  }

  /// Return metadata appropriate for a TBAA root node with the given
  /// name.  This may be identified (uniqued) with other roots with the same
  /// name.
  MDNode *createTBAARoot(StringRef Name);

  /// Return metadata appropriate for an alias scope domain node with
  /// the given name. This may be identified (uniqued) with other roots with
  /// the same name.
  MDNode *createAliasScopeDomain(StringRef Name);

  /// Return metadata appropriate for an alias scope node with
  /// the given name. This may be identified (uniqued) with other scopes with
  /// the same name and domain.
  MDNode *createAliasScope(StringRef Name, MDNode *Domain);

  /// Return metadata for a non-root TBAA node with the given name,
  /// parent in the TBAA tree, and value for 'pointsToConstantMemory'.
  MDNode *createTBAANode(StringRef Name, MDNode *Parent,
                         bool isConstant = false);

  struct TBAAStructField {
    uint64_t Offset;
    uint64_t Size;
    MDNode *Type;
    TBAAStructField(uint64_t Offset, uint64_t Size, MDNode *Type) :
      Offset(Offset), Size(Size), Type(Type) {}
  };

  /// Return metadata for a tbaa.struct node with the given
  /// struct field descriptions.
  MDNode *createTBAAStructNode(ArrayRef<TBAAStructField> Fields);

  /// Return metadata for a TBAA struct node in the type DAG
  /// with the given name, a list of pairs (offset, field type in the type DAG).
  MDNode *
  createTBAAStructTypeNode(StringRef Name,
                           ArrayRef<std::pair<MDNode *, uint64_t>> Fields);

  /// Return metadata for a TBAA scalar type node with the
  /// given name, an offset and a parent in the TBAA type DAG.
  MDNode *createTBAAScalarTypeNode(StringRef Name, MDNode *Parent,
                                   uint64_t Offset = 0);

  /// Return metadata for a TBAA tag node with the given
  /// base type, access type and offset relative to the base type.
  MDNode *createTBAAStructTagNode(MDNode *BaseType, MDNode *AccessType,
                                  uint64_t Offset, bool IsConstant = false);

  /// Return metadata for a TBAA type node in the TBAA type DAG with the
  /// given parent type, size in bytes, type identifier and a list of fields.
  MDNode *createTBAATypeNode(MDNode *Parent, uint64_t Size, Metadata *Id,
                             ArrayRef<TBAAStructField> Fields =
                                 ArrayRef<TBAAStructField>());

  /// Return metadata for a TBAA access tag with the given base type,
  /// final access type, offset of the access relative to the base type, size of
  /// the access and flag indicating whether the accessed object can be
  /// considered immutable for the purposes of the TBAA analysis.
  MDNode *createTBAAAccessTag(MDNode *BaseType, MDNode *AccessType,
                              uint64_t Offset, uint64_t Size,
                              bool IsImmutable = false);

  /// Return mutable version of the given mutable or immutable TBAA
  /// access tag.
  MDNode *createMutableTBAAAccessTag(MDNode *Tag);

  /// Return metadata containing an irreducible loop header weight.
  MDNode *createIrrLoopHeaderWeight(uint64_t Weight);

  struct NoAliasOffsetsField {
    int64_t Offset = 0;
    int64_t Size = 0;
    const MDNode *Record = nullptr;
    int64_t Count = 0;

    NoAliasOffsetsField(int64_t Offset, int64_t Size, int64_t Count)
        : Offset(Offset), Size(Size), Count(Count) {}
    NoAliasOffsetsField(int64_t Offset, const MDNode *Record, int64_t Count)
        : Offset(Offset), Record(Record), Count(Count) {}

    bool isValid() const { return Record || Size; }
    int64_t getFieldSize() const;
    bool tryPullUp();
    bool tryMerge(const NoAliasOffsetsField &Rhs);
  };

  // NoAliasOffsets metadata looks like:
  // { GlobalSize, [offset, (ptrsize | !struct), count]+ }
  class NoAliasOffsetsNode {
    const MDNode *Node;

    int64_t getOpAsInt64(unsigned Index) const;

  public:
    explicit NoAliasOffsetsNode(const MDNode *N) : Node(N) {
      assert(isValid(N) && "Invalid NoAliasOffsets format");
    }

    // Rough check for basic properties of a NoAliasOffsetsNode.
    // Can also be used to differentiate the new style from the old indices.
    static bool isValid(const MDNode *);

    std::size_t getNumEntries() const;
    NoAliasOffsetsField getField(unsigned Index) const;
    int64_t getGlobalSize() const;
  };

  /// Return metadata for a NoAliasOffsets description.
  MDNode *createNoAliasOffsets(uint64_t Size,
                               ArrayRef<NoAliasOffsetsField> Fields);
};

} // end namespace llvm

#endif

; RUN: llvm-as < %s | llvm-dis | FileCheck %s

; Make sure the noalias intrinsics have the expected captures attributes.

; CHECK: declare ptr @llvm.noalias.decl.p0.p0.i64(ptr captures(none), i64, metadata)
declare ptr @llvm.noalias.decl.p0.p0.i64(ptr, i64, metadata)

; CHECK: declare ptr @llvm.noalias.p0.p0.p0.i64(ptr, ptr captures(none), ptr captures(none), i64, metadata)
declare ptr @llvm.noalias.p0.p0.p0.i64(ptr, ptr, ptr, i64, metadata)

; CHECK: declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr, ptr captures(none), ptr captures(none), ptr captures(none), i64, metadata)
declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr, ptr, ptr, ptr, i64, metadata)

; CHECK: declare ptr @llvm.noalias.copy.guard.p0.p0(ptr, ptr captures(none), metadata, metadata)
declare ptr @llvm.noalias.copy.guard.p0.p0(ptr, ptr, metadata, metadata)

; CHECK: declare ptr @llvm.experimental.ptr.provenance.p0.p0(ptr, ptr)
declare ptr @llvm.experimental.ptr.provenance.p0.p0(ptr, ptr)

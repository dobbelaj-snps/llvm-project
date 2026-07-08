; RUN: not llvm-as %s -o /dev/null 2>&1 | FileCheck %s

declare ptr @llvm.noalias.p0.p0.p0.i64(ptr, ptr, ptr, i64, metadata)
declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr, ptr, ptr, ptr, i64, metadata)

; CHECK: llvm.noalias with unknown scope must have a non-null %p.addr
define void @noalias_unknown_scope_null_paddr(ptr %arg0) !noalias !0 {
  %na = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %arg0, ptr null, ptr null, i64 0, metadata !0)
  ret void
}

; CHECK: llvm.provenance.noalias with unknown scope must have a non-null %p.addr
define void @provenance_unknown_scope_null_paddr(ptr %arg0) !noalias !0 {
  %prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr null, ptr null, ptr undef, i64 0, metadata !0)
  ret void
}

!0 = !{!1}
!1 = distinct !{!1, !2, !"unknown scope"}
!2 = distinct !{!2, !"test"}

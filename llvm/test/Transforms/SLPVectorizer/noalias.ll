; RUN: opt -S < %s -passes=slp-vectorizer -slp-max-reg-size=128 -slp-min-reg-size=128 | FileCheck %s

; FIXME: in the broader interpretation of ptr_provenance, it is not always valid to just remove the provenance (and noalias) annotation.
; BUT: for this case, that should still be valid.

; SLP vectorization across a @llvm.provenance.noalias and provenance

; Function Attrs: inaccessiblememonly nounwind willreturn
declare void @llvm.sideeffect() #0

define void @test(ptr %p) {
; CHECK-LABEL: @test(
; CHECK-NEXT:    [[P0:%.*]] = getelementptr float, ptr [[P:%.*]], i64 0
; CHECK-NEXT:    call void @llvm.sideeffect()
; CHECK-NEXT:    call void @llvm.sideeffect()
; CHECK-NEXT:    [[TMP2:%.*]] = load <4 x float>, ptr [[P0]], align 4
; CHECK-NEXT:    store <4 x float> [[TMP2]], ptr [[P0]], align 4
; CHECK-NEXT:    ret void
;
  %p1.decl = tail call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !0)
  %p0 = getelementptr float, ptr %p, i64 0
  %p1 = getelementptr float, ptr %p, i64 1
  %prov.p1 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %p1, ptr %p1.decl, ptr null, ptr undef, i32 0, metadata !0), !noalias !0
  %p2 = getelementptr float, ptr %p, i64 2
  %p3 = getelementptr float, ptr %p, i64 3
  %l0 = load float, ptr %p0, !noalias !0
  %l1 = load float, ptr %p1, ptr_provenance ptr %prov.p1, !noalias !0
  %l2 = load float, ptr %p2, !noalias !0
  call void @llvm.sideeffect()
  %l3 = load float, ptr %p3, !noalias !0
  store float %l0, ptr %p0, !noalias !0
  call void @llvm.sideeffect()
  store float %l1, ptr %p1, ptr_provenance ptr %prov.p1, !noalias !0
  store float %l2, ptr %p2, !noalias !0
  store float %l3, ptr %p3, !noalias !0
  ret void
}

; Function Attrs: argmemonly nounwind
declare ptr @llvm.noalias.decl.p0.p0.i32(ptr, i32, metadata) #1

; Function Attrs: nounwind readnone speculatable
declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr, ptr, ptr, ptr, i32, metadata) #2

attributes #0 = { inaccessiblememonly nounwind willreturn }
attributes #1 = { argmemonly nounwind }
attributes #2 = { nounwind readnone speculatable }

!0 = !{!1}
!1 = distinct !{!1, !2, !"test_f: p"}
!2 = distinct !{!2, !"test_f"}

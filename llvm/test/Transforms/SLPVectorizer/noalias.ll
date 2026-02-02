; RUN: opt -S < %s -passes=slp-vectorizer -slp-max-reg-size=128 -slp-min-reg-size=128 | FileCheck %s

; Function Attrs: inaccessiblememonly nounwind willreturn
declare void @llvm.sideeffect() #0

define void @test_mixed(ptr %p) {
; CHECK-LABEL: @test_mixed(
; CHECK-NEXT:    [[P0:%.*]] = getelementptr float, ptr [[P:%.*]], i64 0
; CHECK-NEXT:    call void @llvm.sideeffect()
; CHECK-NEXT:    call void @llvm.sideeffect()
; CHECK-NEXT:    [[TMP1:%.*]] = load <4 x float>, ptr [[P0]], ptr_provenance ptr unknown_provenance, align 4, !noalias !0
; CHECK-NEXT:    store <4 x float> [[TMP1]], ptr [[P0]], ptr_provenance ptr unknown_provenance, align 4, !noalias !0
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

; Test with same ptr_provenance operand for all loads and stores
define void @test_same_provenance(ptr %p) {
; CHECK-LABEL: @test_same_provenance(
; CHECK-NEXT:    [[P_DECL:%.*]] = tail call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !0)
; CHECK-NEXT:    [[PROV_P:%.*]] = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr [[P:%.*]], ptr [[P_DECL]], ptr null, ptr undef, i32 0, metadata !0), !noalias !0
; CHECK-NEXT:    [[P0:%.*]] = getelementptr float, ptr [[PROV_P]], i64 0
; CHECK-NEXT:    call void @llvm.sideeffect()
; CHECK-NEXT:    call void @llvm.sideeffect()
; CHECK-NEXT:    [[TMP1:%.*]] = load <4 x float>, ptr [[P0]], ptr_provenance ptr [[PROV_P]], align 4, !noalias !0
; CHECK-NEXT:    store <4 x float> [[TMP1]], ptr [[P0]], ptr_provenance ptr [[PROV_P]], align 4, !noalias !0
; CHECK-NEXT:    ret void
;
  %p.decl = tail call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !0)
  %prov.p = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %p, ptr %p.decl, ptr null, ptr undef, i32 0, metadata !0), !noalias !0
  %p0 = getelementptr float, ptr %prov.p, i64 0
  %p1 = getelementptr float, ptr %prov.p, i64 1
  %p2 = getelementptr float, ptr %prov.p, i64 2
  %p3 = getelementptr float, ptr %prov.p, i64 3
  %l0 = load float, ptr %p0, ptr_provenance ptr %prov.p, !noalias !0
  %l1 = load float, ptr %p1, ptr_provenance ptr %prov.p, !noalias !0
  %l2 = load float, ptr %p2, ptr_provenance ptr %prov.p, !noalias !0
  call void @llvm.sideeffect()
  %l3 = load float, ptr %p3, ptr_provenance ptr %prov.p, !noalias !0
  store float %l0, ptr %p0, ptr_provenance ptr %prov.p, !noalias !0
  call void @llvm.sideeffect()
  store float %l1, ptr %p1, ptr_provenance ptr %prov.p, !noalias !0
  store float %l2, ptr %p2, ptr_provenance ptr %prov.p, !noalias !0
  store float %l3, ptr %p3, ptr_provenance ptr %prov.p, !noalias !0
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

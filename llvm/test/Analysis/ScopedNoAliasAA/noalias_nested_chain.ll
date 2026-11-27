; RUN: opt < %s -aa-pipeline=basic-aa,scoped-noalias-aa -passes=aa-eval -evaluate-aa-metadata -print-all-alias-modref-info -disable-output 2>&1 | FileCheck %s

; Chain notation: head-first; head = outermost intrinsic, closest to
; the load/store. E.g. [pA, pB] - pA is head, pB is tail.
;   [pA, pB, <V>]        - V ends the chain; it is not a noalias object
;   [pA(p.addr=%X), pB]  - %p.addr operand of pA is %X (AP annotation)
;   |pX|                 - filtered out by scope
;   {pB | pC}            - PHI joining two chains

@global = global ptr null

declare ptr @llvm.noalias.decl.p0.p0.i64(ptr, i64, metadata) nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: readwrite)

declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr, ptr, ptr, ptr, i64, metadata) nocallback nofree nosync nounwind speculatable willreturn memory(none)

; [pA] <-> [pB]
define void @test_chain_different_heads(ptr %arg0, ptr %arg1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pA.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov, !noalias !11
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  store i32 222, ptr %arg1, ptr_provenance ptr %pB.prov, !noalias !11
  ret void
}
; CHECK-LABEL: Function: test_chain_different_heads:
; CHECK:  NoAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pB.prov, align 4, !noalias !5 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov, align 4, !noalias !5

; [pA, pB] <-> [pA, pC]
define void @test_chain_same_head_different_tail(ptr %arg0, ptr %arg1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !15
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, !noalias !15
  ret void
}
; CHECK-LABEL: Function: test_chain_same_head_different_tail:
; CHECK:  NoAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, align 4, !noalias !7 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !7

; [pA, pC] <-> [pA, pC]
define void @test_chain_same_head_same_tail(ptr %arg0, ptr %arg1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pC.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !13
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov1, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !13
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !13
  %pC.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !13
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov2, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !13
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, !noalias !13
  ret void
}
; CHECK-LABEL: Function: test_chain_same_head_same_tail:
; CHECK:  MayAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, align 4, !noalias !5 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !5

; [pA, pB, pC] <-> [pA, pB, pD]
define void @test_chain_same_head_different_tail_deep(ptr %arg0, ptr %arg1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pD.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !7)
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !12
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !12
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov1, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !12
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !12
  %pD.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pD.decl, ptr null, ptr undef, i64 0, metadata !7), !noalias !12
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pD.prov, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !12
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov2, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !12
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, !noalias !12
  ret void
}
; CHECK-LABEL: Function: test_chain_same_head_different_tail_deep:
; CHECK:  NoAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, align 4, !noalias !9 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !9

; [pA, pB, pC] <-> [pA, pB, pC]
define void @test_chain_same_head_same_tail_deep(ptr %arg0, ptr %arg1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pC.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov1, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov1, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !15
  %pC.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov2, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov2, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, !noalias !15
  ret void
}
; CHECK-LABEL: Function: test_chain_same_head_same_tail_deep:
; CHECK:  MayAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, align 4, !noalias !7 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !7

; [pA(p.addr=%pA.addr), pB] <-> [pA(p.addr=%pA.addr), pC]
define void @test_compare_known_scope_p_addr_equal_different_tail(ptr %arg0, ptr %arg1) {
entry:
  %pA.addr = alloca ptr
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %pA.addr, i64 0, metadata !0)
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov, ptr %pA.decl, ptr %pA.addr, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !15
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr %pA.decl, ptr %pA.addr, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, !noalias !15
  ret void
}
; CHECK-LABEL: Function: test_compare_known_scope_p_addr_equal_different_tail:
; CHECK:  NoAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, align 4, !noalias !7 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !7

; [pA(p.addr=%pA.addr), pB] <-> [pA(p.addr=%pA.addr), pB]
define void @test_compare_known_scope_p_addr_equal_same_tail(ptr %arg0, ptr %arg1) {
entry:
  %pA.addr = alloca ptr
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %pA.addr, i64 0, metadata !0)
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov1, ptr %pA.decl, ptr %pA.addr, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !11
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov2, ptr %pA.decl, ptr %pA.addr, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, !noalias !11
  ret void
}
; CHECK-LABEL: Function: test_compare_known_scope_p_addr_equal_same_tail:
; CHECK:  MayAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, align 4, !noalias !5 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !5

; [pA(p.addr=%pA.addr), pB] <-> [pA(p.addr=%pA.addr.gep), pC]
define void @test_compare_known_scope_p_addr_must_alias_different_tail(ptr %arg0, ptr %arg1) {
entry:
  %pA.addr = alloca ptr
  %pA.addr.gep = getelementptr inbounds ptr, ptr %pA.addr, i64 0
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %pA.addr, i64 0, metadata !0)
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov, ptr %pA.decl, ptr %pA.addr, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !15
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr %pA.decl, ptr %pA.addr.gep, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, !noalias !15
  ret void
}
; CHECK-LABEL: Function: test_compare_known_scope_p_addr_must_alias_different_tail:
; CHECK:  NoAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, align 4, !noalias !7 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !7

; [pA(p.addr=%pA.addr), pB] <-> [pA(p.addr=%pA.addr.gep), pB]
define void @test_compare_known_scope_p_addr_must_alias_same_tail(ptr %arg0, ptr %arg1) {
entry:
  %pA.addr = alloca ptr
  %pA.addr.gep = getelementptr inbounds ptr, ptr %pA.addr, i64 0
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %pA.addr, i64 0, metadata !0)
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov1, ptr %pA.decl, ptr %pA.addr, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !11
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov2, ptr %pA.decl, ptr %pA.addr.gep, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, !noalias !11
  ret void
}
; CHECK-LABEL: Function: test_compare_known_scope_p_addr_must_alias_same_tail:
; CHECK:  MayAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, align 4, !noalias !5 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !5

; [pA(p.addr=null)] <-> [pA(p.addr=%pA.addr)]
define void @test_compare_known_scope_p_addr_null_vs_non_null(ptr %target0, ptr %target1) {
entry:
  %pA.addr = alloca ptr
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %pA.addr, i64 0, metadata !0)
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target0, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, !noalias !0
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target1, ptr %pA.decl, ptr %pA.addr, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, !noalias !0
  ret void
}
; CHECK-LABEL: Function: test_compare_known_scope_p_addr_null_vs_non_null:
; CHECK:  NoAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, align 4, !noalias !0 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, align 4, !noalias !0

; [pA(p.addr=null,objId=0)] <-> [pA(p.addr=null,objId=1)]
define void @test_compare_known_scope_obj_id_different(ptr %target0, ptr %target1) {
entry:
  %pA.decl0 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pA.decl1 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 1, metadata !0)
  %pA.prov0 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target0, ptr %pA.decl0, ptr null, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 111, ptr %target0, ptr_provenance ptr %pA.prov0, !noalias !0
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target1, ptr %pA.decl1, ptr null, ptr undef, i64 1, metadata !0), !noalias !0
  store i32 222, ptr %target1, ptr_provenance ptr %pA.prov1, !noalias !0
  ret void
}
; CHECK-LABEL: Function: test_compare_known_scope_obj_id_different:
; CHECK:  NoAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.prov1, align 4, !noalias !0 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.prov0, align 4, !noalias !0

; [pA(p.addr=%pA.addr0)] <-> [pA(p.addr=%pA.addr1)]
define void @test_compare_known_scope_p_addr_no_alias(ptr %target0, ptr %target1) {
entry:
  %pA.addr0 = alloca ptr
  %pA.addr1 = alloca ptr
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target0, ptr %pA.decl, ptr %pA.addr0, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, !noalias !0
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target1, ptr %pA.decl, ptr %pA.addr1, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, !noalias !0
  ret void
}
; CHECK-LABEL: Function: test_compare_known_scope_p_addr_no_alias:
; CHECK:  NoAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, align 4, !noalias !0 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, align 4, !noalias !0

; [pA(p.addr=%pA.gep0,objId=0)] <-> [pA(p.addr=%pA.gep1,objId=0)]
define void @test_compare_known_scope_p_addr_no_alias_same_base(ptr %target0, ptr %target1) {
entry:
  %pA.addr = alloca [2 x ptr]
  %pA.gep0 = getelementptr ptr, ptr %pA.addr, i64 0
  %pA.gep1 = getelementptr ptr, ptr %pA.addr, i64 1
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %pA.addr, i64 0, metadata !0)
  %pA.prov0 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target0, ptr %pA.decl, ptr %pA.gep0, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 111, ptr %target0, ptr_provenance ptr %pA.prov0, !noalias !0
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target1, ptr %pA.decl, ptr %pA.gep1, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 222, ptr %target1, ptr_provenance ptr %pA.prov1, !noalias !0
  ret void
}
; CHECK-LABEL: Function: test_compare_known_scope_p_addr_no_alias_same_base:
; CHECK:  NoAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.prov1, align 4, !noalias !0 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.prov0, align 4, !noalias !0

; [pA(p.addr=%pA.gep0)] <-> [pA(p.addr=%pA.gep1)]
define void @test_compare_known_scope_p_addr_may_alias(ptr %target0, ptr %target1, i64 %i0, i64 %i1) {
entry:
  %pA.addr = alloca [2 x ptr]
  %pA.gep0 = getelementptr ptr, ptr %pA.addr, i64 %i0
  %pA.gep1 = getelementptr ptr, ptr %pA.addr, i64 %i1
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %pA.addr, i64 0, metadata !0)
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target0, ptr %pA.decl, ptr %pA.gep0, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, !noalias !0
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target1, ptr %pA.decl, ptr %pA.gep1, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, !noalias !0
  ret void
}
; CHECK-LABEL: Function: test_compare_known_scope_p_addr_may_alias:
; CHECK:  MayAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, align 4, !noalias !0 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, align 4, !noalias !0

; [unknown(p.addr=@global), pB] <-> [unknown(p.addr=@global), pC]
define void @test_compare_unknown_scope_p_addr_equal_different_tail(ptr %arg0, ptr %arg1) !noalias !9 {
entry:
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !16
  %unk.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov, ptr null, ptr @global, ptr undef, i64 0, metadata !9), !noalias !16
  store i32 111, ptr %arg0, ptr_provenance ptr %unk.prov1, !noalias !16
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !16
  %unk.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr null, ptr @global, ptr undef, i64 0, metadata !9), !noalias !16
  store i32 222, ptr %arg1, ptr_provenance ptr %unk.prov2, !noalias !16
  ret void
}
; CHECK-LABEL: Function: test_compare_unknown_scope_p_addr_equal_different_tail:
; CHECK:  NoAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %unk.prov2, align 4, !noalias !7 <->   store i32 111, ptr %arg0, ptr_provenance ptr %unk.prov1, align 4, !noalias !7

; [unknown(p.addr=@global), pB] <-> [unknown(p.addr=@global), pB]
define void @test_compare_unknown_scope_p_addr_equal_same_tail(ptr %arg0, ptr %arg1) !noalias !9 {
entry:
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !16
  %unk.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov1, ptr null, ptr @global, ptr undef, i64 0, metadata !9), !noalias !16
  store i32 111, ptr %arg0, ptr_provenance ptr %unk.prov1, !noalias !16
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !16
  %unk.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov2, ptr null, ptr @global, ptr undef, i64 0, metadata !9), !noalias !16
  store i32 222, ptr %arg1, ptr_provenance ptr %unk.prov2, !noalias !16
  ret void
}
; CHECK-LABEL: Function: test_compare_unknown_scope_p_addr_equal_same_tail:
; CHECK:  MayAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %unk.prov2, align 4, !noalias !5 <->   store i32 111, ptr %arg0, ptr_provenance ptr %unk.prov1, align 4, !noalias !5

; [unknown(p.addr=%alloc), pB] <-> [unknown(p.addr=%alloc.gep), pC]
define void @test_compare_unknown_scope_p_addr_must_alias_different_tail(ptr %arg0, ptr %arg1) !noalias !9 {
entry:
  %alloc = alloca ptr
  %alloc.gep = getelementptr inbounds ptr, ptr %alloc, i64 0
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !16
  %unk.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov, ptr null, ptr %alloc, ptr undef, i64 0, metadata !9), !noalias !16
  store i32 111, ptr %arg0, ptr_provenance ptr %unk.prov1, !noalias !16
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !16
  %unk.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr null, ptr %alloc.gep, ptr undef, i64 0, metadata !9), !noalias !16
  store i32 222, ptr %arg1, ptr_provenance ptr %unk.prov2, !noalias !16
  ret void
}
; CHECK-LABEL: Function: test_compare_unknown_scope_p_addr_must_alias_different_tail:
; CHECK:  NoAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %unk.prov2, align 4, !noalias !7 <->   store i32 111, ptr %arg0, ptr_provenance ptr %unk.prov1, align 4, !noalias !7

; [unknown(p.addr=%alloc), pB] <-> [unknown(p.addr=%alloc.gep), pB]
define void @test_compare_unknown_scope_p_addr_must_alias_same_tail(ptr %arg0, ptr %arg1) !noalias !9 {
entry:
  %alloc = alloca ptr
  %alloc.gep = getelementptr inbounds ptr, ptr %alloc, i64 0
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !16
  %unk.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov1, ptr null, ptr %alloc, ptr undef, i64 0, metadata !9), !noalias !16
  store i32 111, ptr %arg0, ptr_provenance ptr %unk.prov1, !noalias !16
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !16
  %unk.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov2, ptr null, ptr %alloc.gep, ptr undef, i64 0, metadata !9), !noalias !16
  store i32 222, ptr %arg1, ptr_provenance ptr %unk.prov2, !noalias !16
  ret void
}
; CHECK-LABEL: Function: test_compare_unknown_scope_p_addr_must_alias_same_tail:
; CHECK:  MayAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %unk.prov2, align 4, !noalias !5 <->   store i32 111, ptr %arg0, ptr_provenance ptr %unk.prov1, align 4, !noalias !5

; [unknown(p.addr=%alloc0)] <-> [unknown(p.addr=%alloc1)]
define void @test_compare_unknown_scope_p_addr_no_alias(ptr %target0, ptr %target1) !noalias !9 {
entry:
  %alloc0 = alloca ptr
  %alloc1 = alloca ptr
  %unk.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target0, ptr null, ptr %alloc0, ptr undef, i64 0, metadata !9), !noalias !9
  store i32 111, ptr %target0, ptr_provenance ptr %unk.prov1, !noalias !9
  %unk.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target1, ptr null, ptr %alloc1, ptr undef, i64 0, metadata !9), !noalias !9
  store i32 222, ptr %target1, ptr_provenance ptr %unk.prov2, !noalias !9
  ret void
}
; CHECK-LABEL: Function: test_compare_unknown_scope_p_addr_no_alias:
; CHECK:  NoAlias:   store i32 222, ptr %target1, ptr_provenance ptr %unk.prov2, align 4, !noalias !0 <->   store i32 111, ptr %target0, ptr_provenance ptr %unk.prov1, align 4, !noalias !0

; [unknown(p.addr=%arg0)] <-> [unknown(p.addr=%arg1)]
define void @test_compare_unknown_scope_p_addr_may_alias(ptr %target0, ptr %target1, ptr %arg0, ptr %arg1) !noalias !9 {
entry:
  %unk.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target0, ptr null, ptr %arg0, ptr undef, i64 0, metadata !9), !noalias !9
  store i32 111, ptr %target0, ptr_provenance ptr %unk.prov1, !noalias !9
  %unk.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target1, ptr null, ptr %arg1, ptr undef, i64 0, metadata !9), !noalias !9
  store i32 222, ptr %target1, ptr_provenance ptr %unk.prov2, !noalias !9
  ret void
}
; CHECK-LABEL: Function: test_compare_unknown_scope_p_addr_may_alias:
; CHECK:  MayAlias:   store i32 222, ptr %target1, ptr_provenance ptr %unk.prov2, align 4, !noalias !0 <->   store i32 111, ptr %target0, ptr_provenance ptr %unk.prov1, align 4, !noalias !0

; [pA, pB] <-> [pA, pA, pC]
define void @test_chain_strip_head_different_tail(ptr %arg0, ptr %arg1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !15
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  %pA.prov2.inner = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  %pA.prov2.outer = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pA.prov2.inner, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2.outer, !noalias !15
  ret void
}
; CHECK-LABEL: Function: test_chain_strip_head_different_tail:
; CHECK:  NoAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2.outer, align 4, !noalias !7 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !7

; [pA, pC, <%arg0>] <-> [pA, pA, pC, <%arg1>]
define void @test_chain_strip_head_same_tail(ptr %arg0, ptr %arg1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pC.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !13
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov1, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !13
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, !noalias !13
  %pC.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !13
  %pA.prov2.inner = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov2, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !13
  %pA.prov2.outer = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pA.prov2.inner, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !13
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2.outer, !noalias !13
  ret void
}
; CHECK-LABEL: Function: test_chain_strip_head_same_tail:
; CHECK:  MayAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2.outer, align 4, !noalias !5 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1, align 4, !noalias !5

; [pA, pA, pC, <%arg0>] <-> [pA, pC, <%arg1>]
define void @test_chain_strip_head_same_tail_swapped(ptr %arg0, ptr %arg1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pC.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !13
  %pA.prov1.inner = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov1, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !13
  %pA.prov1.outer = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pA.prov1.inner, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !13
  store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1.outer, !noalias !13
  %pC.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !13
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov2, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !13
  store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, !noalias !13
  ret void
}
; CHECK-LABEL: Function: test_chain_strip_head_same_tail_swapped:
; CHECK:  MayAlias:   store i32 222, ptr %arg1, ptr_provenance ptr %pA.prov2, align 4, !noalias !5 <->   store i32 111, ptr %arg0, ptr_provenance ptr %pA.prov1.outer, align 4, !noalias !5

; [pA(p.addr=%pA.gep_outer), <@global>] <-> [pA(p.addr=%pA.gep_outer), pA(p.addr=%pA.gep_inner), <%target>]
define void @test_chain_strip_head_different_relation(ptr %target) {
entry:
  %pA.addr = alloca [2 x ptr]
  %pA.gep_outer = getelementptr ptr, ptr %pA.addr, i64 0
  %pA.gep_inner = getelementptr ptr, ptr %pA.addr, i64 1
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %pA.addr, i64 0, metadata !0)
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr @global, ptr %pA.decl, ptr %pA.gep_outer, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 111, ptr @global, ptr_provenance ptr %pA.prov1, !noalias !0
  %pA.prov2.inner = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target, ptr %pA.decl, ptr %pA.gep_inner, ptr undef, i64 0, metadata !0), !noalias !0
  %pA.prov2.outer = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pA.prov2.inner, ptr %pA.decl, ptr %pA.gep_outer, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 222, ptr %target, ptr_provenance ptr %pA.prov2.outer, !noalias !0
  ret void
}
; CHECK-LABEL: Function: test_chain_strip_head_different_relation:
; CHECK:  NoAlias:   store i32 222, ptr %target, ptr_provenance ptr %pA.prov2.outer, align 4, !noalias !0 <->   store i32 111, ptr @global, ptr_provenance ptr %pA.prov1, align 4, !noalias !0

; [pA(p.addr=%pA.gep0), <@global>] <-> [pA(p.addr=%pA.gep0), pA(p.addr=%pA.gep1), <%target>]
define void @test_chain_strip_head_unknown_relation(ptr %target, i64 %i0, i64 %i1) {
entry:
  %pA.addr = alloca [2 x ptr]
  %pA.gep0 = getelementptr ptr, ptr %pA.addr, i64 %i0
  %pA.gep1 = getelementptr ptr, ptr %pA.addr, i64 %i1
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %pA.addr, i64 0, metadata !0)
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr @global, ptr %pA.decl, ptr %pA.gep0, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 111, ptr @global, ptr_provenance ptr %pA.prov1, !noalias !0
  %pA.prov2.inner = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %target, ptr %pA.decl, ptr %pA.gep1, ptr undef, i64 0, metadata !0), !noalias !0
  %pA.prov2.outer = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pA.prov2.inner, ptr %pA.decl, ptr %pA.gep0, ptr undef, i64 0, metadata !0), !noalias !0
  store i32 222, ptr %target, ptr_provenance ptr %pA.prov2.outer, !noalias !0
  ret void
}
; CHECK-LABEL: Function: test_chain_strip_head_unknown_relation:
; CHECK:  MayAlias:   store i32 222, ptr %target, ptr_provenance ptr %pA.prov2.outer, align 4, !noalias !0 <->   store i32 111, ptr @global, ptr_provenance ptr %pA.prov1, align 4, !noalias !0

; [pA, pB] <-> [pA, |pC|, pD]
define void @test_chain_filter_different_tail(ptr %target0, ptr %target1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pD.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !7)
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr null, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !14
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !14
  store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, !noalias !14
  %pD.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr null, ptr %pD.decl, ptr null, ptr undef, i64 0, metadata !7), !noalias !14
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pD.prov, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !14
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !14
  store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, !noalias !14
  ret void
}
; CHECK-LABEL: Function: test_chain_filter_different_tail:
; CHECK:  NoAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, align 4, !noalias !9 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, align 4, !noalias !9

; [pA, pB] <-> [pA, |pC|, pB]
define void @test_chain_filter_same_tail(ptr %target0, ptr %target1) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr null, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov1, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, !noalias !11
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr null, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov2, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !11
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, !noalias !11
  ret void
}
; CHECK-LABEL: Function: test_chain_filter_same_tail:
; CHECK:  MayAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, align 4, !noalias !7 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, align 4, !noalias !7

; [pA, <@global>] <-> [pA, pB, <%arg>]
define void @test_chain_terminator_identified(ptr %arg) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr @global, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 111, ptr @global, ptr_provenance ptr %pA.prov1, !noalias !11
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 222, ptr %arg, ptr_provenance ptr %pA.prov2, !noalias !11
  ret void
}
; CHECK-LABEL: Function: test_chain_terminator_identified:
; CHECK:  NoAlias:   store i32 222, ptr %arg, ptr_provenance ptr %pA.prov2, align 4, !noalias !5 <->   store i32 111, ptr @global, ptr_provenance ptr %pA.prov1, align 4, !noalias !5

; [pA, <%load>] <-> [pA, pB, <%arg>]
define void @test_chain_terminator_unidentified(ptr %target0, ptr %target1, ptr %arg, ptr %p_to_ptr) {
entry:
  %load = load ptr, ptr %p_to_ptr
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %load, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, !noalias !11
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, !noalias !11
  ret void
}
; CHECK-LABEL: Function: test_chain_terminator_unidentified:
; CHECK:  MayAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.prov2, align 4, !noalias !5 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.prov1, align 4, !noalias !5

; [pA, {pB | pC}] <-> [pA, pD]
define void @test_chain_phi_arms_disjoint(ptr %arg0, ptr %arg1, ptr %arg2, i1 %cond) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pD.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !7)
  br i1 %cond, label %then, label %else

then:                                             ; preds = %entry
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !12
  br label %merge

else:                                             ; preds = %entry
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !12
  br label %merge

merge:                                            ; preds = %else, %then
  %prov.phi = phi ptr [ %pB.prov, %then ], [ %pC.prov, %else ]
  %ptr.phi = phi ptr [ %arg0, %then ], [ %arg1, %else ]
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.phi, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !12
  store i32 111, ptr %ptr.phi, ptr_provenance ptr %pA.prov1, !noalias !12
  %pD.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg2, ptr %pD.decl, ptr null, ptr undef, i64 0, metadata !7), !noalias !12
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pD.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !12
  store i32 222, ptr %arg2, ptr_provenance ptr %pA.prov2, !noalias !12
  ret void
}
; CHECK-LABEL: Function: test_chain_phi_arms_disjoint:
; CHECK:  NoAlias:   store i32 222, ptr %arg2, ptr_provenance ptr %pA.prov2, align 4, !noalias !9 <->   store i32 111, ptr %ptr.phi, ptr_provenance ptr %pA.prov1, align 4, !noalias !9

; [pA, {pB | pC}] <-> [pA, {pB | pC}]
define void @test_chain_phi_arms_overlap(ptr %arg0, ptr %arg1, ptr %arg2, ptr %arg3, i1 %cond) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  br i1 %cond, label %then, label %else

then:                                             ; preds = %entry
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg2, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  br label %merge

else:                                             ; preds = %entry
  %pC.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  %pC.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg3, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  br label %merge

merge:                                            ; preds = %else, %then
  %prov.phi1 = phi ptr [ %pB.prov1, %then ], [ %pC.prov1, %else ]
  %ptr.phi1 = phi ptr [ %arg0, %then ], [ %arg1, %else ]
  %prov.phi2 = phi ptr [ %pB.prov2, %then ], [ %pC.prov2, %else ]
  %ptr.phi2 = phi ptr [ %arg2, %then ], [ %arg3, %else ]
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.phi1, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 111, ptr %ptr.phi1, ptr_provenance ptr %pA.prov1, !noalias !15
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.phi2, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 222, ptr %ptr.phi2, ptr_provenance ptr %pA.prov2, !noalias !15
  ret void
}
; CHECK-LABEL: Function: test_chain_phi_arms_overlap:
; CHECK:  MayAlias:   store i32 222, ptr %ptr.phi2, ptr_provenance ptr %pA.prov2, align 4, !noalias !7 <->   store i32 111, ptr %ptr.phi1, ptr_provenance ptr %pA.prov1, align 4, !noalias !7

; [pA, {pB | <%load>}] <-> [pA, pC]
define void @test_chain_phi_arms_unidentified(ptr %arg0, ptr %arg1, ptr %arg2, ptr %p_to_ptr, i1 %cond) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  br i1 %cond, label %then, label %else

then:                                             ; preds = %entry
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  br label %merge

else:                                             ; preds = %entry
  %load = load ptr, ptr %p_to_ptr
  br label %merge

merge:                                            ; preds = %else, %then
  %prov.phi = phi ptr [ %pB.prov, %then ], [ %load, %else ]
  %ptr.phi = phi ptr [ %arg0, %then ], [ %arg1, %else ]
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.phi, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 111, ptr %ptr.phi, ptr_provenance ptr %pA.prov1, !noalias !15
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg2, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 222, ptr %arg2, ptr_provenance ptr %pA.prov2, !noalias !15
  ret void
}
; CHECK-LABEL: Function: test_chain_phi_arms_unidentified:
; CHECK:  MayAlias:   store i32 222, ptr %arg2, ptr_provenance ptr %pA.prov2, align 4, !noalias !7 <->   store i32 111, ptr %ptr.phi, ptr_provenance ptr %pA.prov1, align 4, !noalias !7

; [pA, {pB | pC}] <-> [pA, {pB | pD}]
define void @test_chain_phi_arms_partial_overlap(ptr %arg0, ptr %arg1, ptr %arg2, ptr %arg3, i1 %cond) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  %pD.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !7)
  br i1 %cond, label %then, label %else

then:                                             ; preds = %entry
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !12
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg2, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !12
  br label %merge

else:                                             ; preds = %entry
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !12
  %pD.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg3, ptr %pD.decl, ptr null, ptr undef, i64 0, metadata !7), !noalias !12
  br label %merge

merge:                                            ; preds = %else, %then
  %prov.phi1 = phi ptr [ %pB.prov1, %then ], [ %pC.prov, %else ]
  %ptr.phi1 = phi ptr [ %arg0, %then ], [ %arg1, %else ]
  %prov.phi2 = phi ptr [ %pB.prov2, %then ], [ %pD.prov, %else ]
  %ptr.phi2 = phi ptr [ %arg2, %then ], [ %arg3, %else ]
  %pA.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.phi1, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !12
  store i32 111, ptr %ptr.phi1, ptr_provenance ptr %pA.prov1, !noalias !12
  %pA.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.phi2, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !12
  store i32 222, ptr %ptr.phi2, ptr_provenance ptr %pA.prov2, !noalias !12
  ret void
}
; CHECK-LABEL: Function: test_chain_phi_arms_partial_overlap:
; CHECK:  MayAlias:   store i32 222, ptr %ptr.phi2, ptr_provenance ptr %pA.prov2, align 4, !noalias !9 <->   store i32 111, ptr %ptr.phi1, ptr_provenance ptr %pA.prov1, align 4, !noalias !9

; [pA, {pA, <null> | pB}] <-> [pA, pC]
define void @test_chain_phi_arms_head_disjoint(ptr %target0, ptr %target1, ptr %arg0, ptr %arg1, i1 %cond) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  %pC.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !5)
  br i1 %cond, label %then, label %else

then:                                             ; preds = %entry
  %pA.inner.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr null, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  br label %merge

else:                                             ; preds = %entry
  %pB.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !15
  br label %merge

merge:                                            ; preds = %else, %then
  %prov.phi = phi ptr [ %pA.inner.prov, %then ], [ %pB.prov, %else ]
  %pA.outer.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.phi, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 111, ptr %target0, ptr_provenance ptr %pA.outer.prov1, !noalias !15
  %pC.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pC.decl, ptr null, ptr undef, i64 0, metadata !5), !noalias !15
  %pA.outer.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pC.prov, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !15
  store i32 222, ptr %target1, ptr_provenance ptr %pA.outer.prov2, !noalias !15
  ret void
}
; CHECK-LABEL: Function: test_chain_phi_arms_head_disjoint:
; CHECK:  NoAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.outer.prov2, align 4, !noalias !7 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.outer.prov1, align 4, !noalias !7

; [pA, {pA, <null> | pB}] <-> [pA, pB]
define void @test_chain_phi_arms_head_overlap(ptr %target0, ptr %target1, ptr %arg0, ptr %arg1, i1 %cond) {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %pB.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !3)
  br i1 %cond, label %then, label %else

then:                                             ; preds = %entry
  %pA.inner.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr null, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  br label %merge

else:                                             ; preds = %entry
  %pB.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg0, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  br label %merge

merge:                                            ; preds = %else, %then
  %prov.phi = phi ptr [ %pA.inner.prov, %then ], [ %pB.prov1, %else ]
  %pA.outer.prov1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.phi, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 111, ptr %target0, ptr_provenance ptr %pA.outer.prov1, !noalias !11
  %pB.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %arg1, ptr %pB.decl, ptr null, ptr undef, i64 0, metadata !3), !noalias !11
  %pA.outer.prov2 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %pB.prov2, ptr %pA.decl, ptr null, ptr undef, i64 0, metadata !0), !noalias !11
  store i32 222, ptr %target1, ptr_provenance ptr %pA.outer.prov2, !noalias !11
  ret void
}
; CHECK-LABEL: Function: test_chain_phi_arms_head_overlap:
; CHECK:  MayAlias:   store i32 222, ptr %target1, ptr_provenance ptr %pA.outer.prov2, align 4, !noalias !5 <->   store i32 111, ptr %target0, ptr_provenance ptr %pA.outer.prov1, align 4, !noalias !5

; One "test" domain (level 2), shared across every function above; one
; scope (level 1) per restrict variable (pA, pB, pC, pD) plus one scope
; for the "unknown scope" marker; one singleton list per scope; then one
; multi-element list per unique !noalias union actually used.
!0  = !{!1}                            ; {pA}
!1  = distinct !{!1, !2, !"pA"}
!2  = distinct !{!2, !"test"}
!3  = !{!4}                            ; {pB}
!4  = distinct !{!4, !2, !"pB"}
!5  = !{!6}                            ; {pC}
!6  = distinct !{!6, !2, !"pC"}
!7  = !{!8}                            ; {pD}
!8  = distinct !{!8, !2, !"pD"}
!9  = !{!10}                           ; {unknown scope}
!10 = distinct !{!10, !2, !"unknown scope"}
!11 = !{!1, !4}                        ; {pA, pB}
!12 = !{!1, !4, !6, !8}                ; {pA, pB, pC, pD}
!13 = !{!1, !6}                        ; {pA, pC}
!14 = !{!1, !4, !8}                    ; {pA, pB, pD}
!15 = !{!1, !4, !6}                    ; {pA, pB, pC}
!16 = !{!10, !4, !6}                   ; {unknown scope, pB, pC}

; RUN: opt -aa-pipeline=basic-aa,scoped-noalias-aa  -passes='early-cse<memssa>' -S %s | FileCheck %s

; Test that only a captured provenance lets a noalias pointer escape. A
; noalias object stored in memory may escape even when its address is not
; captured.

target triple = "x86_64-unknown-linux-gnu"

@gp = global ptr null

declare void @callee(ptr)

declare ptr @llvm.noalias.decl.p0.p0.i64(
    ptr nocapture, i64, metadata) nocallback nofree nosync nounwind willreturn
    memory(inaccessiblemem: readwrite)

declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(
    ptr, ptr, ptr, ptr, i64, metadata) nocallback nofree nosync nounwind
    speculatable willreturn memory(none)

declare ptr @llvm.experimental.ptr.provenance.p0.p0(
    ptr, ptr) nocallback nofree nosync nounwind speculatable willreturn
    memory(none)

define i32 @test_direct_no_captures(ptr %p) {
entry:
  %rp.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %rp.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(
      ptr %p, ptr %rp.decl, ptr null, ptr undef, i64 0, metadata !0)
  %rp = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %p, ptr %rp.prov)
  call void @callee(ptr %rp)
  store i32 123, ptr %p, ptr_provenance ptr %rp.prov, !noalias !0
  %g = load ptr, ptr @gp
  %q = load ptr, ptr %g
  store i32 456, ptr %q, !noalias !0
  %v = load i32, ptr %p, ptr_provenance ptr %rp.prov, !noalias !0
  ret i32 %v
}
; CHECK-LABEL: define i32 @test_direct_no_captures(
; CHECK:         ret i32 %v

define i32 @test_direct_captures_none(ptr %p) {
entry:
  %rp.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %rp.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(
      ptr %p, ptr %rp.decl, ptr null, ptr undef, i64 0, metadata !0)
  %rp = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %p, ptr %rp.prov)
  call void @callee(ptr captures(none) %rp)
  store i32 123, ptr %p, ptr_provenance ptr %rp.prov, !noalias !0
  %g = load ptr, ptr @gp
  %q = load ptr, ptr %g
  store i32 456, ptr %q, !noalias !0
  %v = load i32, ptr %p, ptr_provenance ptr %rp.prov, !noalias !0
  ret i32 %v
}
; CHECK-LABEL: define i32 @test_direct_captures_none(
; CHECK:         ret i32 123

define i32 @test_direct_captures_address(ptr %p) {
entry:
  %rp.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %rp.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(
      ptr %p, ptr %rp.decl, ptr null, ptr undef, i64 0, metadata !0)
  %rp = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %p, ptr %rp.prov)
  call void @callee(ptr captures(address) %rp)
  store i32 123, ptr %p, ptr_provenance ptr %rp.prov, !noalias !0
  %g = load ptr, ptr @gp
  %q = load ptr, ptr %g
  store i32 456, ptr %q, !noalias !0
  %v = load i32, ptr %p, ptr_provenance ptr %rp.prov, !noalias !0
  ret i32 %v
}
; CHECK-LABEL: define i32 @test_direct_captures_address(
; CHECK:         ret i32 123

define i32 @test_direct_captures_provenance(ptr %p) {
entry:
  %rp.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !0)
  %rp.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(
      ptr %p, ptr %rp.decl, ptr null, ptr undef, i64 0, metadata !0)
  %rp = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %p, ptr %rp.prov)
  call void @callee(ptr captures(provenance) %rp)
  store i32 123, ptr %p, ptr_provenance ptr %rp.prov, !noalias !0
  %g = load ptr, ptr @gp
  %q = load ptr, ptr %g
  store i32 456, ptr %q, !noalias !0
  %v = load i32, ptr %p, ptr_provenance ptr %rp.prov, !noalias !0
  ret i32 %v
}
; CHECK-LABEL: define i32 @test_direct_captures_provenance(
; CHECK:         ret i32 %v

define i32 @test_addr_no_captures(ptr %p) {
entry:
  %rp.addr = alloca ptr
  %rp.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %rp.addr, i64 0, metadata !0)
  store ptr %p, ptr %rp.addr
  call void @callee(ptr %rp.addr)
  %rp = load ptr, ptr %rp.addr
  %rp.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(
      ptr %rp, ptr %rp.decl, ptr %rp.addr, ptr undef, i64 0, metadata !0)
  store i32 123, ptr %rp, ptr_provenance ptr %rp.prov, !noalias !0
  %g = load ptr, ptr @gp
  %q = load ptr, ptr %g
  store i32 456, ptr %q, !noalias !0
  %v = load i32, ptr %rp, ptr_provenance ptr %rp.prov, !noalias !0
  ret i32 %v
}
; CHECK-LABEL: define i32 @test_addr_no_captures(
; CHECK:         ret i32 %v

define i32 @test_addr_captures_none(ptr %p) {
entry:
  %rp.addr = alloca ptr
  %rp.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %rp.addr, i64 0, metadata !0)
  store ptr %p, ptr %rp.addr
  call void @callee(ptr captures(none) %rp.addr)
  %rp = load ptr, ptr %rp.addr
  %rp.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(
      ptr %rp, ptr %rp.decl, ptr %rp.addr, ptr undef, i64 0, metadata !0)
  store i32 123, ptr %rp, ptr_provenance ptr %rp.prov, !noalias !0
  %g = load ptr, ptr @gp
  %q = load ptr, ptr %g
  store i32 456, ptr %q, !noalias !0
  %v = load i32, ptr %rp, ptr_provenance ptr %rp.prov, !noalias !0
  ret i32 %v
}
; CHECK-LABEL: define i32 @test_addr_captures_none(
; CHECK:         ret i32 %v

define i32 @test_addr_captures_address(ptr %p) {
entry:
  %rp.addr = alloca ptr
  %rp.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %rp.addr, i64 0, metadata !0)
  store ptr %p, ptr %rp.addr
  call void @callee(ptr captures(address) %rp.addr)
  %rp = load ptr, ptr %rp.addr
  %rp.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(
      ptr %rp, ptr %rp.decl, ptr %rp.addr, ptr undef, i64 0, metadata !0)
  store i32 123, ptr %rp, ptr_provenance ptr %rp.prov, !noalias !0
  %g = load ptr, ptr @gp
  %q = load ptr, ptr %g
  store i32 456, ptr %q, !noalias !0
  %v = load i32, ptr %rp, ptr_provenance ptr %rp.prov, !noalias !0
  ret i32 %v
}
; CHECK-LABEL: define i32 @test_addr_captures_address(
; CHECK:         ret i32 %v

define i32 @test_addr_captures_provenance(ptr %p) {
entry:
  %rp.addr = alloca ptr
  %rp.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %rp.addr, i64 0, metadata !0)
  store ptr %p, ptr %rp.addr
  call void @callee(ptr captures(provenance) %rp.addr)
  %rp = load ptr, ptr %rp.addr
  %rp.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(
      ptr %rp, ptr %rp.decl, ptr %rp.addr, ptr undef, i64 0, metadata !0)
  store i32 123, ptr %rp, ptr_provenance ptr %rp.prov, !noalias !0
  %g = load ptr, ptr @gp
  %q = load ptr, ptr %g
  store i32 456, ptr %q, !noalias !0
  %v = load i32, ptr %rp, ptr_provenance ptr %rp.prov, !noalias !0
  ret i32 %v
}
; CHECK-LABEL: define i32 @test_addr_captures_provenance(
; CHECK:         ret i32 %v

!0 = !{!1}
!1 = distinct !{!1, !2, !"rp"}
!2 = distinct !{!2, !"domain"}

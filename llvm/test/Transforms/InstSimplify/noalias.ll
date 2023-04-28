; RUN: opt -passes=instsimplify -S < %s | FileCheck %s

define void @test01(ptr %ptr) {
  call ptr @llvm.noalias.p0.p0.p0.i32(ptr %ptr, ptr null, ptr null, i32 0, metadata !1)
  ret void

; CHECK-LABEL: @test01
; CHECK-NOT: llvm.noalias.p0
; CHECK: ret void
}

define ptr @test02() {
  %v = call ptr @llvm.noalias.p0.p0.p0.i32(ptr null, ptr null, ptr null, i32 0, metadata !1)
  ret ptr %v

; CHECK-LABEL: @test02
; CHECK: llvm.noalias.p0
; CHECK: ret ptr %v
}

define ptr @test03() {
  %v = call ptr @llvm.noalias.p0.p0.p0.i32(ptr undef, ptr null, ptr null, i32 0, metadata !1)
  ret ptr %v

; CHECK-LABEL: @test03
; CHECK-NOT: llvm.noalias.p0
; CHECK: ret ptr undef
}

declare ptr  @llvm.noalias.p0.p0.p0.i32(ptr, ptr, ptr, i32, metadata ) nounwind

define void @test11(ptr %ptr) {
  call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %ptr, ptr null, ptr null, ptr null, i32 0, metadata !1)
  ret void

; CHECK-LABEL: @test11
; CHECK-NOT: llvm.provenance.noalias.p0
; CHECK: ret void
}

define ptr @test12() {
  %v = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr null, ptr null, ptr null, ptr null, i32 0, metadata !1)
  ret ptr %v

; CHECK-LABEL: @test12
; CHECK: llvm.provenance.noalias.p0
; CHECK: ret ptr %v
}

define ptr @test13() {
  %v = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr undef, ptr null, ptr null, ptr null, i32 0, metadata !1)
  ret ptr %v

; CHECK-LABEL: @test13
; CHECK-NOT: llvm.provenance.noalias.p0
; CHECK: ret ptr undef
}

define ptr @test14() {
  %u = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr null, ptr null, ptr null, ptr null, i32 0, metadata !1)
  %v = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %u, ptr null, ptr null, ptr null, i32 0, metadata !1)
  ret ptr %v

; CHECK-LABEL: @test14
; CHECK: llvm.provenance.noalias.p0
; CHECK-NOT: llvm.provenance.noalias.p0
; CHECK: ret ptr %u
}

define ptr @test15() {
  %u = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr null, ptr null, ptr null, ptr null, i32 1, metadata !1)
  %v = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %u, ptr null, ptr null, ptr null, i32 0, metadata !1)
  ret ptr %v

; CHECK-LABEL: @test15
; CHECK: llvm.provenance.noalias.p0
; CHECK: llvm.provenance.noalias.p0
; CHECK: ret ptr %v
}

define ptr @test20() {
  %u = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr null, ptr null, ptr null, ptr null, i32 0, metadata !1)
  %v = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr null, ptr %u)
  ret ptr %v

; CHECK-LABEL: @test20
; CHECK: llvm.provenance.noalias.p0
; CHECK: llvm.experimental.ptr.provenance.p0
; CHECK: ret ptr %v
}

define ptr @test21() {
  %u = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr null, ptr null, ptr null, ptr null, i32 0, metadata !1)
  %v = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr undef, ptr %u)
  ret ptr %v

; CHECK-LABEL: @test21
; CHECK-NOT: llvm.provenance.noalias.p0
; CHECK-NOT: llvm.experimental.ptr.provenance.p0
; CHECK: ret ptr undef
}

define ptr @test30() {
  %v = call ptr @llvm.noalias.copy.guard.p0.p0(ptr null, ptr null, metadata !2, metadata !1)
  ret ptr %v

; CHECK-LABEL: @test30
; CHECK: llvm.noalias.copy.guard.p0
; CHECK: ret ptr %v
}

define void @test31() {
  %v = call ptr @llvm.noalias.copy.guard.p0.p0(ptr null, ptr null, metadata !2, metadata !1)
  ret void

; CHECK-LABEL: @test31
; CHECK-NOT: llvm.noalias.copy.guard.p0
; CHECK: ret void
}

define ptr @test32() {
  %v = call ptr @llvm.noalias.copy.guard.p0.p0(ptr undef, ptr null, metadata !2, metadata !1)
  ret ptr %v

; CHECK-LABEL: @test32
; CHECK-NOT: llvm.noalias.copy.guard.p0
; CHECK: ret ptr undef
}

define void @test40() {
  %v = call ptr @llvm.noalias.decl.p0.p0i32.i32(ptr null, i32 0, metadata !1)
  ret void

; CHECK-LABEL: @test40
; CHECK-NOT: llvm.noalias.decl.p0
; CHECK: ret void
}

define void @test41() {
  %u = alloca ptr
  %v = call ptr @llvm.noalias.decl.p0.p0i32.i32(ptr %u, i32 0, metadata !4)
  ret void

; CHECK-LABEL: @test41
; CHECK-NOT: alloca
; CHECK-NOT: llvm.noalias.decl.p0
; CHECK: ret void
}

define ptr @test42() {
  %u = alloca ptr
  %v = call ptr @llvm.noalias.decl.p0.p0i32.i32(ptr %u, i32 0, metadata !0)
  ret ptr %u

; CHECK-LABEL: @test42
; CHECK: alloca
; CHECK: llvm.noalias.decl.p0
; CHECK: ret ptr %u
}


declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr, ptr, ptr, ptr, i32, metadata ) nounwind
declare ptr @llvm.experimental.ptr.provenance.p0.p0(ptr, ptr) nounwind readnone
declare ptr @llvm.noalias.copy.guard.p0.p0(ptr, ptr, metadata, metadata)
declare ptr @llvm.noalias.decl.p0.p0i32.i32(ptr, i32, metadata) argmemonly nounwind

!0 = !{!0, !"some domain"}
!1 = !{!1, !0, !"some scope"}
!2 = !{!3}
!3 = !{ i64 -1, i64 0 }
!4 = !{!4, !"some other domain"}
!5 = !{!5, !4, !"some other scope"}

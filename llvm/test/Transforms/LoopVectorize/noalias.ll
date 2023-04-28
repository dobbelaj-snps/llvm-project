; RUN: opt -S -passes=loop-vectorize -force-vector-width=2 -force-vector-interleave=1 < %s | FileCheck %s

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"

; Make sure we can vectorize loops which contain noalias intrinsics


; A not-used llvm.noalias should not interfere
; CHECK-LABEL: @test_noalias_not_connected(
; CHECK: @llvm.noalias.p0
; CHECK: store <2 x i32>
; CHECK: ret
define void @test_noalias_not_connected(ptr %d) {
entry:
  br label %for.body

for.body:
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %d2 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %d, ptr null, ptr null, i32 0, metadata !1)
  %arrayidx = getelementptr inbounds i32, ptr %d, i64 %indvars.iv
  %v1 = load i32, ptr %arrayidx, align 8
  store i32 100, ptr %arrayidx, align 8
  %indvars.iv.next = add i64 %indvars.iv, 1
  %lftr.wideiv = trunc i64 %indvars.iv.next to i32
  %exitcond = icmp ne i32 %lftr.wideiv, 128
  br i1 %exitcond, label %for.body, label %for.end

for.end:
  ret void
}

; A used llvm.noalias should block vectorization.
; CHECK-LABEL: @test_noalias_connected(
; CHECK: @llvm.noalias.p0
; CHECK-NOT: store <2 x i32>
; CHECK: ret
define void @test_noalias_connected(ptr %d) {
entry:
  br label %for.body

for.body:
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %d2 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %d, ptr null, ptr null, i32 0, metadata !1)
  %arrayidx = getelementptr inbounds i32, ptr %d2, i64 %indvars.iv
  %v1 = load i32, ptr %arrayidx, align 8
  store i32 100, ptr %arrayidx, align 8
  %indvars.iv.next = add i64 %indvars.iv, 1
  %lftr.wideiv = trunc i64 %indvars.iv.next to i32
  %exitcond = icmp ne i32 %lftr.wideiv, 128
  br i1 %exitcond, label %for.body, label %for.end

for.end:
  ret void
}

; A used llvm.provenance.noalias should NOT block vectorization.
; CHECK-LABEL: @test_provenance.noalias(
; C H E C K: @llvm.provenance.noalias.p0
; NOTE: the ptr_provenance is omitted
; FIXME: This interpretation is not completely correct any more and will need to be handled better:
; FIXME: on the long term it will be unsafe to just omit the ptr_provenance.
; CHECK: store <2 x i32> <i32 100, i32 100>, ptr {{%[0-9.a-zA-Z]*}}, align 8
; CHECK: ret

define void @test_provenance.noalias(ptr %d) {
entry:
  br label %for.body

for.body:
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %prov.d = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %d, ptr null, ptr null, ptr null, i32 0, metadata !1)
  %arrayidx = getelementptr inbounds i32, ptr %d, i64 %indvars.iv
  %v1 = load i32, ptr %arrayidx, ptr_provenance ptr %prov.d, align 8
  store i32 100, ptr %arrayidx, ptr_provenance ptr %prov.d, align 8
  %indvars.iv.next = add i64 %indvars.iv, 1
  %lftr.wideiv = trunc i64 %indvars.iv.next to i32
  %exitcond = icmp ne i32 %lftr.wideiv, 128
  br i1 %exitcond, label %for.body, label %for.end

for.end:
  ret void
}

declare ptr  @llvm.noalias.decl.p0.p0.i32(ptr, i32, metadata) argmemonly nounwind
declare ptr  @llvm.noalias.p0.p0.p0.i32(ptr, ptr, ptr, i32, metadata ) nounwind
declare ptr  @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr, ptr, ptr, ptr, i32, metadata ) nounwind


;declare ptr @llvm.noalias.p0(ptr, metadata) nounwind argmemonly

!0 = !{!0, !"some domain"}
!1 = !{!1, !0, !"some scope"}

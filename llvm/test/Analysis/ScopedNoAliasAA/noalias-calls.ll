; RUN: opt < %s -aa-pipeline=basic-aa,scoped-noalias-aa -passes=aa-eval -evaluate-aa-metadata -print-all-alias-modref-info -disable-output 2>&1 | FileCheck %s
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; Function Attrs: nounwind
declare void @llvm.memcpy.p0.p0.i64(ptr nocapture writeonly, ptr nocapture readonly, i64, i1) #1

; Function Attrs: nounwind
declare void @hey() #1

; Function Attrs: nounwind uwtable
define void @foo(ptr nocapture %a, ptr nocapture readonly %c, ptr nocapture %b) #2 {
entry:
  %l.i = alloca i8, i32 512, align 1
  %prov.a = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %a, ptr null, ptr null, ptr null, i32 0, metadata !0) #0
  %prov.b = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %c, ptr null, ptr null, ptr null, i32 0, metadata !3) #0
  %a.guard = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %a, ptr %prov.a)
  %c.guard = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %c, ptr %prov.b)
  call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %b, i64 16, i1 false) #1, !noalias !5
  call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
  call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
  call void @hey() #1, !noalias !5
  call void @llvm.memcpy.p0.p0.i64(ptr %l.i, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
  ret void
}

; CHECK-LABEL: Function: foo:
; CHECK: Just Ref:   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %b, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: Just Mod:   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %b, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: Just Ref:   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %b, i64 16, i1 false) #1, !noalias !5 <->   call void @hey() #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %b, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %l.i, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: Just Mod:   call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %b, i64 16, i1 false) #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: Just Mod:   call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @hey() #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %l.i, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: Just Mod:   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %b, i64 16, i1 false) #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @hey() #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %l.i, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: Just Mod:   call void @hey() #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %b, i64 16, i1 false) #1, !noalias !5
; CHECK: Both ModRef:   call void @hey() #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: NoModRef:   call void @hey() #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: NoModRef:   call void @hey() #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %l.i, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %l.i, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %b, i64 16, i1 false) #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %l.i, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %l.i, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @llvm.memcpy.p0.p0.i64(ptr %a.guard, ptr %c.guard, i64 16, i1 false) #1, !noalias !5
; CHECK: NoModRef:   call void @llvm.memcpy.p0.p0.i64(ptr %l.i, ptr %c.guard, i64 16, i1 false) #1, !noalias !5 <->   call void @hey() #1, !noalias !5

declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr, ptr, ptr, ptr, i32, metadata) nounwind readnone speculatable
declare ptr @llvm.experimental.ptr.provenance.p0.p0(ptr, ptr) nounwind readnone

attributes #0 = { argmemonly nounwind }
attributes #1 = { nounwind }
attributes #2 = { nounwind uwtable }


!0 = !{!1}
!1 = distinct !{!1, !2, !"hello: %a"}
!2 = distinct !{!2, !"hello"}
!3 = !{!4}
!4 = distinct !{!4, !2, !"hello: %c"}
!5 = !{!1, !4}

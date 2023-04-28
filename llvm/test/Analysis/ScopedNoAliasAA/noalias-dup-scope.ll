; RUN: opt < %s -aa-pipeline=basic-aa,scoped-noalias-aa -passes='require<domtree>,aa-eval,print<loops>' -evaluate-aa-metadata -print-all-alias-modref-info -disable-output 2>&1 | FileCheck %s -check-prefix=WITHDT
; Note: The -loops above can be anything that requires the domtree, and is
; necessary to work around a pass-manager bug.

target datalayout = "E-m:e-i64:64-n32:64"
target triple = "powerpc64-unknown-linux-gnu"

@a = common global ptr null, align 8
@r = common global i32 0, align 4
@a2 = common global ptr null, align 8

; Function Attrs: nounwind
define ptr @foo() #0 {
entry:
  %0 = load ptr, ptr @a, align 8, !tbaa !1, !noalias !5
  %1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %0, ptr null, ptr @a, ptr null, i32 0, metadata !5) #0
  %2 = tail call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %0, ptr %1) #0
  ret ptr %1
}

; Function Attrs: nounwind
declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr, ptr, ptr, ptr, i32, metadata) #0

; Function Attrs: nounwind
declare ptr @llvm.experimental.ptr.provenance.p0.p0(ptr, ptr) #0

; Function Attrs: nounwind
define ptr @foo1(i32 signext %b) #0 {
entry:
  %tobool = icmp eq i32 %b, 0
  br i1 %tobool, label %if.else, label %if.then

if.then:                                          ; preds = %entry
  %0 = load ptr, ptr @a, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !8
  %1 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %0, ptr null, ptr @a, ptr null, i32 0, metadata !12) #0
  %2 = load i32, ptr %0, ptr_provenance ptr %1, align 4, !tbaa !13, !noalias !8
  %3 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !13, !noalias !8
  %add = add nsw i32 %3, %2
  store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !13, !noalias !8
  %guard.1 = tail call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %0, ptr %1) #0
  tail call void @ex1(ptr %guard.1) #0, !noalias !8
  %incdec.ptr = getelementptr inbounds i32, ptr %0, i64 1
  %4 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %0, ptr null, ptr @a, ptr null, i32 0, metadata !12) #0
  %5 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !13, !noalias !8
  store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !13, !noalias !8
  %guard.5 = tail call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %incdec.ptr, ptr %4) #0
  tail call void @ex1(ptr %guard.5) #0, !noalias !8
  %idx.ext = sext i32 %b to i64
  %add.ptr = getelementptr inbounds i32, ptr %incdec.ptr, i64 %idx.ext
  %6 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %0, ptr null, ptr @a, ptr null, i32 0, metadata !12) #0
  %7 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !13, !noalias !8
  store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !13, !noalias !8
  %guard.6 = tail call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %add.ptr, ptr %6) #0
  tail call void @ex1(ptr %guard.6) #0, !noalias !8
  %8 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !8
  %9 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %8, ptr null, ptr @a2, ptr null, i32 0, metadata !15) #0
  %10 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !13, !noalias !8
  store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !13, !noalias !8
  %guard.9 = tail call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %8, ptr %9) #0
  tail call void @ex1(ptr %guard.9) #0, !noalias !8
  br label %if.end

if.else:                                          ; preds = %entry
  %11 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !12
  %12 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %11, ptr null, ptr @a2, ptr null, i32 0, metadata !12) #0
  %13 = load i32, ptr %11, ptr_provenance ptr %12, align 4, !tbaa !13, !noalias !12
  %14 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !13, !noalias !12
  %add1 = add nsw i32 %14, %13
  store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !13, !noalias !12
  br label %if.end

if.end:                                           ; preds = %if.else, %if.then
  %x.0 = phi ptr [ %0, %if.then ], [ %11, %if.else ]
  %prov.x.0 = phi ptr [ %6, %if.then ], [ %12, %if.else ]
  %x.0.guard = tail call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %x.0, ptr %prov.x.0) #0
  ret ptr %x.0.guard
}

; WITHDT:  NoAlias:   %0 = load ptr, ptr @a, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %0 = load ptr, ptr @a, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %0 = load ptr, ptr @a, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %0 = load ptr, ptr @a, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %0 = load ptr, ptr @a, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  NoAlias:   %2 = load i32, ptr %0, ptr_provenance ptr %1, align 4, !tbaa !10, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %2 = load i32, ptr %0, ptr_provenance ptr %1, align 4, !tbaa !10, !noalias !5 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  MayAlias:   %2 = load i32, ptr %0, ptr_provenance ptr %1, align 4, !tbaa !10, !noalias !5 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %2 = load i32, ptr %0, ptr_provenance ptr %1, align 4, !tbaa !10, !noalias !5 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %2 = load i32, ptr %0, ptr_provenance ptr %1, align 4, !tbaa !10, !noalias !5 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  MustAlias:   %3 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %3 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %3 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %3 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  MustAlias:   %3 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  MustAlias:   %5 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %5 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %5 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %5 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  MustAlias:   %5 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  MustAlias:   %7 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %7 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %7 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %7 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  MustAlias:   %7 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  NoAlias:   %8 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %8 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %8 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %8 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %8 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !5 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  MustAlias:   %10 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %10 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %10 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %10 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  MustAlias:   %10 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  NoAlias:   %11 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !9 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %11 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !9 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %11 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !9 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  MayAlias:   %11 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !9 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %11 = load ptr, ptr @a2, ptr_provenance ptr null, align 8, !tbaa !1, !noalias !9 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  NoAlias:   %13 = load i32, ptr %11, ptr_provenance ptr %12, align 4, !tbaa !10, !noalias !9 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %13 = load i32, ptr %11, ptr_provenance ptr %12, align 4, !tbaa !10, !noalias !9 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %13 = load i32, ptr %11, ptr_provenance ptr %12, align 4, !tbaa !10, !noalias !9 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  MayAlias:   %13 = load i32, ptr %11, ptr_provenance ptr %12, align 4, !tbaa !10, !noalias !9 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %13 = load i32, ptr %11, ptr_provenance ptr %12, align 4, !tbaa !10, !noalias !9 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  MustAlias:   %14 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %14 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   %14 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  MayAlias:   %14 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5
; WITHDT:  MustAlias:   %14 = load i32, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9 <->   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9
; WITHDT:  NoAlias:   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  MustAlias:   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9 <->   store i32 %add, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9 <->   store i32 %5, ptr %incdec.ptr, ptr_provenance ptr %4, align 4, !tbaa !10, !noalias !5
; WITHDT:  NoAlias:   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9 <->   store i32 %7, ptr %add.ptr, ptr_provenance ptr %6, align 4, !tbaa !10, !noalias !5
; WITHDT:  MayAlias:   store i32 %add1, ptr @r, ptr_provenance ptr null, align 4, !tbaa !10, !noalias !9 <->   store i32 %10, ptr %8, ptr_provenance ptr %9, align 4, !tbaa !10, !noalias !5

declare void @ex1(ptr)

attributes #0 = { nounwind }

!llvm.ident = !{!0}

!0 = !{!"clang"}
!1 = !{!2, !2, i64 0}
!2 = !{!"any pointer", !3, i64 0}
!3 = !{!"omnipotent char", !4, i64 0}
!4 = !{!"Simple C/C++ TBAA"}
!5 = !{!6}
!6 = distinct !{!6, !7, !"foo: x"}
!7 = distinct !{!7, !"foo"}
!8 = !{!9, !11}
!9 = distinct !{!9, !10, !"foo1: x2"}
!10 = distinct !{!10, !"foo1"}
!11 = distinct !{!11, !10, !"foo1: x"}
!12 = !{!11}
!13 = !{!14, !14, i64 0}
!14 = !{!"int", !3, i64 0}
!15 = !{!9}

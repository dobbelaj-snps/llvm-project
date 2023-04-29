; RUN: opt < %s -passes=convert-noalias,verify -S | FileCheck %s

target datalayout = "e-p:64:64:64-p1:16:16:16-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-n8:16:32:64"

; Function Attrs: nounwind
define dso_local void @test01(ptr %_pA) local_unnamed_addr #0 {
entry:
  %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !2)
  %1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_pA, ptr %0, ptr null, ptr undef, i32 0, metadata !2), !tbaa !5, !noalias !2
  store i32 41, ptr %_pA, ptr_provenance ptr %1, align 4, !tbaa !9, !noalias !2
  %.guard = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %_pA, ptr %1)
  %2 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !11) #5, !noalias !2
  %3 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %.guard, ptr %2, ptr null, ptr undef, i32 0, metadata !11) #3, !tbaa !5, !noalias !14
  store i32 42, ptr %.guard, ptr_provenance ptr %3, align 4, !tbaa !9, !noalias !14
  %.guard.guard.guard.guard.i = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %.guard, ptr %3) #1
  store i32 43, ptr %.guard.guard.guard.guard.i, ptr_provenance ptr undef, align 4, !tbaa !9, !noalias !2
  ret void
}

; CHECK-LABEL: @test01(
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !2)
; CHECK-NEXT:   %1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_pA, ptr %0, ptr null, ptr undef, i32 0, metadata !2), !tbaa !5, !noalias !2
; CHECK-NEXT:   store i32 41, ptr %_pA, ptr_provenance ptr %1, align 4, !tbaa !9, !noalias !2
; CHECK-NEXT:   %2 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !11) #{{[0-9]+}}, !noalias !2
; CHECK-NEXT:   %3 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %1, ptr %2, ptr null, ptr undef, i32 0, metadata !11) #{{[0-9]+}}, !tbaa !5, !noalias !14
; CHECK-NEXT:   store i32 42, ptr %_pA, ptr_provenance ptr %3, align 4, !tbaa !9, !noalias !14
; CHECK-NEXT:   store i32 43, ptr %_pA, ptr_provenance ptr %3, align 4, !tbaa !9, !noalias !2
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; Function Attrs: nounwind
define dso_local void @test02(ptr %_pA) local_unnamed_addr #0 {
entry:
  %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !2)
  %1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_pA, ptr %0, ptr null, ptr undef, i32 0, metadata !2), !tbaa !5, !noalias !2
  store i32 41, ptr %_pA, ptr_provenance ptr %1, align 4, !tbaa !9, !noalias !2
  %.guard = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %_pA, ptr %1)
  %2 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !11) #5, !noalias !2
  %3 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %.guard, ptr %2, ptr null, ptr undef, i32 0, metadata !11) #3, !tbaa !5, !noalias !14
  store i32 42, ptr %.guard, ptr_provenance ptr %3, align 4, !tbaa !9, !noalias !14
  %deg01 = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %.guard, ptr %.guard) #1
  %deg02 = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %.guard, ptr undef) #1
  call void @foo(ptr %deg01), !noalias !14
  call void @foo(ptr %deg01), !noalias !14
  ret void
}

; CHECK-LABEL: @test02(
; CHECK: ret void

%class.e = type { %class.a }
%class.a = type { i32 }

@g = global %class.e zeroinitializer, align 4

; Function Attrs: nounwind
define internal fastcc void @test03() unnamed_addr #0 {
entry:
  %0 = tail call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !15)
  %1 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr nonnull @g, ptr %0, ptr null, ptr undef, i64 0, metadata !15)
  %2 = getelementptr inbounds %class.e, ptr %1, i32 0, i32 0
  %.guard.guard = tail call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr getelementptr inbounds (%class.e, ptr @g, i32 0, i32 0), ptr %2)
  call void @foobar03(ptr %.guard.guard, i32 5), !noalias !15
  ret void
}

; CHECK-LABEL: @test03(
; CHECK: call ptr @llvm.experimental.ptr.provenance.p0.p0
; CHECK: ret void

; Function Attrs: nounwind
declare void @foobar03(ptr, i32) local_unnamed_addr #0

; Function Attrs: argmemonly nounwind
declare ptr @llvm.noalias.decl.p0.p0.i32(ptr, i32, metadata) #1

; Function Attrs: argmemonly nounwind speculatable
declare ptr @llvm.noalias.p0.p0.p0.i32(ptr, ptr, ptr, i32, metadata) #2

; Function Attrs: nounwind readnone speculatable
declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr, ptr, ptr, ptr, i32, metadata) #3

; Function Attrs: nounwind readnone
declare ptr @llvm.experimental.ptr.provenance.p0.p0(ptr, ptr) #4

; Function Attrs: argmemonly nounwind
declare ptr @llvm.noalias.decl.p0.p0.i64(ptr, i64, metadata) #1

; Function Attrs: nounwind readnone speculatable
declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr, ptr, ptr, ptr, i64, metadata) #3

declare void @foo(ptr)

attributes #0 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { argmemonly nounwind }
attributes #2 = { argmemonly nounwind speculatable }
attributes #3 = { nounwind readnone speculatable }
attributes #4 = { nounwind readnone }
attributes #5 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang"}
!2 = !{!3}
!3 = distinct !{!3, !4, !"test01: p1"}
!4 = distinct !{!4, !"test01"}
!5 = !{!6, !6, i64 0, i64 4}
!6 = !{!7, i64 4, !"any pointer"}
!7 = !{!8, i64 1, !"omnipotent char"}
!8 = !{!"Simple C/C++ TBAA"}
!9 = !{!10, !10, i64 0, i64 4}
!10 = !{!7, i64 4, !"int"}
!11 = !{!12}
!12 = distinct !{!12, !13, !"passP: pA"}
!13 = distinct !{!13, !"passP"}
!14 = !{!12, !3}
!15 = !{!16}
!16 = distinct !{!16, !17, !"test03: %agg.result"}
!17 = distinct !{!17, !"test03"}

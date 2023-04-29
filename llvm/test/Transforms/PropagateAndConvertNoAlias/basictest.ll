; RUN: opt < %s -passes=convert-noalias,verify -S | FileCheck %s

@gpA = common dso_local global ptr null, align 4

; Function Attrs: nounwind
define dso_local void @test01(ptr %_pA) #0 {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !2)
  %pA = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %_pA, ptr %pA.decl, ptr null, i32 0, metadata !2), !tbaa !5, !noalias !2
  %arrayidx = getelementptr inbounds i32, ptr %pA, i32 10
  store i32 42, ptr %arrayidx, align 4, !tbaa !9, !noalias !2
  %pA.2 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %_pA, ptr %pA.decl, ptr null, i32 0, metadata !2), !tbaa !5, !noalias !2
  %add.ptr = getelementptr inbounds i32, ptr %pA.2, i32 1
  %pA.3 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %add.ptr, ptr %pA.decl, ptr null, i32 0, metadata !2), !tbaa !5, !noalias !2
  %arrayidx1 = getelementptr inbounds i32, ptr %pA.3, i32 11
  store i32 43, ptr %arrayidx1, align 4, !tbaa !9, !noalias !2
  ret void
}

; CHECK-LABEL: @test01(
; CHECK-NEXT: entry:
; CHECK-NEXT:   %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !2)
; CHECK-NEXT:   %0 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_pA, ptr %pA.decl, ptr null, ptr undef, i32 0, metadata !2), !tbaa !5, !noalias !2
; CHECK-NEXT:   %arrayidx = getelementptr inbounds i32, ptr %_pA, i32 10
; CHECK-NEXT:   store i32 42, ptr %arrayidx, ptr_provenance ptr %0, align 4, !tbaa !9, !noalias !2
; CHECK-NEXT:   %add.ptr = getelementptr inbounds i32, ptr %_pA, i32 1
; CHECK-NEXT:   %arrayidx1 = getelementptr inbounds i32, ptr %add.ptr, i32 11
; CHECK-NEXT:   store i32 43, ptr %arrayidx1, ptr_provenance ptr %0, align 4, !tbaa !9, !noalias !2
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; Function Attrs: nounwind
define dso_local ptr @test02(ptr %_pA) #0 {
entry:
  %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !11)
  %pA.1 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %_pA, ptr %pA.decl, ptr null, i32 0, metadata !11), !tbaa !5, !noalias !11
  store ptr %pA.1, ptr @gpA, align 4, !tbaa !5, !noalias !11
  %pA.2 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %_pA, ptr %pA.decl, ptr null, i32 0, metadata !11), !tbaa !5, !noalias !11
  ret ptr %pA.2
}

; CHECK-LABEL: @test02(
; CHECK-NEXT: entry:
; CHECK-NEXT:   %pA.decl = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !11)
; CHECK-NEXT:   %0 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_pA, ptr %pA.decl, ptr null, ptr undef, i32 0, metadata !11), !tbaa !5, !noalias !11
; CHECK-NEXT:   %pA.1.guard = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %_pA, ptr %0)
; CHECK-NEXT:   store ptr %pA.1.guard, ptr @gpA, align 4, !tbaa !5, !noalias !11
; CHECK-NEXT:   %pA.2.guard = call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %_pA, ptr %0)
; CHECK-NEXT:   ret ptr %pA.2.guard
; CHECK-NEXT: }


; Function Attrs: argmemonly nounwind
declare ptr @llvm.noalias.decl.p0.p0.i32(ptr, i32, metadata) #1

; Function Attrs: argmemonly nounwind speculatable
declare ptr @llvm.noalias.p0.p0.p0.i32(ptr, ptr, ptr, i32, metadata) #2

attributes #0 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { argmemonly nounwind }
attributes #2 = { argmemonly nounwind speculatable }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang"}
!2 = !{!3}
!3 = distinct !{!3, !4, !"test01: pA"}
!4 = distinct !{!4, !"test01"}
!5 = !{!6, !6, i64 0, i64 4}
!6 = !{!7, i64 4, !"any pointer"}
!7 = !{!8, i64 1, !"omnipotent char"}
!8 = !{!"Simple C/C++ TBAA"}
!9 = !{!10, !10, i64 0, i64 4}
!10 = !{!7, i64 4, !"int"}
!11 = !{!12}
!12 = distinct !{!12, !13, !"test02: pA"}
!13 = distinct !{!13, !"test02"}

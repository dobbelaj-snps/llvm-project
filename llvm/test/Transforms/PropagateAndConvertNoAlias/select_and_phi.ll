; RUN: opt < %s -passes=convert-noalias,verify -S | FileCheck %s
; RUN: opt < %s -passes=convert-noalias,verify,convert-noalias,verify -S | FileCheck %s

; Function Attrs: nounwind
define dso_local void @test_phi01(ptr %_pA, ptr %_pB, i32 %n) #0 {
entry:
  %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !2)
  %1 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !5)
  %arrayidx = getelementptr inbounds ptr, ptr %_pB, i32 2
  %2 = load ptr, ptr %arrayidx, align 4, !tbaa !7, !noalias !11
  %3 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %_pA, ptr %0, ptr null, i32 0, metadata !2), !tbaa !7, !noalias !11
  %4 = load ptr, ptr %_pB, align 4, !tbaa !7, !noalias !11
  %arrayidx2 = getelementptr inbounds ptr, ptr %_pB, i32 1
  %5 = load ptr, ptr %arrayidx2, align 4, !tbaa !7, !noalias !11
  br label %for.cond

for.cond:                                         ; preds = %for.body, %entry
  %pTmp00.0 = phi ptr [ %4, %entry ], [ %pTmp01.0, %for.body ]
  %pTmp01.0 = phi ptr [ %5, %entry ], [ %3, %for.body ]
  %i.0 = phi i32 [ 0, %entry ], [ %inc, %for.body ]
  %cmp = icmp slt i32 %i.0, %n
  br i1 %cmp, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.cond
  %6 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %_pA, ptr %0, ptr null, i32 0, metadata !2), !tbaa !7, !noalias !11
  store i32 99, ptr %6, align 4, !tbaa !12, !noalias !11
  store i32 42, ptr %pTmp00.0, align 4, !tbaa !12, !noalias !11
  %cmp5 = icmp sgt i32 %n, 5
  %7 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %2, ptr %1, ptr null, i32 0, metadata !5)
  %cond = select i1 %cmp5, ptr %pTmp00.0, ptr %7
  store i32 43, ptr %cond, align 4, !tbaa !12, !noalias !11
  ret void

for.body:                                         ; preds = %for.cond
  %arrayidx3 = getelementptr inbounds i32, ptr %pTmp01.0, i32 1
  %8 = load i32, ptr %arrayidx3, align 4, !tbaa !12, !noalias !11
  %arrayidx4 = getelementptr inbounds i32, ptr %pTmp00.0, i32 1
  store i32 %8, ptr %arrayidx4, align 4, !tbaa !12, !noalias !11
  %inc = add nsw i32 %i.0, 1
  br label %for.cond
}

; CHECK-LABEL: @test_phi01(
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !2)
; CHECK-NEXT:   %1 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !5)
; CHECK-NEXT:   %arrayidx = getelementptr inbounds ptr, ptr %_pB, i32 2
; CHECK-NEXT:   %2 = load ptr, ptr %arrayidx, align 4, !tbaa !7, !noalias !11
; CHECK-NEXT:   %3 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_pA, ptr %0, ptr null, ptr undef, i32 0, metadata !2), !tbaa !7, !noalias !11
; CHECK-NEXT:   %4 = load ptr, ptr %_pB, align 4, !tbaa !7, !noalias !11
; CHECK-NEXT:   %arrayidx2 = getelementptr inbounds ptr, ptr %_pB, i32 1
; CHECK-NEXT:   %5 = load ptr, ptr %arrayidx2, align 4, !tbaa !7, !noalias !11
; CHECK-NEXT:   br label %for.cond
; CHECK: for.cond:
; CHECK-NEXT:   %prov.pTmp00.0 = phi ptr [ %4, %entry ], [ %prov.pTmp01.0, %for.body ]
; CHECK-NEXT:   %pTmp00.0 = phi ptr [ %4, %entry ], [ %pTmp01.0, %for.body ]
; CHECK-NEXT:   %prov.pTmp01.0 = phi ptr [ %5, %entry ], [ %3, %for.body ]
; CHECK-NEXT:   %pTmp01.0 = phi ptr [ %5, %entry ], [ %_pA, %for.body ]
; CHECK-NEXT:   %i.0 = phi i32 [ 0, %entry ], [ %inc, %for.body ]
; CHECK-NEXT:   %cmp = icmp slt i32 %i.0, %n
; CHECK-NEXT:   br i1 %cmp, label %for.body, label %for.cond.cleanup
; CHECK: for.cond.cleanup:
; CHECK-NEXT:   store i32 99, ptr %_pA, ptr_provenance ptr %3, align 4, !tbaa !12, !noalias !11
; CHECK-NEXT:   store i32 42, ptr %pTmp00.0, ptr_provenance ptr %prov.pTmp00.0, align 4, !tbaa !12, !noalias !11
; CHECK-NEXT:   %cmp5 = icmp sgt i32 %n, 5
; CHECK-NEXT:   %6 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %2, ptr %1, ptr null, ptr undef, i32 0, metadata !5)
; CHECK-NEXT:   %prov.cond = select i1 %cmp5, ptr %prov.pTmp00.0, ptr %6
; CHECK-NEXT:   %cond = select i1 %cmp5, ptr %pTmp00.0, ptr %2
; CHECK-NEXT:   store i32 43, ptr %cond, ptr_provenance ptr %prov.cond, align 4, !tbaa !12, !noalias !11
; CHECK-NEXT:   ret void
; CHECK: for.body:
; CHECK-NEXT:   %arrayidx3 = getelementptr inbounds i32, ptr %pTmp01.0, i32 1
; CHECK-NEXT:   %7 = load i32, ptr %arrayidx3, ptr_provenance ptr %prov.pTmp01.0, align 4, !tbaa !12, !noalias !11
; CHECK-NEXT:   %arrayidx4 = getelementptr inbounds i32, ptr %pTmp00.0, i32 1
; CHECK-NEXT:   store i32 %7, ptr %arrayidx4, ptr_provenance ptr %prov.pTmp00.0, align 4, !tbaa !12, !noalias !11
; CHECK-NEXT:   %inc = add nsw i32 %i.0, 1
; CHECK-NEXT:   br label %for.cond
; CHECK-NEXT: }


; Function Attrs: nounwind
define dso_local void @test_phi02(ptr %_pA, ptr %_pB, i32 %n) #0 {
entry:
  %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !14)
  %1 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !17)
  %arrayidx = getelementptr inbounds ptr, ptr %_pB, i32 2
  %2 = load ptr, ptr %arrayidx, align 4, !tbaa !7, !noalias !19
  %3 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %_pA, ptr %0, ptr null, i32 0, metadata !14), !tbaa !7, !noalias !19
  %4 = load ptr, ptr %_pB, align 4, !tbaa !7, !noalias !19
  %arrayidx2 = getelementptr inbounds ptr, ptr %_pB, i32 1
  %5 = load ptr, ptr %arrayidx2, align 4, !tbaa !7, !noalias !19
  br label %for.cond

for.cond:                                         ; preds = %for.body, %entry
  %pTmp00.0 = phi ptr [ %4, %entry ], [ %pTmp01.0, %for.body ]
  %pTmp01.0 = phi ptr [ %5, %entry ], [ %3, %for.body ]
  %i.0 = phi i32 [ 0, %entry ], [ %inc, %for.body ]
  %cmp = icmp slt i32 %i.0, %n
  br i1 %cmp, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.cond
  %6 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %_pA, ptr %0, ptr null, i32 0, metadata !14), !tbaa !7, !noalias !19
  store i16 99, ptr %6, align 2, !tbaa !20, !noalias !19
  store i16 42, ptr %pTmp00.0, align 2, !tbaa !20, !noalias !19
  %cmp5 = icmp sgt i32 %n, 5
  %7 = call ptr @llvm.noalias.p0.p0.p0.i32(ptr %2, ptr %1, ptr null, i32 0, metadata !17)
  %cond = select i1 %cmp5, ptr %pTmp00.0, ptr %7
  store i16 43, ptr %cond, align 2, !tbaa !20, !noalias !19
  ret void

for.body:                                         ; preds = %for.cond
  %arrayidx3 = getelementptr inbounds i16, ptr %pTmp01.0, i32 1
  %8 = load i16, ptr %arrayidx3, align 2, !tbaa !20, !noalias !19
  %arrayidx4 = getelementptr inbounds i16, ptr %pTmp00.0, i32 1
  store i16 %8, ptr %arrayidx4, align 2, !tbaa !20, !noalias !19
  %inc = add nsw i32 %i.0, 1
  br label %for.cond
}

; CHECK-LABEL: @test_phi02(
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !14)
; CHECK-NEXT:   %1 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !17)
; CHECK-NEXT:   %arrayidx = getelementptr inbounds ptr, ptr %_pB, i32 2
; CHECK-NEXT:   %2 = load ptr, ptr %arrayidx, align 4, !tbaa !7, !noalias !19
; CHECK-NEXT:   %3 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_pA, ptr %0, ptr null, ptr undef, i32 0, metadata !14), !tbaa !7, !noalias !19
; CHECK-NEXT:   %4 = load ptr, ptr %_pB, align 4, !tbaa !7, !noalias !19
; CHECK-NEXT:   %arrayidx2 = getelementptr inbounds ptr, ptr %_pB, i32 1
; CHECK-NEXT:   %5 = load ptr, ptr %arrayidx2, align 4, !tbaa !7, !noalias !19
; CHECK-NEXT:   br label %for.cond
; CHECK: for.cond:
; CHECK-NEXT:   %prov.pTmp00.0 = phi ptr [ %4, %entry ], [ %prov.pTmp01.0, %for.body ]
; CHECK-NEXT:   %pTmp00.0 = phi ptr [ %4, %entry ], [ %pTmp01.0, %for.body ]
; CHECK-NEXT:   %prov.pTmp01.0 = phi ptr [ %5, %entry ], [ %3, %for.body ]
; CHECK-NEXT:   %pTmp01.0 = phi ptr [ %5, %entry ], [ %_pA, %for.body ]
; CHECK-NEXT:   %i.0 = phi i32 [ 0, %entry ], [ %inc, %for.body ]
; CHECK-NEXT:   %cmp = icmp slt i32 %i.0, %n
; CHECK-NEXT:   br i1 %cmp, label %for.body, label %for.cond.cleanup
; CHECK: for.cond.cleanup:
; CHECK-NEXT:   store i16 99, ptr %_pA, ptr_provenance ptr %3, align 2, !tbaa !20, !noalias !19
; CHECK-NEXT:   store i16 42, ptr %pTmp00.0, ptr_provenance ptr %prov.pTmp00.0, align 2, !tbaa !20, !noalias !19
; CHECK-NEXT:   %cmp5 = icmp sgt i32 %n, 5
; CHECK-NEXT:   %6 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %2, ptr %1, ptr null, ptr undef, i32 0, metadata !17)
; CHECK-NEXT:   %prov.cond = select i1 %cmp5, ptr %prov.pTmp00.0, ptr %6
; CHECK-NEXT:   %cond = select i1 %cmp5, ptr %pTmp00.0, ptr %2
; CHECK-NEXT:   store i16 43, ptr %cond, ptr_provenance ptr %prov.cond, align 2, !tbaa !20, !noalias !19
; CHECK-NEXT:   ret void
; CHECK: for.body:
; CHECK-NEXT:   %arrayidx3 = getelementptr inbounds i16, ptr %pTmp01.0, i32 1
; CHECK-NEXT:   %7 = load i16, ptr %arrayidx3, ptr_provenance ptr %prov.pTmp01.0, align 2, !tbaa !20, !noalias !19
; CHECK-NEXT:   %arrayidx4 = getelementptr inbounds i16, ptr %pTmp00.0, i32 1
; CHECK-NEXT:   store i16 %7, ptr %arrayidx4, ptr_provenance ptr %prov.pTmp00.0, align 2, !tbaa !20, !noalias !19
; CHECK-NEXT:   %inc = add nsw i32 %i.0, 1
; CHECK-NEXT:   br label %for.cond
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
!3 = distinct !{!3, !4, !"test_phi01: rpTmp"}
!4 = distinct !{!4, !"test_phi01"}
!5 = !{!6}
!6 = distinct !{!6, !4, !"test_phi01: rp2"}
!7 = !{!8, !8, i64 0, i64 4}
!8 = !{!9, i64 4, !"any pointer"}
!9 = !{!10, i64 1, !"omnipotent char"}
!10 = !{!"Simple C/C++ TBAA"}
!11 = !{!3, !6}
!12 = !{!13, !13, i64 0, i64 4}
!13 = !{!9, i64 4, !"int"}
!14 = !{!15}
!15 = distinct !{!15, !16, !"test_phi02: rpTmp"}
!16 = distinct !{!16, !"test_phi02"}
!17 = !{!18}
!18 = distinct !{!18, !16, !"test_phi02: rp2"}
!19 = !{!15, !18}
!20 = !{!21, !21, i64 0, i64 2}
!21 = !{!9, i64 2, !"short"}

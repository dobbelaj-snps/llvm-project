; RUN: opt -aa-pipeline=basic-aa -passes='require<aa>,require<targetir>,require<scalar-evolution>,require<opt-remark-emit>,loop-mssa(licm)' < %s -S | FileCheck -check-prefixes=CHECK %s

; Function Attrs: nounwind
define dso_local void @test01(ptr %_p, i32 %n) #0 {
entry:
  %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !2)
  br label %do.body

do.body:                                          ; preds = %do.body, %entry
  %n.addr.0 = phi i32 [ %n, %entry ], [ %dec, %do.body ]
  %1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_p, ptr %0, ptr null, ptr undef, i32 0, metadata !2), !tbaa !5, !noalias !2
  store i32 42, ptr %_p, ptr_provenance ptr %1, align 4, !tbaa !9, !noalias !2
  %dec = add nsw i32 %n.addr.0, -1
  %cmp = icmp ne i32 %dec, 0
  br i1 %cmp, label %do.body, label %do.end

do.end:                                           ; preds = %do.body
  ret void
}

; CHECK-LABEL: @test01(
; CHECK-LABEL: entry:
; CHECK:  %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !2)
; CHECK:  %1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_p, ptr %0, ptr null, ptr undef, i32 0, metadata !2), !tbaa !5, !noalias !2
; CHECK-NOT: @llvm.provenance.noalias.
; CHECK: store i32 42, ptr %_p, ptr_provenance ptr %1, align 4, !tbaa !9, !noalias !2
; CHECK-NOT: @llvm.provenance.noalias.
; CHECK-LABEL: do.body:
; CHECK-NOT: @llvm.provenance.noalias.
; CHECK-LABEL: do.end:
; CHECK-NOT: @llvm.provenance.noalias.
; CHECK: ret void

; Function Attrs: nounwind
define dso_local void @test02(ptr %_p, i32 %n) #0 {
entry:
  br label %do.body

do.body:                                          ; preds = %do.body, %entry
  %n.addr.0 = phi i32 [ %n, %entry ], [ %dec, %do.body ]
  %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !11)
  %1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_p, ptr %0, ptr null, ptr undef, i32 0, metadata !11), !tbaa !5, !noalias !11
  store i32 42, ptr %_p, ptr_provenance ptr %1, align 4, !tbaa !9, !noalias !11
  %dec = add nsw i32 %n.addr.0, -1
  %cmp = icmp ne i32 %dec, 0
  br i1 %cmp, label %do.body, label %do.end

do.end:                                           ; preds = %do.body
  ret void
}

; CHECK-LABEL: @test02(
; CHECK-LABEL: entry:
; CHECK-LABEL: do.body:
; CHECK:  %0 = call ptr @llvm.noalias.decl.p0.p0.i32(ptr null, i32 0, metadata !11)
; CHECK:  %1 = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %_p, ptr %0, ptr null, ptr undef, i32 0, metadata !11), !tbaa !5, !noalias !11
; CHECK-NOT: @llvm.provenance.noalias.
; CHECK-LABEL: do.end:
; CHECK-NOT: @llvm.provenance.noalias.
; CHECK: store i32 42, ptr %_p, align 4, !tbaa !9
; CHECK: ret void

%struct.d = type { ptr }
%struct.f = type { ptr }

; Function Attrs: nofree nounwind
define dso_local void @test03(%struct.d* nocapture readonly %h, %struct.f* %j) local_unnamed_addr #0 !noalias !14 {
entry:
  %e = getelementptr inbounds %struct.d, %struct.d* %h, i32 0, i32 0
  %0 = load ptr, ptr %e, align 4, !tbaa !17, !noalias !14
  %1 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %0, ptr null, ptr nonnull %e, ptr undef, i32 0, metadata !14), !tbaa !17, !noalias !14
  %e1 = getelementptr inbounds %struct.f, %struct.f* %j, i32 0, i32 0
  %e1.promoted = load ptr, ptr %e1, align 4, !tbaa !19, !noalias !14
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body
  %add.ptr.guard.guard.guard.lcssa = phi ptr [ %add.ptr.guard.guard.guard, %for.body ]
  store ptr %add.ptr.guard.guard.guard.lcssa, ptr %e1, align 4, !tbaa !19, !noalias !14
  ret void

for.body:                                         ; preds = %entry, %for.body
  %add.ptr.guard.guard.guard8 = phi ptr [ %e1.promoted, %entry ], [ %add.ptr.guard.guard.guard, %for.body ]
  %i.07 = phi i32 [ 0, %entry ], [ %inc, %for.body ]
  %2 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %add.ptr.guard.guard.guard8, ptr null, ptr nonnull %e1, ptr undef, i32 0, metadata !14), !tbaa !19, !noalias !14
  %.unpack.unpack = load i8, ptr %0, ptr_provenance ptr %1, align 1, !tbaa !21, !noalias !14
  store i8 %.unpack.unpack, ptr %add.ptr.guard.guard.guard8, ptr_provenance ptr %2, align 1, !tbaa !21, !noalias !14
  %add.ptr = getelementptr inbounds i8, ptr %add.ptr.guard.guard.guard8, i32 2
  %add.ptr.guard.guard.guard = tail call ptr @llvm.experimental.ptr.provenance.p0.p0(ptr nonnull %add.ptr, ptr %2)
  %inc = add nuw nsw i32 %i.07, 1
  %cmp = icmp ult i32 %i.07, 55
  br i1 %cmp, label %for.body, label %for.cond.cleanup
}

; CHECK-LABEL: @test03
; CHECK: entry:
; CHECK: @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %0, ptr null, ptr nonnull %e, ptr undef, i32 0, metadata !14), !tbaa !17, !noalias !14
; CHECK-NOT: @llvm.provenance.noalias.
; CHECK: for.cond.cleanup:
; CHECK-NOT: @llvm.provenance.noalias.
; CHECK: for.body:
; CHECK: @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr %add.ptr.guard.guard.guard8, ptr null, ptr nonnull %e1, ptr undef, i32 0, metadata !14), !tbaa !19, !noalias !14
; CHECK-NOT: @llvm.provenance.noalias.
; CHECK: }


; Function Attrs: argmemonly nounwind
declare ptr @llvm.noalias.decl.p0.p0.i32(ptr, i32, metadata) #1

; Function Attrs: nounwind readnone speculatable
declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i32(ptr, ptr, ptr, ptr, i32, metadata) #2

; Function Attrs: nounwind readnone speculatable
declare ptr @llvm.experimental.ptr.provenance.p0.p0(ptr %0, ptr %1) #2

attributes #0 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { argmemonly nounwind }
attributes #2 = { nounwind readnone speculatable }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang"}
!2 = !{!3}
!3 = distinct !{!3, !4, !"test01: rp"}
!4 = distinct !{!4, !"test01"}
!5 = !{!6, !6, i64 0, i64 4}
!6 = !{!7, i64 4, !"any pointer"}
!7 = !{!8, i64 1, !"omnipotent char"}
!8 = !{!"Simple C/C++ TBAA"}
!9 = !{!10, !10, i64 0, i64 4}
!10 = !{!7, i64 4, !"int"}
!11 = !{!12}
!12 = distinct !{!12, !13, !"test02: rp"}
!13 = distinct !{!13, !"test02"}
!14 = !{!15}
!15 = distinct !{!15, !16, !"test03: unknown scope"}
!16 = distinct !{!16, !"test03"}
!17 = !{!18, !6, i64 0, i64 4}
!18 = !{!7, i64 4, !"d", !6, i64 0, i64 4}
!19 = !{!20, !6, i64 0, i64 4}
!20 = !{!7, i64 4, !"f", !6, i64 0, i64 4}
!21 = !{!22, !22, i64 0, i64 1}
!22 = !{!7, i64 1, !"b", !23, i64 0, i64 1}
!23 = !{!7, i64 1, !"a"}

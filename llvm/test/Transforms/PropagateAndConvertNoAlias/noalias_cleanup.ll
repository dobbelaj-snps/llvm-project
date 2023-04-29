; RUN: opt < %s -passes=convert-noalias,verify -S | FileCheck %s

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define dso_local void @foo() local_unnamed_addr #0 {
entry:
  br label %for.cond

for.cond:                                         ; preds = %if.then, %entry
  %prov.bar.0 = phi ptr [ undef, %entry ], [ %prov.bar.0, %if.then ]
  br i1 undef, label %for.cond3thread-pre-split, label %if.then

if.then:                                          ; preds = %for.cond
  %0 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.bar.0, ptr undef, ptr null, ptr undef, i64 0, metadata !1)
  br i1 undef, label %for.cond, label %for.body

for.body:                                         ; preds = %for.body, %if.then
  %prov.bar.116 = phi ptr [ %1, %for.body ], [ %prov.bar.0, %if.then ]
  %1 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.bar.116, ptr undef, ptr null, ptr undef, i64 0, metadata !1)
  br label %for.body

for.cond3thread-pre-split:                        ; preds = %for.cond
  br label %for.body5

for.body5:                                        ; preds = %for.body5, %for.cond3thread-pre-split
  %prov.bar.220 = phi ptr [ %2, %for.body5 ], [ %prov.bar.0, %for.cond3thread-pre-split ]
  %2 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %prov.bar.220, ptr undef, ptr null, ptr undef, i64 0, metadata !1)
  br label %for.body5
}

; CHECK-LABEL: @foo
; CHECK: call ptr @llvm.provenance.noalias
; CHECK-NOT: call ptr @llvm.provenance.noalias

; Function Attrs: nounwind readnone speculatable
declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr, ptr, ptr, ptr, i64, metadata) #1

attributes #0 = { "use-soft-float"="false" }
attributes #1 = { nounwind readnone speculatable }

!llvm.ident = !{!0}

!0 = !{!"clang)"}
!1 = !{!2}
!2 = distinct !{!2, !3, !"foo: bar"}
!3 = distinct !{!3, !"foo"}

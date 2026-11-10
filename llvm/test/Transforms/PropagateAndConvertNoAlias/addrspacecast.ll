; RUN: opt < %s -passes=convert-noalias,instcombine,verify -S | FileCheck %s

define void @test(ptr %p, i32 %a) {
entry:
  %r.decl = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !1)
  %r.addr = getelementptr inbounds i32, ptr %p, i32 %a
  %r.prov = call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr %r.addr, ptr %r.decl, ptr null, ptr undef, i64 0, metadata !1), !noalias !1
  %r.prov.as = addrspacecast ptr %r.prov to ptr addrspace(2)
  %r.addr.as = addrspacecast ptr %r.addr to ptr addrspace(2)
  %r.guard = call ptr addrspace(2) @llvm.experimental.ptr.provenance.p2.p2(ptr addrspace(2) %r.addr.as, ptr addrspace(2) %r.prov.as)
  br label %for.body

for.body:
  %iv.i = phi i32 [ 0, %entry ], [ %i.inc, %for.body ]
  %iv.r = phi ptr addrspace(2) [ %r.guard, %entry ], [ %r.inc, %for.body ]
  %iv.p = phi ptr [ %p, %entry ], [ %p.inc, %for.body ]
  %tmp = load i32, ptr addrspace(2) %iv.r, !noalias !1
  store i32 %tmp, ptr %iv.p, !noalias !1
  %i.inc = add nsw i32 %iv.i, 1
  %r.inc = getelementptr inbounds nuw i32, ptr addrspace(2) %iv.r, i32 1
  %p.inc = getelementptr inbounds nuw i32, ptr %iv.p, i32 1
  %cmp = icmp slt i32 %i.inc, %a
  br i1 %cmp, label %for.body, label %for.end

for.end:
  ret void
}

; convert-noalias splits the %iv.r phi into an "addr" and "prov" phi, but would
; fail to connect the "prov" phi to %r.prov.as, leaving it "undef" and thus
; losing the provenance.
;
; (The "prov" phi has itself as input value coming from %for.body; we use
; instcombine to remove it.)

; CHECK-LABEL: @test
; CHECK: for.body:
; CHECK: load i32, ptr addrspace(2) %iv.r, ptr_provenance ptr addrspace(2) %r.prov.as
; CHECK: for.end:

declare ptr @llvm.noalias.decl.p0.p0.i64(ptr, i64, metadata)
declare ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr, ptr, ptr, ptr, i64, metadata)
declare ptr addrspace(2) @llvm.experimental.ptr.provenance.p2.p2(ptr addrspace(2), ptr addrspace(2))

!1 = !{!2}
!2 = distinct !{!2, !3, !"test: r"}
!3 = distinct !{!3, !"test"}

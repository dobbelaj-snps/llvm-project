; RUN: not llvm-as %s -o /dev/null 2>&1 | FileCheck %s

define ptr @test00(ptr %a, ptr %b, i32 %c) {
entry:
  %tobool.not = icmp eq i32 %c, 0
; CHECK: UnknownProvenance not on the ptr_provenance path
; CHECK-NEXT: %add.ptr = getelementptr inbounds i32, ptr unknown_provenance, i64 10
; CHECK-NEXT:0
  %add.ptr = getelementptr inbounds i32, ptr unknown_provenance, i64 10
  %retval = select i1 %tobool.not, ptr %add.ptr, ptr %a
  ret ptr %retval
}

define ptr @test01(ptr %a, ptr %b, i32 %c) {
entry:
  %tobool.not = icmp eq i32 %c, 0
  %retval = select i1 %tobool.not, ptr unknown_provenance, ptr %a
; CHECK: UnknownProvenance not on the ptr_provenance path
; CHECK-NEXT: ret ptr %retval
; CHECK-NEXT:0
  ret ptr %retval
}

define void @test02(ptr %a, ptr %b, i32 %c) {
entry:
  %tobool.not = icmp eq i32 %c, 0
  %retval = select i1 %tobool.not, ptr unknown_provenance, ptr %a
; CHECK: UnknownProvenance not on the ptr_provenance path
; CHECK-NEXT: store i32 %c, ptr %retval
; CHECK-NEXT:1
  store i32 %c, ptr %retval
  ret void
}

define void @test03(ptr %a, ptr %b, i32 %c) {
entry:
  %tobool.not = icmp eq i32 %c, 0
  %retval = select i1 %tobool.not, ptr unknown_provenance, ptr %a
; CHECK-NOT: store i32 %c, ptr %b, ptr_provenance ptr %retval
  store i32 %c, ptr %b, ptr_provenance ptr %retval
  ret void
}
; CHECK-NOT: UnknownProvenance not on the ptr_provenance path

@t = global i32 0, align 4

define void @test04(ptr %a, i32 %c) {
entry:
  %0 = load volatile i32, ptr @t, align 4
  %tobool.not1 = icmp eq i32 %0, 0
  br i1 %tobool.not1, label %while.end, label %while.body

while.body:                                       ; preds = %entry, %while.body
  %c.addr.03 = phi i32 [ %inc, %while.body ], [ %c, %entry ]
  %a.addr.02 = phi ptr [ %incdec.ptr, %while.body ], [ %a, %entry ]
  %prov.a = phi ptr [  unknown_provenance, %while.body ], [ %a, %entry ]
  %inc = add nsw i32 %c.addr.03, 1
  %incdec.ptr = getelementptr inbounds i32, ptr %a.addr.02, i64 1
  store i32 %c.addr.03, ptr %a.addr.02, ptr_provenance ptr %prov.a, align 4
  %1 = load volatile i32, ptr @t, align 4
  %tobool.not = icmp eq i32 %1, 0
  br i1 %tobool.not, label %while.end, label %while.body

while.end:                                        ; preds = %while.body, %entry
  ret void
}

define void @test05(ptr %a, i32 %c) {
entry:
  %0 = load volatile i32, ptr @t, align 4
  %tobool.not1 = icmp eq i32 %0, 0
  br i1 %tobool.not1, label %while.end, label %while.body

while.body:                                       ; preds = %entry, %while.body
  %c.addr.03 = phi i32 [ %inc, %while.body ], [ %c, %entry ]
  %a.addr.02 = phi ptr [ %incdec.ptr, %while.body ], [ %a, %entry ]
  %prov.a = phi ptr [  unknown_provenance, %while.body ], [ %a, %entry ]
  %inc = add nsw i32 %c.addr.03, 1
  %incdec.ptr = getelementptr inbounds i32, ptr %a.addr.02, i64 1
  store i32 %c.addr.03, ptr %prov.a, ptr_provenance ptr %a.addr.02, align 4
  %1 = load volatile i32, ptr @t, align 4
  %tobool.not = icmp eq i32 %1, 0
  br i1 %tobool.not, label %while.end, label %while.body

while.end:                                        ; preds = %while.body, %entry
  ret void
}
; CHECK:        UnknownProvenance not on the ptr_provenance path
; CHECK-NEXT:   store i32 %c.addr.03, ptr %prov.a, ptr_provenance ptr %a.addr.02, align 4
; CHECK-NEXT:   1

; CHECK-NOT: UnknownProvenance not on the ptr_provenance path

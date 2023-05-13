; RUN: opt -passes=deadargelim -S < %s | FileCheck %s

; Checks if !noalias metadata is correct in deadargelim.

define void @caller() #0 {
; CHECK: call void @test_vararg(), !noalias ![[NA:[0-9]]]
; CHECK: call void @test(), !noalias ![[NA]]
  call void (i32, ...) @test_vararg(i32 1), !noalias !0
  call void @test(i32 1), !noalias !0
  ret void
}

define internal void @test_vararg(i32, ...) #1 {
  ret void
}

define internal void @test(i32 %a) #1 {
  ret void
}

; CHECK:![[NA]] = !{![[NA2:[0-9]]]}
; CHECK:![[NA2]] = distinct !{![[NA2]], ![[NA3:[0-9]]], !"the var"}
; CHECK:![[NA3]] = distinct !{![[NA3]], !"the scope"}
!0 = !{!1}
!1 = distinct !{!1, !2, !"the var"}
!2 = distinct !{!2, !"the scope"}


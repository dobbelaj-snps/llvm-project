; RUN: opt < %s -passes=globalopt -S | FileCheck %s

%struct.anon = type { i32, i32 }

@s = internal unnamed_addr global %struct.anon zeroinitializer
; Usage of the global in the ptr_provenance operand blocks SRA currently
; CHECK: @s = internal unnamed_addr global %struct.anon

define void @f(i32 %x) {
  store i32 %x, ptr @s, ptr_provenance ptr @s
  ret void
}

define i32 @g() {
  %val = load i32, ptr @s
  ret i32 %val
}


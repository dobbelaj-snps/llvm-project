// RUN: %clang_cc1 -triple x86_64-unknown-unknown -O2 -ffull-restrict %s -emit-llvm -o - | FileCheck %s

// NOTE: SROA needs to be able to see through <tt>llvm.noalias</tt>. This is introduced in case of returning of larger structs.
struct A {
  int a, b, c, d, e, f, g, h;
};
struct A constructIt(int a) {
  struct A tmp = {a, a, a, a, a, a, a, a};
  return tmp;
}


// Next functions must be identical (except for the name)
int test_sroa01a(unsigned c) {
  int tmp = 0;
  for (int i = 0; i < c; ++i) {
    struct A a = constructIt(i);
    tmp = tmp + a.e;
  }
  return tmp;
}

// CHECK-LABEL: @test_sroa01a
// CHECK: entry:
// CHECK-NEXT:  = icmp eq i32 %c, 0
// CHECK-NEXT:  br i1 {{%.*}}, label %for.cond.cleanup, label %for.body.preheader
// CHECK: for.body.preheader:
// CHECK-NEXT:  add i32 %c, -1
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  add i32 %c, -2
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  mul i33
// CHECK-NEXT:  lshr i33
// CHECK-NEXT:  trunc i33
// CHECK-NEXT:  add i32
// CHECK-NEXT:  add i32
// CHECK-NEXT:  br label %for.cond.cleanup
// CHECK: for.cond.cleanup:
// CHECK-NEXT:  = phi i32
// CHECK-NEXT:  ret i32 %


int test_sroa01b(unsigned c) {
  int tmp = 0;
  for (int i = 0; i < c; ++i) {
    struct A a = {i, i, i, i, i, i, i, i};
    tmp = tmp + a.e;
  }
  return tmp;
}

// CHECK-LABEL: @test_sroa01b
// CHECK: entry:
// CHECK-NEXT:  = icmp eq i32 %c, 0
// CHECK-NEXT:  br i1 {{%.*}}, label %for.cond.cleanup, label %for.body.preheader
// CHECK: for.body.preheader:
// CHECK-NEXT:  add i32 %c, -1
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  add i32 %c, -2
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  mul i33
// CHECK-NEXT:  lshr i33
// CHECK-NEXT:  trunc i33
// CHECK-NEXT:  add i32
// CHECK-NEXT:  add i32
// CHECK-NEXT:  br label %for.cond.cleanup
// CHECK: for.cond.cleanup:
// CHECK-NEXT:  = phi i32
// CHECK-NEXT:  ret i32 %


int test_sroa01c(unsigned c) {
  int tmp = 0;
  for (int i = 0; i < c; ++i) {
    int *__restrict dummy; // should not influence optimizations !
    struct A a = {i, i, i, i, i, i, i, i};
    tmp = tmp + a.e;
  }
  return tmp;
}

// CHECK-LABEL: @test_sroa01c
// CHECK: entry:
// CHECK-NEXT:  = icmp eq i32 %c, 0
// CHECK-NEXT:  br i1 {{%.*}}, label %for.cond.cleanup, label %for.body.preheader
// CHECK: for.body.preheader:
// CHECK-NEXT:  add i32 %c, -1
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  add i32 %c, -2
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  mul i33
// CHECK-NEXT:  lshr i33
// CHECK-NEXT:  trunc i33
// CHECK-NEXT:  add i32
// CHECK-NEXT:  add i32
// CHECK-NEXT:  br label %for.cond.cleanup
// CHECK: for.cond.cleanup:
// CHECK-NEXT:  = phi i32
// CHECK-NEXT:  ret i32 %


int test_sroa02a(unsigned c) {
  int tmp = 0;
  struct A a;
  for (int i = 0; i < c; ++i) {
    a = constructIt(i);
    tmp = tmp + a.e;
  }
  return tmp;
}

// CHECK-LABEL: @test_sroa02a
// CHECK: entry:
// CHECK-NEXT:  = icmp eq i32 %c, 0
// CHECK-NEXT:  br i1 {{%.*}}, label %for.cond.cleanup, label %for.body.preheader
// CHECK: for.body.preheader:
// CHECK-NEXT:  add i32 %c, -1
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  add i32 %c, -2
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  mul i33
// CHECK-NEXT:  lshr i33
// CHECK-NEXT:  trunc i33
// CHECK-NEXT:  add i32
// CHECK-NEXT:  add i32
// CHECK-NEXT:  br label %for.cond.cleanup
// CHECK: for.cond.cleanup:
// CHECK-NEXT:  = phi i32
// CHECK-NEXT:  ret i32 %


int test_sroa02b(unsigned c) {
  struct A a;
  int tmp = 0;
  for (int i = 0; i < c; ++i) {
    a = (struct A){i, i, i, i, i, i, i, i};
    tmp = tmp + a.e;
  }
  return tmp;
}

// CHECK-LABEL: @test_sroa02b
// CHECK: entry:
// CHECK-NEXT:  = icmp eq i32 %c, 0
// CHECK-NEXT:  br i1 {{%.*}}, label %for.cond.cleanup, label %for.body.preheader
// CHECK: for.body.preheader:
// CHECK-NEXT:  add i32 %c, -1
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  add i32 %c, -2
// CHECK-NEXT:  zext i32
// CHECK-NEXT:  mul i33
// CHECK-NEXT:  lshr i33
// CHECK-NEXT:  trunc i33
// CHECK-NEXT:  add i32
// CHECK-NEXT:  add i32
// CHECK-NEXT:  br label %for.cond.cleanup
// CHECK: for.cond.cleanup:
// CHECK-NEXT:  = phi i32
// CHECK-NEXT:  ret i32 %

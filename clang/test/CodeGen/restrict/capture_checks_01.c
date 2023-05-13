// RUN: %clang_cc1 -triple x86_64-unknown-unknown -O3 -ffull-restrict %s -emit-llvm -o - | FileCheck %s
// NOTE: capture tracking is missing some escapes resulting in wrong conclusions. Global objects
//       handling also will need extra investigation

extern void captureIt_p_pp(int *p1, int **p2);
extern void captureIt_pp_pp(int **p1, int **p2);

// CHECK-LABEL: capture_direct_01
// CHECK: ret i32 42
int capture_direct_01(int * restrict p, int *q) {
  *p=42;
  *q=10;
  return *p; // 42
}

// CHECK-LABEL: capture_direct_02
// CHECK: ret i32 %
int capture_direct_02(int * restrict p, int *q) {
  *p=42;
  *q=10;
  captureIt_p_pp(p, &q);
  return *p; // unkown
}

// CHECK-LABEL: capture_direct_03
// CHECK: ret i32 %
int capture_direct_03(int * restrict p, int *q) {
  *p=42;
  *q=10;
  captureIt_pp_pp(&p, &q);
  return *p; // unkown
}

// CHECK-LABEL: capture_direct_04
// CHECK: ret i32 %
int capture_direct_04(int * restrict p, int *q) {
  *p=42;
  *q=10;
  captureIt_pp_pp(&q, &p);
  return *p; // unkown
}


// CHECK-LABEL: capture_indirect_01a
// CHECK: ret i32 %
int capture_indirect_01a(int * restrict *p, int *q) {
  **p=42;
  *q=10;
  return **p; // unknown, q can be based on *p
}

// CHECK-LABEL: capture_indirect_01b
// CHECK: ret i32 42
int capture_indirect_01b(int * restrict * restrict p, int *q) {
  **p=42;
  *q=10;
  return **p; // unknown, q can be based on *p
}

// CHECK-LABEL: capture_indirect_02
// CHECK: ret i32 %
int capture_indirect_02(int * restrict *p, int *q) {
  **p=42;
  *q=10;
  captureIt_p_pp(*p, &q);
  return **p; // unkown
}

// CHECK-LABEL: capture_indirect_03
// CHECK: ret i32 %
int capture_indirect_03(int * restrict *p, int *q) {
  **p=42;
  *q=10;
  captureIt_pp_pp(p, &q);
  return **p; // unkown
}

// CHECK-LABEL: capture_indirect_04
// CHECK: ret i32 %
int capture_indirect_04(int * restrict *p, int *q) {
  **p=42;
  *q=10;
  captureIt_pp_pp(&q, p);
  return **p; // unkown
}

int * restrict grp;
int * restrict * grpp;
int * restrict * restrict grprp;
int * gq;
int * restrict grq;
int * restrict * grqq;
int * restrict * restrict grqrq;

// CHECK-LABEL: capture_global_direct_01
// CHECK: ret i32 %
int capture_global_direct_01(int *q) {
  *grp=42;
  *q=10;
  return *grp; // unknown
}

// CHECK-LABEL: capture_global_direct_02
// CHECK: ret i32 %
int capture_global_direct_02() {
  *grp=42;
  *gq=10;
  return *grp; // unknown (!)
}

// CHECK-LABEL: capture_global_direct_03
// CHECK: ret i32 42
int capture_global_direct_03() {
  *grp=42;
  *grq=10;
  return *grp; // 42
}

// CHECK-LABEL: capture_global_indirect_01
// CHECK: ret i32 %
int capture_global_indirect_01(int *q) {
  **grpp=42;
  *q=10;
  return **grpp; // unknown (!)
}

// CHECK-LABEL: capture_global_indirect_02
// CHECK: ret i32 %
int capture_global_indirect_02() {
  **grpp=42;
  *gq=10;
  return **grpp; // unknown (!)
}

// CHECK-LABEL: capture_global_indirect_03
// CHECK: ret i32 %
int capture_global_indirect_03() {
  **grpp=42;
  *grq=10;
  return **grpp; // unknown (!)
}

// CHECK-LABEL: capture_global_indirect_04
// CHECK: ret i32 %
int capture_global_indirect_04(int *q) {
  **grprp=42;
  *q=10;
  return **grprp; // unknown (!)
}

// CHECK-LABEL: capture_global_indirect_05
// CHECK: ret i32 %
int capture_global_indirect_05() {
  **grprp=42;
  *gq=10;
  return **grprp; // unknown (!)
}

// CHECK-LABEL: capture_global_indirect_06
// CHECK: ret i32 %
int capture_global_indirect_06() {
  **grprp=42;
  **grqq=10;
  return **grprp; // 42
}

// CHECK-LABEL: capture_global_indirect_07
// CHECK: ret i32 42
int capture_global_indirect_07() {
  **grprp=42;
  **grqrq=10;
  return **grprp; // 42
}

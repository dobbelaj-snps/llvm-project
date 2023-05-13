// RUN: %clang_cc1 -triple x86_64-unknown-unknown -O3 -ffull-restrict %s -emit-llvm -o - | FileCheck %s
// NOTE: capture tracking is missing some escapes resulting in wrong conclusions. Global objects
//       handling also will need extra investigation
//
// Similar to capture_checks_01.c; based on examples from the flang community
//
// Currently this is set to xfail. Following deductions are missed:

// - passing a struct (object) containing a restrict pointer to an unknown function is an 'escape' (test_02, test_04)
// - a global non-restrict pointer and a global restrict pointer can alias (test_03, test_04, test_1n2r_g, test_2r1n_g)
// This should be resolved in ScopedNoAliasAA.cpp

typedef struct fdesc_norestric_t { float *base_addr; } fdesc_norestrict_t;
typedef struct fdesc_restrict_t {  float *restrict base_addr; } fdesc_restrict_t;

extern void unknown(fdesc_restrict_t *, fdesc_norestrict_t *);

#if 0 // example unknown function
__attribute__((noinline)) void unknown(fdesc_restrict_t *d1, fdesc_norestrict_t *d2) {
  d2->base_addr = d1->base_addr+7;
}
#endif


// CHECK-LABEL: test_01
// CHECK: load float
// CHECK: store float
// CHECK-NOT: load float
// CHECK-NOT: store float
// CHECK: ret void
void test_01(fdesc_restrict_t d1, fdesc_norestrict_t d2) {
  // d1.base_addr and d2.base_addr are unrelated
  d1.base_addr[14] = d2.base_addr[7] + 1;
  d1.base_addr[14] = d2.base_addr[7] - 1;  // no reload needed
}

// CHECK-LABEL: test_02
// CHECK: load float
// CHECK: store float
// CHECK: load float
// CHECK: store float
// CHECK: ret void
void test_02(fdesc_restrict_t d1, fdesc_norestrict_t d2) {
  unknown(&d1, &d2); // might spill d1.base_addr to d2.base_addr
  d1.base_addr[14] = d2.base_addr[7] + 1;
  d1.base_addr[14] = d2.base_addr[7] - 1; // reload needed
}

// CHECK-LABEL: test_03
// CHECK: load float
// CHECK: store float
// CHECK: load float
// CHECK: store float
// CHECK: ret void
void test_03(fdesc_restrict_t *d1, fdesc_norestrict_t *d2) {
  // d1->base_addr and d2->base_addr might be related
  d1->base_addr[14] = d2->base_addr[7] + 1;
  d1->base_addr[14] = d2->base_addr[7] - 1; // reload needed
}

// CHECK-LABEL: test_04
// CHECK: load float
// CHECK: store float
// CHECK: load float
// CHECK: store float
// CHECK: ret void
void test_04(fdesc_restrict_t *d1, fdesc_norestrict_t *d2) {
  // d1->base_addr and d2->base_addr might be related
  unknown(d1, d2);
  d1->base_addr[14] = d2->base_addr[7] + 1;
  d1->base_addr[14] = d2->base_addr[7] - 1; // reload needed
}


extern fdesc_norestrict_t d1_n;
extern fdesc_norestrict_t d2_n;

extern fdesc_restrict_t d1_r;
extern fdesc_restrict_t d2_r;

// CHECK-LABEL: test_1n2n_g
// CHECK: load float
// CHECK: store float
// CHECK: load float
// CHECK: store float
// CHECK: ret void
void test_1n2n_g() {
  // d1_n.base_addr and d2_n.base_addr might be related
  d1_n.base_addr[2] = d2_n.base_addr[1] + 1;
  d1_n.base_addr[2] = d2_n.base_addr[1] - 1; // reload needed
}

// CHECK-LABEL: test_1n2r_g
// CHECK: load float
// CHECK: store float
// CHECK: load float
// CHECK: store float
// CHECK: ret void
void test_1n2r_g() {
  // d1_n.base_addr and d2_r.base_addr might be related
  d1_n.base_addr[2] = d2_r.base_addr[1] + 1;
  d1_n.base_addr[2] = d2_r.base_addr[1] - 1; // reload needed
}

// CHECK-LABEL: test_2r1n_g
// CHECK: load float
// CHECK: store float
// CHECK: load float
// CHECK: store float
// CHECK: ret void
void test_2r1n_g() {
  // d1_n.base_addr and d2_r.base_addr might be related
  d2_r.base_addr[1] = d1_n.base_addr[1] + 1;
  d2_r.base_addr[1] = d1_n.base_addr[1] - 1;
}

// CHECK-LABEL: test_2r2r_g
// CHECK: load float
// CHECK: store float
// CHECK-NOT: load float
// CHECK-NOT: store float
// CHECK: ret void
void test_2r2r_g() {
  // d2_r.base_addr and d2_r.base_addr are identical
  d2_r.base_addr[2] = d2_r.base_addr[1] + 1;
  d2_r.base_addr[2] = d2_r.base_addr[1] - 1; // no reload needed
}

// CHECK-LABEL: test_1r2r_g
// CHECK: load float
// CHECK: store float
// CHECK-NOT: load float
// CHECK-NOT: store float
// CHECK: ret void
void test_1r2r_g() {
  // d1_r.base_addr and d2_r.base_addr are not related
  d1_r.base_addr[2] = d2_r.base_addr[1] + 1;
  d1_r.base_addr[2] = d2_r.base_addr[1] - 1; // no reload needed
}


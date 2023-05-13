// RUN: %clang -Xclang -nostdsysteminc -Xclang  -triple -Xclang x86_64-unknown-unknown  -O3 -ffull-restrict %s -S -emit-llvm -o - | FileCheck %s
// NOTE: capture tracking is missing some escapes resulting in wrong conclusions. Global objects
//       handling also will need extra investigation
//
// Currently LICM sometimes produces inconsistent code with full restrict, triggering a verification assert.
//
// %6 = tail call ptr @llvm.provenance.noalias.p0.p0.p0.p0.i64(ptr nonnull @a, ptr %.lcssa, ptr null, ptr undef, i64 0, metadata !8), !tbaa !15, !noalias !8
// fatal error: error in backend: Broken module found, compilation aborted!
//
// FIXME: current produced code is far from optimal.

int a, c;
char b;

// CHECK-LABEL: test01
// CHECK: ret void
void test01() {
  for (; b; ++b) {
    int *__restrict e = &a;
    c = *e;
  }
}

// RUN: %clang -### -ffull-restrict -S %s 2>&1 | FileCheck %s --check-prefix=CHECK_FULL
// RUN: %clang -### -fno-full-restrict -S %s 2>&1 | FileCheck %s --check-prefix=CHECK_NO_FULL
// RUN: %clang -### -S %s 2>&1 | FileCheck %s --check-prefix=CHECK_NOTHING

// FIXME: How to really check the 'enabled by defaultl' case ?
// FIXME: This test is not able to verify that the 'default = enable' really works  :(

// CHECK_FULL-NOT: -fno-full-restrict
// CHECK_FULL-NOT: -use-noalias-intrinsic-during-inlining
// CHECK_FULL:     -ffull-restrict
// CHECK_FULL-NOT: -fno-full-restrict
// CHECK_FULL-NOT: -use-noalias-intrinsic-during-inlining

// CHECK_NO_FULL-NOT: -ffull-restrict
// CHECK_NO_FULL-NOT: -use-noalias-intrinsic-during-inlining
// CHECK_NO_FULL:     -fno-full-restrict
// CHECK_NO_FULL:     -use-noalias-intrinsic-during-inlining=scopes
// CHECK_NO_FULL-NOT: -ffull-restrict
// CHECK_NO_FULL-NOT: -use-noalias-intrinsic-during-inlining

// CHECK_NOTHING-NOT: -fno-full-restrict
// CHECK_NOTHING-NOT: -ffull-restrict
// CHECK_NOTHING-NOT: -use-noalias-intrinsic-during-inlining

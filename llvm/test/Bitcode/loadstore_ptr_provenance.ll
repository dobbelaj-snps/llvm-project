; RUN: opt -passes=verify -S < %s | FileCheck %s
; Activate when bitcode support is added:
; R U N: llvm-as < %s | llvm-dis | llvm-as | llvm-dis | FileCheck %s
; R U N: verify-uselistorder < %s

define i32 @f(ptr %p, ptr %q, ptr %word, ptr %base) {
  ; CHECK:      define i32 @f(ptr %p, ptr %q, ptr %word, ptr %base) {
  store i32 42, ptr %p, ptr_provenance ptr %p
  ; CHECK-NEXT:   store i32 42, ptr %p, ptr_provenance ptr %p
  store i32 43, ptr %q, ptr_provenance ptr %q
  ; CHECK-NEXT:   store i32 43, ptr %q, ptr_provenance ptr %q
  %r = load i32, ptr %p, ptr_provenance ptr %p
  ; CHECK-NEXT:   %r = load i32, ptr %p, ptr_provenance ptr %p

  store i32 42, ptr %p, ptr_provenance ptr unknown_provenance
  ; CHECK-NEXT:   store i32 42, ptr %p, ptr_provenance ptr unknown_provenance
  store i32 43, ptr %q, ptr_provenance ptr unknown_provenance
  ; CHECK-NEXT:   store i32 43, ptr %q, ptr_provenance ptr unknown_provenance
  %r2 = load i32, ptr %p, ptr_provenance ptr unknown_provenance
  ; CHECK-NEXT:   %r2 = load i32, ptr %p, ptr_provenance ptr unknown_provenance

  %ld.1p = load atomic i32, ptr %word monotonic, ptr_provenance ptr %word, align 4
  ; CHECK: %ld.1p = load atomic i32, ptr %word monotonic, ptr_provenance ptr %word, align 4
  %ld.2p = load atomic volatile i32, ptr %word acquire, ptr_provenance ptr %word, align 8
  ; CHECK: %ld.2p = load atomic volatile i32, ptr %word acquire, ptr_provenance ptr %word, align 8
  %ld.3p = load atomic volatile i32, ptr %word syncscope("singlethread") seq_cst, ptr_provenance ptr %word, align 16
  ; CHECK: %ld.3p = load atomic volatile i32, ptr %word syncscope("singlethread") seq_cst, ptr_provenance ptr %word, align 16

  store atomic i32 23, ptr %word monotonic, align 4
  ; CHECK: store atomic i32 23, ptr %word monotonic, align 4
  store atomic volatile i32 24, ptr %word monotonic, align 4
  ; CHECK: store atomic volatile i32 24, ptr %word monotonic, align 4
  store atomic volatile i32 25, ptr %word syncscope("singlethread") monotonic, align 4
   ; CHECK: store atomic volatile i32 25, ptr %word syncscope("singlethread") monotonic, align 4

  load ptr, ptr %base, ptr_provenance ptr %base, align 8, !invariant.load !0, !nontemporal !1, !nonnull !1, !dereferenceable !2, !dereferenceable_or_null !2
  ; CHECK: load ptr, ptr %base, ptr_provenance ptr %base, align 8, !invariant.load !0, !nontemporal !1, !nonnull !1, !dereferenceable !2, !dereferenceable_or_null !2
  load volatile ptr, ptr %base, ptr_provenance ptr %base, align 8, !invariant.load !0, !nontemporal !1, !nonnull !1, !dereferenceable !2, !dereferenceable_or_null !2
  ; CHECK: load volatile ptr, ptr %base, ptr_provenance ptr %base, align 8, !invariant.load !0, !nontemporal !1, !nonnull !1, !dereferenceable !2, !dereferenceable_or_null !2

  store ptr null, ptr %base, ptr_provenance ptr %base, align 4, !nontemporal !1
  ; CHECK: store ptr null, ptr %base, ptr_provenance ptr %base, align 4, !nontemporal !1
  store volatile ptr null, ptr %base, ptr_provenance ptr %base, align 4, !nontemporal !1
  ; CHECK: store volatile ptr null, ptr %base, ptr_provenance ptr %base, align 4, !nontemporal !1

  ret i32 %r
  ; CHECK-NEXT:   ret i32 %r
}

!0 = !{i32 1}
!1 = !{}
!2 = !{i64 4}

; RUN: opt < %s -passes=sroa -S | FileCheck %s  --check-prefixes=CHECK


; Share the dependency on llvm.noalias.copy.guard:
; RUN: sed < %s -e 's/tmp18,/tmp10,/' -e 's/cp3,/cp2,/' | opt -passes=sroa -S | FileCheck %s --check-prefixes=CHECK,CHECK_S

; Validate that SROA correctly deduces noalias pointers when removing:
; - llvm.mempcy
; - aggregate load/store
; - copying the struct through i64

; General form of each function is based on:
; ------
; struct FOO {
;   int* __restrict p;
; };
;
; struct FUM {
;   int* __restrict p0;
;   struct FOO m1;
; };
;
; void testXXXXXX(struct FUM* a_fum)  // Scope A
; {
;   struct FUM l_fum = *a_fum;       // Scope B
;   {
;     struct FUM l2_fum = l_fum;     // Scope C1
;
;     *l2_fum.p0 = 42;
;   }
;   {
;     struct FUM l3_fum = l_fum;     // Scope C2
;
;     *l3_fum.m1.p = 43;
;   }
; }
; ----
; After SROA, we expect to see following llvm.noalias dependencies:
;  store 42 -> C1 -> B -> A
;  store 43 -> C2 -> B -> A


; ModuleID = 'test.c'
source_filename = "test.c"
target datalayout = "e-m:e-p:32:32-p270:32:32-p271:32:32-p272:64:64-f64:32:64-f80:32-n8:16:32-S128"
target triple = "i386-unknown-linux-gnu"

%struct.FUM = type { ptr, %struct.FOO }
%struct.FOO = type { ptr }

; Function Attrs: nounwind
define dso_local void @test01_memcpy(ptr %a_fum) #0 !noalias !3 {
entry:
  %a_fum.addr = alloca ptr, align 4
  %l_fum = alloca %struct.FUM, align 4
  %l2_fum = alloca %struct.FUM, align 4
  %l3_fum = alloca %struct.FUM, align 4
  store ptr %a_fum, ptr %a_fum.addr, align 4, !tbaa !6, !noalias !10
  %tmp0 = bitcast ptr %l_fum to ptr
  call void @llvm.lifetime.start.p0(i64 8, ptr %tmp0) #5, !noalias !10
  %tmp1 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %l_fum, i64 0, metadata !12), !noalias !10
  %tmp2 = load ptr, ptr %a_fum.addr, align 4, !tbaa !6, !noalias !10
  %tmp3 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %tmp2, ptr null, metadata !13, metadata !3)
  %tmp4 = bitcast ptr %l_fum to ptr
  %tmp5 = bitcast ptr %tmp3 to ptr
  call void @llvm.memcpy.p0.p0.i32(ptr align 4 %tmp4, ptr align 4 %tmp5, i32 8, i1 false), !tbaa.struct !16, !noalias !10
  %tmp6 = bitcast ptr %l2_fum to ptr
  call void @llvm.lifetime.start.p0(i64 8, ptr %tmp6) #5, !noalias !17
  %tmp7 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %l2_fum, i64 0, metadata !19), !noalias !17
  %tmp8 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %l_fum, ptr %tmp1, metadata !13, metadata !12)
  %tmp9 = bitcast ptr %l2_fum to ptr
  %tmp10 = bitcast ptr %tmp8 to ptr
  call void @llvm.memcpy.p0.p0.i32(ptr align 4 %tmp9, ptr align 4 %tmp10, i32 8, i1 false), !tbaa.struct !16, !noalias !17
  %p0 = getelementptr inbounds %struct.FUM, ptr %l2_fum, i32 0, i32 0
  %tmp11 = load ptr, ptr %p0, align 4, !tbaa !20, !noalias !17
  %tmp12 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %tmp11, ptr %tmp7, ptr %p0, i64 0, metadata !19), !tbaa !20, !noalias !17
  store i32 42, ptr %tmp12, align 4, !tbaa !23, !noalias !17
  %tmp13 = bitcast ptr %l2_fum to ptr
  call void @llvm.lifetime.end.p0(i64 8, ptr %tmp13) #5, !noalias !10
  %tmp14 = bitcast ptr %l3_fum to ptr
  call void @llvm.lifetime.start.p0(i64 8, ptr %tmp14) #5, !noalias !25
  %tmp15 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %l3_fum, i64 0, metadata !27), !noalias !25
  %tmp16 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %l_fum, ptr %tmp1, metadata !13, metadata !12)
  %tmp17 = bitcast ptr %l3_fum to ptr
  %tmp18 = bitcast ptr %tmp16 to ptr
  call void @llvm.memcpy.p0.p0.i32(ptr align 4 %tmp17, ptr align 4 %tmp18, i32 8, i1 false), !tbaa.struct !16, !noalias !25
  %m1 = getelementptr inbounds %struct.FUM, ptr %l3_fum, i32 0, i32 1
  %p = getelementptr inbounds %struct.FOO, ptr %m1, i32 0, i32 0
  %tmp19 = load ptr, ptr %p, align 4, !tbaa !28, !noalias !25
  %tmp20 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %tmp19, ptr %tmp15, ptr %p, i64 0, metadata !27), !tbaa !28, !noalias !25
  store i32 43, ptr %tmp20, align 4, !tbaa !23, !noalias !25
  %tmp21 = bitcast ptr %l3_fum to ptr
  call void @llvm.lifetime.end.p0(i64 8, ptr %tmp21) #5, !noalias !10
  %tmp22 = bitcast ptr %l_fum to ptr
  call void @llvm.lifetime.end.p0(i64 8, ptr %tmp22) #5
  ret void
}

; CHECK-LABEL: @test01_memcpy
; CHECK-NOT: alloca
; CHECK:  %0 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !6)
; CHECK:  %1 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 4, metadata !6)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %l_fum.sroa.0.0.l_fum.sroa.0.0.copyload.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %l_fum.sroa.0.0.copyload, ptr null, ptr %tmp5.clone, i64 0, metadata !3)
; CHECK:  %l_fum.sroa.[[SROA:[0-9]+]].0.tmp5.sroa_[[IDX3:idx[0-9]*]] = getelementptr inbounds i8, ptr %tmp5.clone{{3|4}}, i32 4
; CHECK:  %l_fum.sroa.[[SROA]].0.l_fum.sroa.[[SROA]].0.copyload.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %l_fum.sroa.[[SROA]].0.copyload, ptr null, ptr %l_fum.sroa.[[SROA]].0.tmp5.sroa_[[IDX3]], i64 0, metadata !3)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %2 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !15)
; CHECK:  %3 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 4, metadata !15)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %l2_fum.sroa.0.0.l2_fum.sroa.0.0.copyload.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %l_fum.sroa.0.0.l_fum.sroa.0.0.copyload.noalias, ptr %0, ptr null, i64 0, metadata !6)
; CHECK:  %l2_fum.sroa.7.0.l2_fum.sroa.7.0.copyload.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %l_fum.sroa.[[SROA]].0.l_fum.sroa.[[SROA]].0.copyload.noalias, ptr %1, ptr null, i64 4, metadata !6)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %tmp12 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %l2_fum.sroa.0.0.l2_fum.sroa.0.0.copyload.noalias, ptr %2, ptr null, i64 0, metadata !15), !tbaa !17, !noalias !20
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %4 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !23)
; CHECK:  %5 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 4, metadata !23)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %l3_fum.sroa.0.0.l3_fum.sroa.0.0.copyload.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %l_fum.sroa.0.0.l_fum.sroa.0.0.copyload.noalias, ptr %0, ptr null, i64 0, metadata !6)
; CHECK:  %l3_fum.sroa.5.0.l3_fum.sroa.5.0.copyload.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %l_fum.sroa.[[SROA]].0.l_fum.sroa.[[SROA]].0.copyload.noalias, ptr %1, ptr null, i64 4, metadata !6)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %tmp20 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %l3_fum.sroa.5.0.l3_fum.sroa.5.0.copyload.noalias, ptr %5, ptr null, i64 4, metadata !23), !tbaa !25, !noalias !26
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK: ret void

; Function Attrs: argmemonly nounwind willreturn
declare void @llvm.lifetime.start.p0(i64 immarg %0, ptr nocapture %1) #1

; Function Attrs: argmemonly nounwind
declare ptr @llvm.noalias.decl.p0.p0.i64(ptr %0, i64 %1, metadata %2) #2

; Function Attrs: nounwind readnone
declare ptr @llvm.noalias.copy.guard.p0.p0(ptr %0, ptr %1, metadata %2, metadata %3) #3

; Function Attrs: argmemonly nounwind willreturn
declare void @llvm.memcpy.p0.p0.i32(ptr noalias nocapture writeonly %0, ptr noalias nocapture readonly %1, i32 %2, i1 immarg %3) #1

; Function Attrs: argmemonly nounwind speculatable
declare ptr @llvm.noalias.p0.p0.p0.i64(ptr %0, ptr %1, ptr %2, i64 %3, metadata %4) #4

; Function Attrs: argmemonly nounwind willreturn
declare void @llvm.lifetime.end.p0(i64 immarg %0, ptr nocapture %1) #1

; Function Attrs: nounwind
define dso_local void @test02_aggloadstore(ptr %a_fum) #0 !noalias !29 {
entry:
  %a_fum.addr = alloca ptr, align 4
  %l_fum = alloca %struct.FUM, align 4
  %l2_fum = alloca %struct.FUM, align 4
  %l3_fum = alloca %struct.FUM, align 4
  store ptr %a_fum, ptr %a_fum.addr, align 4, !tbaa !6, !noalias !32
  %tmp0 = bitcast ptr %l_fum to ptr
  call void @llvm.lifetime.start.p0(i64 8, ptr %tmp0) #5, !noalias !32
  %tmp1 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %l_fum, i64 0, metadata !34), !noalias !32
  %tmp2 = load ptr, ptr %a_fum.addr, align 4, !tbaa !6, !noalias !32
  %tmp3 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %tmp2, ptr null, metadata !13, metadata !29)
  %cp1 = load %struct.FUM, ptr %tmp3, align 4
  store %struct.FUM %cp1, ptr %l_fum, align 4
  %tmp6 = bitcast ptr %l2_fum to ptr
  call void @llvm.lifetime.start.p0(i64 8, ptr %tmp6) #5, !noalias !35
  %tmp7 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %l2_fum, i64 0, metadata !37), !noalias !35
  %tmp8 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %l_fum, ptr %tmp1, metadata !13, metadata !34)
  %cp2 = load %struct.FUM, ptr %tmp8, align 4
  store %struct.FUM %cp2, ptr %l2_fum, align 4
  %p0 = getelementptr inbounds %struct.FUM, ptr %l2_fum, i32 0, i32 0
  %tmp11 = load ptr, ptr %p0, align 4, !tbaa !20, !noalias !35
  %tmp12 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %tmp11, ptr %tmp7, ptr %p0, i64 0, metadata !37), !tbaa !20, !noalias !35
  store i32 42, ptr %tmp12, align 4, !tbaa !23, !noalias !35
  %tmp13 = bitcast ptr %l2_fum to ptr
  call void @llvm.lifetime.end.p0(i64 8, ptr %tmp13) #5, !noalias !32
  %tmp14 = bitcast ptr %l3_fum to ptr
  call void @llvm.lifetime.start.p0(i64 8, ptr %tmp14) #5, !noalias !38
  %tmp15 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %l3_fum, i64 0, metadata !40), !noalias !38
  %tmp16 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %l_fum, ptr %tmp1, metadata !13, metadata !34)
  %cp3 = load %struct.FUM, ptr %tmp16, align 4
  store %struct.FUM %cp3, ptr %l3_fum, align 4
  %m1 = getelementptr inbounds %struct.FUM, ptr %l3_fum, i32 0, i32 1
  %p = getelementptr inbounds %struct.FOO, ptr %m1, i32 0, i32 0
  %tmp19 = load ptr, ptr %p, align 4, !tbaa !28, !noalias !38
  %tmp20 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %tmp19, ptr %tmp15, ptr %p, i64 0, metadata !40), !tbaa !28, !noalias !38
  store i32 43, ptr %tmp20, align 4, !tbaa !23, !noalias !38
  %tmp21 = bitcast ptr %l3_fum to ptr
  call void @llvm.lifetime.end.p0(i64 8, ptr %tmp21) #5, !noalias !32
  %tmp22 = bitcast ptr %l_fum to ptr
  call void @llvm.lifetime.end.p0(i64 8, ptr %tmp22) #5
  ret void
}

; CHECK-LABEL: @test02_aggloadstore
; CHECK-NOT: alloca
; CHECK:  %0 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !30)
; CHECK:  %1 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 4, metadata !30)
; CHECK:  %tmp3 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %a_fum, ptr null, metadata !32, metadata !27)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %cp1.fca.0.[[GEP5:gep[0-9]+]] = getelementptr inbounds %struct.FUM, ptr %a_fum, i32 0, i32 0
; CHECK:  %cp1.fca.0.load.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %cp1.fca.0.load, ptr null, ptr %cp1.fca.0.[[GEP5]], i64 0, metadata !27)
; CHECK:  %cp1.fca.1.0.[[GEP6:gep[0-9]+]] = getelementptr inbounds %struct.FUM, ptr %a_fum, i32 0, i32 1, i32 0
; CHECK:  %cp1.fca.1.0.load.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %cp1.fca.1.0.load, ptr null, ptr %cp1.fca.1.0.[[GEP6]], i64 0, metadata !27)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %2 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !35)
; CHECK:  %3 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 4, metadata !35)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %cp2.fca.0.load.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %cp1.fca.0.extract, ptr %0, ptr null, i64 0, metadata !30)
; CHECK:  %cp2.fca.1.0.load.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %cp1.fca.1.0.extract, ptr %1, ptr null, i64 4, metadata !30)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %tmp12 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %cp2.fca.{{.*}}.extract, ptr %2, ptr null, i64 0, metadata !35), !tbaa !17, !noalias !37
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %4 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !38)
; CHECK:  %5 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 4, metadata !38)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %cp3.fca.0.load.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %cp1.fca.0.extract, ptr %0, ptr null, i64 0, metadata !30)
; CHECK:  %cp3.fca.1.0.load.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %cp1.fca.1.0.extract, ptr %1, ptr null, i64 4, metadata !30)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %tmp20 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %{{cp3|cp2}}.fca.1.0.extract, ptr %5, ptr null, i64 4, metadata !38), !tbaa !25, !noalias !40
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  ret void

; Function Attrs: nounwind
define dso_local void @test03_i64loadstore(ptr %a_fum) #0 !noalias !41 {
entry:
  %a_fum.addr = alloca ptr, align 4
  %l_fum = alloca %struct.FUM, align 4
  %l2_fum = alloca %struct.FUM, align 4
  %l3_fum = alloca %struct.FUM, align 4
  store ptr %a_fum, ptr %a_fum.addr, align 4, !tbaa !6, !noalias !44
  %tmp0 = bitcast ptr %l_fum to ptr
  call void @llvm.lifetime.start.p0(i64 8, ptr %tmp0) #5, !noalias !44
  %tmp1 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %l_fum, i64 0, metadata !46), !noalias !44
  %tmp2 = load ptr, ptr %a_fum.addr, align 4, !tbaa !6, !noalias !44
  %tmp3 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %tmp2, ptr null, metadata !13, metadata !41)
  %tmp4 = bitcast ptr %l_fum to ptr
  %tmp5 = bitcast ptr %tmp3 to ptr
  %cp1 = load i64, ptr %tmp5, align 4
  store i64 %cp1, ptr %tmp4, align 4
  %tmp6 = bitcast ptr %l2_fum to ptr
  call void @llvm.lifetime.start.p0(i64 8, ptr %tmp6) #5, !noalias !47
  %tmp7 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %l2_fum, i64 0, metadata !49), !noalias !47
  %tmp8 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %l_fum, ptr %tmp1, metadata !13, metadata !46)
  %tmp9 = bitcast ptr %l2_fum to ptr
  %tmp10 = bitcast ptr %tmp8 to ptr

  ; FIXME: Should we treat an i64 copy as a conversion from ptrtoint / inttoptr (which hides provenance somehow) ?
  %cp2 = load i64, ptr %tmp10, align 4
  store i64 %cp2, ptr %tmp9, align 4
  %p0 = getelementptr inbounds %struct.FUM, ptr %l2_fum, i32 0, i32 0
  %tmp11 = load ptr, ptr %p0, align 4, !tbaa !20, !noalias !47
  %tmp12 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %tmp11, ptr %tmp7, ptr %p0, i64 0, metadata !49), !tbaa !20, !noalias !47
  store i32 42, ptr %tmp12, align 4, !tbaa !23, !noalias !47
  %tmp13 = bitcast ptr %l2_fum to ptr
  call void @llvm.lifetime.end.p0(i64 8, ptr %tmp13) #5, !noalias !44
  %tmp14 = bitcast ptr %l3_fum to ptr
  call void @llvm.lifetime.start.p0(i64 8, ptr %tmp14) #5, !noalias !50
  %tmp15 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr %l3_fum, i64 0, metadata !52), !noalias !50
  %tmp16 = call ptr @llvm.noalias.copy.guard.p0.p0(ptr %l_fum, ptr %tmp1, metadata !13, metadata !46)
  %tmp17 = bitcast ptr %l3_fum to ptr
  %tmp18 = bitcast ptr %tmp16 to ptr
  %cp3 = load i64, ptr %tmp18, align 4
  store i64 %cp3, ptr %tmp17, align 4
  %m1 = getelementptr inbounds %struct.FUM, ptr %l3_fum, i32 0, i32 1
  %p = getelementptr inbounds %struct.FOO, ptr %m1, i32 0, i32 0
  %tmp19 = load ptr, ptr %p, align 4, !tbaa !28, !noalias !50
  %tmp20 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %tmp19, ptr %tmp15, ptr %p, i64 0, metadata !52), !tbaa !28, !noalias !50
  store i32 43, ptr %tmp20, align 4, !tbaa !23, !noalias !50
  %tmp21 = bitcast ptr %l3_fum to ptr
  call void @llvm.lifetime.end.p0(i64 8, ptr %tmp21) #5, !noalias !44
  %tmp22 = bitcast ptr %l_fum to ptr
  call void @llvm.lifetime.end.p0(i64 8, ptr %tmp22) #5
  ret void
}

; CHECK-LABEL: @test03_i64loadstore
; CHECK-NOT: alloca
; CHECK:  %0 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !44)
; CHECK:  %1 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 4, metadata !44)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %{{cp1[0-9]*}}.sroa_as_ptr.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %{{cp1[0-9]*}}.sroa_as_ptr, ptr null, ptr %2, i64 0, metadata !41)
; CHECK:  %{{cp1[0-9]*}}.sroa_as_ptr.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %{{cp1[0-9]*}}.sroa_as_ptr, ptr null, ptr %tmp5.sroa_idx, i64 0, metadata !41)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %5 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !46)
; CHECK:  %6 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 4, metadata !46)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK_S:  %cp21.sroa_as_ptr.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %3, ptr %0, ptr null, i64 0, metadata !44)
; CHECK_S:  %cp22.sroa_as_ptr.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %4, ptr %1, ptr null, i64 4, metadata !44)
; CHECK:  %{{cp2[0-9]+}}.sroa_as_ptr.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %3, ptr %0, ptr null, i64 0, metadata !44)
; CHECK:  %{{cp2[0-9]+}}.sroa_as_ptr.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %4, ptr %1, ptr null, i64 4, metadata !44)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %tmp12 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %7, ptr %5, ptr null, i64 0, metadata !46), !tbaa !17, !noalias !48
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %9 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 0, metadata !49)
; CHECK:  %10 = call ptr @llvm.noalias.decl.p0.p0.i64(ptr null, i64 4, metadata !49)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %{{cp3[0-9]*}}.sroa_as_ptr.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %3, ptr %0, ptr null, i64 0, metadata !44)
; CHECK:  %{{cp3[0-9]*}}.sroa_as_ptr.noalias = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %4, ptr %1, ptr null, i64 4, metadata !44)
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  %tmp20 = call ptr @llvm.noalias.p0.p0.p0.i64(ptr %12, ptr %10, ptr null, i64 4, metadata !49), !tbaa !25, !noalias !51
; CHECK-NOT: llvm.noalias.copy.guard
; CHECK-NOT: llvm.noalias.p
; CHECK-NOT: llvm.noalias.decl
; CHECK:  ret void


attributes #0 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "frame-pointer"="none" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="pentium4" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { argmemonly nounwind willreturn }
attributes #2 = { argmemonly nounwind }
attributes #3 = { nounwind readnone }
attributes #4 = { argmemonly nounwind speculatable }
attributes #5 = { nounwind }

!llvm.module.flags = !{!0, !1}
!llvm.ident = !{!2}

!0 = !{i32 1, !"NumRegisterParameters", i32 0}
!1 = !{i32 1, !"wchar_size", i32 4}
!2 = !{!"clang version"}
!3 = !{!4}
!4 = distinct !{!4, !5, !"test01_memcpy: unknown scope"}
!5 = distinct !{!5, !"test01_memcpy"}
!6 = !{!7, !7, i64 0}
!7 = !{!"any pointer", !8, i64 0}
!8 = !{!"omnipotent char", !9, i64 0}
!9 = !{!"Simple C/C++ TBAA"}
!10 = !{!11, !4}
!11 = distinct !{!11, !5, !"test01_memcpy: l_fum"}
!12 = !{!11}
!13 = !{i64 8, i64 0, !14, i64 1}
!14 = !{i64 8, i64 0, i64 4, i64 1, i64 4, !15, i64 1}
!15 = !{i64 4, i64 0, i64 4, i64 1}
!16 = !{i64 0, i64 4, !6, i64 4, i64 4, !6}
!17 = !{!18, !11, !4}
!18 = distinct !{!18, !5, !"test01_memcpy: l2_fum"}
!19 = !{!18}
!20 = !{!21, !7, i64 0}
!21 = !{!"FUM", !7, i64 0, !22, i64 4}
!22 = !{!"FOO", !7, i64 0}
!23 = !{!24, !24, i64 0}
!24 = !{!"int", !8, i64 0}
!25 = !{!26, !11, !4}
!26 = distinct !{!26, !5, !"test01_memcpy: l3_fum"}
!27 = !{!26}
!28 = !{!21, !7, i64 4}
!29 = !{!30}
!30 = distinct !{!30, !31, !"test02_aggloadstore: unknown scope"}
!31 = distinct !{!31, !"test02_aggloadstore"}
!32 = !{!33, !30}
!33 = distinct !{!33, !31, !"test02_aggloadstore: l_fum"}
!34 = !{!33}
!35 = !{!36, !33, !30}
!36 = distinct !{!36, !31, !"test02_aggloadstore: l2_fum"}
!37 = !{!36}
!38 = !{!39, !33, !30}
!39 = distinct !{!39, !31, !"test02_aggloadstore: l3_fum"}
!40 = !{!39}
!41 = !{!42}
!42 = distinct !{!42, !43, !"test03_i64loadstore: unknown scope"}
!43 = distinct !{!43, !"test03_i64loadstore"}
!44 = !{!45, !42}
!45 = distinct !{!45, !43, !"test03_i64loadstore: l_fum"}
!46 = !{!45}
!47 = !{!48, !45, !42}
!48 = distinct !{!48, !43, !"test03_i64loadstore: l2_fum"}
!49 = !{!48}
!50 = !{!51, !45, !42}
!51 = distinct !{!51, !43, !"test03_i64loadstore: l3_fum"}
!52 = !{!51}

; CHECK:  !0 = !{i32 1, !"NumRegisterParameters", i32 0}
; CHECK:  !1 = !{i32 1, !"wchar_size", i32 4}
; CHECK:  !2 = !{!"clang version"}
; CHECK:  !3 = !{!4}
; CHECK:  !4 = distinct !{!4, !5, !"test01_memcpy: unknown scope"}
; CHECK:  !5 = distinct !{!5, !"test01_memcpy"}
; CHECK:  !6 = !{!7}
; CHECK:  !7 = distinct !{!7, !5, !"test01_memcpy: l_fum"}
; CHECK:  !8 = !{i64 0, i64 4, !9, i64 4, i64 4, !9}
; CHECK:  !9 = !{!10, !10, i64 0}
; CHECK:  !10 = !{!"any pointer", !11, i64 0}
; CHECK:  !11 = !{!"omnipotent char", !12, i64 0}
; CHECK:  !12 = !{!"Simple C/C++ TBAA"}
; CHECK:  !13 = !{!7, !4}
; CHECK:  !14 = !{i64 0, i64 4, !9}
; CHECK:  !15 = !{!16}
; CHECK:  !16 = distinct !{!16, !5, !"test01_memcpy: l2_fum"}
; CHECK:  !17 = !{!18, !10, i64 0}
; CHECK:  !18 = !{!"FUM", !10, i64 0, !19, i64 4}
; CHECK:  !19 = !{!"FOO", !10, i64 0}
; CHECK:  !20 = !{!16, !7, !4}
; CHECK:  !21 = !{!22, !22, i64 0}
; CHECK:  !22 = !{!"int", !11, i64 0}
; CHECK:  !23 = !{!24}
; CHECK:  !24 = distinct !{!24, !5, !"test01_memcpy: l3_fum"}
; CHECK:  !25 = !{!18, !10, i64 4}
; CHECK:  !26 = !{!24, !7, !4}
; CHECK:  !27 = !{!28}
; CHECK:  !28 = distinct !{!28, !29, !"test02_aggloadstore: unknown scope"}
; CHECK:  !29 = distinct !{!29, !"test02_aggloadstore"}
; CHECK:  !30 = !{!31}
; CHECK:  !31 = distinct !{!31, !29, !"test02_aggloadstore: l_fum"}
; CHECK:  !32 = !{i64 8, i64 0, !33, i64 1}
; CHECK:  !33 = !{i64 8, i64 0, i64 4, i64 1, i64 4, !34, i64 1}
; CHECK:  !34 = !{i64 4, i64 0, i64 4, i64 1}
; CHECK:  !35 = !{!36}
; CHECK:  !36 = distinct !{!36, !29, !"test02_aggloadstore: l2_fum"}
; CHECK:  !37 = !{!36, !31, !28}
; CHECK:  !38 = !{!39}
; CHECK:  !39 = distinct !{!39, !29, !"test02_aggloadstore: l3_fum"}
; CHECK:  !40 = !{!39, !31, !28}
; CHECK:  !41 = !{!42}
; CHECK:  !42 = distinct !{!42, !43, !"test03_i64loadstore: unknown scope"}
; CHECK:  !43 = distinct !{!43, !"test03_i64loadstore"}
; CHECK:  !44 = !{!45}
; CHECK:  !45 = distinct !{!45, !43, !"test03_i64loadstore: l_fum"}
; CHECK:  !46 = !{!47}
; CHECK:  !47 = distinct !{!47, !43, !"test03_i64loadstore: l2_fum"}
; CHECK:  !48 = !{!47, !45, !42}
; CHECK:  !49 = !{!50}
; CHECK:  !50 = distinct !{!50, !43, !"test03_i64loadstore: l3_fum"}
; CHECK:  !51 = !{!50, !45, !42}

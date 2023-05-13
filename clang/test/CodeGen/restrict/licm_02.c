// RUN: %clang -Xclang -nostdsysteminc -Xclang  -triple -Xclang x86_64-unknown-unknown  -O3 -ffull-restrict -DRESTRICT=__restrict %s -S -emit-llvm -o - | FileCheck %s --check-prefixes=CHECK_NORESTRICT
// RUN: %clang -Xclang -nostdsysteminc -Xclang  -triple -Xclang x86_64-unknown-unknown  -O3 -ffull-restrict -DRESTRICT= %s -S -emit-llvm -o - | FileCheck %s --check-prefixes=CHECK_NORESTRICT
// NOTE: capture tracking is missing some escapes resulting in wrong conclusions. Global objects
//       handling also will need extra investigation
//
// In this example, LICM hoists the store to h[1] outside the loop, although it is being used inside the loop.
// The reason is that AliasSet is losing (=unaware of) ptr_provenance information. When this is combined with a
// store/load that does has ptr_provenance information, wrong analysis can be done.

// NOTE: when things go wrong, we observe a hoisted store:  
// CHECK_RESTRICT:  _crit_edge:
// CHECK_RESTRICT-NEXT: = phi i16
// CHECK_RESTRICT-NEXT: store i16
// CHECK_RESTRICT-NEXT: br label %for.end
// CHECK_RESTRICT:for.end{{.*}}:
// CHECK_RESTRICT-NEXT: ret void

// CHECK_NORESTRICT-NOT: _crit_edge:
// CHECK_NORESTRICT-LABEL:for.end12:
// CHECK_NORESTRICT-NEXT: ret void

int b, c;
short d;
short a(short, short) __attribute__((const));
void e(short *f, short *g, short *_k) {
  short *RESTRICT h = f;
  short *RESTRICT k =_k;
  short *RESTRICT l = g;
  unsigned i, j;
  i = 0;
  for (; i < b; ++i) {
    short *m = h;
    short *n = h;
    short o = *l++;
    j = 0;
    for (; j < c; ++j) {
      short p = *m++;
      short q = a(o, p);
      (void)a(d, q);
      *n++ = a(q, p);
    }
    *k++ = d + 2;
    h[1] = o; // LICM hoist this out, although it can alisa with 'short p = *m++' above
  }
}

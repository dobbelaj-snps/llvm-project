; RUN: llc < %s

define i32* @test(i32* %p, i32* %p.provenance) {
  %p.joined = call i32* @llvm.experimental.ptr.provenance.p0i32.p0i32(i32* %p, i32* %p.provenance)
  ret i32* %p.joined
}

declare i32* @llvm.experimental.ptr.provenance.p0i32.p0i32(i32*, i32*) nounwind readnone

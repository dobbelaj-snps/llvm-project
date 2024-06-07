2024/06/07 jeroen.dobbelaere@synopsys.com

This branch adds full restrict support. It is work in progress.
Not all patches have been clean up.

Currently a number of tests are failing:
  LLVM :: CodeGen/BPF/preserve-static-offset/load-unroll-inline.ll
  -> A recent test added on 2023/12/05 ; started failing after this rebase, no further investigation yet

  LLVM :: Analysis/ScopedNoAliasAA/noalias-dup-scope.ll
  -> An alias analysis test. Recent fixes in full restrict changed the behavior. Still need to investigate
     Overall the changes have as result to be "less agressive" in making use of the full restrict properties.
     (where the original more aggressive version could make incorrect decisions).
     
  LLVM :: Transforms/JumpThreading/noalias-decl02.ll
  -> Most recent reduction coming from a 'rust' build.

JumpThreading and Full Restrict
-------------------------------

The 'JumpThreading' pass seems to be making life hard for full restrict (and vice versa).

The main issue is the following:
- The 'llvm.noalias.decl' intrinsic defines the 'physical' location of a restrict variable.
- 'llvm.noalias' / 'llvm.provenance.noalias' / 'llvm.noalias.copy.guard' are (explicitely) depending on a
  'llvm.noalias.decl' and contain (redundant) scope information.
- When a 'llvm.noalias.decl' is cloned, the rule is that it's scope must be cloned (duplicated) as well.
  Depending (cloned) access their scope should change as well.

  The reason for this is to avoid wrong aliasing decisions:

  example:

  0) plain loop with 2 restrict variables in the body
  loop:
    restrict var A, B
    A(i)
    B(i)

  1) after loop unrolling, if we would keep the same scope (WRONG !)
  loop:
    restrict var A, B
    A(i) (active scopes: A, B)
    B(i) (active scopes: A, B)
    A(i+1) (active scopes: A,B) // wrong: A(i+1) could alias with B(i), but this is not visible here
    B(i+1) (active scopes: A,B) // wrong: B(i+1) could alias with A(i), but this is not visible here

  2) after loop unrolling, if we would keep the same scope (WRONG !)
  loop:
    restrict var A, B, C, D
    A(i) (active scopes: A, B)
    B(i) (active scopes: A, B)
    C(i+1) (active scopes: C,D) // C == A, but not wrt to the scope, C can alias with A and B
    D(i+1) (active scopes: C,D) // D == B, but not wrt to the scope, D can alias with A and B

- Sometimes it is sufficient to split a scope in two scopes (loop rotate). This results in less information, but
  everything is still correct.

- Currently, with JumpThreading, if a 'llvm.noalias.decl' is found, it seems to be tricky to always take a correct decision:
  - sometimes not all the dependant instructions are being cloned, resulting a mix of scopes ('fixed' in the latest patches)
  - sometimes this results in instructions depending on multiple (different) 'llvm.noalias.decl'


  - all of this results in the *verifier* triggering.
    NOTE: the current LLVM without full restrict has similar problems ! Only, the verifier is not detecting them.
          In practice, it will also not have that much chance on resulting in wrong code. A combination
          of jump threading followed by loop unrolling + some interesting order of load/stores should be able to expose the problem.


- Possible ways out:
  - track all uses of the llvm.noalias.decl to be cloned in a JumpThreading and replace their provenance/etc uses with UNKNOWN_PROVENANCE
    -> might work, will hide more opportunities for not-aliasing.
  - remove the specific scope:
    - can be done, but is expensive: must be done for the whole function;
    - interaction with 'out-of-function' scope can complicate this. (a out-of-function scope, can potentially alias with other restrict accesses,
      but not with accesses that do not depend on restrict)
  - Block JumpThreading when a llvm.noalias.decl would be cloned
  - Move a llvm.noalias.decl to a common place, instead of cloning it and adding PHI nodes.


Greetings,

Jeroen Dobbelaere

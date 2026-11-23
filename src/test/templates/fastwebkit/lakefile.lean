import Lake
open Lake DSL

/- fastwebkit's machine-checked proofs: the critical arithmetic and the ledger rule, proved, not just tested.
   Core Lean only, builds in seconds: `lake build`. -/
package «fastwebkit» where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib «Fastwebkit» where
  roots := #[`Fastwebkit]

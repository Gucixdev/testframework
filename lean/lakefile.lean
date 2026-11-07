import Lake
open Lake DSL

/- The shared Lean side of the test framework: every library a proof here may want, in one package, so a project
   takes all of them with one `require testframework from "../testframework/lean"`.
   Mathlib brings batteries, aesop, plausible (property tests), Qq, ProofWidgets and the rest of its closure. -/
package «testframework» where
  leanOptions := #[⟨`autoImplicit, false⟩]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.26.0"

require TrustLean from git
  "https://github.com/manuelpuebla/trust-lean" @ "aaf67f6ce98690042318f90573c2b3077b88123b"

require «amo-lean» from git
  "https://github.com/manuelpuebla/amo-lean" @ "555e5db8732ae644e930ff1541e20e00dc2322e1"

@[default_target]
lean_lib «Tf» where
  roots := #[`Tf]

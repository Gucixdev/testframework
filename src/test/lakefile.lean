import Lake
open Lake DSL

/- The shared Lean side of the test framework: every library a proof here may want, in one package, so a project
   takes all of them with one `require testframework from "../testframework/lean"`.
   Mathlib brings batteries, aesop, plausible (property tests), Qq (quote4), importGraph, Cli (lean4-cli), ProofWidgets
   and the rest of its closure. The libraries below are pinned to their v4.26.0 tag, the toolchain of this package.
   Wanted but with no release for v4.26.0, so not required (bump the toolchain, or pin a commit that builds):
   lean4-alloy (4.21), lean4-partax (4.3), LeanSerde (4.34), leansqlite (4.36+), nerodia (4.35+), lean4-sdk of Extism
   (nightly). Addresses not found yet: leanurl, l4yaml, a TOML library, lean4markdown, leanpostgres, lean.py. -/
package «testframework» where
  leanOptions := #[⟨`autoImplicit, false⟩]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.26.0"

require verso from git
  "https://github.com/leanprover/verso" @ "v4.26.0"

require «doc-gen4» from git
  "https://github.com/leanprover/doc-gen4" @ "v4.26.0"

require repl from git
  "https://github.com/leanprover-community/repl" @ "v4.26.0"

require regex from git
  "https://github.com/pandaman64/lean-regex" @ "v4.26.0" / "regex"

require TrustLean from git
  "https://github.com/manuelpuebla/trust-lean" @ "aaf67f6ce98690042318f90573c2b3077b88123b"

require «amo-lean» from git
  "https://github.com/manuelpuebla/amo-lean" @ "555e5db8732ae644e930ff1541e20e00dc2322e1"

@[default_target]
lean_lib «Tf» where
  roots := #[`Tf]

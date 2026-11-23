# templates - Lean 4 code from real projects, as reference

Copies of the `lean4/` folders of the projects below (build products and lockfiles left out). They are examples
to read and start from, not part of the `Tf` package: nothing here is built by `lake build` in `src/`. When a
project moves its proofs, the copy here is the older one; the project's own `lean4/` is the truth.

| folder | from | shows |
| --- | --- | --- |
| `holyc` | holyc | the shared package and `lib.sh` every project's `lean4/` starts from (audit, step runner) |
| `holyc-core` | holyc/core | allocator models (arena, pool), a C oracle, differential run against the header |
| `holyc-nnn` | holyc/nnn | empty scaffold: the folder layout, audit and run steps; nothing proved yet |
| `caveutils` | caveutils | empty scaffold, as `holyc-nnn` (nothing proved yet) |
| `vecindex` | vecindex | GF(2^n) store integrity, oracle generation, mutants that must be caught |
| `lazytui` | lazytui | empty scaffold, as `holyc-nnn` (nothing proved yet) |
| `gael` | gael | empty scaffold, as `holyc-nnn` (nothing proved yet) |
| `netman` | netman | core Lean only, no Mathlib: models of the pure logic of the network manager |
| `qlogin` | qlogin | core Lean only: login greeter and login1 daemon logic |
| `ergokeys` | ergokeys | `Ergokeys.lean` bookkeeping of the optimizer (core Lean, exact integers); `Cost.lean` the cost model over the reals (Mathlib) |
| `frost` | frost | buffer split and edit deltas: `apply_delta`, `split_left`, `split_right` |
| `fastwebkit` | fastwebkit | replay safety: `replay_is_noop`, `second_is_not_first`, `grants_le_one` |

## Core Lean or Mathlib

Core Lean (netman, qlogin, `ergokeys/Ergokeys.lean`) builds in seconds and has no dependency; use it for
bookkeeping, parsers and state machines over integers and lists. Mathlib (`ergokeys/Cost.lean`) is for real numbers, metrics and `nlinarith`; it needs the cache in `src/.lake` (7 GB) and importing it is slow. Run a Mathlib file from `src/`: `lake env lean templates/ergokeys/Cost.lean`.

## Gaps stated on purpose

`ergokeys/Cost.lean` proves properties of the cost model over exact reals. The C code uses `double` and `sqrt`;
no run compares the two numerically yet, so the link between C and the model is review plus the program's own
tests, not a checked oracle.

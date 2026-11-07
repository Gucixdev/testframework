# testframework (working name)

One test framework, all batteries included, for code that has to be right: a C (or other) implementation is
checked against a plain reference model proved in Lean 4, and then attacked from every side the same way.

Status: scaffold. `lib/steps.sh` is copied from holyc's `lean4/lib.sh` (steps marked "have" run today);
holyc keeps its own copy until a project is moved over and its tests still pass.

## Coverage matrix

| attack | step | state |
|---|---|---|
| proofs build, no sorry/axioms beyond the 3 classical | lean_build, lean_audit, lean_scan | have |
| C equals the model (gcc and clang, seeds) | diff_test | have |
| a wrong change is caught | mutant | have |
| UB and memory errors (ASan, UBSan, MSan, leaks) | sanitize | have |
| random cases nobody picked, odd sizes | fuzz_diff | have |
| crash at any instant (kill -9 prefix replays), ENOMEM | crash_test | have |
| parallel load, determinism, peak RSS | stress | have |
| coverage-guided fuzzing (libFuzzer/AFL++) | fuzz_cov | todo |
| data races (TSan), deadlock under timeout | tsan | todo |
| differential equations: C solver vs closed form / Lean oracle, error bounds | ode_check | todo |
| ACID: torn writes, fsync order, power cut (dm-flakey/LD_PRELOAD fault injection) | acid | todo |
| fault injection (malloc/read/write fail at the Nth call) | inject | todo |
| every CPU: 32/64-bit, little/big endian, x86 ARM RISC-V PPC s390x LoongArch (zig cc + qemu-user) | portable | have |
| builds on Windows / macOS / BSD (compile-only, honest table) | platforms | have |
| performance regression with median and spread | perf | todo |
| line/branch coverage gate | cov | todo |

## Rules

A step prints `ok` or `FAIL` and a one-line summary; a step that cannot run says so and fails, never silently
passes. A step needs a passing `diff_test` first, so it never attacks code the model already disagrees with.

## Layout

- `lean/` - one Lake package, `require testframework from "<path>/lean"`: Mathlib (and so batteries, aesop,
  plausible, Qq), TrustLean, AMO-Lean, and `Tf/` (the shared modules: Audit, Oracle, Bits).
- `lib/steps.sh` - the steps, one bash function each.
- `scripts/` - any step may be bash or Python; a script prints `ok`/`FAIL` lines the same way.
- Not yet built: `lake update` here (Mathlib is a multi-GB download; vecindex already has the 4.26.0 cache).

## What works where (measured on base, 2026-11-07)

Run on 7 CPUs and passed against the model: i386, armv7, aarch64, riscv64, ppc64le, s390x (big-endian), loongarch64.
Not run for lack of a libc in zig or no target: mips, mipsel, mips64, ppc32, m68k.

| OS | builds | runs | note |
|---|---|---|---|
| Linux (gnu, musl) | yes | yes | all steps |
| macOS (x86_64, arm64) | yes | not run | needs a Mac or a VM to claim more |
| Windows | no | no | the harness uses `sys/mman.h` (POSIX mmap); no wine here |
| FreeBSD | no | no | `MAP_NORESERVE` is undeclared there |
| NetBSD | no | no | `popcount32` conflicts with a libc symbol |

"Builds" never means "works": a row is only green for what was executed and compared with the model.

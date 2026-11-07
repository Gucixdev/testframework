# battery

One test framework, all batteries included, for code that has to be right: a C (or other) implementation is
checked against a plain reference model proved in Lean 4, and then attacked from every side the same way.

Status: scaffold. `lib/steps.sh` is copied from holyc's `lean4/lib.sh` (the steps below marked "have" run today);
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
| every -march / cross target under qemu | cross | todo |
| performance regression with median and spread | perf | todo |
| line/branch coverage gate | cov | todo |

## Rules

A step prints `ok` or `FAIL` and a one-line summary; a step that cannot run says so and fails, never silently
passes. A step needs a passing `diff_test` first, so it never attacks code the model already disagrees with.

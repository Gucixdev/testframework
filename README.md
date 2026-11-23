devframework 

framework 

test bench deploy verify

# testframework (working name)

One test framework, all batteries included, for code that has to be right: a C (or other) implementation is
checked against a plain reference model proved in Lean 4, and then attacked from every side the same way.

Status: scaffold. `src/test/steps.sh` is copied from holyc's `lean4/lib.sh` (steps marked "have" run today);
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
| data races (TSan), deadlock under timeout | tsan | have |
| differential equations: C solver vs closed form / Lean oracle, error bounds | ode_check | todo |
| ACID: torn writes, fsync order, power cut (dm-flakey/LD_PRELOAD fault injection) | acid | todo |
| fault injection (malloc/mmap fail at the Nth call) | inject | have |
| every CPU: 32/64-bit, little/big endian, x86 ARM RISC-V PPC s390x LoongArch (zig cc + qemu-user) | portable | have |
| builds on Windows / macOS / BSD (compile-only, honest table) | platforms | have |
| performance regression with median and spread | perf | todo |
| line coverage gate | cov | have |
| MISRA C:2012 rules a pattern can see (dynamic memory, stdio, goto, ...) | misra_scan | have |

## Rules

A step prints `ok` or `FAIL` and a one-line summary; a step that cannot run says so and fails, never silently
passes. A step needs a passing `diff_test` first, so it never attacks code the model already disagrees with.

## Guide

What is in here, the steps, the files, what works where and by language: [docs/guide.md](docs/guide.md).

## Requirements

`./requirements` installs every toolchain, debugger and helper the steps use (gcc, clang, clangd, gdb, lldb, valgrind,
cargo, go, node, java, zig, ffmpeg, renderdoc, tmux, ... and pytest, ruff, mypy into `./.venv`), from
`requirements.list`. It knows pacman, apt, dnf, xbps and nix (`REQ_PM=nix` forces nix; nix also fills in packages the
distro lacks). `./requirements check` only reports, `-n` shows the commands. `templates/project/tools/requirements`
is the same script as an example for a new project's own list.

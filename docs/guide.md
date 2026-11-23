# testframework guide

## What is in here, in plain words

**The idea.** You wrote a program, usually in C, and want to know it is right. Testing a few inputs by hand does not
tell you that. So this repo does three things:

1. **The model.** The same program is written a second time, as simply as possible, in Lean 4: a language where a
   claim like "this can never go out of bounds" is *proved*, and a proof with a gap (`sorry`) is refused.
2. **The comparison.** The real program and the model are fed the same thousands of random inputs. They must print
   exactly the same thing, letter for letter. Any difference means the program (or the model) is wrong.
3. **The abuse.** The program is then hurt on purpose: killed at a random moment, starved of memory, run on a dozen
   kinds of CPU, run with a bug planted in it to see whether the tests notice.

Every test is one bash function that prints `ok` or `FAIL` with one line of explanation. Nothing passes silently.

### The tests (`src/test/steps.sh`)

| step | what it does, in one breath |
|---|---|
| `lean_build`, `lean_audit`, `lean_scan` | build the proofs; check that none of them cheats (no `sorry`, no extra axioms) |
| `diff_test` | run the program and the model on the same random inputs; the output must be identical |
| `mutant` | break the program in one small way on purpose; the test must notice, or the test is too weak |
| `sanitize` | run it under the compiler's memory and undefined-behaviour checkers |
| `fuzz_diff` | the same comparison with odd inputs nobody picked: empty, one, huge |
| `crash_test` | kill the program at random moments and with a memory cap; what it printed before dying must still be correct |
| `stress` | big workloads, many at once; same input twice must give the same output; prints time and memory |
| `tsan` | look for threads stepping on each other (data races) and for deadlocks (a timeout) |
| `inject` | make the 1st, 2nd, 3rd ... memory request fail; the program must stop cleanly, never crash |
| `cov` | how many lines of the source the tests actually ran |
| `portable` | run it on other CPUs (ARM, RISC-V, big-endian machines ...) under an emulator |
| `platforms` | does it at least compile for Windows, macOS, FreeBSD? Honest table: "builds" is not "works" |
| `misra_scan` | count the C habits that the MISRA safety standard forbids (malloc, goto, printf ...) |

### The files in `src/test/`

- `steps.sh` - the tests above, one function each. A project's `run` script is just a list of them.
- `lakefile.lean`, `lake-manifest.json` - the Lean side: one package with the libraries every project may want
  (Mathlib and what it brings, verso, doc-gen4, repl, regex, ...). `lean-toolchain` pins the Lean version.
- `Tf.lean` and `Tf/` - the shared Lean library every model builds on:
  - `Audit.lean` - the cheat detector: lists every theorem and checks it rests on nothing but Lean's three standard axioms.
  - `Oracle.lean` - the referee for `diff_test`: reads what the program printed, recomputes it from the model, prints what it should have been.
  - `Bits.lean` - bit tricks of C (masking, rounding up to a power of two) proved to mean what people think they mean.
  - `inject.c` - the shim behind the `inject` step: it makes the Nth `malloc` fail.
  - `deadlock.lean` - why taking locks in a fixed order makes a deadlock impossible, and a two-lock example that shows the opposite.
  - `racing.lean` - why "one lock per piece of data, always held" means two threads can never race.
  - `segfault.lean` - the classic bounds check `offset + length <= size` can wrap around and let a bad access through; the safe form is proved correct.
  - `deadcode.lean` - finding code nothing can reach, with a proof you can check instead of trust.
  - `mem_layout.lean` - how a C compiler places the fields of a struct (padding, alignment) and that they never overlap.
  - `guess.lean` - the "what if" model, see below.
  - `circuit`, `liar`, `Probe`, `Prove`, `theorem`, `Guessing` (`.lean`) - empty on purpose for now: names held for later.
  - `readme.lean` - one sentence of intent: a library for analysing AI models, meshes, data and guardrails.
- `guess.test` - checks that `guess.lean` builds without cheating and that the `guess` runner really limits cores and memory.
- `bench` - a fair stopwatch: runs two or more commands alternately, so the machine's mood hits all equally, and prints median, spread, peak memory and "x1.4 slower".

### "What if my program ran on a weaker machine?" (guess)

- `Tf/guess.lean` - a back-of-the-envelope model: a job takes as long as the slower of "doing the maths" and "moving
  the data". Describe a device (cores, memory, speed) and a job; it says whether it fits and how long it should take.
  It is proved that more cores never make the estimate slower, and a lighter job is never slower than a heavier one.
- `templates/project/bash/tools/guess` - the real thing: `guess deck -- ./myprogram` runs your command limited to a
  Steam Deck's cores and memory (also `rpi4`, `gtx1050ti`, `desktop`, or `2x2048` for 2 cores and 2 GB) and prints the
  measured time, so you can set it beside the estimate.

### Everything else

- `templates/project/` - an empty project skeleton (docs, `build`/`test`/`check`/`run` scripts, `tools/`). Copy it for a new project.
- `templates/project/bash/tools/` - small stand-alone tools:
  - `guess` - run a command as if on a weaker device (above).
  - `misrac-scan` - list, with file and line, the places where C code breaks the MISRA C rules a pattern can see.
  - `harden` - how hard is a compiled program to take apart and to exploit: address randomisation, stack canary, stripped symbols, leaked paths.
  - `leaninit` - start a project's `lean4/` folder (Lean version, proofs folder, cheat check, run script) in one command.
  - `metadata_cleaner` - strip camera, author and GPS data from files before sharing them.
  - `textswap` - blur the meaning of a screenshot or video: swaps some words for random Chinese characters.
- `templates/lang/` and `templates/new` - ready-made starting points per language (C, Rust, Go, Python, bash, Lean): `KIND=rust NAME=my-tool ./templates/new`.
- `src/test/templates/` - the Lean proofs of other projects, kept as examples to read.
- `examples/counter/` - the smallest complete example: one Lean model, one program per language, all checked against it.
- `src/autodemo/` - a separate program: records a scripted demo of a terminal or window program as an animated image for a README.
- `src/ergokeys/` - a separate program: measures how awkward keyboard shortcuts are to press and suggests cheaper ones.
- `requirements` and `requirements.list` - installs everything the steps need (compilers, debuggers, emulators) on pacman, apt, dnf, xbps or nix.
- Build the Lean side: `cd src/test && lake build` (the Mathlib cache is large and not in git).

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

## By language

`templates/lang/{c,rust,go,python,bash,lean}` each hold a working sample project's tools (`build`, `test`, `check`),
and `KIND=<lang> NAME=<name> ./templates/new` copies the neutral skeleton plus one of them. See
`templates/lang/README.md` for what each language's steps attack.

The differential test takes a harness in C, Rust, Go, Python or bash (by file extension); see `examples/counter/`.

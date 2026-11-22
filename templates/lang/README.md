# Templates by language

`templates/project/` is the neutral skeleton (docs, tools, bench). Each folder here adds one language on top of it:
its own `tools/build`, `tools/test`, `tools/check`, a tiny source, and a sample test that really runs.

    KIND=rust NAME=my-tool DEST=~/dev ./templates/new

| KIND | build | test | check | what the test step attacks |
|---|---|---|---|---|
| c | gcc, `-Wall -Wextra -Werror`, incremental | every `test/test_*.c` under gcc and clang with ASan+UBSan | warnings as errors at -O2, cppcheck if present | UB, memory errors, two compilers |
| rust | `cargo build --release` | `cargo test` | rustfmt, clippy `-D warnings`, cargo audit if present | logic, plus the compiler's own proofs |
| go | `go build` | `go test -race` | gofmt, `go vet`, staticcheck if present | data races |
| python | byte-compile | pytest | ruff (or pyflakes), mypy if present | logic |
| bash | `bash -n` | bats | shellcheck | logic, quoting, exit codes |
| lean | `lake build` | build plus no `sorry` | no sorry/admit/native_decide in src | the proofs themselves |

The differential test is language-agnostic: a harness in any language prints one line per operation for
`HARNESS SEED OPS`, the Lean oracle replays the lines on the model, and the output must be identical. `diff_test`
(in `src/test/steps.sh`) finds the language from the extension, else from the shebang, so a script without `.sh`
works. Builds: C (gcc, clang), C++ (g++, clang++), Rust (release, debug with overflow checks), Go (plain, `-race`),
Zig, Java, C# (dotnet SDK), Python, bash, Perl, Lua (and luajit), JavaScript (node, bun), TypeScript (tsc then node),
Teal (`tl`), and Lean itself (`lean --run`, the implementation in the model's own language). A toolchain that is not
installed is listed as skipped; with `SKIP_MISSING=1` that is a visible SKIP line, otherwise the step fails.
`fuzz_diff` works for all of them. The rest (sanitize, crash_test, stress, tsan, inject, cov, portable, mutant) are
C-only and say so when given another harness.

`examples/counter` is one Lean model checked against one harness per language; `./run` shows them all. Run on this
machine: C, C++, Rust, Go, Java, Python, bash, Perl, Lua, luajit, JavaScript, bun, TypeScript, Lean. Written but not
run here (toolchain missing): C#, Teal, Zig.

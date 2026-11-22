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
(in `src/test/steps.sh`) picks the build by extension: `.c` gcc and clang, `.rs` release and debug (overflow checks),
`.go` plain and `-race`, `.py` python3, `.sh` bash. `fuzz_diff` then works for them all too. The rest (sanitize,
crash_test, stress, tsan, inject, cov, portable, mutant) are still C-only and say so when given another harness.
`examples/counter` is the same Lean model checked against one harness per language; `./run` there shows all five.

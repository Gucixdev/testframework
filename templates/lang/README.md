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

The heavy, cross-language steps (differential test against a Lean model, fuzzing, crash, stress, inject, portable
under qemu) are in `src/test/steps.sh` and work on a C harness today. They stay C-only until a second language
gets a harness; the table in the top README marks which are done.

# shellcheck shell=bash
# lean4/lib.sh - the steps every PROJECT/lean4/run takes, so each run is a list of steps:
#
#   . "$(dirname "$0")/../../lean4/lib.sh" || exit 2
#   lean_build; lean_audit; lean_scan
#   diff_test c/HARNESS.c ORACLE      the harness, built from ../src with gcc and clang, prints one line per
#                                     operation; the lake exe ORACLE replays them on the model; outputs must match
#   mutant NAME FILE SED              a copy of ../src with one sed change; the differential test must catch it
#   sanitize                          the same harness under ASan+UBSan (gcc, clang) and MSan (clang): any report aborts, and
#                                     the output must still equal the plain build's (a sanitizer must not change behaviour)
#   fuzz_diff                         random seeds and operation counts (0, 1, tiny, huge) for FUZZ_SECS (default 20),
#                                     C against the model, so a case nobody picked by hand is also checked
#   crash_test                        kill -9 the harness at random moments: what it printed before dying must still be a
#                                     prefix the model reproduces exactly (nothing half-applied is ever visible), and a
#                                     memory cap (ENOMEM paths) must end in a clean exit or a clean abort, never a hang
#   stress                            big operation counts, NPROC runs in parallel, same seed twice: identical output
#                                     (no nondeterminism, no leak that grows), time and peak RSS printed
#   tsan                              the harness under ThreadSanitizer (data races abort) and a 30 s deadlock timeout
#   inject                            the Nth malloc/realloc/mmap fails (LD_PRELOAD, N = 1..INJECT_MAX, default 40): the run
#                                     must end with exit 0 or a deliberate trap/abort, never SIGSEGV/SIGBUS, never a hang
#   cov                               gcov line coverage of ../src over the differential seeds; COV_MIN (default 0) gates
#   portable                          the harness built with zig cc for every CPU in PORT_TARGETS (x86, ARM 32/64, RISC-V,
#                                     MIPS, PowerPC, s390x big-endian, LoongArch, ...) and run under qemu-user: its output
#                                     must equal the model's replay, so word size, endianness and alignment are tested
#                                     too. A target that cannot be built or has no qemu is listed as skipped, never ok.
#   platforms                         does the harness BUILD for Windows, macOS, FreeBSD, NetBSD (zig cc, compile only)? Prints
#                                     a table. Built is not the same as works: only Linux targets are also RUN (qemu), so every
#                                     other row says "builds, not run" until you run it on that system or in a VM (or wine).
#   misra_scan                        the MISRA C:2012 rules a pattern can decide, over ../src: dynamic memory (21.3), setjmp (21.4),
#                                     signal (21.5), stdio (21.6), atoi and atof (21.7), abort, exit, getenv, system (21.8), qsort and
#                                     bsearch (21.9), time.h (21.10), stdarg (17.1), goto (15.1), union (19.2), #undef (20.5), counted per
#                                     rule (the tool is templates/project/bash/tools/misrac-scan: run it by hand for file:line). cppcheck's misra addon
#                                     runs too when installed.
#                                     MISRA_MAX=N fails the step when the "required" findings exceed N (default: report only)
#   lean_end                          the mutant line, then exit 1 if any step failed
#
# SEEDS=N sets the seeds per compiler (default 200), OPS=N the operations per run (default 3000). Each step prints
# "ok" or "FAIL" and a summary.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[1]}")" || exit 2
export PATH="$HOME/.elan/bin:$PATH"
fail=0 caught=0 total=0 survived="" lean_harness="" lean_oracle="" lean_ready=0 lean_main=""
lean_tmp=$(mktemp -d)
trap 'rm -rf "$lean_tmp"' EXIT

step() { printf '  %-4s %s\n' "$1" "$2"; [[ $1 == ok ]] || fail=1; }

lean_build() {
    if lake build > .lake-build.log 2>&1; then step ok "lake build: $(grep -oE '[0-9]+ jobs' .lake-build.log | tail -1)"
    else tail -20 .lake-build.log; step FAIL "lake build"; fi
}

lean_audit() {
    if lake build +Tf.Audit > .lake-audit.log 2>&1 && lake env lean Audit.lean > .lake-audit.log 2>&1 &&
            grep -q 'none rests' .lake-audit.log; then
        step ok "$(grep -oE 'axiom audit: [0-9]+ theorems \([0-9]+ written' .lake-audit.log) in the sources)"
    else cat .lake-audit.log; step FAIL "axiom audit"; fi
}

lean_scan() {
    if grep -rnE '\b(sorry|admit|native_decide|bv_decide)\b|^[[:space:]]*axiom ' --include=*.lean --exclude=Audit.lean \
            --exclude-dir=.lake .; then step FAIL "source scan"
    else step ok "source scan: no sorry, admit, native_decide, bv_decide or axiom"; fi
}

# HARNESS-BINARY SEED: its output and the oracle's replay of it are identical
lean_same_() {
    { "$1" "$2" "${OPS:-3000}" > "$lean_tmp/c"; } 2> /dev/null && "$lean_oracle" < "$lean_tmp/c" > "$lean_tmp/l" &&
        cmp -s "$lean_tmp/c" "$lean_tmp/l"
}

# Every language's harness is the same contract: HARNESS SEED OPS prints one line per operation and the oracle replays
# the lines on the model. The kind comes from the extension, else from the shebang (`#!/usr/bin/env bash`, so a script
# without .sh works). lean_variants_ builds the harness every way worth comparing and prints "label path" lines;
# "label -" is a build that failed, "label ?" a toolchain that is not installed (skipped, and said so).
#   c gcc clang   cpp g++ clang++   rust release+debug   go plain+race   zig   java   cs (dotnet SDK)
#   python  bash  perl  lua (+luajit)  js node (+bun)  ts tsc+node  teal (tl)  lean (lean --run, the model's own language)
lean_kind_() {
    local f=$1 first w
    case $f in
        *.c) echo c; return ;;
        *.cc | *.cpp | *.cxx) echo cpp; return ;;
        *.rs) echo rust; return ;;
        *.go) echo go; return ;;
        *.zig) echo zig; return ;;
        *.java) echo java; return ;;
        *.cs) echo cs; return ;;
        *.py) echo python; return ;;
        *.sh | *.bash) echo bash; return ;;
        *.pl | *.pm) echo perl; return ;;
        *.lua) echo lua; return ;;
        *.tl) echo teal; return ;;
        *.js | *.mjs | *.cjs) echo js; return ;;
        *.ts) echo ts; return ;;
        *.lean) echo lean; return ;;
    esac
    first=$(head -n 1 "$f" 2> /dev/null | head -c 200)
    if [[ $first == '#!'* ]]; then
        # shellcheck disable=SC2086
        set -- ${first#\#!}
        w=${1##*/}
        if [[ $w == env ]]; then shift; while [[ ${1:-} == -* ]]; do shift; done; w=${1##*/}; fi
        case $w in
            bash | sh | dash | zsh | ksh) echo bash ;;
            python*) echo python ;;
            perl*) echo perl ;;
            lua*) echo lua ;;
            node | nodejs | bun) echo js ;;
            tl) echo teal ;;
            *) echo "unknown($w)" ;;
        esac
        return
    fi
    echo unknown
}

# a wrapper script, so every variant is one executable taking SEED OPS
lean_wrap_() { printf '#!/bin/sh\nexec %s "$@"\n' "$2" > "$1"; chmod +x "$1"; }

# lean_try_ LABEL OUT BUILD...: run BUILD quietly; print "LABEL OUT" or "LABEL -"
lean_try_() { local l=$1 o=$2; shift 2; if "$@" > /dev/null 2>&1; then echo "$l $o"; else echo "$l -"; fi; }
lean_have_() { command -v "$2" > /dev/null || { echo "$1 ?"; return 1; }; }

lean_variants_() {
    local h=$1 out=$lean_tmp/h_$$ abs cc cxx name dir major
    abs=$(readlink -f "$h")
    case $(lean_kind_ "$h") in
        c) for cc in gcc clang; do
               lean_have_ "$cc" "$cc" || continue
               lean_try_ "$cc" "$out.$cc" "$cc" -std=gnu11 -O2 -w -D_GNU_SOURCE -I../src -o "$out.$cc" "$h"
           done ;;
        cpp) for cxx in g++ clang++; do
                 lean_have_ "$cxx" "$cxx" || continue
                 lean_try_ "$cxx" "$out.$cxx" "$cxx" -std=c++17 -O2 -w -o "$out.$cxx" "$h"
             done ;;
        rust) lean_have_ rust rustc || return
              lean_try_ rust-release "$out.rs" rustc -O -o "$out.rs" "$h"
              lean_try_ rust-debug "$out.rsd" rustc -C debug-assertions=on -C overflow-checks=on -o "$out.rsd" "$h" ;;
        go) lean_have_ go go || return
            lean_try_ go "$out.go" go build -o "$out.go" "$h"
            lean_try_ go-race "$out.gor" go build -race -o "$out.gor" "$h" ;;
        zig) lean_have_ zig zig || return
             lean_try_ zig "$out.zig" zig build-exe -O ReleaseSafe "-femit-bin=$out.zig" "$h" ;;
        java) lean_have_ java javac || return
              name=$(basename "$h" .java); mkdir -p "$out.j"
              if javac -d "$out.j" "$h" > /dev/null 2>&1; then lean_wrap_ "$out.java" "java -cp $out.j $name"; echo "java $out.java"; else echo "java -"; fi ;;
        cs) lean_have_ cs dotnet || return
            dotnet --list-sdks 2> /dev/null | grep -q . || { echo "cs ?"; return; }
            dir=$out.cs.d; mkdir -p "$dir"; cp "$h" "$dir/Program.cs"; major=$(dotnet --version | cut -d. -f1)
            printf '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net%s.0</TargetFramework><Nullable>disable</Nullable><ImplicitUsings>disable</ImplicitUsings></PropertyGroup></Project>\n' "$major" > "$dir/h.csproj"
            if dotnet build -c Release -o "$dir/o" -nologo -v q "$dir/h.csproj" > /dev/null 2>&1; then lean_wrap_ "$out.cs" "dotnet $dir/o/h.dll"; echo "csharp $out.cs"; else echo "csharp -"; fi ;;
        python) lean_have_ python python3 || return; lean_wrap_ "$out.py" "python3 -I $abs"; echo "python $out.py" ;;
        bash) lean_wrap_ "$out.sh" "bash $abs"; echo "bash $out.sh" ;;
        perl) lean_have_ perl perl || return; lean_wrap_ "$out.pl" "perl $abs"; echo "perl $out.pl" ;;
        lua) lean_have_ lua lua || return; lean_wrap_ "$out.lua" "lua $abs"; echo "lua $out.lua"
             command -v luajit > /dev/null && { lean_wrap_ "$out.lj" "luajit $abs"; echo "luajit $out.lj"; } ;;
        teal) lean_have_ teal tl || return; lean_wrap_ "$out.tl" "tl run $abs --"; echo "teal $out.tl" ;;
        js) lean_have_ node node || return; lean_wrap_ "$out.js" "node $abs"; echo "node $out.js"
            command -v bun > /dev/null && { lean_wrap_ "$out.bun" "bun $abs"; echo "bun $out.bun"; } ;;
        ts) lean_have_ ts tsc || return; lean_have_ node node || return
            if tsc --target es2022 --module commonjs --outDir "$out.t" "$h" > /dev/null 2>&1; then
                lean_wrap_ "$out.ts" "node $out.t/$(basename "$h" .ts).js"; echo "ts-tsc $out.ts"; else echo "ts-tsc -"; fi ;;
        lean) lean_have_ lean lake || return; lean_wrap_ "$out.lean" "sh -c 'cd $PWD && exec lake env lean --run $abs \"\$@\"' --"; echo "lean $out.lean" ;;
        *) echo "$(lean_kind_ "$h") -" ;;
    esac
}

# a step that only makes sense for a C harness says so and fails, never passes silently
lean_c_only_() { [[ $(lean_kind_ "$lean_harness") == c ]] && return 0; step FAIL "$1: needs a C harness (this one is $(lean_kind_ "$lean_harness"))"; return 1; }

diff_test() {
    local label path s runs=0 bad="" skipped="" seeds=${SEEDS:-200} names=""
    lean_harness=$1 lean_oracle=.lake/build/bin/$2
    if ! lake build "$2" > .lake-oracle.log 2>&1; then tail -20 .lake-oracle.log; step FAIL "$2 build"; return; fi
    while read -r label path; do
        if [[ $path == - ]]; then bad="$bad $label(build)"; continue; fi
        if [[ $path == '?' ]]; then skipped="$skipped $label"; continue; fi
        names="$names${names:+, }$label"; lean_main=${lean_main:-$path}
        for s in $(seq 1 "$seeds"); do
            if lean_same_ "$path" "$s"; then runs=$((runs + 1))
            else bad="$bad $label:seed$s"; diff "$lean_tmp/c" "$lean_tmp/l" | head -4; break; fi
        done
    done < <(lean_variants_ "$lean_harness")
    if [[ -z $bad && $runs -gt 0 ]]; then
        lean_ready=1
        step ok "differential: $runs runs of ${OPS:-3000} operations (seeds 1-$seeds, $names), the code equals the model${skipped:+; SKIPPED (toolchain not installed):$skipped}"
    elif [[ -z $bad && -n $skipped && ${SKIP_MISSING:-} == 1 ]]; then
        printf '  %-4s %s\n' SKIP "differential: toolchain not installed:$skipped (SKIP_MISSING=1)"
    else step FAIL "differential:${bad:- nothing could run}${skipped:+; skipped:$skipped}"; fi
}


# build the harness with extra flags into $lean_tmp/NAME; fails quietly (the step reports it)
lean_cc_() { local cc=$1 out=$2; shift 2; "$cc" -std=gnu11 -O1 -g -w -D_GNU_SOURCE -I../src "$@" -o "$out" "$lean_harness" -lm 2> /dev/null; }

sanitize() {
    local cc s name flags runs=0 bad="" skipped="" seeds=${SANSEEDS:-30}
    (( lean_ready )) || { step FAIL "sanitize: needs a passing diff_test first"; return; }
    lean_c_only_ sanitize || return
    for cc in gcc clang; do
        command -v "$cc" > /dev/null || continue
        for name in asan-ubsan msan; do
            case $name in
                asan-ubsan) flags="-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer" ;;
                msan) [[ $cc == clang ]] || continue; flags="-fsanitize=memory -fsanitize-memory-track-origins -fno-omit-frame-pointer" ;;
            esac
            if ! lean_cc_ "$cc" "$lean_tmp/s_${cc}_$name" $flags; then
                [[ $name == msan ]] && { skipped="$skipped $cc:$name(no libs)"; continue; }
                bad="$bad $cc:$name(build)"; continue
            fi
            lean_cc_ "$cc" "$lean_tmp/p_${cc}_$name" || { bad="$bad $cc:plain"; continue; }
            for s in $(seq 1 "$seeds"); do
                if ASAN_OPTIONS=detect_leaks=1:abort_on_error=0 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
                        "$lean_tmp/s_${cc}_$name" "$s" "${OPS:-3000}" > "$lean_tmp/san.out" 2> "$lean_tmp/san.err" &&
                        "$lean_tmp/p_${cc}_$name" "$s" "${OPS:-3000}" > "$lean_tmp/pl.out" 2> /dev/null &&
                        cmp -s "$lean_tmp/san.out" "$lean_tmp/pl.out"; then runs=$((runs + 1))
                else bad="$bad $cc:$name:seed$s"; head -12 "$lean_tmp/san.err"; break; fi
            done
        done
    done
    if [[ -z $bad && $runs -gt 0 ]]; then step ok "sanitizers: $runs runs clean (ASan, UBSan, MSan; leaks on)${skipped:+; skipped$skipped}"
    else step FAIL "sanitizers:$bad"; fi
}

fuzz_diff() {
    local end=$((SECONDS + ${FUZZ_SECS:-20})) n=0 seed ops bad="" odd=(0 1 2 3 7 8 9 63 64 65 1000 20000)
    (( lean_ready )) || { step FAIL "fuzz_diff: needs a passing diff_test first"; return; }
    [[ -n $lean_main ]] || { step FAIL "fuzz_diff: no harness build"; return; }
    cp "$lean_main" "$lean_tmp/fz"
    while (( SECONDS < end )); do
        seed=$(( (RANDOM << 15 | RANDOM) + 1000 ))
        (( n % 3 == 0 )) && ops=${odd[RANDOM % ${#odd[@]}]} || ops=$(( RANDOM % 6000 ))
        if ! { "$lean_tmp/fz" "$seed" "$ops" > "$lean_tmp/c"; } 2> /dev/null ||
                ! "$lean_oracle" < "$lean_tmp/c" > "$lean_tmp/l" || ! cmp -s "$lean_tmp/c" "$lean_tmp/l"; then
            bad="seed=$seed ops=$ops"; break
        fi
        n=$((n + 1))
    done
    if [[ -z $bad ]]; then step ok "fuzz: $n random (seed, ops) cases in ${FUZZ_SECS:-20}s, the code equals the model"
    else step FAIL "fuzz: first failure $bad (rerun: HARNESS $bad)"; fi
}

crash_test() {
    local i seed ms n=${CRASHES:-60} ok=0 bad="" cut
    (( lean_ready )) || { step FAIL "crash_test: needs a passing diff_test first"; return; }
    lean_c_only_ crash_test || return
    lean_cc_ gcc "$lean_tmp/cr" -O2 || { step FAIL "crash_test: build"; return; }
    for i in $(seq 1 "$n"); do
        seed=$((i * 7919)); ms=$((RANDOM % 40 + 1))
        { timeout -s KILL "0.0$(printf %02d "$ms")" "$lean_tmp/cr" "$seed" 200000 > "$lean_tmp/part"; } 2> /dev/null
        # a kill can cut a line in half: drop the last, incomplete line; the rest must replay identically
        head -c -0 "$lean_tmp/part" | sed '$d' > "$lean_tmp/cut"
        [[ -s $lean_tmp/part && $(tail -c1 "$lean_tmp/part" | wc -l) -eq 1 ]] && cp "$lean_tmp/part" "$lean_tmp/cut"
        if "$lean_oracle" < "$lean_tmp/cut" > "$lean_tmp/l" 2> /dev/null && cmp -s "$lean_tmp/cut" "$lean_tmp/l"; then ok=$((ok + 1))
        else bad="$bad seed$seed@${ms}ms"; fi
    done
    # memory cap: a failing allocation must end the run cleanly, not hang or corrupt (a signal exit is a bad exit)
    local rc
    { ( ulimit -v $((${CAP_MB:-64} * 1024)); timeout 20 "$lean_tmp/cr" 1 2000000 > /dev/null 2> /dev/null ); } 2> /dev/null; rc=$?
    # a deliberate trap (SIGILL from __builtin_trap) or abort (SIGABRT) is a clean refusal; SIGSEGV/SIGBUS or a hang is not
    if (( rc == 124 )); then bad="$bad hang-under-ENOMEM"
    elif (( rc == 139 || rc == 135 || rc == 138 )); then bad="$bad crash(signal$((rc - 128)))-under-ENOMEM"; fi
    if [[ -z $bad ]]; then step ok "crash: $ok of $n kill -9 cuts replay exactly; ${CAP_MB:-64} MB cap ended with exit $rc"
    else step FAIL "crash:$bad"; fi
}

stress() {
    local par=${NPROC:-$(nproc)} big=${STRESS_OPS:-300000} i t0 rss
    (( lean_ready )) || { step FAIL "stress: needs a passing diff_test first"; return; }
    lean_c_only_ stress || return
    lean_cc_ gcc "$lean_tmp/st" -O2 || { step FAIL "stress: build"; return; }
    t0=$SECONDS
    for i in $(seq 1 "$par"); do ( "$lean_tmp/st" 4242 "$big" > "$lean_tmp/st.$i" 2> /dev/null ) & done; wait
    for i in $(seq 2 "$par"); do
        cmp -s "$lean_tmp/st.1" "$lean_tmp/st.$i" || { step FAIL "stress: same seed, different output (run $i)"; return; }
    done
    "$lean_oracle" < "$lean_tmp/st.1" > "$lean_tmp/st.l" 2> /dev/null && cmp -s "$lean_tmp/st.1" "$lean_tmp/st.l" ||
        { step FAIL "stress: $big operations differ from the model"; return; }
    rss=$(python3 -c 'import resource,subprocess,sys;subprocess.run(sys.argv[1:],stdout=subprocess.DEVNULL);print(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)' \
        "$lean_tmp/st" 4242 "$big" 2> /dev/null)
    step ok "stress: $big operations x $par parallel, identical and equal to the model; $((SECONDS - t0))s, peak RSS ${rss:-?} KB"
}

tsan() {
    local s bad="" n=0
    (( lean_ready )) || { step FAIL "tsan: needs a passing diff_test first"; return; }
    lean_c_only_ tsan || return
    lean_cc_ clang "$lean_tmp/ts" -fsanitize=thread || lean_cc_ gcc "$lean_tmp/ts" -fsanitize=thread || { step FAIL "tsan: build"; return; }
    for s in $(seq 1 "${TSANSEEDS:-10}"); do
        if { TSAN_OPTIONS=halt_on_error=1 timeout 30 "$lean_tmp/ts" "$s" "${OPS:-3000}" > /dev/null 2> "$lean_tmp/ts.err"; }; then n=$((n + 1))
        else bad="seed$s(rc=$?)"; head -8 "$lean_tmp/ts.err"; break; fi
    done 2> /dev/null
    if [[ -z $bad ]]; then step ok "tsan: $n runs without a race or deadlock"; else step FAIL "tsan: $bad"; fi
}

inject() {
    local n rc total max=${INJECT_MAX:-300} clean=0 refused=0 bad="" here
    here=$(dirname "${BASH_SOURCE[0]}")
    (( lean_ready )) || { step FAIL "inject: needs a passing diff_test first"; return; }
    lean_c_only_ inject || return
    cc -shared -fPIC -o "$lean_tmp/inject.so" "$here/inject.c" -ldl 2> /dev/null || { step FAIL "inject: build shim"; return; }
    lean_cc_ gcc "$lean_tmp/ij" -O2 || { step FAIL "inject: build"; return; }
    { INJECT_REPORT="$lean_tmp/ij.n" LD_PRELOAD="$lean_tmp/inject.so" "$lean_tmp/ij" 3 2000 > /dev/null 2> /dev/null; } 2> /dev/null
    total=$(cat "$lean_tmp/ij.n" 2> /dev/null || echo 0)
    (( total > 0 )) || { step FAIL "inject: the shim saw no malloc/realloc/mmap call (static binary?)"; return; }
    (( max > total )) && max=$total
    for n in $(seq 1 "$max"); do
        { INJECT_N=$n LD_PRELOAD="$lean_tmp/inject.so" timeout 20 "$lean_tmp/ij" 3 2000 > /dev/null 2> /dev/null; } 2> /dev/null; rc=$?
        case $rc in
            0) clean=$((clean + 1)) ;;
            132|134) refused=$((refused + 1)) ;;   # SIGILL from __builtin_trap, SIGABRT: a deliberate refusal
            *) bad="$bad N=$n(rc=$rc)" ;;
        esac
    done
    if [[ -z $bad ]]; then step ok "inject: every one of the first $max of $total calls failed in turn, $clean carried on, $refused refused by trap/abort, none crashed or hung"
    else step FAIL "inject:$bad"; fi
}

cov() {
    local d s out pct min=${COV_MIN:-0}
    (( lean_ready )) || { step FAIL "cov: needs a passing diff_test first"; return; }
    lean_c_only_ cov || return
    d=$(mktemp -d "$lean_tmp/cov.XXXX")
    gcc -std=gnu11 -O0 -w -D_GNU_SOURCE -I../src --coverage -o "$d/h" "$lean_harness" -lm 2> /dev/null || { step FAIL "cov: build"; return; }
    for s in $(seq 1 "${COVSEEDS:-30}"); do "$d/h" "$s" "${OPS:-3000}" > /dev/null 2>&1; done
    out=$(cd "$d" && gcov -n -o . h-*.gcda 2> /dev/null | awk "/^File '.*src\\//{f=1;next} /^File /{f=0} f&&/Lines executed/{print}")
    pct=$(awk -F'[: %]+' '/Lines executed/{ split($0,a,"of "); n+=$3*a[2]/100; t+=a[2] } END { if (t) printf "%.1f", 100*n/t; else print 0 }' <<< "$out")
    if awk -v p="$pct" -v m="$min" 'BEGIN{exit !(p+0 >= m+0)}'; then step ok "coverage: ${pct}% of src lines run by the harness (gate ${min}%)"
    else step FAIL "coverage: ${pct}% < ${min}%"; fi
}

# the rules live in the tool, so the step and a hand run say the same thing
misrac_tool_="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../templates/project/bash/tools/misrac-scan"

misra_scan() {
    local out rc
    [[ -x $misrac_tool_ ]] || { step FAIL "misra_scan: $misrac_tool_ is missing"; return; }
    out=$("$misrac_tool_" -q ${MISRA_MAX:+-m "$MISRA_MAX"} ../src 2>&1); rc=$?
    case $rc in
        0) step ok "$out${MISRA_MAX:+ (gate: required <= $MISRA_MAX)}${MISRA_MAX:- (report only, MISRA_MAX unset)}" ;;
        *) step FAIL "$out${MISRA_MAX:+ (gate: required <= $MISRA_MAX)}" ;;
    esac
}

# triple|qemu binary|label. Zig builds all of them with its own musl, static, no sysroot needed.
PORT_TARGETS_DEFAULT="x86-linux-musl|qemu-i386|i386(32bit) arm-linux-musleabihf|qemu-arm|armv7 aarch64-linux-musl|qemu-aarch64|aarch64 riscv64-linux-musl|qemu-riscv64|riscv64 mips-linux-musl|qemu-mips|mips(BE,32bit) mipsel-linux-musl|qemu-mipsel|mipsel(32bit) mips64-linux-musl|qemu-mips64|mips64(BE) powerpc-linux-musl|qemu-ppc|ppc32(BE) powerpc64le-linux-musl|qemu-ppc64le|ppc64le s390x-linux-musl|qemu-s390x|s390x(BE) loongarch64-linux-musl|qemu-loongarch64|loongarch64 m68k-linux-musl|qemu-m68k|m68k(BE,16bit-aligned)"

portable() {
    local spec triple qemu label s ok="" bad="" skip="" t out
    (( lean_ready )) || { step FAIL "portable: needs a passing diff_test first"; return; }
    lean_c_only_ portable || return
    command -v zig > /dev/null || { step FAIL "portable: zig not found (zig cc is the cross compiler)"; return; }
    for spec in ${PORT_TARGETS:-$PORT_TARGETS_DEFAULT}; do
        IFS='|' read -r triple qemu label <<< "$spec"
        command -v "$qemu" > /dev/null || command -v "$qemu-static" > /dev/null || { skip="$skip $label(no-qemu)"; continue; }
        t=$lean_tmp/x_${triple}
        if ! zig cc -target "$triple" -std=gnu11 -O2 -w -D_GNU_SOURCE -I../src -o "$t" "$lean_harness" -lm 2> "$lean_tmp/zig.err"; then
            skip="$skip $label(build:$(grep -m1 -oE 'error: .{0,50}' "$lean_tmp/zig.err" | head -1))"; continue
        fi
        out=ok
        for s in $(seq 1 "${PORTSEEDS:-3}"); do
            { timeout "${PORT_TIMEOUT:-120}" "$(command -v "$qemu" || command -v "$qemu-static")" "$t" "$s" "${PORT_OPS:-1000}" > "$lean_tmp/c" 2> /dev/null; } 2> /dev/null
            "$lean_oracle" < "$lean_tmp/c" > "$lean_tmp/l" 2> /dev/null && [[ -s $lean_tmp/c ]] && cmp -s "$lean_tmp/c" "$lean_tmp/l" || { out=diff; break; }
        done
        [[ $out == ok ]] && ok="$ok $label" || bad="$bad $label"
    done
    if [[ -z $bad && -n $ok ]]; then step ok "portable: C equals the model on:$ok${skip:+  | skipped:$skip}"
    else step FAIL "portable: wrong output on:${bad:- none ran}${skip:+  | skipped:$skip}"; fi
}

platforms() {
    local spec triple os label err rows="" n=0 b=0 can_run
    command -v zig > /dev/null || { step FAIL "platforms: zig not found"; return; }
    for spec in linux:x86_64-linux-gnu linux:x86_64-linux-musl windows:x86_64-windows-gnu windows:x86-windows-gnu windows:aarch64-windows-gnu \
                macos:x86_64-macos macos:aarch64-macos freebsd:x86_64-freebsd freebsd:aarch64-freebsd netbsd:x86_64-netbsd; do
        os=${spec%%:*} triple=${spec#*:}; n=$((n + 1))
        if zig cc -target "$triple" -std=gnu11 -O2 -w -D_GNU_SOURCE -I../src -o "$lean_tmp/p_$triple" "$lean_harness" -lm 2> "$lean_tmp/pl.err"; then
            b=$((b + 1)); can_run="builds, not run"
            [[ $os == linux ]] && can_run="builds, RUN (this machine)"
            [[ $os == windows ]] && command -v wine > /dev/null && can_run="builds, wine available"
            printf '    %-8s %-24s %s\n' "$os" "$triple" "$can_run" >> "$lean_tmp/plat.txt"
        else
            err=$(grep -m1 -oE "(error|fatal error): .{0,70}" "$lean_tmp/pl.err")
            printf '    %-8s %-24s DOES NOT BUILD: %s\n' "$os" "$triple" "$err" >> "$lean_tmp/plat.txt"
        fi
    done
    cat "$lean_tmp/plat.txt"
    step ok "platforms: $b of $n targets build (see the table; only Linux is run here)"
}

mutant() {
    local m s
    total=$((total + 1))
    (( lean_ready )) || return  # a mutant only counts against a differential test that passes
    [[ $(lean_kind_ "$lean_harness") == c ]] || { survived="$survived $1(C harness only)"; return; }
    m=$(mktemp -d "$lean_tmp/m.XXXX"); cp -r ../src "$m/src"
    sed -i "$3" "$m/src/$2"
    if cmp -s "../src/$2" "$m/src/$2"; then survived="$survived $1(sed-matched-nothing)"; return; fi
    gcc -std=gnu11 -O2 -w -D_GNU_SOURCE -I"$m/src" -o "$m/h" "$lean_harness" 2> /dev/null || { caught=$((caught + 1)); return; }
    for s in 1 2 3 4 5; do lean_same_ "$m/h" "$s" || { caught=$((caught + 1)); return; }; done
    survived="$survived $1"
}

lean_end() {
    if (( total > 0 )); then
        if (( !lean_ready )); then step FAIL "mutants: not run, the differential test did not pass"
        elif [[ -z $survived ]]; then step ok "mutants: $caught of $total caught"
        else step FAIL "mutants: survived:$survived"; fi
    fi
    exit "$fail"
}

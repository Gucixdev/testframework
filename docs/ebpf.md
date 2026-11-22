# ebpf in devframework (plan, nothing built yet)

Goal: measure first, tune second. One command per question, output is the answer, not the data.

| question | tool | command shape |
|---|---|---|
| what is slow at boot / on a frame | bpftrace, bcc `runqlat`, `offcputime` | `devframework ebpf runqlat 10` |
| which process wakes the disk / CPU | `biolatency`, `execsnoop`, `opensnoop` | `devframework ebpf who-wakes` |
| is the compositor missing frames | uprobes on the frame callback + `drm_vblank` tracepoint | `devframework ebpf frames finedesktop` |
| scheduler fit for desktop/games | sched_ext (`scx_lavd`, `scx_bpfland`) A/B with the same bench | `devframework bench --sched lavd` |
| network | XDP/tc counters, nftables stays the policy | later |

Rules: needs root or CAP_BPF, so every script prints what it will attach before it does; nothing stays loaded after exit;
each tune (sysctl, scheduler, mitigations) is recorded with the before/after number, like the lobotomy check for models.
Open: which of bpftrace/bcc/libbpf-rs to wrap (bpftrace first: one binary, scripts are text).

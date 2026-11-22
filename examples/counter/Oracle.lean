/-! The model of a saturating counter (0..100), proved bounded, and the oracle that replays a harness's lines on it.
A harness line is `OP ARG STATE`: the oracle recomputes STATE from its own state and prints the line it would have
written; the test passes when its output equals the harness's, byte for byte. -/

def cap : Nat := 100

def step (s : Nat) (op : String) (a : Nat) : Nat :=
  if op == "add" then min (s + a) cap
  else if op == "sub" then s - a
  else 0

theorem step_bounded (s a : Nat) (op : String) (h : s ≤ cap) : step s op a ≤ cap := by
  unfold step
  split
  · exact Nat.min_le_right _ _
  · split <;> omega

partial def loop (h : IO.FS.Stream) (s : Nat) : IO Unit := do
  let line ← h.getLine
  if line.isEmpty then return
  match line.trimAscii.toString.splitOn " " with
  | [op, a, _] =>
    let s' := step s op a.toNat!
    IO.println s!"{op} {a} {s'}"
    loop h s'
  | _ => IO.eprintln s!"bad line: {line}"; IO.Process.exit 1

def main : IO Unit := do loop (← IO.getStdin) 0

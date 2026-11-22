/-! The same harness written in Lean itself: the compiled-style implementation checked against the model. -/

def rnd (x : UInt32) : UInt32 :=
  let x := x ^^^ (x <<< 13)
  let x := x ^^^ (x >>> 17)
  x ^^^ (x <<< 5)

def main (args : List String) : IO Unit := do
  let seed := (args.getD 0 "0").toNat!
  let n := (args.getD 1 "100").toNat!
  let mut x : UInt32 := UInt32.ofNat seed * 2654435761 + 1
  let mut s : Nat := 0
  let names := #["add", "sub", "reset"]
  for _ in [0:n] do
    x := rnd x
    let op := (x % 3).toNat
    x := rnd x
    let a := (x % 100).toNat
    s := if op == 0 then min (s + a) 100 else if op == 1 then s - a else 0
    IO.println s!"{names[op]!} {a} {s}"

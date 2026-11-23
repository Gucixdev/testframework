/-! Model of frost's undo-history delta (`delta` in src/buffer.rs), with proofs, and an oracle that
    writes every case over a small alphabet for the Rust tests to compare against.
    Core Lean only, no Mathlib.  Check: `./test` in the repo root. -/

namespace Frost

/-- longest common prefix: (prefix, rest of a, rest of b) -/
def split {α} [DecidableEq α] : List α → List α → List α × List α × List α
  | x :: xs, y :: ys =>
      if x = y then let (p, a, b) := split xs ys; (x :: p, a, b) else ([], x :: xs, y :: ys)
  | xs, ys => ([], xs, ys)

theorem split_left {α} [DecidableEq α] : ∀ (a b : List α), (split a b).1 ++ (split a b).2.1 = a
  | [], [] => by simp [split]
  | [], _ :: _ => by simp [split]
  | _ :: _, [] => by simp [split]
  | x :: xs, y :: ys => by
      by_cases h : x = y
      · simp [split, h, split_left xs ys]
      · simp [split, h]

theorem split_right {α} [DecidableEq α] : ∀ (a b : List α), (split a b).1 ++ (split a b).2.2 = b
  | [], [] => by simp [split]
  | [], _ :: _ => by simp [split]
  | _ :: _, [] => by simp [split]
  | x :: xs, y :: ys => by
      by_cases h : x = y
      · simp [split, h, split_right xs ys]
      · simp [split, h]

/-- one replacement: at `start` remove `del` chars and put `ins` -/
structure Delta where
  start : Nat
  del : Nat
  ins : List Char
deriving Repr

/-- common head and tail trimmed, exactly like the Rust code (tail is taken from what the head left) -/
def delta (a b : List Char) : Delta :=
  let (p, ra, rb) := split a b
  let (_, ma, mb) := split ra.reverse rb.reverse
  { start := p.length, del := ma.length, ins := mb.reverse }

def apply (l : List Char) (d : Delta) : List Char :=
  l.take d.start ++ d.ins ++ l.drop (d.start + d.del)

/-- the key property: applying the delta of (a, b) to a gives b -/
theorem apply_delta (a b : List Char) : apply a (delta a b) = b := by
  unfold delta apply
  have hl := split_left a b
  have hr := split_right a b
  generalize split a b = t at hl hr ⊢
  obtain ⟨p, ra, rb⟩ := t
  simp only at hl hr ⊢
  have hl2 := split_left ra.reverse rb.reverse
  have hr2 := split_right ra.reverse rb.reverse
  generalize split ra.reverse rb.reverse = u at hl2 hr2 ⊢
  obtain ⟨s, ma, mb⟩ := u
  simp only at hl2 hr2 ⊢
  -- ra = (s ++ ma).reverse = ma.reverse ++ s.reverse ; rb = mb.reverse ++ s.reverse
  have ea : ra = ma.reverse ++ s.reverse := by
    have := congrArg List.reverse hl2; simpa using this.symm
  have eb : rb = mb.reverse ++ s.reverse := by
    have := congrArg List.reverse hr2; simpa using this.symm
  subst hl; subst hr
  rw [ea, eb]
  simp [List.drop_append]

end Frost

#print axioms Frost.apply_delta

open Frost in
/-- every pair of strings over {a, b, ż} up to length 4, with the delta the model computes -/
def strings : List (List Char) := Id.run do
  let mut all : List (List Char) := [[]]
  let mut layer : List (List Char) := [[]]
  for _ in [0:4] do
    layer := layer.flatMap fun s => ['a', 'b', 'ż'].map (· :: s)
    all := all ++ layer
  return all

open Frost in
def main : IO Unit := do
  let out ← IO.getStdout
  for a in strings do
    for b in strings do
      let d := delta a b
      out.putStrLn s!"{String.ofList a}\t{String.ofList b}\t{d.start}\t{d.del}\t{String.ofList d.ins}"

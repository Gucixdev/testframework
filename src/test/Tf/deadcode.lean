/-
  Dead code as a certificate. A control-flow graph is a list of edges between node numbers. A node is dead when no
  path from the entry reaches it. Finding the live nodes is a search that may be written any way (`live` below, fuel
  bounded rounds of "add every successor"); what is trusted is only a check of its answer: a set `S` that holds
  the entry and every successor of its members contains every reachable node, so a node outside `S` is dead
  (`dead_of_closed`). `closedB` runs that check as a function.
-/
namespace Tf.Deadcode

abbrev Edge := Nat × Nat

/-- `n` can be reached from `entry` along the edges. -/
inductive Reach (es : List Edge) (entry : Nat) : Nat → Prop
  | start : Reach es entry entry
  | step {a b : Nat} : Reach es entry a → (a, b) ∈ es → Reach es entry b

/-- The set holds the entry and is closed under successors. -/
def Closed (es : List Edge) (entry : Nat) (S : List Nat) : Prop :=
  entry ∈ S ∧ ∀ e ∈ es, e.1 ∈ S → e.2 ∈ S

def closedB (es : List Edge) (entry : Nat) (S : List Nat) : Bool :=
  decide (entry ∈ S) && es.all (fun e => decide (e.1 ∈ S → e.2 ∈ S))

theorem closedB_sound {es : List Edge} {entry : Nat} {S : List Nat} (h : closedB es entry S = true) :
    Closed es entry S := by
  simp only [closedB, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true] at h
  exact ⟨h.1, fun e he => by simpa using h.2 e he⟩

theorem reach_in_closed {es : List Edge} {entry : Nat} {S : List Nat} (h : Closed es entry S) {n : Nat}
    (r : Reach es entry n) : n ∈ S := by
  induction r with
  | start => exact h.1
  | step _ he ih => exact h.2 _ he ih

/-- A node outside a closed set is dead. -/
theorem dead_of_closed {es : List Edge} {entry : Nat} {S : List Nat} (h : Closed es entry S) {n : Nat}
    (hn : n ∉ S) : ¬ Reach es entry n := fun r => hn (reach_in_closed h r)

/-- One round: the set and every successor of its members. -/
def grow (es : List Edge) (seen : List Nat) : List Nat :=
  seen ++ es.filterMap fun e => if e.1 ∈ seen ∧ e.2 ∉ seen then some e.2 else none

/-- The live nodes found in `fuel` rounds; the answer is checked with `closedB`, not trusted. -/
def live (es : List Edge) (fuel : Nat) (seen : List Nat) : List Nat :=
  match fuel with
  | 0 => seen
  | n + 1 => live es n (grow es seen)

/-- Nodes of `nodes` outside the closed set found from `entry`, or none when the search did not close. -/
def dead (es : List Edge) (entry : Nat) (nodes : List Nat) : Option (List Nat) :=
  let s := live es nodes.length [entry]
  if closedB es entry s then some (nodes.filter (· ∉ s)) else none

/-- Whatever `dead` returns is unreachable. -/
theorem dead_sound {es : List Edge} {entry : Nat} {nodes d : List Nat} (h : dead es entry nodes = some d)
    {n : Nat} (hn : n ∈ d) : ¬ Reach es entry n := by
  simp only [dead] at h
  split at h
  · rename_i hc
    cases h
    obtain ⟨_, hn2⟩ := List.mem_filter.mp hn
    exact dead_of_closed (closedB_sound hc) (by simpa using hn2)
  · cases h

example : dead [(0, 1), (1, 2), (3, 2)] 0 [0, 1, 2, 3] = some [3] := by decide

end Tf.Deadcode

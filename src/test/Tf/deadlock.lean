/-
  Deadlock freedom by lock order. A set of threads where every thread only requests a lock whose rank is above the
  rank of every lock it already holds can't wait in a circle, so nothing deadlocks. `no_deadlock` is that proof; a
  project's lock ranks (one number per lock, written in its header) are the only thing it has to satisfy, and a
  checker for the rule is a loop over the acquire sites.
  `crossed_not_ordered` is the classic failure: two threads take locks 0 and 1 in opposite orders, and no rank
  function can order that.
-/
namespace Tf.Deadlock

/-- Who holds which lock, and who is asking for which. -/
structure State (T L : Type) where
  holds : T → L → Prop
  wants : T → L → Prop

/-- `t` waits for `u`: `t` asks for a lock `u` holds. -/
def State.waitsFor {T L : Type} (s : State T L) (t u : T) : Prop := ∃ l, s.wants t l ∧ s.holds u l

/-- The rule: a thread asks only for locks ranked above everything it holds. -/
def State.Ordered {T L : Type} (s : State T L) (rank : L → Nat) : Prop :=
  ∀ t l, s.wants t l → ∀ k, s.holds t k → rank k < rank l

/-- Along a chain of waits, the last thread holds a lock ranked above everything the first holds. -/
theorem chain {T L : Type} (s : State T L) (rank : L → Nat) (h : s.Ordered rank) {t u : T}
    (c : Relation.TransGen s.waitsFor t u) :
    ∃ k, s.holds u k ∧ ∀ j, s.holds t j → rank j < rank k := by
  induction c with
  | single e =>
    obtain ⟨l, hw, hh⟩ := e
    exact ⟨l, hh, h _ _ hw⟩
  | tail _ e ih =>
    obtain ⟨k, hk, hj⟩ := ih
    obtain ⟨l, hw, hh⟩ := e
    exact ⟨l, hh, fun j hj' => Nat.lt_trans (hj j hj') (h _ _ hw k hk)⟩

/-- Under the rule no thread waits, through any number of others, for itself: no deadlock. -/
theorem no_deadlock {T L : Type} (s : State T L) (rank : L → Nat) (h : s.Ordered rank) (t : T) :
    ¬ Relation.TransGen s.waitsFor t t := fun c => by
  obtain ⟨k, hk, hj⟩ := chain s rank h c
  exact Nat.lt_irrefl _ (hj k hk)

/-- Threads 0 and 1 each hold one of the locks 0 and 1 and ask for the other. -/
def crossed : State Nat Nat where
  holds t k := (t = 0 ∧ k = 0) ∨ (t = 1 ∧ k = 1)
  wants t l := (t = 0 ∧ l = 1) ∨ (t = 1 ∧ l = 0)

/-- No ranking of the locks makes the crossed acquisition ordered, so the rule rejects it. -/
theorem crossed_not_ordered (rank : Nat → Nat) : ¬ crossed.Ordered rank := fun h => by
  have a := h 0 1 (Or.inl ⟨rfl, rfl⟩) 0 (Or.inl ⟨rfl, rfl⟩)
  have b := h 1 0 (Or.inr ⟨rfl, rfl⟩) 1 (Or.inr ⟨rfl, rfl⟩)
  omega

end Tf.Deadlock

/-
  Data races by lockset. Two accesses race when they come from different threads, touch the same address, at
  least one writes, and they hold no lock in common. `guarded_no_race` is the discipline that rules that out: give
  every address a lock (`guard`) and take it for every access, and no two accesses can race. `raceB` is the check
  a trace analysis runs on a pair, proved to agree with `Race` in one direction (`raceB_sound`: what it reports is a race).
-/
namespace Tf.Racing

/-- One memory access: who, where, read or write, and the locks held at that moment. -/
structure Access where
  thread : Nat
  addr : Nat
  write : Bool
  locks : List Nat

def Race (a b : Access) : Prop :=
  a.thread ≠ b.thread ∧ a.addr = b.addr ∧ (a.write = true ∨ b.write = true) ∧
    ∀ l, l ∈ a.locks → l ∉ b.locks

/-- Executable form of `Race` for traces. -/
def raceB (a b : Access) : Bool :=
  a.thread != b.thread && a.addr == b.addr && (a.write || b.write) && a.locks.all (fun l => !b.locks.contains l)

theorem raceB_sound {a b : Access} (h : raceB a b = true) : Race a b := by
  simp only [raceB, Bool.and_eq_true, bne_iff_ne, ne_eq, beq_iff_eq, Bool.or_eq_true,
    List.all_eq_true, Bool.not_eq_true'] at h
  obtain ⟨⟨⟨ht, ha⟩, hw⟩, hl⟩ := h
  refine ⟨ht, ha, hw, fun l hl' hb => ?_⟩
  have := hl l hl'
  simp [hb] at this

/-- The access holds the lock that guards its address. -/
def Guarded (guard : Nat → Nat) (a : Access) : Prop := guard a.addr ∈ a.locks

/-- Every access takes its address's lock: no two accesses race. -/
theorem guarded_no_race (guard : Nat → Nat) {a b : Access} (ha : Guarded guard a) (hb : Guarded guard b) :
    ¬ Race a b := fun ⟨_, hadd, _, hno⟩ => by
  apply hno _ ha
  rw [hadd]
  exact hb

end Tf.Racing

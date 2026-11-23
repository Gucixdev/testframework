/-
  Struct layout as C does it: each field goes at the next offset that is a multiple of its alignment. The proofs
  say what a layout checker may rely on: every field sits at an aligned offset (`layout_aligned`), the fields are in
  order and none overlaps the next (`layout_apart`), and the whole struct can be rounded up to a multiple of its
  largest alignment without cutting a field (`total_ge_end`, `total_dvd`).
-/
namespace Tf.MemLayout

/-- The least multiple of `a` that is at least `x` (`a` > 0). -/
def alignUp (x a : Nat) : Nat := (x + a - 1) / a * a

theorem alignUp_ge {x a : Nat} (ha : 0 < a) : x ≤ alignUp x a := by
  unfold alignUp
  have h := Nat.div_add_mod (x + a - 1) a
  have hr := Nat.mod_lt (x + a - 1) ha
  generalize (x + a - 1) / a = q at *
  generalize (x + a - 1) % a = r at *
  rw [Nat.mul_comm] at h
  omega

theorem alignUp_dvd (x a : Nat) : a ∣ alignUp x a := Nat.dvd_mul_left a _

theorem alignUp_lt {x a : Nat} (ha : 0 < a) : alignUp x a < x + a := by
  unfold alignUp
  have h := Nat.div_add_mod (x + a - 1) a
  have hr := Nat.mod_lt (x + a - 1) ha
  generalize (x + a - 1) / a = q at *
  generalize (x + a - 1) % a = r at *
  rw [Nat.mul_comm] at h
  omega

/-- A field's size and alignment. -/
structure Field where
  size : Nat
  align : Nat

/-- A placed field: offset, size, alignment. -/
abbrev Slot := Nat × Nat × Nat

/-- Place the fields in order, the first no lower than `off`. -/
def layout : List Field → Nat → List Slot
  | [], _ => []
  | f :: fs, off => (alignUp off f.align, f.size, f.align) :: layout fs (alignUp off f.align + f.size)

/-- The end of the last field: where the struct would stop with no tail padding. -/
def endOf : List Field → Nat → Nat
  | [], off => off
  | f :: fs, off => endOf fs (alignUp off f.align + f.size)

theorem layout_aligned (fs : List Field) (off : Nat) : ∀ s ∈ layout fs off, s.2.2 ∣ s.1 := by
  induction fs generalizing off with
  | nil => simp [layout]
  | cons f fs ih =>
    intro s hs
    simp only [layout, List.mem_cons] at hs
    rcases hs with rfl | hs
    · exact alignUp_dvd _ _
    · exact ih _ s hs

theorem layout_start (fs : List Field) (off : Nat) (hpos : ∀ f ∈ fs, 0 < f.align) :
    ∀ s ∈ layout fs off, off ≤ s.1 := by
  induction fs generalizing off with
  | nil => simp [layout]
  | cons f fs ih =>
    intro s hs
    simp only [layout, List.mem_cons] at hs
    have h0 := alignUp_ge (x := off) (hpos f (List.mem_cons_self ..))
    rcases hs with rfl | hs
    · exact h0
    · have := ih (alignUp off f.align + f.size) (fun g hg => hpos g (List.mem_cons_of_mem _ hg)) s hs
      omega

/-- In order and apart: each slot ends before every later slot begins. -/
theorem layout_apart (fs : List Field) (off : Nat) (hpos : ∀ f ∈ fs, 0 < f.align) :
    (layout fs off).Pairwise (fun p q => p.1 + p.2.1 ≤ q.1) := by
  induction fs generalizing off with
  | nil => simp [layout]
  | cons f fs ih =>
    simp only [layout, List.pairwise_cons]
    exact ⟨fun q hq => layout_start fs _ (fun g hg => hpos g (List.mem_cons_of_mem _ hg)) q hq,
      ih _ (fun g hg => hpos g (List.mem_cons_of_mem _ hg))⟩

theorem endOf_ge (fs : List Field) (off : Nat) (hpos : ∀ f ∈ fs, 0 < f.align) : off ≤ endOf fs off := by
  induction fs generalizing off with
  | nil => simp [endOf]
  | cons f fs ih =>
    have h0 := alignUp_ge (x := off) (hpos f (List.mem_cons_self ..))
    have := ih (alignUp off f.align + f.size) (fun g hg => hpos g (List.mem_cons_of_mem _ hg))
    simp only [endOf]
    omega

/-- The struct size: the end of the fields rounded up to the struct's alignment `a`. -/
def total (fs : List Field) (a : Nat) : Nat := alignUp (endOf fs 0) a

theorem total_ge_end (fs : List Field) {a : Nat} (ha : 0 < a) : endOf fs 0 ≤ total fs a := alignUp_ge ha

theorem total_dvd (fs : List Field) (a : Nat) : a ∣ total fs a := alignUp_dvd _ _

/-- clang and gcc agree on `struct { char c; int i; short s; }`: offsets 0, 4, 8 and size 12 for 4-byte alignment. -/
example : layout [⟨1, 1⟩, ⟨4, 4⟩, ⟨2, 2⟩] 0 = [(0, 1, 1), (4, 4, 4), (8, 2, 2)] ∧
    total [⟨1, 1⟩, ⟨4, 4⟩, ⟨2, 2⟩] 4 = 12 := by decide

end Tf.MemLayout

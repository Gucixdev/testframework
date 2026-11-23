/-! Model of the bookkeeping in ergokeys' `suggest` (src/opt.c), with proofs.

    The search moves actions between chords. Its one promise is "no two actions on one chord", kept by the
    `occ` array (chord -> action number + 1, 0 = free). Here: `f a` is the chord of action `a` (`mask`, `key`
    in the C code), `occ` is the array, and the moves are `p_put` (relocation) and the swap in `p_improve`.
    Proved: the guards of the C code are enough to keep `occ` and the assignment consistent, so no chord is
    shared, and the cost change the search adds up (`d`) is exactly the change of the total.
    Costs are exact integers here; the C code adds f64, so it can differ by rounding (its `verify` mode
    recomputes the total after every greedy move). Core Lean, no Mathlib.  Check: `./run` in the repo root. -/

namespace Ergokeys

abbrev Cell := Nat × Nat            -- (modifier mask, key)

/-- `f` places action `a < n` on chord `f a`; `occ c = a + 1` exactly when action `a` sits on `c`. -/
def Cons (n : Nat) (f : Nat → Cell) (occ : Cell → Nat) : Prop :=
  (∀ a, a < n → occ (f a) = a + 1) ∧ (∀ c a, occ c = a + 1 → a < n ∧ f a = c)

def upd (f : Nat → Cell) (i : Nat) (c : Cell) : Nat → Cell := fun x => if x = i then c else f x
def setv (g : Cell → Nat) (c : Cell) (v : Nat) : Cell → Nat := fun x => if x = c then v else g x

/-- no two actions on one chord -/
theorem cons_inj {n f occ} (h : Cons n f occ) {a b} (ha : a < n) (hb : b < n) (e : f a = f b) : a = b := by
  have h1 := h.1 a ha
  have h2 := h.1 b hb
  rw [e] at h1
  omega

/-- `occ[old] = 0; p_put(i, c)`; the guard of the C code is `occ[c] == 0` -/
theorem relocate {n f occ} (h : Cons n f occ) {i c} (hi : i < n) (free : occ c = 0) :
    Cons n (upd f i c) (setv (setv occ (f i) 0) c (i + 1)) := by
  have hocc := h.1 i hi
  have hcne : c ≠ f i := by intro e; rw [← e] at hocc; omega
  constructor
  · intro a ha
    by_cases hai : a = i
    · subst hai; simp [upd, setv]
    · have hfa := h.1 a ha
      have h1 : f a ≠ c := by intro e; rw [e] at hfa; omega
      have h2 : f a ≠ f i := by intro e; rw [e] at hfa; omega
      simp [upd, setv, hai, h1, h2, hfa]
  · intro x a hx
    by_cases hxc : x = c
    · subst hxc; simp [setv] at hx
      subst hx; exact ⟨hi, by simp [upd]⟩
    · by_cases hxf : x = f i
      · subst hxf; simp [setv, hxc] at hx
      · simp [setv, hxc, hxf] at hx
        obtain ⟨ha, hfa⟩ := h.2 x a hx
        have hai : a ≠ i := by intro e; subst e; exact hxf hfa.symm
        exact ⟨ha, by simp [upd, hai, hfa]⟩

/-- sum of `ct a (f a)` over the movable actions `l` (the total the search minimizes), exact integers -/
def total (ct : Nat → Cell → Int) (f : Nat → Cell) : List Nat → Int
  | [] => 0
  | a :: l => ct a (f a) + total ct f l

theorem total_upd_out (ct : Nat → Cell → Int) (f : Nat → Cell) (i : Nat) (c : Cell) :
    ∀ l : List Nat, i ∉ l → total ct (upd f i c) l = total ct f l
  | [], _ => rfl
  | y :: t, h => by
      have hy : y ≠ i := fun e => h (e ▸ List.mem_cons_self)
      have ht : i ∉ t := fun e => h (List.mem_cons_of_mem _ e)
      show ct y (upd f i c y) + total ct (upd f i c) t = ct y (f y) + total ct f t
      rw [show upd f i c y = f y by simp [upd, hy], total_upd_out ct f i c t ht]

theorem total_upd (ct : Nat → Cell → Int) (f : Nat → Cell) (i : Nat) (c : Cell) :
    ∀ l : List Nat, l.Nodup → i ∈ l →
      total ct (upd f i c) l = total ct f l + ct i c - ct i (f i)
  | [], _, h => by simp at h
  | a :: l, hnd, hi => by
      have hnd' := List.nodup_cons.mp hnd
      show ct a (upd f i c a) + total ct (upd f i c) l = ct a (f a) + total ct f l + ct i c - ct i (f i)
      by_cases hai : a = i
      · subst hai
        rw [total_upd_out ct f a c l hnd'.1]
        simp [upd]; omega
      · have hil : i ∈ l := by simpa [Ne.symm hai] using hi
        rw [show upd f i c a = f a by simp [upd, hai], total_upd ct f i c l hnd'.2 hil]; omega

/-- the swap of `p_improve`: both actions leave their chords, then take `ni` and `nj`.
    The guard: the two new chords differ, and each is free or held by `i` or `j` themselves. -/
theorem swap {n f occ} (h : Cons n f occ) {i j ni nj} (hi : i < n) (hj : j < n) (hij : i ≠ j)
    (hne : ni ≠ nj)
    (gi : occ ni = 0 ∨ occ ni = i + 1 ∨ occ ni = j + 1)
    (gj : occ nj = 0 ∨ occ nj = i + 1 ∨ occ nj = j + 1) :
    Cons n (upd (upd f i ni) j nj)
      (setv (setv (setv (setv occ (f i) 0) (f j) 0) ni (i + 1)) nj (j + 1)) := by
  have hoi := h.1 i hi
  have hoj := h.1 j hj
  have hfij : f i ≠ f j := by intro e; rw [e] at hoi; omega
  constructor
  · intro a ha
    by_cases haj : a = j
    · subst haj; simp [upd, setv]
    · by_cases hai : a = i
      · subst hai; simp [upd, setv, haj, hne]
      · have hfa := h.1 a ha
        have n1 : f a ≠ ni := by intro e; rw [e] at hfa; rcases gi with g | g | g <;> omega
        have n2 : f a ≠ nj := by intro e; rw [e] at hfa; rcases gj with g | g | g <;> omega
        have n3 : f a ≠ f i := by intro e; rw [e] at hfa; omega
        have n4 : f a ≠ f j := by intro e; rw [e] at hfa; omega
        simp [upd, setv, hai, haj, n1, n2, n3, n4, hfa]
  · intro x a hx
    by_cases hxj : x = nj
    · subst hxj; simp [setv] at hx
      subst hx; exact ⟨hj, by simp [upd]⟩
    · by_cases hxi : x = ni
      · subst hxi; simp [setv, hxj] at hx
        subst hx; exact ⟨hi, by simp [upd, hij]⟩
      · by_cases hx1 : x = f i
        · subst hx1; simp [setv, hxj, hxi] at hx
        · by_cases hx2 : x = f j
          · subst hx2; simp [setv, hxj, hxi] at hx
          · simp [setv, hxj, hxi, hx1, hx2] at hx
            obtain ⟨ha, hfa⟩ := h.2 x a hx
            have hai : a ≠ i := by intro e; subst e; exact hx1 hfa.symm
            have haj : a ≠ j := by intro e; subst e; exact hx2 hfa.symm
            exact ⟨ha, by simp [upd, hai, haj, hfa]⟩

/-- the swap changes the total by `d` of `p_improve`: new costs of both minus the old costs of both -/
theorem swap_delta (ct : Nat → Cell → Int) (f : Nat → Cell) {i j : Nat} {ni nj : Cell} (hij : i ≠ j)
    (l : List Nat) (hnd : l.Nodup) (hi : i ∈ l) (hj : j ∈ l) :
    total ct (upd (upd f i ni) j nj) l = total ct f l + (ct i ni + ct j nj - ct i (f i) - ct j (f j)) := by
  rw [total_upd ct (upd f i ni) j nj l hnd hj, total_upd ct f i ni l hnd hi]
  simp [upd, Ne.symm hij]; omega

end Ergokeys

#print axioms Ergokeys.relocate
#print axioms Ergokeys.swap
#print axioms Ergokeys.total_upd
#print axioms Ergokeys.swap_delta
#print axioms Ergokeys.cons_inj

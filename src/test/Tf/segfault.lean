/-
  Out-of-bounds accesses, the bounds check that C gets wrong. `off + len <= size` wraps around in fixed width:
  with off = 2^64 - 8 and len = 16 the sum is 8 and the check passes while the access runs far past the block
  (`naive_wraps`, a concrete case). `len <= size && off <= size - len` can't wrap, and `safe_iff` proves it is
  exactly the check on true integers: it accepts an access when, and only when, every byte lies inside the block.
-/
namespace Tf.Segfault

/-- The check as C writes it: the sum can wrap. -/
def naive (size off len : UInt64) : Bool := off + len ≤ size

/-- The check that can't wrap: compare the length with the size first, then the offset with what is left. -/
def safe (size off len : UInt64) : Bool := len ≤ size && off ≤ size - len

theorem safe_iff (size off len : UInt64) :
    safe size off len = true ↔ off.toNat + len.toNat ≤ size.toNat := by
  simp only [safe, Bool.and_eq_true, decide_eq_true_eq, UInt64.le_iff_toNat_le]
  constructor
  · rintro ⟨h1, h2⟩
    rw [UInt64.toNat_sub_of_le _ _ (UInt64.le_iff_toNat_le.mpr h1)] at h2
    omega
  · intro h
    refine ⟨by omega, ?_⟩
    rw [UInt64.toNat_sub_of_le _ _ (UInt64.le_iff_toNat_le.mpr (by omega))]
    omega

/-- Every byte of an accepted access lies inside the block. -/
theorem safe_inside (size off len : UInt64) (h : safe size off len = true) (i : Nat) (hi : i < len.toNat) :
    off.toNat + i < size.toNat := by
  have := (safe_iff size off len).mp h
  omega

/-- The naive check accepts an access that starts 8 bytes below the top of the address space. -/
theorem naive_wraps : ∃ size off len : UInt64,
    naive size off len = true ∧ ¬ off.toNat + len.toNat ≤ size.toNat :=
  ⟨16, 0xFFFFFFFFFFFFFFF8, 16, by decide, by decide⟩

end Tf.Segfault

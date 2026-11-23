import Mathlib.Analysis.InnerProductSpace.PiL2
import Mathlib.Analysis.SpecialFunctions.Sqrt
import Mathlib.Data.Finset.Max
import Mathlib.Tactic.Positivity
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Ring

/-! The cost model of ergokeys (src/cost.c), examined over the real numbers.

    One finger move costs `travel * wd v p q` with `wd v p q = sqrt(dx^2 + (v*dy)^2)` (`v` = vertical_factor,
    default 1.3). What the model rests on, and what is proved here:

    * `wd` is a metric when `v ≠ 0`: symmetric, zero only for equal points, triangle inequality. So a finger that
      detours through a key never travels cheaper than the direct line (`detour`), and the cost of a move does not
      depend on the direction.
    * `euclid_le_wd`, `wd_le`: for `1 ≤ v` the weighted distance lies between the plain distance (the `mm` the
      program prints) and `v` times it. So `mm * travel ≤ weighted travel ≤ v * mm * travel`, the two numbers the
      output shows can never contradict each other.
    * the cheapest modifier combination is monotone in every weight (`best_mono`): raising a penalty never lowers
      the cost of a step, so "cost goes up when you raise a penalty" holds for the whole shortcut (clamping at zero
      is monotone too, `clamp_mono`).

    Not proved: the f64 rounding of the C code and the specific penalty rules (the tests check those by hand).
    Needs Mathlib (narrow imports on purpose: `import Mathlib` loads ~5 GB cold and takes over 10 minutes, this takes about 2), so it builds in the testframework package: `lake env lean templates/ergokeys/Cost.lean` from src/. -/

namespace Ergokeys.Cost

open Real

/-- weighted distance between two key positions (x, y) in mm -/
noncomputable def wd (v : ℝ) (p q : ℝ × ℝ) : ℝ := √((q.1 - p.1) ^ 2 + (v * (q.2 - p.2)) ^ 2)

theorem wd_nonneg (v : ℝ) (p q : ℝ × ℝ) : 0 ≤ wd v p q := Real.sqrt_nonneg _

theorem wd_self (v : ℝ) (p : ℝ × ℝ) : wd v p p = 0 := by simp [wd]

theorem wd_comm (v : ℝ) (p q : ℝ × ℝ) : wd v p q = wd v q p := by
  unfold wd
  congr 1
  ring

theorem wd_eq_zero {v : ℝ} (hv : v ≠ 0) {p q : ℝ × ℝ} (h : wd v p q = 0) : p = q := by
  unfold wd at h
  rw [Real.sqrt_eq_zero (by positivity)] at h
  have h1 : (q.1 - p.1) ^ 2 = 0 := by nlinarith [sq_nonneg (q.1 - p.1), sq_nonneg (v * (q.2 - p.2))]
  have h2 : (v * (q.2 - p.2)) ^ 2 = 0 := by nlinarith [sq_nonneg (q.1 - p.1), sq_nonneg (v * (q.2 - p.2))]
  have a := pow_eq_zero_iff (two_ne_zero) |>.mp h1
  have b := pow_eq_zero_iff (two_ne_zero) |>.mp h2
  have b' : q.2 - p.2 = 0 := (mul_eq_zero.mp b).resolve_left hv
  exact Prod.ext (by linarith) (by linarith)

/-- `wd` is the Euclidean distance of the points after stretching the vertical axis by `v` -/
theorem wd_eq_dist (v : ℝ) (p q : ℝ × ℝ) :
    wd v p q = dist (!₂[p.1, v * p.2] : EuclideanSpace ℝ (Fin 2)) !₂[q.1, v * q.2] := by
  rw [EuclideanSpace.dist_eq]
  simp only [wd, Fin.sum_univ_two, Real.dist_eq, sq_abs]
  simp
  congr 1
  ring

theorem wd_triangle (v : ℝ) (p q r : ℝ × ℝ) : wd v p r ≤ wd v p q + wd v q r := by
  rw [wd_eq_dist, wd_eq_dist, wd_eq_dist]
  exact dist_triangle _ _ _

/-- a finger that goes via `q` pays at least what the direct move pays -/
theorem detour (v : ℝ) (p q r : ℝ × ℝ) (t : ℝ) (ht : 0 ≤ t) :
    t * wd v p r ≤ t * wd v p q + t * wd v q r := by
  rw [← mul_add]
  exact mul_le_mul_of_nonneg_left (wd_triangle v p q r) ht

/-- plain distance, the `mm` of the output -/
noncomputable def dist2 (p q : ℝ × ℝ) : ℝ := √((q.1 - p.1) ^ 2 + (q.2 - p.2) ^ 2)

/-- scaling a square by `v ^ 2 ≥ 1` does not shrink it -/
theorem sq_le_scaled {v : ℝ} (hv : 1 ≤ v) (x : ℝ) : x ^ 2 ≤ v ^ 2 * x ^ 2 := by
  have h2 : 1 ≤ v ^ 2 := by nlinarith
  have := mul_le_mul_of_nonneg_right h2 (sq_nonneg x)
  linarith

theorem euclid_le_wd {v : ℝ} (hv : 1 ≤ v) (p q : ℝ × ℝ) : dist2 p q ≤ wd v p q := by
  unfold dist2 wd
  apply Real.sqrt_le_sqrt
  have : (q.2 - p.2) ^ 2 ≤ (v * (q.2 - p.2)) ^ 2 := by
    rw [mul_pow]
    exact sq_le_scaled hv _
  linarith

theorem wd_le {v : ℝ} (hv : 1 ≤ v) (p q : ℝ × ℝ) : wd v p q ≤ v * dist2 p q := by
  unfold dist2 wd
  have h0 : 0 ≤ v := by linarith
  rw [← Real.sqrt_sq h0, ← Real.sqrt_mul (sq_nonneg v), Real.sqrt_sq h0]
  apply Real.sqrt_le_sqrt
  have : (q.1 - p.1) ^ 2 ≤ v ^ 2 * (q.1 - p.1) ^ 2 := sq_le_scaled hv _
  nlinarith [mul_pow v (q.2 - p.2) 2]

/-- the cheapest of the modifier combinations, monotone in a weight when each combination is -/
theorem best_mono {ι : Type*} (s : Finset ι) (hs : s.Nonempty) (c : ι → ℝ → ℝ) (h : ∀ k, Monotone (c k)) :
    Monotone (fun w => s.inf' hs (fun k => c k w)) := by
  intro a b hab
  apply Finset.le_inf'
  intro k hk
  exact (Finset.inf'_le _ hk).trans (h k hab)

theorem clamp_mono : Monotone (fun x : ℝ => max 0 x) := fun _ _ h => max_le_max le_rfl h

theorem clamp_nonneg (x : ℝ) : 0 ≤ max 0 x := le_max_left _ _

end Ergokeys.Cost

#print axioms Ergokeys.Cost.wd_triangle
#print axioms Ergokeys.Cost.wd_eq_zero
#print axioms Ergokeys.Cost.euclid_le_wd
#print axioms Ergokeys.Cost.wd_le
#print axioms Ergokeys.Cost.best_mono

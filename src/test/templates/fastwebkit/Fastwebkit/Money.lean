/-! Money: `centsToDecimal` in gems/payments/paypal.go prints `cents/100 "." cents%100 (2 digits)`.
    These theorems are the facts that function relies on: nothing is lost or shifted by a factor of 100. -/

namespace Fastwebkit

/-- whole units and the two-digit fraction of an amount in minor units -/
def split (cents : Nat) : Nat × Nat := (cents / 100, cents % 100)

/-- recombining the printed parts gives back exactly the original amount: no cent lost or invented -/
theorem split_roundtrip (c : Nat) : (split c).1 * 100 + (split c).2 = c := by
  unfold split; simp only; omega

/-- the fraction always fits in two digits, so "%02d" never widens the number (no x10 / x100 error) -/
theorem frac_lt_100 (c : Nat) : (split c).2 < 100 := by
  unfold split; simp only; omega

/-- splitting is injective: two different prices can never print the same decimal string -/
theorem split_injective (a b : Nat) (h : split a = split b) : a = b := by
  have h1 := split_roundtrip a
  have h2 := split_roundtrip b
  rw [h] at h1
  omega

/-- adding whole units adds exactly 100 x as many cents (units never leak into the fraction) -/
theorem split_add_units (c u : Nat) : split (c + 100 * u) = ((split c).1 + u, (split c).2) := by
  unfold split; simp only [Prod.mk.injEq]; omega

end Fastwebkit

namespace Fastwebkit

/-- `Payment.Matches` in gems/payments/provider.go: known, exact amount, same currency. -/
def payMatches (known : Bool) (paid price : Nat) (curPaid curPrice : String) : Bool :=
  known && paid == price && curPaid == curPrice

/-- an underpayment (or overpayment, or unknown amount, or other currency) never unlocks -/
theorem underpay_never_matches (known : Bool) (paid price : Nat) (c1 c2 : String) (h : paid ≠ price) :
    payMatches known paid price c1 c2 = false := by
  unfold payMatches; simp [h]

theorem unknown_never_matches (paid price : Nat) (c1 c2 : String) :
    payMatches false paid price c1 c2 = false := by
  unfold payMatches; simp

theorem other_currency_never_matches (known : Bool) (paid price : Nat) (c1 c2 : String) (h : c1 ≠ c2) :
    payMatches known paid price c1 c2 = false := by
  unfold payMatches; simp [h]

end Fastwebkit

/-! Ledger: a paid webhook may grant an item at most once, however often (or in whatever order)
    the provider retries. Model: the ledger is the set of seen event hashes; `Record` inserts.
    This is the contract of gems/payments/ledger.go (PRIMARY KEY (provider, event_hash) +
    INSERT .. ON CONFLICT DO NOTHING). Concurrency is the database's job: the primary key makes
    the insert atomic - verified by tests on SQLite, Postgres and MariaDB. -/

namespace Fastwebkit

abbrev Seen := List String

/-- `record` returns (first?, new ledger) -/
def record (seen : Seen) (h : String) : Bool × Seen :=
  if h ∈ seen then (false, seen) else (true, h :: seen)

/-- recording the same event twice: the second time is never "first" -/
theorem second_is_not_first (seen : Seen) (h : String) :
    (record (record seen h).2 h).1 = false := by
  unfold record
  by_cases hm : h ∈ seen <;> simp [hm]

/-- a replay never changes the ledger -/
theorem replay_is_noop (seen : Seen) (h : String) :
    (record (record seen h).2 h).2 = (record seen h).2 := by
  unfold record
  by_cases hm : h ∈ seen <;> simp [hm]

/-- each event grants at most once over any sequence of deliveries: counting `true`s for hash h
    in a run is ≤ 1 -/
def grants (h : String) : Seen → List String → Nat
  | _, [] => 0
  | seen, x :: xs =>
    let (first, seen') := record seen x
    (if first && x == h then 1 else 0) + grants h seen' xs

theorem grants_le_one_of_member (h : String) (xs : List String) (seen : Seen) (hm : h ∈ seen) :
    grants h seen xs = 0 := by
  induction xs generalizing seen with
  | nil => rfl
  | cons x xs ih =>
    unfold grants record
    by_cases hx : x ∈ seen
    · simp [hx, ih seen hm]
    · have : h ∈ x :: seen := List.mem_cons_of_mem _ hm
      simp [hx, ih (x :: seen) this]
      intro e; subst e; exact absurd hm hx

theorem grants_le_one (h : String) (xs : List String) (seen : Seen) : grants h seen xs ≤ 1 := by
  induction xs generalizing seen with
  | nil => simp [grants]
  | cons x xs ih =>
    unfold grants record
    by_cases hx : x ∈ seen
    · simp [hx, ih seen]
    · by_cases hxh : x = h
      · subst hxh
        have : x ∈ x :: seen := List.mem_cons_self
        simp [hx, grants_le_one_of_member x xs (x :: seen) this]
      · simp [hx, hxh, ih (x :: seen)]

end Fastwebkit

def add (a b : Nat) : Nat := a + b

theorem add_comm' (a b : Nat) : add a b = add b a := Nat.add_comm a b

#eval add 2 3

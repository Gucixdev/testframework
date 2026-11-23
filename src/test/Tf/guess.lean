/-
guess (working name) - "what if" models: the same job, light or heavy, on different devices.
A roofline estimate: the job takes as long as the slower of its compute and its memory traffic.
Units: flopsG = giga-operations, gflopsCore = giga-operations per second per core, bytesMB = megabytes moved,
bandwidthMBs = megabytes per second, times in milliseconds. Integer division, so estimates round down.
The bash companion `guess` runs a real command under the limits of a chosen device and prints this
prediction next to the measured time. Check:  lake env lean guess.lean
-/

structure Device where
  name : String
  cores : Nat
  ramMB : Nat
  vramMB : Nat
  gflopsCore : Nat
  bandwidthMBs : Nat

structure Workload where
  name : String
  flopsG : Nat
  bytesMB : Nat
  workingSetMB : Nat
  parallel : Nat

/-- The job fits when its working set is within RAM plus VRAM. -/
def fits (d : Device) (w : Workload) : Bool := decide (w.workingSetMB ≤ d.ramMB + d.vramMB)

/-- Threads that do useful work: at least one, at most what the job can use and the device has. -/
def usedCores (d : Device) (w : Workload) : Nat := max 1 (min d.cores w.parallel)

def computeMs (d : Device) (w : Workload) : Nat :=
  w.flopsG * 1000 / max 1 (d.gflopsCore * usedCores d w)

def memoryMs (d : Device) (w : Workload) : Nat :=
  w.bytesMB * 1000 / max 1 d.bandwidthMBs

def timeMs (d : Device) (w : Workload) : Nat := max (computeMs d w) (memoryMs d w)

theorem usedCores_pos (d : Device) (w : Workload) : 0 < usedCores d w := by
  unfold usedCores; omega

theorem usedCores_mono {d1 d2 : Device} (w : Workload) (h : d1.cores ≤ d2.cores) :
    usedCores d1 w ≤ usedCores d2 w := by
  unfold usedCores; omega

/-- More cores (all else equal) never make the estimate slower. -/
theorem more_cores_not_slower (d1 d2 : Device) (w : Workload) (hc : d1.cores ≤ d2.cores)
    (hg : d1.gflopsCore = d2.gflopsCore) (hb : d1.bandwidthMBs = d2.bandwidthMBs) :
    timeMs d2 w ≤ timeMs d1 w := by
  have hu := usedCores_mono w hc
  have h1 : computeMs d2 w ≤ computeMs d1 w := by
    unfold computeMs
    rw [← hg]
    have hm := Nat.mul_le_mul_left d1.gflopsCore hu
    exact Nat.div_le_div_left (by omega) (by omega)
  have h2 : memoryMs d2 w = memoryMs d1 w := by unfold memoryMs; rw [hb]
  unfold timeMs
  omega

/-- A lighter job (less compute, less traffic, same parallelism) is never slower on the same device. -/
theorem lighter_not_slower (d : Device) (w1 w2 : Workload) (hf : w1.flopsG ≤ w2.flopsG)
    (hb : w1.bytesMB ≤ w2.bytesMB) (hp : w1.parallel = w2.parallel) :
    timeMs d w1 ≤ timeMs d w2 := by
  have hu : usedCores d w1 = usedCores d w2 := by unfold usedCores; rw [hp]
  have h1 : computeMs d w1 ≤ computeMs d w2 := by
    unfold computeMs
    rw [hu]
    exact Nat.div_le_div_right (Nat.mul_le_mul_right 1000 hf)
  have h2 : memoryMs d w1 ≤ memoryMs d w2 := by
    unfold memoryMs
    exact Nat.div_le_div_right (Nat.mul_le_mul_right 1000 hb)
  unfold timeMs
  omega

/-- If the heavier job fits, the lighter one fits too. -/
theorem fits_mono (d : Device) (w1 w2 : Workload) (h : w1.workingSetMB ≤ w2.workingSetMB)
    (hf : fits d w2 = true) : fits d w1 = true := by
  simp only [fits, decide_eq_true_eq] at *
  omega

/-- More RAM never turns a fit into a miss. -/
theorem fits_more_ram (d1 d2 : Device) (w : Workload) (h : d1.ramMB + d1.vramMB ≤ d2.ramMB + d2.vramMB)
    (hf : fits d1 w = true) : fits d2 w = true := by
  simp only [fits, decide_eq_true_eq] at *
  omega

/-! ## Devices and workloads (rough public figures, edit freely) -/

def gtx1050ti : Device := ⟨"1050 Ti 4GB + 6c CPU", 6, 16384, 4096, 120, 112000⟩
def steamDeck : Device := ⟨"Steam Deck", 8, 16384, 0, 25, 88000⟩
def rpi4 : Device := ⟨"Raspberry Pi 4", 4, 4096, 0, 6, 4000⟩
def desktop : Device := ⟨"desktop 16c", 16, 32768, 12288, 120, 500000⟩

def light : Workload := ⟨"light (1 Tflop, 2 GB moved, 512 MB)", 1000, 2000, 512, 2⟩
def heavy : Workload := ⟨"heavy (50 Tflop, 80 GB moved, 9 GB)", 50000, 80000, 9000, 16⟩

def row (d : Device) (w : Workload) : String :=
  s!"{d.name} | {w.name} | fits={fits d w} | cores={usedCores d w} | {timeMs d w} ms"

#eval String.intercalate "\n" <|
  [gtx1050ti, steamDeck, rpi4, desktop].flatMap fun d => [light, heavy].map (row d)

-- the theorems must not rest on sorryAx
#print axioms more_cores_not_slower
#print axioms lighter_not_slower
#print axioms fits_mono
#print axioms fits_more_ram

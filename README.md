# Microwatt + Systolic Array Accelerator

## About the Project
This project is part of the **Microwatt Momentum Hackathon**.  
We extend the [Microwatt OpenPOWER CPU core](https://github.com/antonblanchard/microwatt) by integrating systolic array accelerators for **Edge AI workloads** (matrix multiplication, neural network layers).  

The design uses the **OpenFrame SoC platform**, targeting tapeout in the provided **15 mm² user area** with open-source tools.  

---

## Motivation
- **AI at the Edge:** AI inference/training requires efficient matrix multiplication, which general CPUs handle poorly.  
- **Microwatt + Accelerator:** Our systolic array co-processor offloads this workload, enabling higher performance per watt.  
- **Open Hardware Impact:** By extending an open POWER ISA CPU with an accelerator, we demonstrate reproducible, tapeout-ready AI silicon using fully open-source flows.  

---

## Project Variants

We developed two variants to validate the design approach and achieve production readiness:

### Option A: 4×4 GPIO-Based Systolic Array
Minimal GPIO-controlled prototype for rapid validation and design space exploration.

### Option B: 8×8 Wishbone-Based Systolic Array
Production-ready, software-programmable accelerator with full Wishbone B4 bus interface.

---

## Option A: 4×4 GPIO-Based Systolic Array

### Overview
The first stage implements a **4×4 INT8 weight-stationary systolic array** integrated with Microwatt via GPIO control lines. This minimal interface validates the processing-element (PE) array, control FSM, and OpenLane flow before full Wishbone bus implementation.

### Design Rationale

#### Why Start with GPIO Instead of Wishbone?
- **Risk Reduction:** Wishbone adds protocol and timing complexity. Starting from a pure-GPIO interface let us prove correctness of computation and synthesis first.  
- **Simplicity & Visibility:** GPIO pins can be directly toggled and probed—ideal for early bring-up and debugging.  
- **OpenFrame Compatibility:** The official example design already uses a top module named `user_proj_timer`. Re-using that wrapper name ensured seamless tool compatibility and padframe pin mapping inside OpenFrame.  
- **Rapid Iteration:** The 4×4 array fits comfortably within the 15 mm² user area, allowing sub-minute OpenLane runs and fast design-space exploration.  
- **Verification before Scaling:** Beginning with GPIO simplified verifying Verilog correctness and timing before scaling up the array size and control complexity.  
- **Synthesis Runtime Simplicity:** A small cell count meant short synthesis runtime, enabling quick iteration cycles to validate every generated Verilog block end-to-end.  

---

### RTL Architecture

**Hierarchy:**
```
user_proj_timer (top)
  └── systolic_array_4x4
       └── pe ×16 (u00 … u33)
```

**RTL Files** (`verilog/rtl_v1/`):
- `pe.v` – Processing Element (MAC unit)  
- `systolic_array_4x4.v` – Array interconnect + dataflow control  
- `user_proj_timer.v` – GPIO wrapper + FSM controller  

Using the same wrapper name (`user_proj_timer`) as the reference OpenFrame example simplified pin-order generation and automated sign-off scripts, avoiding re-wiring of the padframe.

---

### OpenLane Configuration

**Design directory:** `openlane/user_proj_timer/`  
**Run tag:** `accel_v1`

**Config files:**
- `openlane/user_proj_timer/config.json` – Main settings  
- `openlane/user_proj_timer/pin_order.cfg` – Pad placement  

```json
{
  "DESIGN_NAME": "user_proj_timer",
  "CLOCK_PERIOD": 40,
  "DIE_AREA": "0 0 500 500",
  "FP_CORE_UTIL": 35,
  "PL_TARGET_DENSITY": 0.40,
  "RT_MAX_LAYER": "met4",
  "MAX_FANOUT_CONSTRAINT": 10,
  "RUN_HEURISTIC_DIODE_INSERTION": 1,
  "GRT_REPAIR_ANTENNAS": 1,
  "RUN_CVC": 0
}
```

**Run commands:**
```bash
cd openlane/user_proj_timer
flow.tcl -design . -tag accel_v1 -overwrite
```

**Artifacts:** `runs/accel_v1/results/final/gds/user_proj_timer.gds`, LEF, netlists, reports under `runs/accel_v1/reports/`.

---

### Synthesis Results

| Metric | Value | Notes |
|--------|-------|-------|
| Total Cells | 345 | Very compact design |
| Flip-Flops | 53 | FSM + pipeline registers |
| Gate Instances | 11,013 | Primitive logic cells |
| Runtime | < 1 min | Fast due to small size |
| Library | sky130_fd_sc_hd | High-density std cells |

- **Logic levels:** 9  
- **Voltage:** 1.8 V (vccd1/vssd1)  

---

### Physical Design Results

| Parameter | Value | Unit |
|-----------|-------|------|
| Die Width | 488.52 | µm |
| Die Height | 476.0 | µm |
| Core Utilization | 35 | % |
| Core Area | 0.233 | mm² |
| Total Cells (after fill/taps) | 23,860 | - |

**Routing Stats:**
- **Max Layer:** met4  
- **Total wire length:** ≈ 10.6 mm  
- **Vias:** ≈ 3 k  
- **Congestion:** < 2 % on all layers  

---

### Timing Analysis

| Corner | WNS | TNS | Status |
|--------|-----|-----|--------|
| Min | 0.0 ns | 0.0 ns | ✅ PASS |
| Typ | 0.0 ns | 0.0 ns | ✅ PASS |
| Max | 0.0 ns | 0.0 ns | ✅ PASS |

- **Critical path:** ≈ 1.82 ns → theoretical ≈ 550 MHz limit  
- **Chosen period:** 40 ns (25 MHz) for robustness  

---

### Power Analysis

| Component | Typical Corner |
|-----------|----------------|
| Internal | 148 µW |
| Switching | 94.8 µW |
| Leakage | 0.0146 µW |
| **Total** | **≈ 243 µW** |

Low-power design (< 0.25 mW) → ideal for edge inference prototypes.

---

### Verification & Sign-Off

**All checks ✅ PASS:**
- **Magic/KLayout DRC:** 0 violations  
- **LVS:** Clean  
- **Antenna:** None  
- **Routing:** No shorts/spacing errors  
- **XOR Check:** Identical layouts between Magic and KLayout  

**Minor notes:** Max-fanout warnings (non-critical) and Verilator lint style warnings.

---

### Functional Behavior

**Inputs** (`io_in`):
- `[0]` start pulse  
- `[1]` clear accumulators  

**Outputs** (`io_out`):
- `[0]` done  
- `[1]` busy  
- `[10:2]` result (9 bits)  

**Computation:** Hard-coded matrices A and B multiply to C = A×Bᵀ → verify C[3][0] = 41 (0x29).  
**FSM:** IDLE→LOAD→CLEAR→COMPUTE→DONE (≈10 cycles @ 25 MHz ≈ 400 ns total).

---

### Manufacturing Readiness

- **PDK:** Sky130A  
- **Library:** sky130_fd_sc_hd  
- **DRC/LVS/Antenna:** Clean  
- **Meets density rules**  
- **Ready for mask generation**  
- **✅ Tape-out Ready (Score 10/10)**  

---

### Performance Summary

| Metric | Value | Status |
|--------|-------|--------|
| Area Efficiency | 1,481 cells/mm² | ✅ Excellent |
| Timing Margin | 95 % | ✅ Excellent |
| Power | 0.243 mW | ✅ Low |
| DRC/LVS | Clean | ✅ Perfect |
| Routing | < 2 % | ✅ Excellent |

**Flow runtime:** ≈ 1 min 16 s (total), with synthesis ≈ 20 s and routing ≈ 15 s.

---

### Lessons & Takeaways

**Strengths:**
- GPIO simplicity → first GDSII success  
- Loose timing → easy closure  
- Low utilization → minimal congestion  
- Short synthesis runtime simplified correctness verification of Verilog modules before scaling  

**Limitations:**
- Hard-coded matrices and limited I/O pins (11 GPIOs)  
- Single output observation (9 bits)  

Still, this validated our PE and array logic and proved the flow to silicon.

---

### Directory Map

```
/project/
├─ verilog/rtl_v1/
│   ├─ pe.v
│   ├─ systolic_array_4x4.v
│   └─ user_proj_timer.v
├─ openlane/user_proj_timer/
│   ├─ config.json
│   ├─ pin_order.cfg
│   └─ runs/accel_v1/
│        ├─ results/final/{gds,lef,verilog}/user_proj_timer.*
│        └─ reports/{synthesis,signoff}/
└─ backups/accel_v1_WORKING/
```

---

## Option B: 8×8 Wishbone-Based Systolic Array

### Motivation for Scaling to 8×8

After validating the 4×4 GPIO-based prototype, we scaled to an 8×8 systolic array to enhance throughput and enable flexible, software-programmable operation. Rather than doubling incrementally (e.g., 6×6 or 12×12), 8×8 was chosen as the next logical balance between computational gain and OpenFrame area constraints. The design still fits comfortably within a 4 mm² user project area on SKY130 while keeping runtime and routing manageable.

### Why Weight-Stationary (WS) Dataflow?

We adopted the Weight-Stationary (WS) approach because:
- **Reuse Efficiency:** Weights remain constant across multiple input tiles, reducing data movement and power.  
- **Predictable Dataflow:** Enables regular scheduling and simple local control for systolic arrays.  
- **Simplified Scratchpads:** WS eliminates the need for dual-port or high-bandwidth memories, fitting well with OpenLane register-based scratchpads.  
- **Timing Stability:** Fixed weight flow yields consistent critical paths per PE, easing timing closure at 20 MHz.  

Alternative dataflows (Output-Stationary, Input-Stationary) were considered, but WS offered the best trade-off between area, timing, and local buffering complexity on a small-scale OpenFrame ASIC.

---

### Design Overview

**Module Hierarchy:**
```
accel_wb_wrapper_8x8 (top)
 └── systolic_array_8x8
      └── pe ×64 (u00 … u77)
```

**RTL Files** (`verilog/rtl`):
- `pe.v` – Pipelined MAC unit (INT8×INT8→INT32)  
- `systolic_array_8x8.v` – 8×8 PE grid with WS dataflow  
- `accel_wb_wrapper_8x8.v` – Wishbone slave wrapper + FSM + scratchpads  

---

### Why Stop at 8×8 Instead of 16×16?

- **Design Feasibility:** 64 k logic cells (8×8) fit comfortably in OpenLane with <3 h runtime; 16×16 would exceed 250 k cells and >12 h runtime.  
- **Area Limit:** 8×8 occupies ~4 mm² of 15 mm² OpenFrame area, leaving margin for integration.  
- **Power Limit:** <10 mW typical vs. ~35 mW estimated for 16×16—ideal for Edge-AI targets.  
- **Verification Practicality:** 8×8 ensures full-corner signoff (0 violations) within OpenLane resource limits.  

---

### Architectural Details

| Parameter | Value |
|-----------|-------|
| Weight Precision | 8-bit |
| Activation Precision | 8-bit |
| Accumulator Width | 32-bit |
| Scratchpads | A/B (64×8-bit), C (64×32-bit) |
| Total On-Chip Memory | 3,072 bits (384 bytes) |
| Bus Interface | Wishbone B4, 32-bit data/address |
| Clock | 20 MHz (50 ns period) |
| FSM States | 6 (IDLE, LOADW, CLEAR, STREAM, DRAIN, CAPTURE) |
| Total Latency | ~18–19 cycles (≈950 ns @ 20 MHz) |
| Throughput | 512 MACs / 18 cycles = 568 MOPS @ 20 MHz |

**Memory Map:**
```
0x00000000 CTRL   Control (start, clear, irq_en)
0x00000004 STATUS Status (busy, done)
0x00000008 DIM_MNK Dimension config (M,N,K)
0x0000000C POST_S Scale factor
0x00400000 A_WIN  Activation window (64B)
0x00600000 B_WIN  Weight window (64B)
0x00800000 C_WIN  Result window (256B)
```

---

### Synthesis Results

| Metric | Value |
|--------|-------|
| Total Logic Cells | 64,268 |
| Flip-Flops | 5,578 (8.7 %) |
| Combinational Gates | 58,690 (91.3 %) |
| Area (pre-placement) | 693,719 µm² (0.694 mm²) |
| Wires | 64,245 |
| Public Wires | 5,553 |
| Runtime | ≈ 20 min |
| Library | sky130_fd_sc_hd |
| PDK | Sky130A |

**Gate Breakdown:**
- AND: 8,151  
- OR: 4,719  
- NAND: 6,266  
- NOR: 5,385  
- XOR/XNOR: 6,527  
- AOI/OAI: 22,778  
- MUX: 4,144  
- INV: 719  

---

### Physical Design Results

| Parameter | Value |
|-----------|-------|
| Die Size | 2000 µm × 2000 µm = 4.0 mm² |
| Core Area | 3.93 mm² |
| Utilization | 20.28 % |
| Logic Cell Density | 16,351 cells/mm² |
| Total Physical Cells | 496,837 |
| Logic Cells | 64,268 |
| Decap | 56,133 |
| Welltap | 35,060 |
| Diode | 92,008 |
| Fill | 74,807 |

**Why So Many Cells?**  
Decaps stabilize power; welltaps meet substrate rules; 92 k diodes protect against antenna charging.

---

### Timing Results

| Corner | Voltage | Temp | WNS | TNS | Status |
|--------|---------|------|-----|-----|--------|
| Fast | 1.95 V | −40 °C | 0.0 | 0.0 | ✅ PASS |
| Typical | 1.8 V | 25 °C | 0.0 | 0.0 | ✅ PASS |
| Slow | 1.6 V | 100 °C | 0.0 | 0.0 | ✅ PASS |

- **Critical Path Delay:** 7.03 ns → theoretical ~142 MHz  
- **Chosen Clock Period:** 50 ns (20 MHz) → 44 ns slack (88 % margin)  

**Reasoning for 20 MHz Target:**
- Matches typical Wishbone SoC clock domain  
- Guarantees stability at all corners  
- Lower power and IR drop  
- Ample headroom for signoff  

---

### Power Analysis

| Corner | Voltage | Temp | Total Power | Notes |
|--------|---------|------|-------------|-------|
| Fast | 1.95 V | −40 °C | 10.66 mW | Max power case |
| Typical | 1.8 V | 25 °C | 9.17 mW | Nominal operation |
| Slow | 1.6 V | 100 °C | 7.59 mW | High-temp case |

**Power Distribution:**
- Clock network ≈ 50 % of total power  
- Sequential logic ≈ 47 %  
- Combinational ≤ 6 %  
- Leakage increases ×47,000 from −40 °C → 100 °C  

**Efficiency Metrics:**
- Energy per MAC: 16.1 pJ (MAC)  
- Efficiency: 0.062 TOPS/W @ 130 nm → competitive with older ASICs  

---

### Routing Results

| Metric | Value |
|--------|-------|
| Total Wire Length | 2.66 m |
| Vias | 621,777 |
| Nets | 64,739 |
| HPWL | 1.46 × 10⁹ units |
| Layers Used | met2–met5 (met4 max) |

**Layer Utilization:**
- met2: 19.7 %  
- met3: 18.3 %  
- met4: 5.2 %  
- met5: 6.8 %  

**Congestion:** ≈ 12.5 % average → Excellent routability  
**Violations:** 0 (shorts, spacing, off-grid)  

---

### Verification & Sign-Off

| Check | Tool | Status |
|-------|------|--------|
| DRC | Magic & KLayout | ✅ 0 violations |
| LVS | Netgen | ✅ Matched |
| Antenna | ARC | ✅ 24 violations mitigated (92 k diodes) |
| STA | OpenSTA | ✅ All corners pass |
| XOR | KLayout vs Magic | ✅ Identical |
| SPEF | Extracted (min/nom/max) | ✅ Generated |

**Tape-Out Readiness Score: 10 / 10 ✅**

---

### Configuration Summary

**Design Directory:** `openlane/accel_wb_8x8/`

**Configuration** (`config.json`):
```json
{
  "DESIGN_NAME": "accel_wb_wrapper_8x8",
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 50,
  "FP_CORE_UTIL": 20,
  "PL_TARGET_DENSITY": 0.55,
  "RT_MAX_LAYER": "met4",
  "MAX_FANOUT_CONSTRAINT": 8,
  "SYNTH_STRATEGY": "AREA 0",
  "GRT_REPAIR_ANTENNAS": 1,
  "RUN_HEURISTIC_DIODE_INSERTION": 1
}
```

**Key Decisions:**
- 50 ns clock → conservative margin for multi-corner reliability.  
- 20 % core utilization → relaxed routing.  
- AREA optimization → minimize cell count.  
- Auto diode insertion → prevent antenna damage.  

---

### Performance & Comparison

| Metric | GPIO 4×4 | Wishbone 8×8 | Ratio |
|--------|----------|--------------|-------|
| Logic Cells | 345 | 64,268 | 186× |
| Die Area (mm²) | 0.233 | 4.0 | 17× |
| Utilization (%) | 35 | 20.3 | 0.6× |
| Runtime | 1 min 16 s | 2 h 47 m | 131× |
| Power (mW) | 0.243 | 9.17 | 38× |
| MACs | 16 | 64 | 4× |
| Throughput (MOPS) | 640 | 568 | 0.89× |
| DRC/LVS Errors | 0 | 0 | – |

**Insights:**
- Complexity ↑ 186×, runtime ↑ 131×, but power ↑ only 38× → strong scaling efficiency.  
- Slight throughput loss (fill/drain overhead) compensated by programmable flexibility.  
- Area per MAC = 0.0625 mm² → reasonable for 130 nm.  

---

### Flow Runtime Summary

| Stage | Duration |
|-------|----------|
| Synthesis | 20 min |
| Floorplan | 5 min |
| Placement | 25 min |
| CTS | 8 min |
| Routing | 65 min |
| Optimization + Signoff | 44 min |
| **Total** | **2 h 47 m** |

**Resource Usage:** ≈ 5.8 GB RAM, 95 % CPU (single thread).  
**Tool:** OpenLane v2 (Docker Linux x86_64).

---

### Lessons Learned & Design Insights

**What Worked:**
- Modular hierarchy (PE → Array → Wrapper) simplified verification.  
- Register-based scratchpads avoided SRAM toolchain complexity.  
- Conservative timing closed cleanly across all PVT corners.  
- Wishbone bus enabled dynamic data loading and control flexibility.  
- Low utilization → zero routing congestion, clean DRC/LVS.  

**Challenges:**
- Antenna mitigation added 92 k diodes (+143 % cell count overhead).  
- Register scratchpads increased area/power (~55 % of DFFs).  
- Runtime ≈ 3 h for flow → future hierarchical flow suggested.  

**Optimization Opportunities:**
- Use SRAM macros → 24 % power reduction / 12 % area reduction.  
- Increase core utilization to 40 – 50 %.  
- Raise frequency to 50 – 100 MHz with retiming.  
- Pipeline MAC stage (PIPELINE_MUL = 1) for >200 MHz.  
- Adopt hierarchical synthesis for faster QoR.  

---

### Key Achievements

✅ Closed timing (all corners) → 0 violations (44 ns slack)  
✅ DRC/LVS clean → manufacturable layout  
✅ 568 MOPS @ 9.17 mW (62 GOPS/W)  
✅ Wishbone B4 compliant & interrupt-capable  
✅ Full RTL-to-GDSII verified (950 lines of Verilog)  
✅ 4 mm² die with 64 k logic cells, zero congestion  

---

### Directory Map

```
/project/
├─ verilog/rtl/
│   ├─ pe.v
│   ├─ systolic_array_8x8.v
│   └─ accel_wb_wrapper_8x8.v
└─ openlane/accel_wb_8x8/
    ├─ config.json
    └─ runs/run_synth1/
         ├─ results/final/{gds,lef,verilog,spice,sdf,spef,sdc,def}/accel_wb_wrapper_8x8.*
         ├─ reports/{synthesis,routing,signoff}/
         └─ logs/{synthesis,placement,cts,routing,signoff}/
```

---

## Tools & Platforms

- **CPU Core:** [Microwatt](https://github.com/antonblanchard/microwatt) (OpenPOWER v3.1C compliant).  
- **SoC Platform:** [OpenFrame User Project](https://github.com/chipfoundry/openframe_user_project).  
- **Simulation:** GHDL, Verilator.  
- **Synthesis & PnR:** Yosys, OpenROAD, OpenLane.  
- **Software Toolchain:** GCC for POWER (ppc64le), GDB.  

---

## References

- [Microwatt OpenPOWER Core](https://github.com/antonblanchard/microwatt)  
- [Gemmini Accelerator](https://github.com/ucb-bar/gemmini)  
- Jouppi et al., In-Datacenter Performance Analysis of a TPU  
- [OpenFrame User Project Template](https://github.com/chipfoundry/openframe_user_project)
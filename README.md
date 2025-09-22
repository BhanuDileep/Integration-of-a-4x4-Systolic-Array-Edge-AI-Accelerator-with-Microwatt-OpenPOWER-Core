# OpenFrame Overview

The OpenFrame Project provides an empty harness chip that differs significantly from the Caravel and Caravan designs. Unlike Caravel and Caravan, which include integrated SoCs and additional features, OpenFrame offers only the essential padframe, providing users with a clean slate for their custom designs.

<img width="256" alt="Screenshot 2024-06-24 at 12 53 39 PM" src="https://github.com/efabless/openframe_timer_example/assets/67271180/ff58b58b-b9c8-4d5e-b9bc-bf344355fa80">

## Key Characteristics of OpenFrame

1. **Minimalist Design:**  
   - No integrated SoC or additional circuitry.  
   - Only includes the padframe, a power-on-reset circuit, and a digital ROM containing the 32-bit project ID.

2. **Padframe Compatibility:**  
   - The padframe design and pin placements match those of the Caravel and Caravan chips, ensuring compatibility and ease of transition between designs.  
   - Pin types are identical, with power and ground pins positioned similarly and the same power domains available.

3. **Flexibility:**  
   - Provides full access to all GPIO controls.  
   - Maximizes the user project area, allowing for greater customization and integration of alternative SoCs or user-specific projects at the same hierarchy level.

4. **Simplified I/O:**  
   - Pins that previously connected to CPU functions (e.g., flash controller interface, SPI interface, UART) are now repurposed as general-purpose I/O, offering flexibility for various applications.

The OpenFrame harness is ideal for those looking to implement custom SoCs or integrate user projects without the constraints of an existing SoC.

## Features

1. 44 configurable GPIOs.  
2. User area of approximately 15 mm².  
3. Supports digital, analog, or mixed-signal designs.

---

# Integration of a 4×4 Systolic Array Edge-AI Accelerator with Microwatt OpenPOWER Core

## About the Project
This project is part of the **Microwatt Momentum Hackathon**.  
We extend the [Microwatt OpenPOWER CPU core](https://github.com/antonblanchard/microwatt) by integrating a **4×4 systolic array accelerator** for **Edge AI workloads** (matrix multiplication, neural network layers).  

The design uses the **OpenFrame SoC platform**, targeting tapeout in the provided **15 mm² user area** with open-source tools.  

---

## Motivation
- **AI at the Edge:** AI inference/training requires efficient matrix multiplication, which general CPUs handle poorly.  
- **Microwatt + Accelerator:** Our systolic array co-processor offloads this workload, enabling higher performance per watt.  
- **Open Hardware Impact:** By extending an open POWER ISA CPU with an accelerator, we demonstrate reproducible, tapeout-ready AI silicon using fully open-source flows.  

---

## System Architecture

```text
+------------------------+
|   Microwatt CPU Core   |
+-----------+------------+
            |
       Wishbone Bus
            |
+-----------+-----------+
|                       |
|   Scratchpad SRAM     |
|        16 KB          |
|                       |
|   Accelerator (4×4)   |
|     16 PEs            |
+-----------------------+
```



- **Microwatt CPU** executes control software.  
- **Wishbone Interconnect** links CPU, scratchpad, and accelerator.  
- **4×4 Systolic Array** (16 PEs) accelerates matrix multiplication.  
- **Scratchpad SRAM (16 KB)** buffers activations and weights.  

---

## Integration with OpenFrame
- The **Microwatt core** is placed in the OpenFrame CPU slot.  
- The **accelerator + scratchpad** connect through the **Wishbone bus** in the OpenFrame user area.  
- Dataflow: **CPU configures DMA → data loaded into scratchpad → systolic array executes MatMul → results written back**.  
- Verified with **GHDL/Verilator** simulations before OpenLane synthesis.  

---

## Workflow
We follow a structured workflow to ensure reproducibility and tapeout readiness:

1. **Architecture & Specification**  
   - Define 4×4 systolic PE, memory map, Wishbone registers, DMA.  
2. **RTL Implementation**  
   - Write Verilog/VHDL for systolic array and controller.  
   - Connect to Microwatt + SRAM.  
3. **Simulation**  
   - Unit tests for PE, systolic array, DMA.  
   - Integration test with Microwatt executing software.  
4. **Synthesis & PnR**  
   - Yosys → OpenROAD/OpenLane → GDSII.  
   - Floorplanning in OpenFrame template.  
5. **Verification & Tapeout**  
   - Ensure area/power < 15 mm².  
   - Submit GDSII via OpenFrame MPW flow.  

---

## Use of Generative AI
We use **Generative AI (GenAI)** (e.g., AutoChip, ChipChat, ChatGPT) in this project as part of our methodology:  

- **Brainstorming & Ideation:** Exploring design-space trade-offs (4×4 vs 8×8 arrays, memory sizing).  
- **Code Assistance:** Drafting RTL templates (human-reviewed before use).  
- **Documentation:** Logging AI-assisted sessions, design notes, and generated snippets in this repo.  
- **Transparency:** All AI involvement is documented for reproducibility and clarity.  

---

## Tools & Platforms
- **CPU Core:** [Microwatt](https://github.com/antonblanchard/microwatt) (OpenPOWER v3.1C compliant).  
- **SoC Platform:** [OpenFrame User Project](https://github.com/chipfoundry/openframe_user_project).  
- **Simulation:** GHDL, Verilator.  
- **Synthesis & PnR:** Yosys, OpenROAD, OpenLane.  
- **Software Toolchain:** GCC for POWER (ppc64le), GDB.  

---

## Deliverables
- RTL design of **4×4 systolic array accelerator**.  
- Wishbone bus integration with Microwatt.  
- Scratchpad memory controller.  
- End-to-end demo (matrix multiplication, small NN workloads).  
- Verified GDSII for tapeout.  
- Logs of GenAI-assisted design process.  

---

## Roadmap
- [x] Project topic finalized  
- [ ] Architecture specification  
- [ ] RTL design of systolic array PE  
- [ ] Wishbone integration  
- [ ] Scratchpad memory controller  
- [ ] Simulation & verification  
- [ ] Synthesis & place-and-route  
- [ ] Tapeout submission  

---

## Getting Started
Clone this repository:

```bash
git clone https://github.com/BhanuDileep/Integration-of-4x4-Systolic-Array.git
cd Integration-of-4x4-Systolic-Array
```
## Future Work
- Extend systolic array from **4×4 → 8×8** for higher throughput.  
- Explore support for **quantized INT8 inference**.  
- Integrate simple **RISC-V or AI kernel offload**.  
- Evaluate performance across different edge workloads (CNN layers, transformers).  

## References
- [Microwatt OpenPOWER Core](https://github.com/antonblanchard/microwatt)  
- [Gemmini Accelerator](https://github.com/ucb-bar/gemmini)  
- Jouppi et al., *In-Datacenter Performance Analysis of a TPU*  
- [OpenFrame User Project Template](https://github.com/chipfoundry/openframe_user_project)  


# 32-bit Signed Radix-4 SRT Integer Divider

A high-performance, structurally modeled 32-bit integer divider implementing the Radix-4 SRT algorithm in Verilog. This design features a dynamic iteration scaling mechanism, On-The-Fly Conversion (OTFC) for zero-latency quotient resolution, and a Coarse-Fine post-processing architecture for efficient remainder recovery.

## 🚀 Key Features

*   **Signed Integer Support:** Seamlessly handles signed 32-bit arithmetic via a dedicated `sign_manager` wrapper.
*   **Radix-4 SRT Algorithm:** Computes 2 quotient bits per clock cycle using Carry-Save Adders (CSA) to eliminate carry-propagation delays in the core loop.
*   **Dynamic Iteration Scaling:** Intelligently calculates the required number of clock cycles based on the magnitude of the operands, bypassing redundant cycles for large divisors.
*   **Guard-Bit Architecture:** Utilizes an extended 38-bit internal datapath to inherently protect against early-cycle remainder overflow without stalling the pipeline.
*   **Coarse-Fine Post-Processing:** Efficiently recovers the true mathematical remainder using a hybrid sequential (4-bit coarse shift) and combinational (0-3 bit fine shift) mechanism.
*   **Comprehensive Self-Checking Testbench:** Verified against 8,000+ randomized signed 8-bit, 16-bit, and full 32-bit vectors, including extreme mathematical corner cases.

## 📂 Repository Structure

*   `topmodule.v`: The top-level wrapper integrating the sign manager, FSM, and datapath.
*   `controller.v`: The Finite State Machine (FSM) managing the division phases (`PREPROCESS`, `DIVIDE`, `POST_PROCESS`).
*   `datapath.v`: Contains the core arithmetic units, structurally instantiated as three distinct sub-modules:
    *   `r4_div_preprocess`: Handles divisor normalization and dynamic clock calculation.
    *   `r4_div_core`: The 38-bit Radix-4 SRT engine, featuring Quotient Selection Logic (`Q_SEL`) and OTFC.
    *   `r4_div_postprocess`: Re-aligns the remainder.
*   `components.v`: Structural hardware primitives (Registers, Multiplexers, Adders, Shift Registers, Down Counters).
*   `tb_r4_div_top.v`: The automated testbench for rigorous verification.

## 🧠 Architecture Overview

The divider is built on a split-phase architecture to maximize maximum operating frequency (Fmax) and minimize area:
1. **Normalization:** The divisor is shifted to align its MSB, and a dynamic iteration count is passed to the controller.
2. **SRT Core:** A structural `Q_SEL` block examines a 7-bit window (`[35:29]`) of the shifted residual to select the next radix-4 digit `{-2, -1, 0, 1, 2}`. 
3. **OTFC:** Converts the redundant quotient digits into standard binary format on the fly, eliminating the need for a carry-propagate adder at the end of the quotient generation.
4. **Recovery:** The remainder is statically pushed back to its true scale using a highly optimized Coarse-Fine shifting datapath.

## 🛠️ Simulation & Verification

The design has been strictly verified at the RTL level using **ModelSim**. The testbench automatically compares the hardware output against Verilog's native division operations. 

### Running the Testbench
1. Compile all `.v` files in your simulator environment.
2. Set `tb_r4_div_top` as the top-level simulation entity.
3. Run the simulation. The testbench will execute 4 distinct phases and output a summary log in the transcript:
   - Phase 1: Directed Corner Cases (e.g., divide by zero fallback, negative maximums)
   - Phase 2: 8-Bit Signed Randoms
   - Phase 3: 16-Bit Signed Randoms
   - Phase 4: Full 32-Bit Signed Randoms

## 📈 Synthesis & Implementation (WIP)
*Targeting RTL synthesis tools (e.g., Quartus, Yosys) to evaluate gate count, Area, and Fmax metrics.*

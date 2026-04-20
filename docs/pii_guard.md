# Real-Time PII Guard

This document provides the complete set of instructions to build, program, and demonstrate the **Hardware-Accelerated PII Scrubber** on an FPGA, along with deep technical details about the underlying regex engine architecture.

---

## 1. Prerequisites & Setup

### Hardware

- **FPGA Board:** Xilinx Nexys A7 100T (Artix-7).
- **Cable:** Micro-USB to USB-A (connected to the `USB-PROG` port).
- **Switch:** Power switch in the `ON` position.

### Software

- **Vivado Design Suite:** (2019.1 or newer recommended).
- **Terminal/Shell:** Bash (Linux) or Git Bash (Windows).
- **Python 3.x:** With dependencies listed in `tui/requirements.txt` (`pip install -r tui/requirements.txt`).
- **PuTTY:** Serial terminal client.

---

## 2. Build & Hardware Generation

Before opening Vivado, we must use the C++ compiler to generate the specific Verilog modules for our PII patterns.

1.  **Open your terminal** in the project directory.
2.  **Generate the Streaming Verilog Modules:**
    This command reads `inputs/regexes.txt` and outputs the Verilog to the `output/` folder with PII-specific hardware (including the 128-byte delay buffer).
    ```bash
    make pii_build
    ```
3.  **Synthesize and Program the FPGA:**
    We have automated Vivado TCL scripts for this. From the terminal, simply run:

    ```bash
    make pii_synth
    make program
    ```

    _Note: If you prefer the GUI, you can open Vivado, create a new project for the `xc7a100tcsg324-1` part, add all `.v` files and the `.xdc` file from the `output/` folder, set `top_fpga.v` as the top module, and generate the bitstream manually._

    **Important:** Press the **Center Button (BTNC)** on the FPGA after programming to reset the internal state machines and clear the BRAM buffers.

---

## 3. The Live Demo (Using PuTTY)

This mode allows for a dramatic "live-typing" demonstration where characters are redacted as you type.

1.  **Open Device Manager** on your PC to find the **COM Port** (Eg., `COM3`).
2.  **Launch PuTTY** and configure exactly as follows:
    - **Connection Type:** Serial
    - **Serial Line:** `COMx` (your port)
    - **Speed:** `115200`
3.  **Configure PuTTY Terminal Behavior:**
    - Go to **Category: Terminal** in the left sidebar.
    - Check: **Implicit LF on every CR**
    - Check: **Implicit CR on every LF**
    - **Local Echo:** Set to **Force Off** (Characters should only appear if the FPGA sends them back).
    - **Local Line Editing:** Set to **Force Off**.
4.  **Open the Connection.**
5.  **Press the Reset Button (BTNC)** on the FPGA to ensure the engine is ready.

---

## 4. The High-Speed Streaming Script

To demonstrate the system running with a simulated data stream (perfect for testing high-throughput):

1. Navigate to the `tui/` directory and ensure dependencies are installed:
   ```bash
   pip install -r requirements.txt
   ```
2. Open `tui/pii_demo.py` and ensure the `PORT` variable matches your setup.
3. Run the script:
   ```bash
   python pii_demo.py
   ```
4. The script will stream a block of text containing credit cards and emails, simulating network line-rate, and print the perfectly redacted string (Eg., `XXXXXXXXXXXXXXXX`) back to your terminal as it flows out of the FPGA's BRAM buffer.

---

## 5. Engine Architecture Details

### Stage 1 - C++ Regex Parser

- **Lexer:** Reads raw regex strings and transforms them into typed tokens (Eg., `LITERAL`, `STAR`, `LBRACKET`). It filters for printable ASCII and implements literal escaping (`\`).
- **Parser:** Constructs an Abstract Syntax Tree (AST) using recursive descent, cleanly supporting custom character classes (`[a-z]`) alongside standard operators.

### Stage 2 - NFA Construction

Converts the AST into an ε-free NFA using Glushkov's algorithm.

1.  **Linearization:** Symbols and character classes are assigned unique integer positions.
2.  **Nullable/Firstpos/Lastpos/Followpos:** Evaluates the AST to determine precise state transitions.
3.  **Global State Numbering:** Every state across all input regular expressions gets a globally unique ID to avoid Verilog identifier collisions.

### Stage 3 - Verilog Emitter

Transforms the NFA structures into synthesizable Verilog HDL.

- **One-Hot Encoding:** State registers use one-hot encoding for high-speed, shallow combinational logic.
- **Top-Level Wrapper:** `top_fpga.v` orchestrates the NFA modules in parallel.
- **PII Embellishments:** When compiled with the `--pii` flag, the emitter automatically generates a 128-byte latency buffer utilizing BRAM to support look-behind redaction of matched sequences.

# Stage 1 — C++ Regex Parser

This stage is responsible for transforming a raw regular expression string into an Abstract Syntax Tree (AST) that can be processed by the NFA construction stage.

---

## 1. Lexer Details

### Overview

The lexer is the first component. Its primary responsibility is to read a raw regular expression string character-by-character and transform it into a sequence of typed tokens. This abstraction simplifies the downstream parsing process by handling character-level concerns like literal character validation and metacharacter identification.

### Token Types

The lexer identifies the following token types:

| Token Type     | Representation               | Description                                         |
| -------------- | ---------------------------- | --------------------------------------------------- |
| `LITERAL`      | Any printable ASCII (32–126) | Represents a literal character match.               |
| `DOT`          | `.`                          | Matches any single character.                       |
| `STAR`         | `*`                          | Kleene star: zero or more repetitions.              |
| `PLUS`         | `+`                          | One or more repetitions.                            |
| `QUESTION`     | `?`                          | Optional: zero or one occurrence.                   |
| `PIPE`         | `\|`                         | Union / Alternation operator.                       |
| `LPAREN`       | `(`                          | Start of a subexpression group.                     |
| `RPAREN`       | `)`                          | End of a subexpression group.                       |
| `END_OF_INPUT` | `\0`                         | Sentinel token marking the end of the regex string. |

### Input Processing Rules

1. **Character Filtering:** Only printable ASCII characters (codes 32–126) are allowed. Non-printable characters are reported by their numeric code in error messages.
2. **Coordinate Tracking:** Each token records its `line` and `column` number for precise error reporting.
3. **Implicit Concatenation:** The lexer treats characters as discrete units. The parser handles the logic of implicit concatenation.
4. **Metacharacter Recognition:** Characters like `*`, `+`, `?`, `|`, `(`, `)`, and `.` are immediately recognised as their respective operator tokens.

---

## 2. Parser Details

### Overview

The parser consumes the token stream produced by the lexer and constructs an Abstract Syntax Tree (AST). It uses a **recursive descent** approach and strictly enforces operator precedence.

### Grammar and Precedence

The parser implements the following grammar (highest to lowest precedence):

1. **Atom:** The basic building blocks (Literal, Dot, or a Parenthesised Expression).
2. **Factor:** An Atom optionally followed by a quantifier (`*`, `+`, or `?`).
3. **Term:** One or more concatenated Factors.
4. **Expression:** One or more Terms separated by the union operator (`|`).

### AST Node Structure

The parser produces a tree composed of various node types (Literal, Dot, Concatenation, Union, Star, Plus, Optional).

**Important Design Note:** While the base `ASTNode` class contains fields for `nullable`, `firstpos`, and `lastpos`, these are **not** populated by the parser. They are reserved for and populated by the **Stage 2 — NFA Builder**.

### Error Handling

The parser detects and reports the following errors with meaningful messages including line and column numbers:

- **Unmatched Parentheses:** e.g., `(a|b`.
- **Quantifier applied to nothing:** e.g., `*abc` or `(+a)`.
- **Empty alternation branch:** Both left-side (e.g., `|abc`) and right-side (e.g., `abc|`) are explicitly detected.
- **Unexpected Tokens:** Tokens that don't fit the expected grammar at the current position.

---

## Stage 2 — NFA Construction

This stage converts the Abstract Syntax Tree (AST) into an ε-free Non-deterministic Finite Automaton (NFA) using Glushkov's algorithm.

---

### 1. Glushkov's Algorithm

The algorithm produces an NFA with exactly $n+1$ states, where $n$ is the number of symbol occurrences (literals or dots) in the regex.

#### Construction Steps:

1. **Linearization:** Each symbol is assigned a unique integer position (1 to $n$).
2. **Nullable:** Computes if a sub-expression can match the empty string.
3. **Firstpos:** The set of positions that can match the first character of a string.
4. **Lastpos:** The set of positions that can match the last character of a string.
5. **Followpos:** A map where for each position $p$, it stores the set of positions that can immediately follow it.
6. **Transitions:**
   - State 0 is the start state.
   - Transitions from state 0 go to all positions in `firstpos` of the root.
   - Transitions from state $p$ go to all positions in `followpos(p)`.

### 2. Global State Numbering

To facilitate Stage 3 (Verilog Emitter), every NFA state across all input regular expressions is assigned a **globally unique ID**. This ensures that multiple FSM modules can be instantiated in a single Verilog project without identifier collisions.

### 3. Dot Operator Handling

The dot (`.`) matches any character. In the NFA, a dot position generates 256 individual transition arcs for every possible byte value (0–255). This ensures the hardware matcher correctly identifies any character in that position.

---

## Validation and Simulation

To ensure the integrity of the regex-to-NFA conversion before hardware generation, the builder includes an optional simulation engine.

### 1. NFA Simulation

The `NFA::simulate` method implements a software-based FSM runner:

- It tracks the set of active states simultaneously (handling non-determinism).
- It consumes the input string character-by-character.
- It returns `true` if any final active state is an acceptance state.

## Stage 3 — Verilog Emitter

This stage transforms the internal NFA structures into synthesisable Verilog HDL code.

### 1. Per-NFA Modules

For each regular expression, the emitter generates a self-contained Verilog module (`nfa_N.v`):

- **File I/O:** All file and directory operations use the C++17 `<filesystem>` library for cross-platform compatibility and improved error handling. File streams are configured to throw exceptions on failure, providing detailed system-level error messages (e.g., "Permission denied").
- **Robustness:** The emitter validates its inputs before generating code. It will skip emission if no valid NFAs are provided and will throw an error if the golden reference data does not match the number of NFAs, preventing the generation of invalid Verilog.
- **One-Hot Encoding:** The state register uses one-hot encoding (one flip-flop per NFA state). This is ideal for FPGA implementation as it results in high-speed, shallow combinational logic.
- **Optimised Next-State Logic:** Transitions are implemented as pure combinational logic. To improve generation speed, the logic is built by iterating over destination states rather than source states.
- **Deterministic Output:** Global state IDs are sorted during emission to ensure consistent and deterministic Verilog code generation.
- **Match Logic:** The `match` output is registered. The logic uses a Verilog OR-reduction (`|{...}`) for a concise and efficient way to check if any of the final accept states are active.

### 2. Top-Level Wrapper

A `top.v` module is generated to instantiate all NFA modules in parallel.

- All modules share the same clock, reset, and input character stream.
- The results are aggregated into a `match_bus` where each bit corresponds to one regular expression (Regex $k$ maps to `match_bus[k]`).

### 3. Simulation Testbench

A fully functional testbench (`tb_top.v`) is generated:

- It automatically loads test cases from `test_strings.txt`.
- It integrates **Golden Reference** matches generated via `std::regex`.
- For each test string, it drives the `start`, `char_in`, and `end_of_str` signals with correct, deterministic timing. The testbench samples the registered `match` output on the exact clock cycle it becomes valid (the cycle immediately following the assertion of `end_of_str`), explicitly avoiding race conditions and double-sampling bugs.
- It reports `PASS` or `FAIL` for each test case directly in the simulation console and generates a `dump.vcd` for waveform analysis.

---

## Stage 4 — FPGA Integration (Hardware I/O)

This stage connects the Verilog regex engine to the physical FPGA I/O: a USB-UART serial link for bidirectional communication with a host PC. Three new hardware modules are added.

### 4.1 UART Transmitter (`uart_tx.v`)

A standard 8-N-1 UART transmitter with a 4-state FSM:

| State         | Action                                            |
| ------------- | ------------------------------------------------- |
| `S_IDLE`      | Line held high; waits for `tx_start` pulse        |
| `S_START_BIT` | Drives line low for exactly `CLKS_PER_BIT` cycles |
| `S_DATA_BITS` | Clocks out 8 data bits, LSB first                 |
| `S_STOP_BIT`  | Drives line high for `CLKS_PER_BIT` cycles        |

The `tx_busy` output is held high for the entire duration of a transmission. The caller (the TX serializer in `top_fpga.v`) must not assert `tx_start` while `tx_busy` is high.

Default baud rate: 115200 at 100 MHz clock (`CLKS_PER_BIT = 868`), configurable via a Verilog parameter.

---

### 4.2 Input FIFO Buffer (`uart_rx_fifo.v`)

A 16-entry × 8-bit circular FIFO sits between `uart_rx` and the NFA control FSM. This decouples the UART receiver from the NFA pipeline so that incoming bytes are never dropped during the multi-cycle end-of-string and TX response sequence.

- **Architecture:** Power-of-two depth (configurable via `DEPTH_LOG2` parameter, default 4 → 16 entries). Inferred as distributed RAM (Xilinx SRL16/LUTRAM) on a 7-series device.
- **Write side:** Driven by `uart_rx.rx_ready`; silently discards bytes when full (overflow protection).
- **Read side:** Consumed one byte per cycle by the control FSM.
- **Status flags:** `full` and `empty` are combinationally derived from a `count` register to avoid the grey-code synchronisation complexity that arises with dual-clock designs (this FIFO is single-clock).

---

### 4.3 Updated `top_fpga.v` — Control FSM and TX Serializer

`top_fpga.v` replaces the previous single-byte latch (`rx_latched_data` / `rx_pending`) with the FIFO-backed architecture and adds two new FSMs.

#### Main Control FSM (12 states)

```
S_IDLE  ──► S_FETCH ──► S_DECODE ──► S_CHAR_LOAD ──► S_CHAR_STEP ──► S_IDLE
                             │
                             ├── (newline) ──► S_EOL_END ──► S_EOL_MATCH
                             │                    ──► S_EOL_LATCH ──► S_TX_ARM
                             │                    ──► S_TX_WAIT ──► S_RESET_NFA
                             │
                             └── ('?') ──► S_QUERY_TX ──► S_TX_WAIT
```

- `S_IDLE` / `S_FETCH` / `S_DECODE`: pop the FIFO and classify the byte.
- `S_CHAR_LOAD` / `S_CHAR_STEP`: feed one character into the NFA; increment `byte_count`.
- `S_EOL_END` / `S_EOL_MATCH` / `S_EOL_LATCH`: assert `end_of_str`, clock the match flip-flops, capture `match_bus`, update `match_count[k]` for every matched regex, and latch the result to `match_leds`.
- `S_TX_ARM`: call the `build_response` task to serialise the ASCII response into the TX buffer; pulse `tx_send`.
- `S_TX_WAIT`: wait for the TX drain sub-FSM to finish before resetting the NFA.
- `S_RESET_NFA`: assert `nfa_start + nfa_en` for one cycle to re-initialise all NFA FSMs.
- `S_QUERY_TX`: handle the `?` command — build a counter snapshot and transmit without feeding any character to the NFA.

#### TX Drain Sub-FSM (4 states)

A separate small FSM drains the ASCII TX buffer byte-by-byte through `uart_tx`:

```
TX_IDLE ──► TX_LOAD ──► TX_WAIT ──► TX_NEXT ──► (TX_LOAD if more bytes, else TX_IDLE)
```

This sub-FSM runs concurrently with the control FSM, which simply waits in `S_TX_WAIT` until `tx_state == TX_IDLE`.

#### Hardware Counters

| Register         | Width        | Description                                                          |
| ---------------- | ------------ | -------------------------------------------------------------------- |
| `byte_count`     | 32 bits      | Total bytes fed to the NFA engine since the last hardware reset      |
| `match_count[k]` | 16 bits each | Cumulative match events for regex _k_; up to 16 independent counters |

Both are cleared by asserting `rst_btn`. Values are transmitted as part of every response packet.

---

## Stage 5 — Processor-based Regex Engine

The processor-based engine (`processor/` directory) provides a dynamic alternative to the static Verilog FSMs. Instead of synthesising a new circuit for each regex, we use a custom Soft-Processor that executes "Regex Instructions" loaded into memory.

### 5.1 Regex CPU Architecture

The Regex CPU is a specialized processor optimized for NFA simulation:

- **Instruction Set:** Custom 32-bit instructions (CHAR, SPLIT, JMP, MATCH, ANY).
- **Instruction Memory:** 256-word × 32-bit memory (BRAM/LUTRAM inferred).
- **State Representation:** A 256-bit wide `active_candidates` register represents the set of currently active NFA states.
- **Execution Model:**
  - **Character Match Phase:** Iterates through all active states and checks for a character match.
  - **Epsilon Expansion Phase:** Iterates through active states to follow SPLIT and JMP transitions until only character-matching or terminal states remain active.
  - **Terminal Phase:** Checks if any active state is a MATCH state at the end of the input string.

### 5.2 Glushkov Assembler Toolchain

A Python-based compiler converts standard regular expressions into the processor's native machine code:

1. **`compile_regex.py`**:
   - Parses regex into an AST.
   - Computes Glushkov `first`, `last`, and `follow` sets.
   - Generates a `SPLIT` chain to allow multiple regexes to run in parallel.
   - Outputs an assembly file (`.rasm`).
2. **`asm.py`**:
   - Parses the `.rasm` file.
   - Packs instruction fields into 32-bit binary words.
   - Outputs a hex file (`imem.hex`) for FPGA memory initialization or runtime programming.

### 5.3 Instruction Format

| Field   | Bits    | Description                                      |
| ------- | ------- | ------------------------------------------------ |
| `char`  | [31:24] | ASCII character to match (or 0 for epsilon/any). |
| `next1` | [23:16] | Primary target PC for jump/split.                |
| `next2` | [15:8]  | Secondary target PC for split.                   |
| `mid`   | [7:4]   | Match ID (Regex index 0–15).                     |
| `term`  | [3]     | Terminal bit (1 if this is a MATCH state).       |
| `any`   | [0]     | Wildcard bit (1 if this matches any character).  |

### 5.4 Advantages of the Processor Approach

- **Runtime Flexibility:** Regexes can be updated by simply writing to the instruction memory over UART.
- **Resource Efficiency:** Supports up to 16 complex regexes with a fixed amount of FPGA logic, regardless of regex complexity (up to 256 instructions).
- **Deterministic Latency:** Fixed scan time of 256 cycles per character ensures predictable performance.

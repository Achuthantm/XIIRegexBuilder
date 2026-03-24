# XIIRegexBuilder: FPGA-Accelerated Regular Expression Matching Engine

Group Number: 6

## 1. System Description

Our project is a custom hardware accelerator for high-speed text processing. A C++ compiler translates regular expressions into parallel, one-hot encoded hardware Finite State Machines (FSMs) in Verilog. These FSMs are synthesised onto an FPGA to parse continuous ASCII character streams, bypassing the sequential bottleneck of software-based regex engines.

The host PC communicates with the FPGA over a standard USB-UART serial link at 115200 baud. An included Python terminal UI (`tui.py`) lets you type strings interactively and see per-regex match results, cumulative byte counts, and per-regex hit counters rendered in a colour-coded table.

## 2. Use Cases

- **FIX Protocol Parsing**: High-speed filtering of electronic trading messages (orders/fills) to route data before it reaches the software stack.
- **Market Data Feed Filtering**: Scanning millions of events per second to discard irrelevant instrument data at line-rate, saving CPU cycles.
- **Trade Surveillance**: Detecting malicious network patterns (e.g., spoofing, wash trading) continuously across live, high-speed data flows.

## 3. FPGA Relevance

- **Massive Parallelism**: An FPGA evaluates all N regex FSMs simultaneously in a single clock cycle, whereas software throughput degrades linearly as N grows.
- **Strict Determinism**: Hardware matching ensures a fixed, predictable number of clock cycles per match, eliminating OS scheduling and cache-miss latency variations.

## 4. System Architecture

```text
[Host PC]
    │  USB-UART 115200-8N1
    ▼
uart_rx  ──►  uart_rx_fifo (16-byte circular FIFO)
                   │
                   ▼
             Control FSM  ──►  top.v  (parallel NFA engine)
                   │                │
                   │           match_bus[N-1:0]
                   │           byte_count[31:0]
                   │           match_count_k[15:0]
                   ▼
             TX Serializer  ──►  uart_tx  ──►  [Host PC]
```

### Hardware Modules

| File                    | Description                                                         |
| ----------------------- | ------------------------------------------------------------------- |
| `output/uart_tx.v`      | 8-N-1 UART transmitter (parallel-in / serial-out)                   |
| `output/uart_rx_fifo.v` | 16-byte circular FIFO (distributed RAM) between RX and engine       |
| `output/top_fpga.v`     | Top-level integrating FIFO, NFA engine, counters, TX serializer FSM |

### Response Packet (FPGA → Host)

Every time the NFA engine finishes a string (newline received), the FPGA sends one ASCII line:

```text
MATCH=<N-bit binary> BYTES=<8 hex digits> HITS=<4hex per regex, comma-separated>\r\n
```

Example (6 regexes, regexes 0 and 2 matched, 71 total bytes processed):

```text
MATCH=000101 BYTES=00000047 HITS=0003,0001,0012,0000,0000,0000
```

Send `?` at any time to query the current counters without feeding any character to the NFA.

### Hardware Counters

- `byte_count [31:0]` — total bytes fed into the NFA engine since the last reset.
- `match_count_k [15:0]` — cumulative match events for regex _k_ (independent counter per regex).

## 5. System Scope

### Minimum System (Commitment)

- C++ Verilog Emitter compiling basic literal and concatenation patterns (e.g., abc).
- At least one generated Verilog FSM successfully simulated and executing correctly on the FPGA.

### Goal System — **ACHIEVED**

- Full compiler support for complex operators (`*`, `+`, `?`, `|`, `.`) via Glushkov's epsilon-free construction.
- Integration of up to 16 parallel FSM modules passing the C++ golden reference testbenches.
- UART host-side controller: host application sends arbitrary test strings and receives match bitmasks over serial in real time.
- **UART Transmitter** (`uart_tx.v`): dedicated TX module with a serializer state machine that formats and sends structured ASCII result packets.
- **Input FIFO Buffer** (`uart_rx_fifo.v`): 16-byte circular FIFO decouples the UART receiver from the NFA engine FSM, eliminating byte-drop risk.
- **Hardware Counters**: `byte_count` and per-regex `match_count` registers, queryable via UART or the Python TUI.

### Stretch Goal

- Bounded quantifiers `{m,n}`: compiler and hardware support for repetition counts.
- Live FIX message demo: stream a recorded FIX log from the host and demonstrate real-time field extraction.

## 6. Design Goals

- **Latency**: 1 clock cycle per ASCII character; match output registered on the cycle immediately following `end_of_str` assertion.
- **Throughput**: 1 byte per clock cycle continuously (100 MB/s at 100 MHz).
- **Resource usage**: Efficient one-hot state encoding (exactly N+1 flip-flops per FSM).
- **Correctness**: 100% full-match accuracy against the C++ `std::regex` golden reference.

## 7. Quick Start

### Build the C++ compiler and generate Verilog

```bash
make run   # builds regex_builder, runs it on inputs/regexes.txt
```

### Simulate in Vivado

```bash
make sim   # xvlog + xelab + xsim
```

### Synthesise and program the Nexys A7

```bash
make synth    # runs synth.tcl through Vivado batch mode
make program  # programs the attached FPGA
```

### Launch the Python TUI

```bash
pip install pyserial rich
python tui.py --port /dev/ttyUSB0 --regexes inputs/regexes.txt
# On Windows: python tui.py --port COM3 --regexes inputs/regexes.txt
```

The TUI auto-detects the first available USB-Serial port if `--port` is omitted.

## 8. File Layout

```text
XIIRegexBuilder/
├── inputs/
│   ├── regexes.txt          # one regex per line
│   └── test_strings.txt     # one test string per line
├── src/
│   ├── main.cpp             # pipeline entry point
│   ├── lexer.{h,cpp}        # tokeniser
│   ├── parser.{h,cpp}       # recursive-descent AST builder
│   ├── nfa.{h,cpp}          # Glushkov NFA construction
│   ├── emitter.{h,cpp}      # Verilog code generator
│   ├── golden.cpp           # C++ std::regex reference
│   └── parser_tester.cpp    # unit-test harness
├── output/                  # generated by `make run`
│   ├── nfa_0.v … nfa_N.v
│   ├── top.v
│   ├── uart_rx.v            # UART receiver
│   ├── uart_tx.v            # UART transmitter
│   ├── uart_rx_fifo.v       # Input FIFO
│   ├── top_fpga.v           # FPGA top-level
│   ├── tb_top.v
│   ├── constraints.xdc
│   └── expected_matches.txt
├── tui.py                   # Python TUI
├── scripts/
│   ├── synth.tcl            # Vivado synthesis script
│   └── program.tcl          # Vivado programming script
├── Makefile
├── README.md
├── Specifications.md
├── details.md
└── usecase.md
```

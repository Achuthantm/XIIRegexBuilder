# Regex → NFA → Verilog Hardware Matcher

## Project Specification

---

## 1. Project Overview

This project implements a hardware-accelerated regular expression matching pipeline. A set of regular expressions defined in plain text is automatically compiled into parallel hardware finite state machines (FSMs), expressed in Verilog, and synthesised onto an FPGA. At runtime, a stream of ASCII characters is fed into the hardware one character per clock cycle, and the system reports which regular expressions are matched by the full input string.

The pipeline consists of four major stages: regex parsing, NFA construction, Verilog code generation, and hardware simulation and synthesis.

---

## 2. Finalised Design Decisions

| Decision                      | Choice                                                              |
| ----------------------------- | ------------------------------------------------------------------- |
| Supported operators           | Kleene star, plus, optional, union, dot, parentheses, literals      |
| NFA construction algorithm    | Glushkov's construction                                             |
| Architecture                  | One independent Verilog FSM module per NFA, all running in parallel |
| ε-transition handling         | None — Glushkov's construction produces ε-free NFAs directly        |
| State encoding                | One-hot (one flip-flop per NFA state)                               |
| Character stream interface    | Synchronous; one 8-bit ASCII character per clock cycle              |
| Match semantics               | Full match only (the entire input string must satisfy the regex)    |
| Scale                         | Fewer than 20 regular expressions                                   |
| Simulation and synthesis tool | Xilinx Vivado                                                       |

---

## 3. Input Specification

### 3.1 Regex Input File

The input is a plain text file, referred to throughout as `regexes.txt`. It obeys the following rules:

- One regular expression per line.
- Lines beginning with the `#` character are treated as comments and ignored.
- Blank lines are ignored.
- Each non-comment, non-blank line is assigned a zero-based index that becomes the index of the corresponding NFA and Verilog module.

### 3.2 Supported Regex Syntax

The following constructs must be supported:

- **Literal characters** — any printable ASCII character (codes 32–126) that is not a metacharacter is matched literally.
- **Dot** (`.`) — matches any single character.
- **Kleene star** (`*`) — matches zero or more repetitions of the preceding atom.
- **Plus** (`+`) — matches one or more repetitions of the preceding atom.
- **Optional** (`?`) — matches zero or one occurrence of the preceding atom.
- **Union** (`|`) — matches either the expression on the left or the expression on the right. Union may appear both within a single regex (e.g. between subexpressions) and effectively between entire regex lines via the separate-line structure.
- **Parentheses** (`(` and `)`) — group subexpressions and control the scope of operators.

The operator precedence from highest to lowest is: `*`, `+`, `?` (postfix quantifiers) → concatenation (implicit) → `|` (union).

Anchors (`^` and `$`) are not supported. Full-match semantics are enforced by the hardware control signals rather than by the regex syntax.

### 3.3 Test String Input File

A second plain text input file provides strings to test against the regex set. Each line is one test string. The test strings are used to drive the hardware simulation testbench and to generate golden reference output.

---

## 4. Stage 1 — C++ Regex Parser

### 4.1 Lexer

The lexer reads a regex string character by character and produces a flat sequence of typed tokens. The token types are: literal character, dot, star, plus, question mark, pipe (union), left parenthesis, and right parenthesis.

### 4.2 Parser

The parser consumes the token stream produced by the lexer and constructs an Abstract Syntax Tree (AST). The parser uses recursive descent and enforces the correct operator precedence. The grammar it implements, informally stated, is:

- An expression is one or more concatenated terms separated by `|`.
- A term is one or more concatenated factors.
- A factor is an atom optionally followed by one quantifier (`*`, `+`, or `?`).
- An atom is either a literal, a dot, or a parenthesised expression.

Each AST node is one of the following types: Literal, Dot, Concatenation, Union, Star, Plus, Optional.

### 4.3 Error Handling

The parser must detect and report, with a meaningful message and line number:

- Unmatched parentheses.
- A quantifier applied to nothing (e.g. a leading `*`).
- An empty alternation branch (e.g. `a|`).
- Any character outside the printable ASCII range.

---

## 5. Stage 2 — C++ NFA Construction (Glushkov's Construction)

### 5.1 Overview

Glushkov's construction is applied to each AST to produce an ε-free NFA. Unlike Thompson's construction, Glushkov's algorithm never introduces ε-transitions. Instead, it works by analysing the positions of symbol occurrences within the regex and computing which positions can follow which others during a match. The resulting NFA has exactly one state per symbol occurrence in the regex, plus one distinguished initial state, and all transitions are labelled with concrete characters.

This ε-free property means the Verilog emitter requires no combinational ε-closure layer — the next-state logic is entirely registered, which simplifies synthesis and removes combinational depth as a timing concern.

### 5.2 Step 1 — Linearisation

Each symbol occurrence in the regex (every literal character and every dot) is assigned a unique integer position label, numbered from 1 upwards, in left-to-right order of appearance. Position 0 is reserved for the special initial state and does not correspond to any symbol. Two occurrences of the same character are treated as distinct positions.

For example, the regex `ab*a` is linearised as `a₁ b₂* a₃`, yielding positions 1, 2, and 3.

### 5.3 Step 2 — Computing Nullable

For each node in the AST, a Boolean property `nullable` is computed, indicating whether the sub-expression rooted at that node can match the empty string. The rules are:

- A Literal or Dot node is never nullable.
- A Star or Optional node is always nullable.
- A Plus node is nullable if and only if its inner sub-expression is nullable.
- A Union node is nullable if either branch is nullable.
- A Concatenation node is nullable if and only if both sub-expressions are nullable.

### 5.4 Step 3 — Computing Firstpos

For each AST node, `firstpos` is the set of positions that can match the first character of any string accepted by that sub-expression. The rules are:

- A Literal or Dot node at position p has `firstpos = {p}`.
- A Star, Plus, or Optional node has the same `firstpos` as its inner sub-expression.
- A Union node has `firstpos` equal to the union of the `firstpos` sets of both branches.
- A Concatenation node of left and right sub-expressions has `firstpos` equal to the `firstpos` of the left sub-expression, plus the `firstpos` of the right sub-expression if the left sub-expression is nullable.

### 5.5 Step 4 — Computing Lastpos

For each AST node, `lastpos` is the set of positions that can match the last character of any string accepted by that sub-expression. The rules are:

- A Literal or Dot node at position p has `lastpos = {p}`.
- A Star, Plus, or Optional node has the same `lastpos` as its inner sub-expression.
- A Union node has `lastpos` equal to the union of the `lastpos` sets of both branches.
- A Concatenation node of left and right sub-expressions has `lastpos` equal to the `lastpos` of the right sub-expression, plus the `lastpos` of the left sub-expression if the right sub-expression is nullable.

### 5.6 Step 5 — Computing Followpos

For each position p, `followpos(p)` is the set of positions that can immediately follow position p in any match. This set is built by traversing the AST and applying two rules:

- **Concatenation rule:** for every position p in `lastpos` of the left sub-expression of a Concatenation node, add all positions in `firstpos` of the right sub-expression to `followpos(p)`.
- **Star and Plus rule:** for every position p in `lastpos` of the inner sub-expression of a Star or Plus node, add all positions in `firstpos` of that same inner sub-expression to `followpos(p)`.

All other node types (Union, Optional, Literal, Dot) do not contribute to `followpos` directly.

### 5.7 Step 6 — Building the NFA

With the position functions computed, the NFA is assembled as follows:

- **States:** one state for each position 1 through n (where n is the total number of symbol occurrences), plus state 0 as the initial state.
- **Start state:** state 0.
- **Accept states:** all positions in `lastpos` of the root AST node. Additionally, state 0 is an accept state if the root node is nullable (i.e. the regex matches the empty string).
- **Transitions from state 0:** for each position p in `firstpos` of the root node, add a transition from state 0 on the symbol at position p to state p.
- **Transitions from state p (p > 0):** for each position q in `followpos(p)`, add a transition from state p on the symbol at position q to state q.

Because dot (`.`) matches any character, transitions labelled with a dot position are expanded to one transition arc per possible input character (all 256 byte values).

### 5.8 NFA Representation

Each NFA is described by a set of numbered states. Each state carries: a unique integer identifier, a Boolean flag indicating whether it is an accept state, and a map from input characters to sets of destination states. There are no ε-transitions. The total number of states for a given regex is exactly equal to the number of symbol occurrences plus one.

### 5.9 Global State Numbering

All NFA states across all N NFAs share a single global numbering space. This avoids identifier collisions when multiple NFAs are emitted into a single Vivado project.

---

## 6. Stage 3 — C++ Verilog Emitter

### 6.1 Overview

The emitter walks each NFA and produces a self-contained Verilog module. It also produces a top-level wrapper module and a simulation testbench. All output files are written to the `output/` directory.

Because Glushkov's construction produces ε-free NFAs, the emitter requires no combinational ε-closure logic. Every transition is labelled with a concrete character, and the next-state logic is a straightforward combinational decode of `char_in` gated by the currently active states. This results in clean, purely registered FSMs with no combinational feedback paths.

### 6.2 Per-NFA Module Interface

Each NFA produces one Verilog module. The module's ports are:

- `clk` — clock input.
- `rst` — synchronous active-high reset.
- `start` — a one-cycle pulse that initialises the FSM to its start state, beginning a new match attempt.
- `end_of_str` — a one-cycle pulse asserted one cycle after the final character of the input string.
- `char_in` — an 8-bit input carrying the current ASCII character.
- `match` — a registered output that is asserted for one cycle when the FSM is in an accept state at the moment `end_of_str` is asserted.

### 6.3 One-Hot State Encoding

The state register inside each module is one-hot: there is one flip-flop per NFA state. A bit being set means that NFA state is currently active. Because the NFA is non-deterministic, multiple bits may be set simultaneously, faithfully representing the parallel set of active NFA states.

On reset or on the `start` pulse, the state register is cleared and only the bit corresponding to state 0 (the initial state) is set.

### 6.4 Next-State Logic

The next-state logic is purely combinational and free of any ε-closure computation. For each state j, its next-state bit is asserted if any currently active state i has a transition to j on the current value of `char_in`. The resulting next-state vector is registered on the rising clock edge.

### 6.5 Match Output Logic

The `match` output is registered. It is asserted on the cycle following the cycle on which `end_of_str` is asserted, provided that at least one accept-state bit is active in the state register at the time `end_of_str` is seen. This ensures correct matching for both non-empty and empty strings (if the regex is nullable).

### 6.6 Top-Level Wrapper Module

A single top-level Verilog module instantiates all N NFA modules. All instances share the same `clk`, `rst`, `start`, `end_of_str`, and `char_in` signals. Each instance drives one bit of an N-bit `match` output bus, where bit k corresponds to NFA k.

### 6.7 Emitter Output Files

| File                   | Contents                                        |
| ---------------------- | ----------------------------------------------- |
| `nfa_0.v` … `nfa_N.v`  | One self-contained FSM module per regex         |
| `top.v`                | Top-level wrapper instantiating all NFA modules |
| `tb_top.v`             | Simulation testbench                            |
| `expected_matches.txt` | Golden reference output for validation          |

---

## 7. Stage 4 — Simulation Testbench

### 7.1 Structure

The testbench instantiates `top` and drives all its inputs. It operates as follows for each test string:

1. Assert `rst` for a fixed number of cycles to initialise all FSMs.
2. Assert `start` for one cycle.
3. Drive `char_in` with successive characters of the test string, one per clock cycle.
4. On the cycle following the last character, assert `end_of_str` for one cycle.
5. Sample `match` on the following cycle and compare it against the expected bitmask from the golden reference.
6. Print a PASS or FAIL message for each test case, including the test string and the observed versus expected match bitmasks.

### 7.2 Waveform Dump

The testbench dumps all signals to a VCD file for inspection in Vivado's waveform viewer.

### 7.3 Timing Assumptions

- The clock period is fixed at 10 ns.
- `char_in` is stable before the rising clock edge.
- All control signals (`start`, `end_of_str`) are synchronous and held for exactly one cycle.

---

## 8. Stage 5 — Golden Reference

A separate C++ program reads `regexes.txt` and `test_strings.txt`, runs each test string against each regex using the C++ standard library's full-match mode, and writes `expected_matches.txt`. Each line of the output corresponds to one test string and contains a bitmask (or equivalent structured text) indicating which regexes matched.

This output is consumed by the testbench generator and used during simulation to validate the Verilog results.

---

## 9. Build System and Project Structure

### 9.1 Directory Layout

```
project/
├── regexes.txt
├── test_strings.txt
│
├── src/
│   ├── main.cpp
│   ├── lexer.h / lexer.cpp
│   ├── parser.h / parser.cpp
│   ├── nfa.h / nfa.cpp
│   └── emitter.h / emitter.cpp
│
├── golden/
│   └── golden.cpp
│
└── output/
    ├── nfa_0.v … nfa_N.v
    ├── top.v
    ├── tb_top.v
    └── expected_matches.txt
```

### 9.2 Build and Run Order

The pipeline is executed in the following sequence:

1. Compile and run the C++ frontend on `regexes.txt` to produce all Verilog files and `expected_matches.txt`.
2. Compile and run the golden reference binary on `regexes.txt` and `test_strings.txt` to produce or verify `expected_matches.txt`.
3. Import all Verilog files into a Xilinx Vivado project.
4. Run behavioural simulation; confirm all test cases report PASS.
5. Run synthesis and implementation targeting the chosen FPGA part.
6. Review timing and resource utilisation reports.

---

## 10. Validation Strategy

### 10.1 Unit Testing the C++ Frontend

Each C++ component is tested independently before integration:

- The lexer is verified against a set of regex strings by inspecting the token stream it produces.
- The parser is verified by comparing its AST output against hand-drawn trees for representative regexes.
- The NFA builder is verified by checking, for representative regexes, that the linearisation is correct, that the firstpos, lastpos, and followpos sets match hand-computed values, and that the resulting state and transition counts equal the number of symbol occurrences plus one.
- The emitter is verified by compiling its output in Vivado and confirming the modules are syntax-valid.

### 10.2 Simulation Validation

Every test case in the testbench must produce a match bitmask identical to the golden reference output. Any discrepancy is a bug in the NFA construction logic or the emitter.

### 10.3 Synthesis Validation

After synthesis and implementation, the following are checked:

- No combinational loops reported by Vivado (expected to be clean given the ε-free NFA structure).
- Timing closure achieved at the target clock frequency (10 ns period).
- One-hot encoding inferred correctly for all state registers (confirmed via synthesis log).
- Resource utilisation (LUT and FF count) scales reasonably with the number of symbol occurrences in the regex set.

---

## 11. Known Design Constraints and Risks

### 11.1 One-Hot State Register Size

One-hot encoding allocates one flip-flop per NFA state. Glushkov's construction produces exactly one state per symbol occurrence plus one initial state — generally fewer states than Thompson's construction for the same regex. With fewer than 20 regexes and relatively simple patterns this is not expected to be problematic, but unusually long or repetitive regexes should be monitored for excessive flip-flop usage.

### 11.2 Dot Operator Fan-Out

The dot operator (`.`) matches any of the 256 possible byte values. Each dot position in the NFA produces transition arcs to its followpos targets for all 256 input characters. Heavy use of dot in patterns will increase LUT usage in the next-state logic accordingly.

### 11.3 Full Match Only

The system performs full-match checking only. Substring search is not supported. Any future extension to substring matching would require changes to how the `start` signal is managed, specifically recycling the FSM from state 0 on every input character.

### 11.4 Shared Symbol Positions Across Regexes

Because all N NFAs share a global state numbering space, the emitter must ensure that position labels assigned during linearisation of one regex do not collide with those of another. This is managed by maintaining a running position counter across all regexes during the construction phase.

---

## 12. Out of Scope

The following are explicitly not part of this project:

- Character classes (`[a-z]`, `[^abc]`, etc.)
- Anchors (`^` and `$`)
- Backreferences or capture groups
- Unicode support (ASCII only)
- Intersection of regular languages
- Substring or multi-match modes
- AXI-Stream or other bus-protocol interfaces
- Formal verification
- A graphical front-end or interactive tooling

---

## 13. Stage 5 — FPGA I/O Integration

### 13.1 UART Transmitter (`uart_tx.v`)

| Property   | Value                                                                                         |
| ---------- | --------------------------------------------------------------------------------------------- |
| Framing    | 8-N-1                                                                                         |

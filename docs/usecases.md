# Why Hardware Regex Matching Matters

## The Core Problem

Modern financial markets generate enormous volumes of structured text — orders, quotes, news, and trade confirmations — all arriving as high-speed character streams. Firms need to filter, detect, and act on specific patterns within this data faster than any software stack can manage. Hardware regex matching on an FPGA puts that decision as close to the wire as physically possible.

---

## Key Use Cases in Quantitative Finance

**FIX Protocol Parsing.** Every order, cancel, and fill in electronic trading is an ASCII FIX message. Filtering and validating millions of these per second in hardware means routing decisions are made before the message reaches software — shaving off critical microseconds.

**Market Data Feed Filtering.** Exchanges blast full order book updates at millions of events per second. Running regex matches in hardware lets firms discard irrelevant instruments at line rate, so the CPU only processes what the strategy actually needs.

**Tick Data Pattern Detection.** Price movement sequences — bid size spikes, spread collapses, momentum signals — can be encoded as regex patterns over a tokenised tick stream. Hardware detection latency is measured in nanoseconds, not microseconds.

**News and Sentiment Feeds.** Scanning incoming Reuters or Bloomberg text for company names, earnings figures, or central bank language is a multi-regex problem. An FPGA can flag a relevant news item before the full message has even arrived.

**Trade Surveillance and Compliance.** Patterns like spoofing, layering, and wash trading are detectable as sequences in live order flow. Hardware matching enables real-time compliance checks on the live feed rather than retrospective analysis on stored logs.

**Dynamic Strategy Adjustment.** Financial conditions shift in milliseconds. The **Soft-Processor engine** allows traders to update their regex filtering rules on-the-fly without needing to take the system offline for a slow hardware re-synthesis. This combination of hardware speed and software flexibility is a unique advantage of our dual-architecture approach.

---

## Why FPGA and Not Just Faster Software?

The fundamental advantage is parallelism. A software engine checks N regexes sequentially — throughput degrades linearly as N grows. An FPGA runs all N FSMs in the same clock cycle, so throughput is flat regardless of how many patterns are active. At scale, no amount of SIMD optimisation closes that gap.

The second advantage is determinism. Software latency varies with cache state, OS scheduling, and branching behaviour. Hardware latency is a fixed number of clock cycles, every time — essential when a one-microsecond edge translates directly into profit.

---

## The Bottom Line

In quantitative finance, the matching decision needs to happen before any further processing, on a continuous high-speed stream, against many patterns simultaneously, with the lowest and most predictable latency possible. That is precisely the problem this system is designed to solve.

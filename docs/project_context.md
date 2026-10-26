# AXI4 Slave UVM Verification

A full AXI4 slave with a UVM 1.2 verification environment, simulated on Xilinx Vivado 2026.1 (xsim). The environment contains a driver, monitor, reference-model scoreboard, constrained-random sequences, functional coverage and an SVA protocol checker, and was validated by deliberately injecting bugs into the DUT.

## Summary of results

| Item | Result |
|---|---|
| Tests | `axi4_directed_test`, `axi4_rand_test`, `axi4_cross_test` |
| Clean DUT | 0 scoreboard mismatches, 0 monitor errors, 0 SVA failures on all tests |
| Functional coverage | 100% on both random tests |
| SVA | 42 assertions, 8 covers |
| Bug injection | 10 injected DUT bugs, all caught by both random tests |

Details of the bug-injection study are in `m6_closure_report.md`.

## DUT

`rtl/axi4_slave_mem.sv` is a byte-addressable AXI4 slave with a 4096-byte memory.

- All five channels (AW, W, B, AR, R), parameterised address, data and ID widths.
- FIXED, INCR and WRAP bursts; narrow and unaligned transfers; WSTRB partial writes.
- SLVERR for any beat at or above the memory size; out-of-range write beats are skipped and out-of-range reads return 0.
- Independent write FSM (`W_IDLE`, `W_DATA`, `W_RESP`) and read FSM (`R_IDLE`, `R_DATA`).
- Scope: single outstanding transaction, no READY backpressure, WRAP lengths of 2, 4, 8 or 16 beats only. Design notes are in `axi4_dut_design_notes.md`.

`rtl/axi4_if.sv` provides the interface with modports, a driver clocking block (`cb`) and an input-only monitor clocking block (`mcb`) to avoid testbench/DUT races. It also carries two testbench-only variables, `sva_errors` and `allow_4k_cross`.

## Verification environment

| Component | File | Role |
|---|---|---|
| Transaction | `uvm/agent/axi4_transaction.sv` | One class for reads and writes; constraints, closed-form `beat_addr(n)` and `lane_mask(n)`, `do_compare` |
| Driver | `uvm/agent/axi4_driver.sv` | Drives AW/W/B and AR/R through `cb`, waits for reset release |
| Monitor | `uvm/agent/axi4_monitor.sv` | Passive; rebuilds transactions from the bus, checks WLAST/RLAST, publishes on an analysis port |
| Agent, sequencer | `uvm/agent/` | Active/passive agent |
| Scoreboard | `uvm/env/axi4_scoreboard.sv` | Sparse reference memory and independent address/strobe math; compares response and data on active lanes |
| Coverage | `uvm/env/axi4_coverage.sv` | Covergroup in a subscriber: burst, size, length, response, region, alignment, strobe kinds, 4096 edge, crosses |
| SVA checker | `sva/axi4_protocol_checker.sv` | Protocol assertions and covers on the interface |
| Sequences | `uvm/seq/` | Directed, write-read, and constrained-random with mixed-shape read-back |
| Tests | `uvm/test/` | Base, directed, random, cross-boundary |

### Scoreboard rules

- A beat is out of range if its address is at or above 4096.
- Out-of-range write beats are not stored; out-of-range reads return 0.
- The response is SLVERR if any beat of the burst is out of range; a read response is the OR of its beats.

### Stimulus

- Per iteration: one write (sometimes two back to back), a read of the same shape, and half the time a read of a different shape at a previously written word.
- Burst mix about 50/20/30 INCR/FIXED/WRAP; sizes 1, 2 and 4 bytes; about 15% of addresses out of range; address 4096 is picked exactly 8% of the time.
- `axi4_cross_test` also sends bursts that cross the end of memory (`allow_4k_cross`).
- xsim does not honour `dist` weights in these constraints, so the mix is chosen in code (sequence and `post_randomize`). See `m4_notes.md`.

### SVA checker

- Reset behaviour and X checks; VALID and payload stability on all five channels; burst legality (WRAP length and alignment, FIXED length, 4 KB crossing unless allowed); WLAST/RLAST alignment; ordering; BID/RID match; legal responses; single outstanding transaction; bounded response latency.
- Failures increment `sva_errors`; the base test reports a UVM error in `check_phase` if it is non-zero.
- Cover counters are plain `always` blocks because xsim does not run the action statements of `cover property`.
- Not checked: strobes inside active lanes, write data before address, multiple outstanding transactions. The handshake-stability checks cannot fail until backpressure is added. See `m5_sva_notes.md`.

## Verification results

| Test | Coverage | Transactions | Mismatches | SVA failures |
|---|---|---|---|---|
| `axi4_directed_test` | n/a | 22 | 0 | 0 |
| `axi4_rand_test` | 100% | 548 | 0 | 0 |
| `axi4_cross_test` | 100% | 548 | 0 | 0 |

The cross test sends 38 reads and 36 writes across the end of memory.

## Bug injection

`rtl/axi4_slave_mem.sv` reads a compile-time define `BUG_ID` (0 or unset is the clean DUT). Each of ten single-point mutations is selected by one value:

| ID | Mutation | Caught by |
|---|---|---|
| 1 | WSTRB ignored on write | scoreboard |
| 2 | WRAP steps like INCR | scoreboard |
| 3 | FIXED steps like INCR | scoreboard |
| 4 | Out-of-range write returns OKAY | scoreboard |
| 5 | Out-of-range read returns OKAY | scoreboard |
| 6 | BID always 0 | SVA only |
| 7 | Write range check `>` instead of `>=` | scoreboard |
| 8 | Last write beat not stored | scoreboard |
| 9 | INCR step ignores transfer size | scoreboard |
| 10 | BVALID not reset | SVA only |

Two findings came out of the regression. Bug 7 exposed a stimulus hole: no random transaction started exactly at address 4096, which was closed with a coverpoint, a cross and a targeted address pick. The first version of bug 9 turned out to be an equivalent mutant with no observable effect and was replaced.

## Repository layout

```
axi4_verification/
├── rtl/        axi4_if.sv, axi4_slave_mem.sv
├── sva/        axi4_protocol_checker.sv
├── tb/         tb_axi4_slave_mem_sanity.sv (directed, non-UVM), tb_axi4_uvm_top.sv (UVM top)
├── uvm/
│   ├── axi4_pkg.sv
│   ├── agent/  transaction, sequencer, driver, monitor, agent
│   ├── env/    env, scoreboard, coverage
│   ├── seq/    write_read_seq, directed_seq, rand_seq
│   └── test/   base, directed, rand, cross tests
├── scripts/    run_bug.sh, run_regression.sh
└── docs/       this file, DUT notes, per-milestone notes, closure report
```

## Running

### Vivado GUI

1. Add `rtl/`, `sva/`, `tb/` and `uvm/` files to the simulation sources.
2. Add `uvm/agent`, `uvm/env`, `uvm/seq` and `uvm/test` as Include Directories (the package includes class files by bare filename).
3. Set `tb_axi4_uvm_top` as the simulation top and `xsim.simulate.runtime` to `-all`.
4. Select a test with `-testplusarg UVM_TESTNAME=axi4_rand_test` in `xsim.simulate.xsim.more_options`. Without it the directed test runs. Optional: `-sv_seed N`, `-testplusarg UVM_VERBOSITY=UVM_HIGH`.
5. To inject a bug, add the Verilog define `BUG_ID=n`.

### Command line

With Vivado's `settings64.sh` sourced, from the repository root:

```
scripts/run_bug.sh <bug_id> <test_name>     one bug, one test
scripts/run_regression.sh                   all bugs and tests; table in build/regression.txt
```

Expected on the clean DUT: `SB_SUMMARY ... 0 mismatches`, `UVM_ERROR : 0` and `[SVA] summary: 0 failure(s)`.

## Development history

| Milestone | Content | Notes |
|---|---|---|
| M1 | DUT and directed non-UVM test | A race between testbench and DUT on a plain clock edge was fixed with a clocking block |
| M2 | UVM skeleton: transaction, driver, monitor, agent, env, directed sequence | Every class file needs its own UVM include and import because Vivado compiles files individually |
| M3 | Scoreboard and reference model | Found and fixed a one-cycle-late read data/RLAST bug in the DUT; negative control with the old DUT was caught by scoreboard and monitor |
| M4 | Constrained-random sequences and functional coverage | Closed holes in write-to-write transitions and partial-strobe definition; found that xsim ignores `dist` weights |
| M5 | SVA protocol checker | Negative control fired `a_ar_single` and related assertions; found that xsim does not run `cover property` actions |
| M6 | Bug injection and closure report | 10 of 10 bugs caught; closed the 4096-edge stimulus gap |

## Possible extensions

- READY/VALID backpressure in the driver, which would make the handshake-stability assertions meaningful.
- Multiple outstanding transactions and ID handling in the DUT, scoreboard and checker.
- A negative test for illegal WRAP lengths, which the DUT deliberately does not defend against.

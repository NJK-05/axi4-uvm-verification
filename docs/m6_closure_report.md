# Verification closure report

AXI4 slave (32-bit data, 4 KB memory, single outstanding transaction) verified with a UVM 1.2 environment on Vivado xsim.

## Environment

| Component | Role |
|---|---|
| Driver, monitor, sequencer, agent | Drive and observe all five AXI4 channels through clocking blocks |
| Scoreboard with reference model | Independent closed-form address and strobe model; checks every transaction's response and data |
| Functional coverage | Burst type, size, length, response, region, alignment, strobe kinds, 4096 edge, and crosses |
| Constrained-random sequences | Weighted mix of burst types, lengths, sizes and address regions, plus mixed-shape read-back |
| SVA protocol checker | 42 assertions and 8 covers on the interface (reset, X checks, handshake stability, burst legality, LAST alignment, ordering, response codes, bounded latency) |

## Tests

| Test | Purpose |
|---|---|
| `axi4_directed_test` | 22 hand-written transactions covering each burst type, narrow, partial strobe and out-of-range |
| `axi4_rand_test` | Constrained-random, bursts stay inside memory unless out of range from the start |
| `axi4_cross_test` | Constrained-random with bursts that cross the end of memory |

## Results on the clean DUT

All three tests: 0 scoreboard mismatches, 0 monitor errors, 0 SVA failures.

| Metric | `axi4_rand_test` | `axi4_cross_test` |
|---|---|---|
| Functional coverage | 100.00% | 100.00% |
| Transactions | 548 | 548 |
| Burst x length hits | all legal bins hit | all legal bins hit |
| Size mix (1B / 2B / 4B) | 139 / 119 / 290 | 139 / 119 / 290 |
| Region (low / mid / near end / out of range) | 118 / 307 / 2 / 121 | 37 / 93 / 321 / 97 |
| Bursts crossing the end of memory (reads / writes) | 0 / 0 | 38 / 36 |

## Bug injection

Ten single-point mutations of the DUT were applied one at a time (`BUG_ID` define). A bug counts as caught when the scoreboard, the monitor or the SVA checker reports at least one failure.

| ID | Mutation | Directed | Random | Cross | First detector |
|---|---|---|---|---|---|
| 1 | WSTRB ignored on write | caught | caught | caught | scoreboard |
| 2 | WRAP steps like INCR | caught | caught | caught | scoreboard |
| 3 | FIXED steps like INCR | caught | caught | caught | scoreboard |
| 4 | Out-of-range write returns OKAY | caught | caught | caught | scoreboard |
| 5 | Out-of-range read returns OKAY | caught | caught | caught | scoreboard |
| 6 | BID always 0 | missed | caught | caught | SVA only |
| 7 | Range check off by one at 4096 | missed | caught | caught | scoreboard |
| 8 | Last write beat not stored | caught | caught | caught | scoreboard |
| 9 | INCR step ignores transfer size | missed | caught | caught | scoreboard |
| 10 | BVALID not reset | caught | caught | caught | SVA only |

All ten bugs are caught by both random tests. Bugs 6 and 10 are invisible to the scoreboard and are caught only by the assertions, which is the reason the checker exists.

## Findings from the regression

1. **Stimulus hole at address 4096.** Bug 7 was missed by `axi4_rand_test` in the first regression and caught by one mismatch in `axi4_cross_test`. No random transaction started exactly at address 4096. A coverpoint (`cp_edge`, `cx_dir_edge`) and a targeted address pick were added; bug 7 is now caught by both random tests (6 mismatches each).
2. **Equivalent mutant.** The first version of bug 9 (INCR stepping from the unaligned address) was caught by nothing. Analysis showed it cannot change any observable behaviour, because the DUT uses only the word address and the offset never leaves the word or crosses 4096. It was replaced by a mutation with a visible effect.
3. **Directed test limits.** The directed test misses bugs 6, 7 and 9: it uses ID 0 only, has no write starting at 4096 and has no multi-beat narrow INCR burst. These are the cases the random tests exist for.

## Scope and limits

- Single outstanding transaction, no backpressure on READY, no exclusive access, no DECERR. The handshake-stability assertions cannot fail until backpressure is added.
- The 10 bugs are hand-chosen single-point mutations, not an exhaustive mutation set.
- xsim does not honour `dist` weights in these constraints; the traffic mix is chosen in code, documented in `m4_notes.md`.
- The `near_end` region has only 2 hits in `axi4_rand_test`; `axi4_cross_test` covers it heavily (321).
- Coverage is 100% of the defined model. It shows the model was exercised, not that the model is complete.

## Reproducing

```
scripts/run_regression.sh
```

writes the bug table to `build/regression.txt`. Each run is `scripts/run_bug.sh <bug_id> <test>`.

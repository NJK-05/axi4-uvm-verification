# AXI4 Slave Memory DUT — Design Notes

## Scope decision: full AXI4, not AXI4-Lite

Chose a full AXI4 slave (burst support, ID field, WSTRB) rather than AXI4-Lite.
Lite only has single-beat transfers with no burst/ID logic, which gives a UVM
environment much less to actually verify — no burst boundary checks, no
out-of-order ID tracking, no WRAP address math. Full AXI4 gives the
verification environment real teeth: burst types, narrow/partial writes via
WSTRB, and protocol-violation scenarios worth building negative-control tests
around later.

## DUT: `axi4_slave_mem`

- 5 independent AXI4 channels (AW, W, B, AR, R), parameterized `ADDR_WIDTH`,
  `DATA_WIDTH`, `ID_WIDTH`.
- Byte-addressable memory array (`MEM_DEPTH_BYTES`, default 4KB) so `WSTRB`
  byte-lane writes are real, not just decorative.
- Burst types implemented: `FIXED`, `INCR`, `WRAP` (address math in
  `next_addr()`).
- Out-of-range access (`addr >= MEM_DEPTH_BYTES`) returns `SLVERR` on the
  B or R channel instead of silently wrapping or corrupting memory.
- Separate write FSM (`W_IDLE/W_DATA/W_RESP`) and read FSM (`R_IDLE/R_DATA`)
  so reads and writes can be in flight independently, matching real AXI4
  slave behavior.

## Documented simplifications (first pass — intentional, not oversights)

- **Single outstanding transaction per channel.** The DUT accepts one AW/W
  sequence and one AR sequence at a time; it does not yet accept a second
  AWID before the first completes. Real AXI4 slaves can have multiple
  outstanding IDs completing out of order — that's a meaty verification
  target in its own right, so it's deferred to a later milestone rather than
  built in now and left unverified.
- **No `WREADY` backpressure modeling beyond one cycle at a time.** The DUT
  always asserts `WREADY` for the full burst once accepted; it doesn't
  randomly stall mid-burst. Backpressure/stall injection is meant to live on
  the UVM driver/sequence side, not be baked into the DUT.
- **WRAP boundary math assumes `AxLEN+1` is a power of two**, per the AXI4
  spec's own requirement for WRAP bursts. No defensive check is added for a
  non-power-of-two WRAP request — that's exactly the kind of illegal-input
  case a negative-control test should catch, not something the DUT should
  silently tolerate.

## Milestone plan for this project

1. **M1 — DUT design** (this step): `axi4_if.sv`, `axi4_slave_mem.sv`,
   directed sanity testbench (`tb_axi4_slave_mem_sanity.sv`) to
   elaboration-check basic write/read-back and the out-of-range SLVERR path.
2. **M2 — UVM environment skeleton**: transaction item, sequencer, driver,
   monitor, agent wrapping `axi4_if`.
3. **M3 — Scoreboard + reference model**: predict expected memory state and
   compare against monitor-observed read data.
4. **M4 — Constrained-random sequences + functional coverage**: burst type,
   burst length, WSTRB patterns, back-to-back read/write, boundary-crossing
   attempts.
5. **M5 — SVA assertions**: protocol compliance (e.g. no `VALID` deassertion
   before `READY`, `WLAST` alignment, response ordering).
6. **M6 — Negative-control / bug injection + coverage closure report**:
   deliberately break the DUT (e.g. drop the out-of-range check, break WRAP
   math) and confirm the environment actually catches it — same discipline
   used on the RISC-V core project.

# AXI4 to APB Bridge — UVM Verification Environment

A complete, reusable UVM verification environment for the PULP-platform
`axi2apb` bridge (AXI4 → APB, 32-bit). The project verifies protocol
handshaking, data/control propagation, response behaviour, and corner-case
handling using a dual-agent UVM testbench, scoreboard, functional coverage,
and both directed and constrained-random tests.

---

## Table of Contents

- [Overview](#overview)
- [DUT Description](#dut-description)
- [Repository Structure](#repository-structure)
- [Environment Architecture](#environment-architecture)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Test List](#test-list)
- [Coverage](#coverage)
- [RTL Observations](#rtl-observations)
- [References](#references)

---

## Overview

The AXI-to-APB bridge is a protocol converter. The AXI side accepts single-beat
writes (`AWADDR`/`WDATA`) and reads (`ARADDR`), and translates each into one
APB transfer. The APB slave returns `PRDATA` / `PREADY` / `PSLVERR`, and the
bridge returns the corresponding `B` response (for writes) or `R` response
(for reads) to the AXI master.

This project provides a complete verification environment built on top of the
supplied RTL, **without modifying the DUT**. It exercises:

- AXI and APB protocol handshakes
- Data and address propagation
- Response ID/USER propagation
- Backpressure on both AXI and APB sides
- Read/write priority
- Reset behaviour
- Unsupported-feature corner cases (burst, WSTRB, PSLVERR)

---

## DUT Description

| Property | Value |
|---|---|
| Top-level module | `axi2apb_wrap` (wraps `axi2apb`) |
| AXI address width | 32 bits |
| AXI data width | 32 bits |
| AXI ID width | 6 bits |
| AXI USER width | 6 bits |
| APB address width | 32 bits |
| APB data width | 32 bits |
| AXI buffer depth | 4 (configured as 2 in wrapper) |
| FSM states | `IDLE`, `WAIT_R_PREADY`, `WAIT_W_PREADY`, `DONE_SINGLE_RD`, `SEND_B_RESP` |

The DUT is sourced from the PULP-platform `axi` repository. **The RTL is
unmodified** — all observations in this README describe the RTL as supplied.

---

## Repository Structure

```text
axi2apb_uvm/
├── rtl/                          # DUT and dependent RTL (fifo, axi_slice, axi2apb_wrap)
├── tb/                           # Top-level testbench and interface definitions
│   ├── axi_bus.sv                # AXI_BUS interface + master_cb / monitor_cb
│   ├── apb_bus.sv                # APB_BUS interface + slave_cb / monitor_cb
│   └── tb_top.sv                 # Clock, reset, interfaces, UVM start
├── uvm/                          # UVM package (all classes)
│   ├── axi_apb_pkg.sv            # Top package (includes everything below)
│   ├── axi_seq_item.sv           # AXI transaction item
│   ├── axi_sequencer.sv
│   ├── axi_driver.sv             # Non-blocking via master_cb
│   ├── axi_monitor.sv            # Passive sample via monitor_cb
│   ├── axi_agent.sv
│   ├── apb_item.sv               # APB transaction item
│   ├── apb_slave_driver.sv       # Reactive slave (wait states, mem, PSLVERR)
│   ├── apb_monitor.sv
│   ├── apb_agent.sv              # Includes apb_sequencer
│   ├── axi_apb_scoreboard.sv     # Content-based matcher + ref memory
│   ├── axi_apb_coverage.sv       # axi_cg + apb_cg covergroups
│   └── axi_apb_env.sv
├── sequences/
│   ├── axi_single_write_seq.sv
│   ├── axi_single_read_seq.sv
│   ├── axi_apb_base_seq.sv       # do_write / do_read_check / do_read_raw
│   ├── axi_apb_directed_seq.sv   # T1..T13 directed scenarios
│   └── axi_apb_random_seq.sv     # 5 constrained-random sequence classes
├── tests/
│   ├── axi_apb_base_test.sv
│   ├── axi_apb_directed_test.sv
│   └── axi_apb_random_test.sv    # 5 random test classes
├── Makefile
├── build.flist
├── .gitignore
└── README.md
```

---

## Environment Architecture

The testbench uses a **dual-agent UVM environment**:

```text
                ┌─────────────────────────────────────┐
                │    uvm_test (directed / random)     │
                └──────────────────┬──────────────────┘
                                   │ virtual / directed sequence
                                   ▼
        ┌──────────────────┐                 ┌──────────────────┐
        │    AXI Agent     │                 │    APB Agent     │
        │  (Master side)   │                 │   (Slave side)   │
        │                  │                 │                  │
        │  Sequencer       │                 │  Sequencer       │
        │  Driver          │ ──── AXI ─────► │  Slave Driver    │
        │                  │      DUT        │  (wait states,   │
        │  Monitor         │ ◄─── APB ────── │   memory model)  │
        │                  │                 │  Monitor         │
        └────────┬─────────┘                 └────────┬─────────┘
                 │                                    │
                 │ axi_seq_item (analysis)            │ apb_item (analysis)
                 ▼                                    ▼
        ┌───────────────────────────────────────────────────────┐
        │              Scoreboard (content-based)               │
        │  - AXI ↔ APB direction/addr/data match                │
        │  - Response ID/USER propagation                       │
        │  - Read-after-write reference memory                  │
        │  - PSLVERR observed but ignored (RTL limitation)      │
        └───────────────────────────────────────────────────────┘
                 │                                    │
                 ▼                                    ▼
        ┌──────────────────┐                 ┌──────────────────┐
        │   axi_coverage   │                 │   apb_coverage   │
        │     (axi_cg)     │                 │     (apb_cg)     │
        └──────────────────┘                 └──────────────────┘
```

### Key design decisions

- **Non-blocking drivers:** Both AXI and APB drivers use SystemVerilog
  **clocking blocks** (`master_cb`, `slave_cb`). Signals are driven via `<=`
  and sampled via clocking-block inputs (`#1step`). This eliminates races
  between driver and monitor without manual `@(negedge)` juggling.

- **Content-based scoreboard:** Instead of pairing AXI and APB items by FIFO
  order (which breaks when APB waits shift timing), the scoreboard searches
  the APB queue for a matching (direction, address, data) tuple. This is
  robust against arbitrary ordering from the two monitors.

- **Raw `vif` sampling for B/R channels:** Because clocking-block `#1step`
  input skew would sample B/R payload one cycle late, the AXI driver samples
  `b_resp` / `b_id` / `r_data` / `r_id` directly from `vif` on
  `@(posedge vif.clk)` to capture the correct transaction.

---

## Requirements

| Item | Details |
|---|---|
| Simulator | Synopsys VCS (tested with L-2016.06_Full64) |
| UVM | 1.2 (provided by VCS `-ntb_opts uvm-1.2`) |
| Licenses | VCS, Verdi/DVE, and `-lca` (for the `-kdb` Verdi KDB flow) |
| OS | Linux (tested on Ubuntu / CentOS) |

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/MIrfan017/axi2apb-uvm-verif.git
cd axi2apb_uvm

# 2. Compile + run the directed test
make run TEST=axi_apb_directed_test WAVE=0

# 3. Run one random test
make random TEST=axi_apb_rand_mixed_test SEED=42

# 4. Full regression (directed + 5 random tests × 3 seeds)
make regress

# 5. Merge coverage from all builds
make cov_merge

# 6. View final HTML coverage report
firefox out/cov_final_excluded/dashboard.html &
```

### Common targets

| Command | Purpose |
|---|---|
| `make compile TEST=<name>` | Compile RTL + TB into `out/build_<name>/simv` |
| `make sim TEST=<name>` | Run already-compiled `simv` |
| `make run TEST=<name>` | Compile + run |
| `make directed` | Run `axi_apb_directed_test` |
| `make random TEST=<name> SEED=<N>` | Run one random test |
| `make regress` | Directed + all random × seeds |
| `make cov` | Coverage report for current test |
| `make cov_merge` | Merge all builds → final report |
| `make gui TEST=<name>` | Open waveform in DVE |
| `make clean TEST=<name>` | Delete one build |
| `make allclean` | Delete entire `out/` |

---

## Test List

### Directed Tests — `axi_apb_directed_test`

All scenarios are in `sequences/axi_apb_directed_seq.sv`:

| ID | Scenario |
|---|---|
| T1 | Single write + read back, APB ready immediately |
| T2 | Multiple addresses, out-of-order readback |
| T3 | Overwrite same address |
| T4 | Data patterns (0, all-1, alternating, walking-0, walking-31) |
| T5 | Address extremes (`0x0`, `0xFFFFFFFC`, `0xFFFFFFFF`) |
| T6 | APB wait states (1, 2, 5 cycles) |
| T7 | BREADY/RREADY backpressure (6 cycles) |
| T8 | Read of a preloaded APB location (no prior AXI write) |
| T9 | Back-to-back mixed write/read traffic |
| T10 | Max ID (`0x3F`) reuse |
| T11 | ID + USER propagation on B and R responses |
| T12 | PSLVERR driven high (RTL ignores it → response stays OKAY) |
| T13 | Simultaneous read + write — read priority (RTL spec) |

### Constrained-Random Tests — 5 scenarios × N seeds

| Test | Constraint focus |
|---|---|
| `axi_apb_rand_mixed_test` | Full 32-bit address range, mixed R/W, resp_delay 0–8 |
| `axi_apb_rand_write_heavy_test` | 100% writes, lower memory range |
| `axi_apb_rand_read_heavy_test` | 100% reads, higher memory range |
| `axi_apb_rand_backpressure_test` | resp_delay 5–15 (heavy BREADY/RREADY delay) |
| `axi_apb_rand_edge_test` | Unaligned + min/max address edge cases |

Every test uses `+ntb_random_seed=$(SEED)`, so any failure is reproducible:

```bash
make random TEST=axi_apb_rand_mixed_test SEED=42 WAVE=0
```

---

## Coverage

### Functional coverage

Two covergroups:

**`axi_cg`**

| Coverpoint | Bins |
|---|---|
| `cp_dir` | read / write |
| `cp_addr` | zero / max / low / mid / high |
| `cp_addr_unaligned` | aligned / offset_1 / offset_2 / offset_3 |
| `cp_data` | zero / ones / alt_aa / alt_55 / walking_0 / walking_31 |
| `cp_resp` | okay |
| `cp_id` | zero / one / misc |
| `cp_user` | zero / max / misc |
| `cp_backpressure` | none / one / few / many |
| `cp_b2b` | b2b_read / b2b_write |

Crosses: `x_dir_addr`, `x_dir_data`, `x_dir_bp`, `x_dir_resp_bp`,
`x_dir_id`, `x_dir_user`, `x_dir_addr_un`.

**`apb_cg`**

| Coverpoint | Bins |
|---|---|
| `cp_dir` | read / write |
| `cp_waits` | low (0–1) / few (2–3) / many (4+) |
| `cp_slverr` | low / high |

Crosses: `x_dir_waits`, `x_dir_slverr`.

### Code coverage

Collected via VCS `-cm line+cond+tgl+assert+branch`. The following are
excluded from the final report (justified in [Known Limitations](#known-limitations)):

- UVM library (not part of the DUT)
- `fifo.sv` `FALL_THROUGH` branch (dead code — `FALL_THROUGH=0` in all instances)

### Typical results after full regression

| Metric | Value |
|---|---|
| Functional coverage (merged) | ~98% |
| Line coverage (axi2apb FSM) | ~92% |
| Branch coverage (axi2apb FSM) | ~79% |
| All tests pass | ✅ |

---

## RTL Observations

These are documented behaviours of the supplied RTL (not bugs introduced by
the testbench). They were confirmed during verification:

1. **Read priority** — In `IDLE`, `ARVALID` is checked before `AWVALID`.
   Simultaneous read + write → read is served first (verified in T13).

2. **Write requires AW + W together** — If `AWVALID` is seen without `WVALID`,
   the FSM returns to `IDLE` and defers. AXI buffers retain the AW, so the
   write still completes once W arrives (verified via scoreboard correlation).

3. **PSLVERR is ignored** — The bridge never uses `PSLVERR` in the FSM.
   Driving `PSLVERR=1` on the APB slave still produces `BRESP`/`RRESP` = OKAY.
   The scoreboard logs this (T12) but does not flag it as an error.

4. **WSTRB/WLAST are unused** — `PWDATA = WDATA` in full. Partial writes
   are not masked (documented, not tested as a feature).

5. **AWLEN/ARLEN are unused in the 32/32 DUT** — No burst progression.
   `RLAST` is always asserted on the single read beat. AXI bursts degrade to
   single beats (documented in T4 patterns).

6. **PSEL is tied high** — `assign PSEL = 1'b1;` in `axi2apb.sv`. This
   deviates from strict APB, which expects `PSEL` low between transfers.

7. **No APB setup phase** — `PENABLE` is combinational and can assert in the
   same cycle as `PSEL`. The APB slave driver is written to tolerate this.

8. **Buffer depth limits back-to-back** — The wrapper instantiates the DUT
   with `BUFF_DEPTH_SLAVE = 2`. Back-to-back traffic is limited to 2
   outstanding AXI transactions per channel.

---

## References

- [repository](https://github.com/MIrfan017/axi2apb-uvm-verif.git) — source of the DUT
- AMBA AXI4 Protocol Specification (ARM)
- AMBA APB Protocol Specification (ARM)
- UVM 1.2 User's Guide (Accellera)

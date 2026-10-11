# CDC to APB Transaction Controller

## Overview

This project implements a Clock Domain Crossing (CDC) to Advanced Peripheral Bus (APB) transaction controller using Verilog HDL and Xilinx Vivado.

The controller transfers transaction requests from a source clock domain (`clk_A`) to an APB peripheral operating in a destination clock domain (`clk_B`). It uses a request/acknowledgment toggle handshake, flip-flop synchronizers, and an APB finite state machine to coordinate transactions across the two clock domains.

The design also includes read-data capture logic, error-status handling, debug signals, and a Verilog testbench for functional verification.

## Features

- CDC request and acknowledgment handshake using toggle signals.
- Configurable flip-flop synchronizer.
- Independent source and destination clocks.
- 8-bit transaction address and data interfaces.
- APB read and write transaction control.
- Three-state APB finite state machine.
- Read-data and error-status capture.
- Debug outputs for observing synchronization and acknowledgment timing.
- Testbench checks for expected read data and stale-data detection.

## Design Architecture

```text
             Source Clock Domain
                   clk_A
                     |
                     v
             Transaction Request
             i_valid_A / i_addr_A
             i_data_A / i_write_A
                     |
                     v
              Request Toggle
                  w_req
                     |
                     v
             Flip-Flop Synchronizer
                  clk_B
                     |
                     v
             Request Edge Detection
                     |
                     v
              APB Controller FSM
             IDLE -> SETUP -> ENABLE
                     |
                     v
                APB Interface
          PSEL, PENABLE, PADDR, PWRITE
                     |
                     v
           APB Peripheral / Test Model
                     |
                     v
             Read Data and Status
                     |
                     v
              Response Handshake
                  w_ack
                     |
                     v
             Flip-Flop Synchronizer
                  clk_A
                     |
                     v
             o_ready_A / o_rdata_A
```

## Source Files

### 1. `cdc_to_apb.v`

The main transaction controller.

Responsibilities:

- Accepts requests through `i_valid_A`.
- Captures the address, data, and read/write control.
- Generates the request toggle `w_req`.
- Synchronizes the request into clock domain B.
- Detects new requests using edge detection.
- Controls the APB transaction using a finite state machine.
- Captures and stabilizes read data and error status.
- Generates an acknowledgment after the APB transaction completes.
- Provides debug outputs for waveform analysis.

### 2. `ff_synchronizer.v`

Implements a configurable multi-stage flip-flop synchronizer.

**Parameter:** `G_STAGES = 2` by default.

**Inputs:** `i_clk`, `i_rst`, `i_async`

**Output:** `o_sync`

The asynchronous control signal passes through synchronization stages clocked by the destination clock. This helps reduce the risk of metastability propagating into downstream logic.

### 3. `cdc_to_apb_tb.v`

The testbench verifies the controller with two independent clock signals and a simulated APB peripheral.

It includes:

- Clock and reset generation.
- Write and read transaction tasks.
- APB response modeling.
- Request and acknowledgment edge detection.
- Transaction cycle counting.
- Expected read-data comparisons.
- Debug messages for checking stale or incorrect read data.

The testbench module is named `tb`.

## Clock Domain Crossing

The testbench uses the following clock periods:

| Clock | Period | Frequency |
|---|---:|---:|
| `clk_A` | 10 ns | 100 MHz |
| `clk_B` | 20 ns | 50 MHz |

The clocks operate at different frequencies, so the controller must coordinate requests and responses across the clock boundary.

### Request and acknowledgment handshake

1. The source accepts a transaction when `i_valid_A` and the ready condition are satisfied.
2. The request toggle `w_req` changes state.
3. The request passes through the synchronizer into clock domain B.
4. The destination detects the request and captures the transaction information.
5. The APB FSM performs the transaction.
6. The response acknowledgment `w_ack` toggles after the response data-capture sequence.
7. The acknowledgment is synchronized back to clock domain A.
8. The source-side logic updates its ready status and read data.

The transaction data is held in source-side registers while the request is pending. The design relies on this stability during the CDC handshake.

## APB Finite State Machine

The APB controller uses three states.

| State | Operation |
|---|---|
| `IDLE` | Waits for a new synchronized request. |
| `SETUP` | Asserts `PSEL` and prepares the address and control signals. |
| `ENABLE` | Asserts `PSEL` and `PENABLE` and waits for `PREADY`. |

When `PREADY` is asserted during the access phase, the FSM returns to `IDLE`.

### APB signals used

| Signal | Width | Function |
|---|---:|---|
| `PSEL` | 1 bit | Selects the peripheral. |
| `PENABLE` | 1 bit | Indicates the access phase. |
| `PADDR` | 8 bits | Peripheral address. |
| `PWRITE` | 1 bit | Selects read or write. |
| `PWDATA` | 8 bits | Write data. |
| `PRDATA` | 8 bits | Read data from the peripheral. |
| `PREADY` | 1 bit | Indicates transfer completion. |
| `PSLVERR` | 1 bit | Indicates a peripheral transfer error. |

## Read-Data Timing and Debugging

The design contains dedicated registers and control signals for observing read-data timing:

| Signal | Purpose |
|---|---|
| `PRDATA_hold` | Captures the peripheral read data. |
| `PRDATA_stable` | Holds the staged read-data value. |
| `PSLVERR_hold` | Captures the peripheral error status. |
| `PSLVERR_stable` | Holds the staged error-status value. |
| `ack_pending` | Indicates the first response-delay stage. |
| `ack_pending2` | Indicates the second response-delay stage. |
| `w_ack` | Destination-side acknowledgment toggle. |
| `r_ack_sync` | Synchronized acknowledgment in clock domain A. |
| `w_req` | Source-side request toggle. |

These signals help investigate whether the read data is stable before the acknowledgment crosses back into clock domain A.

The testbench monitors `PRDATA_stable` when the acknowledgment toggles and compares the returned `o_rdata_A` against the expected value.

## Testbench and Expected Results

The simulated APB peripheral in `cdc_to_apb_tb.v` generates read data using:

```verilog
PRDATA <= PADDR + 8'h10;
```

This is a simple test model, not a memory that stores and returns previously written data.

### Expected read values

| Read address | Expected data |
|---|---|
| `0x20` | `0x30` |
| `0x40` | `0x50` |
| `0x10` | `0x20` |
| `0x30` | `0x40` |
| `0x50` | `0x60` |

The testbench performs multiple write and read transactions. It prints transaction addresses, data, cycle counts, and PASS/FAIL messages for read-data comparisons.

**Note:** These are expected results from the testbench model. Run the simulation and verify the console and waveforms before claiming that every test passes.

## Tools and Technologies

- Verilog HDL
- Xilinx Vivado
- RTL behavioral simulation
- Clock Domain Crossing (CDC)
- APB protocol
- Finite State Machine (FSM)
- Flip-flop synchronization
- Digital design verification
## Simulation Result
<img width="1896" height="973" alt="image" src="https://github.com/user-attachments/assets/ee8e5bb9-1e71-4c28-b969-4e05fde0d8b6" />

## Applications

- Peripheral transaction control across clock domains.
- APB-based register access.
- CDC handshake design.
- FPGA and SoC digital design.
- RTL verification and waveform debugging.


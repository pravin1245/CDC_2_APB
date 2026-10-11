`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.03.2026 09:45:42
// Design Name: 
// Module Name: cdc_to_apb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module cdc_to_apb #(parameter G_STAGES = 2)
(
    input  wire        i_clk_A,
    input  wire        i_rst_A,
    input  wire        i_valid_A,
    input  wire [7:0]  i_addr_A,
    input  wire [7:0]  i_data_A,
    input  wire        i_write_A,
    output reg         o_ready_A,
    output reg  [7:0]  o_rdata_A,
    output wire        o_pslverr_A,

    input  wire        i_clk_B,
    input  wire        i_rst_B,

    output reg         PSEL,
    output reg         PENABLE,
    output reg [7:0]   PADDR,
    output reg         PWRITE,
    output reg [7:0]   PWDATA,
    input  wire [7:0]  PRDATA,
    input  wire        PREADY,
    input  wire        PSLVERR,

    // debug ports for waveform visibility
    output wire [7:0]  PRDATA_hold_out,
    output wire [7:0]  PRDATA_stable_out,
    output wire        w_ack_out,
    output wire        ack_pending_out,
    output wire        ack_pending2_out,
    output wire        r_ack_sync_out,
    output wire        w_req_out
);

// CDC handshake toggles
reg w_req;
reg w_ack;

wire r_req_sync;
wire r_ack_sync;

// Ready when req equals ack (no pending transaction)
wire w_ready = (w_req == r_ack_sync);

// Request data held stable until ack returns
reg [7:0] addr_reg, data_reg;
reg write_reg;

// Domain A: capture request and toggle req
always @(posedge i_clk_A or posedge i_rst_A) begin
    if (i_rst_A) begin
        w_req     <= 0;
        o_ready_A <= 1;
        addr_reg  <= 0;
        data_reg  <= 0;
        write_reg <= 0;
    end
    else begin
        o_ready_A <= w_ready;
        if (i_valid_A && w_ready) begin
            addr_reg  <= i_addr_A;
            data_reg  <= i_data_A;
            write_reg <= i_write_A;
            w_req     <= ~w_req;
        end
    end
end

// Synchronise req into domain B
ff_synchronizer #(G_STAGES) sync_A2B (
    .i_clk  (i_clk_B),
    .i_rst  (i_rst_B),
    .i_async(w_req),
    .o_sync (r_req_sync)
);

// Edge detect on synchronised req
reg r_req_d;

always @(posedge i_clk_B or posedge i_rst_B) begin
    if (i_rst_B)
        r_req_d <= 0;
    else
        r_req_d <= r_req_sync;
end

wire new_req = r_req_sync ^ r_req_d;

// Capture request data in domain B
reg [7:0] addr_B, data_B;
reg write_B;

always @(posedge i_clk_B or posedge i_rst_B) begin
    if (i_rst_B) begin
        addr_B  <= 0;
        data_B  <= 0;
        write_B <= 0;
    end
    else if (new_req) begin
        addr_B  <= addr_reg;
        data_B  <= data_reg;
        write_B <= write_reg;
    end
end

// APB FSM
reg [1:0] state;

localparam IDLE   = 2'd0;
localparam SETUP  = 2'd1;
localparam ENABLE = 2'd2;

always @(posedge i_clk_B or posedge i_rst_B) begin
    if (i_rst_B)
        state <= IDLE;
    else begin
        case (state)
            IDLE:   if (new_req) state <= SETUP;
            SETUP:  state            <= ENABLE;
            ENABLE: if (PREADY) state <= IDLE;
        endcase
    end
end

// APB output signals
always @(posedge i_clk_B or posedge i_rst_B) begin
    if (i_rst_B) begin
        PSEL    <= 0;
        PENABLE <= 0;
        PADDR   <= 0;
        PWRITE  <= 0;
        PWDATA  <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                PSEL    <= 0;
                PENABLE <= 0;
            end
            SETUP: begin
                PSEL    <= 1;
                PENABLE <= 0;
                PADDR   <= addr_B;
                PWRITE  <= write_B;
                PWDATA  <= data_B;
            end
            ENABLE: begin
                PSEL    <= 1;
                PENABLE <= 1;
            end
        endcase
    end
end

// PROBLEM 
// PRDATA_stable is updated using PRDATA_hold in the same clock cycle:
//
//   PRDATA_hold   <= PRDATA;
//   PRDATA_stable <= PRDATA_hold;
//
// Due to non-blocking assignment behavior,
// PRDATA_stable receives the OLD value of PRDATA_hold
// in that cycle instead of the newly captured PRDATA.
//
// If w_ack toggles in the same or next immediate cycle,
// the CDC side may sample stale/old read data before
// PRDATA_stable is fully updated.
//
// Result:
// Possible old data return during ACK completion timing.
//
// CORRECT FIX - two stage pending:
//   cycle N   (PREADY):
//     PRDATA_hold    <= PRDATA         new into hold
//     PRDATA_stable  <= PRDATA_hold    OLD (non-blocking)
//     ack_pending    <= 1              stage 1 arm
//
//   cycle N+1 (ack_pending=1):
//     PRDATA_stable now has NEW value  <- settled 
//     ack_pending2  <= 1              stage 2 arm
//     ack_pending   <= 0
//
//   cycle N+2 (ack_pending2=1):
//     w_ack <= ~w_ack                  toggles AFTER stable settled 

reg [7:0] PRDATA_hold,  PRDATA_stable;
reg       PSLVERR_hold, PSLVERR_stable;
reg       ack_pending;
reg       ack_pending2;

// Cycle N: latch PRDATA into hold, promote hold to stable
// PRDATA_stable gets OLD hold on cycle N (non-blocking)
// PRDATA_stable gets NEW hold on cycle N+1 (settled)
always @(posedge i_clk_B or posedge i_rst_B) begin
    if (i_rst_B) begin
        PRDATA_hold    <= 0;
        PRDATA_stable  <= 0;
        PSLVERR_hold   <= 0;
        PSLVERR_stable <= 0;
        ack_pending    <= 0;
    end
    else begin
        ack_pending <= 0;                    // default clear
        if (state == ENABLE && PREADY) begin
            PRDATA_hold    <= PRDATA;        // cycle N: new into hold
            PSLVERR_hold   <= PSLVERR;
            PRDATA_stable  <= PRDATA_hold;   // cycle N: OLD hold (non-blocking)
            PSLVERR_stable <= PSLVERR_hold;  // cycle N: OLD hold (non-blocking)
            ack_pending    <= 1;             // cycle N: arm stage 1
        end
    end
end

// Cycle N+1: PRDATA_stable now has NEW value, arm stage 2
always @(posedge i_clk_B or posedge i_rst_B) begin
    if (i_rst_B)
        ack_pending2 <= 0;
    else begin
        ack_pending2 <= 0;                   // default clear
        if (ack_pending)
            ack_pending2 <= 1;               // cycle N+1: arm w_ack
    end
end

// Cycle N+2: w_ack toggles after PRDATA_stable fully settled
// PRDATA_stable guaranteed valid since cycle N+1
always @(posedge i_clk_B or posedge i_rst_B) begin
    if (i_rst_B)
        w_ack <= 0;
    else if (ack_pending2)
        w_ack <= ~w_ack;                     // cycle N+2: stable valid 
end

// Debug ports
assign PRDATA_hold_out    = PRDATA_hold;
assign PRDATA_stable_out  = PRDATA_stable;
assign w_ack_out          = w_ack;
assign ack_pending_out    = ack_pending;
assign ack_pending2_out   = ack_pending2;
assign r_ack_sync_out     = r_ack_sync;
assign w_req_out          = w_req;

// Synchronise ack into domain A
ff_synchronizer #(G_STAGES) sync_B2A (
    .i_clk  (i_clk_A),
    .i_rst  (i_rst_A),
    .i_async(w_ack),
    .o_sync (r_ack_sync)
);

// Domain A: edge detect on ack, sample stable read data
reg ack_d;
reg err_A;

always @(posedge i_clk_A or posedge i_rst_A) begin
    if (i_rst_A) begin
        ack_d     <= 0;
        o_rdata_A <= 0;
        err_A     <= 0;
    end
    else begin
        ack_d <= r_ack_sync;
        if (r_ack_sync ^ ack_d) begin
            o_rdata_A <= PRDATA_stable;      // stable guaranteed valid 
            err_A     <= PSLVERR_stable;
        end
    end
end

assign o_pslverr_A = err_A;

endmodule
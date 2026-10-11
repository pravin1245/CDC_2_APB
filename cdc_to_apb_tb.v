`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.03.2026 09:49:01
// Design Name: 
// Module Name: cdc_to_apb_tb
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
// Testbench for cdc_to_apb
// clk_A = 100 MHz, clk_B = 50 MHz
// APB slave: PRDATA = PADDR + 0x10 for reads
module tb();

// Clocks
reg clk_A = 0;
always #5  clk_A = ~clk_A;

reg clk_B = 0;
always #10 clk_B = ~clk_B;

reg rst_A, rst_B;

reg        i_valid_A;
reg [7:0]  i_addr_A;
reg [7:0]  i_data_A;
reg        i_write_A;

wire       o_ready_A;
wire [7:0] o_rdata_A;
wire       o_pslverr_A;

wire       PSEL;
wire       PENABLE;
wire [7:0] PADDR;
wire       PWRITE;
wire [7:0] PWDATA;

reg  [7:0] PRDATA;
reg        PREADY;
reg        PSLVERR;


wire [7:0] PRDATA_hold;
wire [7:0] PRDATA_stable;
wire       w_ack;
wire       ack_pending;
wire       ack_pending2;
wire       r_ack_sync;
wire       w_req;

cdc_to_apb dut (
    .i_clk_A           (clk_A),
    .i_rst_A           (rst_A),
    .i_valid_A         (i_valid_A),
    .i_addr_A          (i_addr_A),
    .i_data_A          (i_data_A),
    .i_write_A         (i_write_A),
    .o_ready_A         (o_ready_A),
    .o_rdata_A         (o_rdata_A),
    .o_pslverr_A       (o_pslverr_A),
    .i_clk_B           (clk_B),
    .i_rst_B           (rst_B),
    .PSEL              (PSEL),
    .PENABLE           (PENABLE),
    .PADDR             (PADDR),
    .PWRITE            (PWRITE),
    .PWDATA            (PWDATA),
    .PRDATA            (PRDATA),
    .PREADY            (PREADY),
    .PSLVERR           (PSLVERR),
    .PRDATA_hold_out   (PRDATA_hold),
    .PRDATA_stable_out (PRDATA_stable),
    .w_ack_out         (w_ack),
    .ack_pending_out   (ack_pending),
    .ack_pending2_out  (ack_pending2),
    .r_ack_sync_out    (r_ack_sync),
    .w_req_out         (w_req)
);

// Simple APB slave: read data = PADDR + 0x10
always @(posedge clk_B) begin
    if (rst_B) begin
        PREADY  <= 0;
        PRDATA  <= 0;
        PSLVERR <= 0;
    end
    else begin
        if (PSEL && PENABLE) begin
            PREADY <= 1;
            if (!PWRITE)
                PRDATA <= PADDR + 8'h10;
        end
        else
            PREADY <= 0;
    end
end

// Free-running cycle counter in domain A
reg [31:0] cycle = 0;
always @(posedge clk_A)
    cycle <= cycle + 1;

// w_ack edge detect in clk_B domain
// at this edge PRDATA_stable must have NEW value
reg  w_ack_d;
wire w_ack_edge;

always @(posedge clk_B)
    w_ack_d <= w_ack;

assign w_ack_edge = w_ack ^ w_ack_d;

// r_ack_sync edge detect in clk_A domain
reg  ack_d;
wire ack_edge;

always @(posedge clk_A)
    ack_d <= r_ack_sync;

assign ack_edge = r_ack_sync ^ ack_d;

reg [31:0] start_c, end_c;

// Write task
task write(input [7:0] addr, input [7:0] data);
begin
    @(posedge clk_A);
    while (!o_ready_A) @(posedge clk_A);
    start_c   = cycle;
    i_addr_A  = addr;
    i_data_A  = data;
    i_write_A = 1;
    i_valid_A = 1;
    @(posedge clk_A);
    i_valid_A = 0;
    wait (ack_edge);
    @(posedge clk_A);
    end_c = cycle;
    $display("[WRITE] addr=%02h  data=%02h  cycles=%0d",
             addr, data, end_c - start_c);
end
endtask

// Read task
// at w_ack_edge PRDATA_stable must have NEW value
// ack_pending and ack_pending2 show two-stage delay pipeline
task read(input [7:0] addr);
begin
    @(posedge clk_A);
    while (!o_ready_A) @(posedge clk_A);
    start_c   = cycle;
    i_addr_A  = addr;
    i_write_A = 0;
    i_valid_A = 1;
    @(posedge clk_A);
    i_valid_A = 0;

    // at w_ack_edge: PRDATA_stable must equal expected
    wait (w_ack_edge);
    $display("[CHECK w_ack] addr=%02h  PRDATA_hold=%02h  PRDATA_stable=%02h  expected=%02h  %s",
             addr,
             PRDATA_hold,
             PRDATA_stable,
             addr + 8'h10,
             (PRDATA_stable == (addr + 8'h10)) ? "NEW DATA OK" : "OLD DATA BUG ***");

    wait (ack_edge);
    @(posedge clk_A);
    end_c = cycle;
    $display("[READ ] addr=%02h  o_rdata_A=%02h  expected=%02h  cycles=%0d  %s",
             addr,
             o_rdata_A,
             addr + 8'h10,
             end_c - start_c,
             (o_rdata_A == (addr + 8'h10)) ? "PASS" : "FAIL *** STALE DATA ***");
end
endtask

// Stimulus
initial begin
    rst_A     = 1;
    rst_B     = 1;
    i_valid_A = 0;
    i_addr_A  = 0;
    i_data_A  = 0;
    i_write_A = 0;

    #40;
    rst_A = 0;
    rst_B = 0;
    #20;

    write(8'h20, 8'hAA);
    write(8'h40, 8'h01);

    read(8'h20);   // expect 0x30
    read(8'h40);   // expect 0x50

    write(8'h10, 8'h55);
    read(8'h10);   // expect 0x20

    write(8'h30, 8'h99);
    read(8'h30);   // expect 0x40

    read(8'h50);   // expect 0x60

    #200;
    $display("--- Simulation complete ---");
    $finish;
end

endmodule
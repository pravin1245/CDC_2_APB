`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.03.2026 19:50:25
// Design Name: 
// Module Name: axi_to_apb_top
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


module axi_to_apb_top (

    input wire clk_A,
    input wire rst_A,
    input wire clk_B,
    input wire rst_B,

    // AXI WRITE ADDRESS
    input wire [7:0] AWADDR,
    input wire AWVALID,
    output wire AWREADY,

    // AXI WRITE DATA
    input wire [7:0] WDATA,
    input wire WVALID,
    output wire WREADY,

    // AXI WRITE RESPONSE
    output wire BVALID,
    input wire BREADY,
    output wire [1:0] BRESP,

    // AXI READ ADDRESS
    input wire [7:0] ARADDR,
    input wire ARVALID,
    output wire ARREADY,

    // AXI READ DATA
    output wire [7:0] RDATA,
    output wire RVALID,
    input wire RREADY,
    output wire [1:0] RRESP
);

    // Internal connection wires
    wire trans_valid;
    wire trans_type;
    wire [7:0] trans_addr;
    wire [7:0] trans_data;

    wire trans_ready;
    wire [7:0] read_data;
    wire error_flag;

    // APB signals
    wire PSEL, PENABLE, PWRITE;
    wire [7:0] PADDR, PWDATA, PRDATA;
    wire PREADY, PSLVERR;

    //------------------------------------------
    // AXI TRANSLATOR
    //------------------------------------------
    slave_axi_translator axi_translator (
        .clk(clk_A),
        .rst(rst_A),

        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),

        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),

        .BVALID(BVALID),
        .BREADY(BREADY),
        .BRESP(BRESP),

        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),

        .RDATA(RDATA),
        .RVALID(RVALID),
        .RREADY(RREADY),
        .RRESP(RRESP),

        .transaction_valid(trans_valid),
        .transaction_type(trans_type),
        .address(trans_addr),
        .data(trans_data),

        .transaction_ready(trans_ready),
        .read_data_from_cdc(read_data),
        .error_from_cdc(error_flag)
    );

    //------------------------------------------
    // CDC + APB BRIDGE
    //------------------------------------------
    axi_cdc_apb_bridge cdc_apb (

        .i_clk_A(clk_A),
        .i_rst_A(rst_A),
        .i_valid_A(trans_valid),
        .i_write_A(trans_type),
        .i_addr_A(trans_addr),
        .i_data_A(trans_data),
        .o_ready_A(trans_ready),

        .o_rdata_A(read_data),
        .o_error_A(error_flag),
        .o_valid_A(),   // not used here (AXI handles valid)

        .i_clk_B(clk_B),
        .i_rst_B(rst_B),

        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),

        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );

    //------------------------------------------
    // APB MEMORY
    //------------------------------------------
    apb_memory memory (

        .PCLK(clk_B),
        .PRESET(rst_B),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),

        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );

endmodule

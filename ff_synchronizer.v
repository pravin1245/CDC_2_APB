`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.03.2026 09:46:33
// Design Name: 
// Module Name: ff_synchronizer
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

`timescale 1ns/1ps

module ff_synchronizer #(parameter G_STAGES = 2)
(
    input  wire i_clk,
    input  wire i_rst,
    input  wire i_async,
    output wire o_sync
);

reg [G_STAGES-1:0] sync_reg;

always @(posedge i_clk or posedge i_rst) begin
    if (i_rst)
        sync_reg <= 0;
    else begin
        sync_reg[0] <= i_async;
        sync_reg[G_STAGES-1:1] <= sync_reg[G_STAGES-2:0];
    end
end

assign o_sync = sync_reg[G_STAGES-1];

endmodule
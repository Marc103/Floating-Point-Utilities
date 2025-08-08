/* Floating Point Multiplier Z
 * Mimics a floating point multiplier to buffer other streams
 * of data.
 */

 module floating_point_multiplier_z #(
    parameter EXP_WIDTH = 0,
    parameter FRAC_WIDTH = 0,

    ////////////////////////////////////////////////////////////////
    // Local parameters
    parameter FP_WIDTH_REG = 1 + FRAC_WIDTH + EXP_WIDTH
 ) (
    input clk_i,
    input rst_i,

    input  [FP_WIDTH_REG - 1 : 0] fp_a_i,
    input                         valid_i,

    output [FP_WIDTH_REG - 1 : 0] fp_o,
    output                        valid_o
 );

    ////////////////////////////////////////////////////////////////
    // Input Registers
    logic [FP_WIDTH_REG - 1 : 0] fp_a_reg [2];
    logic                        valid_reg[2];

    always_ff @(posedge clk_i) begin
        // 2 stages 
        fp_a_reg[0]  <= fp_a_i;
        fp_a_reg[1]  <= fp_a_reg[0];
        if(rst_i) begin
            valid_reg[0] <= 0;
            valid_reg[1] <= 0;
        end else begin  
            valid_reg[0] <= valid_i;
            valid_reg[1] <= valid_reg[0];
        end
    end

    ////////////////////////////////////////////////////////////////
    // Output
    assign fp_o    = fp_a_reg[1];
    assign valid_o = valid_reg[1];

 endmodule
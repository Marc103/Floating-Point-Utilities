
/* Single Scale V W divider
 * C si |W|. performs
 *
 * V / W   => Z
 *
 * C / w_t => C max
 *
 * where w_t is the sum of the weights.
 */
module v_w_divider_0 #(
    parameter EXP_WIDTH = 0,
    parameter FRAC_WIDTH = 0,

    ////////////////////////////////////////////////////////////////
    // Local parameters
    parameter FP_WIDTH_REG = 1 + FRAC_WIDTH + EXP_WIDTH

) (
    input clk_i,
    input rst_i,

    input  [FP_WIDTH_REG - 1 : 0] v_i,
    input  [FP_WIDTH_REG - 1 : 0] w_i,
    input  [FP_WIDTH_REG - 1 : 0] w_t_i,
    input  [15:0]                 col_i,
    input  [15:0]                 row_i,
    input                         valid_i,

    output [FP_WIDTH_REG - 1 : 0] z_o,
    output [FP_WIDTH_REG - 1 : 0] c_o,
    output [15:0]                 col_o,
    output [15:0]                 row_o,  
    output                        valid_o
);

    logic [FP_WIDTH_REG - 1 : 0] c_i;
    always_comb begin
        c_i[FP_WIDTH_REG - 1] = 0;
        c_i[FP_WIDTH_REG - 2 : 0] = w_i[FP_WIDTH_REG - 2 : 0];
    end

    floating_point_divider #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) v_w_divider (
        .clk_i(clk_i),
        .rst_i(rst_i),
        
        .fp_a_i (v_i),
        .fp_b_i (w_i),
        .valid_i(valid_i),

        .fp_o   (z_o),
        .valid_o(valid_o)
    );

    floating_point_divider #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) c_w_t_divider (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i (c_i),
        .fp_b_i (w_t_i),
        .fp_o   (c_o)
    );

    floating_point_divider_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) col_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(col_i),
        .fp_o  (col_o)
    );

    floating_point_divider_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) row_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(row_i),
        .fp_o  (row_o)
    );
endmodule


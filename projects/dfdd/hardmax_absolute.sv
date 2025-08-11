/*
 * Accepts several channels and associated data,
 * selects greatest, expects only positive values.
 * In the form (V, W, C). Ideally this should be 
 * a pipeline comparator tree but since the NO_COMPARORS
 * is going to be small, and separated too, it should
 * be fine doing this naively.
 *
 */

module hardmax_absolute #(
    parameter EXP_WIDTH = 0,
    parameter FRAC_WIDTH = 0,

    parameter NO_COMPARORS = 0,

    ////////////////////////////////////////////////////////////////
    // Local parameters
    parameter FP_WIDTH_REG = 1 + FRAC_WIDTH + EXP_WIDTH
) (
    input clk_i,
    input rst_i,

    input  [FP_WIDTH_REG - 1 : 0] v_i [NO_COMPARORS],
    input  [FP_WIDTH_REG - 1 : 0] w_i [NO_COMPARORS],
    input  [FP_WIDTH_REG - 1 : 0] c_i [NO_COMPARORS],
    input                         valid_i,

    output [FP_WIDTH_REG - 1 : 0] v_o,
    output [FP_WIDTH_REG - 1 : 0] w_o,
    output [FP_WIDTH_REG - 1 : 0] c_o,
    output                        valid_o 
)

    logic [FP_WIDTH_REG - 1 : 0] v [NO_COMPARORS];
    logic [FP_WIDTH_REG - 1 : 0] w [NO_COMPARORS];
    logic [FP_WIDTH_REG - 1 : 0] c [NO_COMPARORS];
    logic                        valid;

    always@(posedge clk_i) begin
        v <= v_i;
        w <= w_i;
        c <= c_i;
        if(rst_i) begin
            valid <= 0;
        end else begin
            valid <= valid_i;
        end
    end

    logic [FP_WIDTH_REG - 1 : 0] max_v;
    logic [FP_WIDTH_REG - 1 : 0] max_w;
    logic [FP_WIDTH_REG - 1 : 0] max_c;

    always_comb begin
        max_v = v[0];
        max_w = w[0];
        max_c = c[0];

        for(int i = 1; i < NO_COMPARORS; i++) begin
            if(c[i] > max_c) begin
                max_v = v[i];
                max_w = w[i];
                max_c = c[i];
            end
        end
    end

    assign v_o = max_v;
    assign w_o = max_w;
    assign c_o = max_c;
    assign valid_o = valid;
 endmodule
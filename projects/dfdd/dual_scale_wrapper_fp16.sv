module dual_scale_wrapper_fp16 #(
    parameter EXP_WIDTH = 5,
    parameter FRAC_WIDTH = 10,

    parameter IMAGE_WIDTH,
    parameter IMAGE_HEIGHT,

    parameter DX_DY_ENABLE = 0,
    parameter BORDER_ENABLE= 0,
    ////////////////////////////////////////////////////////////////
    // Local parameters
    parameter FP_WIDTH_REG = 1 + FRAC_WIDTH + EXP_WIDTH
) (
    input clk_i,
    input rst_i,

    input  [FP_WIDTH_REG - 1 : 0] i_rho_plus_i,
    input  [FP_WIDTH_REG - 1 : 0] i_rho_minus_i,
    input  [15:0]                 col_i,
    input  [15:0]                 row_i,
    input                         valid_i,

    input [FP_WIDTH_REG - 1 : 0] w_i [2][3],
    input [FP_WIDTH_REG - 1 : 0] w_t_i,
    input [FP_WIDTH_REG - 1 : 0] a_i [2],
    input [FP_WIDTH_REG - 1 : 0] b_i [2],

    output [FP_WIDTH_REG - 1 : 0] z_o,
    output [FP_WIDTH_REG - 1 : 0] c_o,
    output [15:0]                 col_o,
    output [15:0]                 row_o,
    output                        valid_o
);
    
    logic [FP_WIDTH_REG - 1 : 0] i_a_data_w;
    logic [FP_WIDTH_REG - 1 : 0] i_t_data_w;
    logic [15:0]                 i_a_col_w;
    logic [15:0]                 i_a_row_w;
    logic                        i_a_valid_w;

    preprocessing_fp16  #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) preprocessor (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .i_rho_plus_i (i_rho_plus_i),
        .i_rho_minus_i(i_rho_minus_i),
        .col_i        (col_i),
        .row_i        (row_i),
        .valid_i      (valid_i),

        .i_a_o  (i_a_data_w),
        .i_t_o  (i_t_data_w),
        .col_o  (i_a_col_w),
        .row_o  (i_a_row_w),
        .valid_o(i_a_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] v_0_data_w;
    logic [FP_WIDTH_REG - 1 : 0] w_0_data_w;
    logic [15:0]                 v_0_col_w;
    logic [15:0]                 v_0_row_w;
    logic                        v_0_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_a_0_downsample_data_w;
    logic [FP_WIDTH_REG - 1 : 0] i_t_0_downsample_data_w;
    logic [15:0]                 i_a_0_downsample_col_w;
    logic [15:0]                 i_a_0_downsample_row_w;
    logic                        i_a_0_downsample_valid_w;

    zero_scale_fp16 #(
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .BORDER_ENABLE(BORDER_ENABLE),
        .DX_DY_ENABLE (DX_DY_ENABLE)
    ) zero_scale (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .i_a_i  (i_a_data_w),
        .i_t_i  (i_t_data_w),
        .col_i  (i_a_col_w),
        .row_i  (i_a_row_w),
        .valid_i(i_a_valid_w),

        .w_i(w_i[0]),
        .a_i(a_i[0]),
        .b_i(b_i[0]),

        .i_a_downsample_o  (i_a_0_downsample_data_w),
        .i_t_downsample_o  (i_t_0_downsample_data_w),
        .col_downsample_o  (i_a_0_downsample_col_w),
        .row_downsample_o  (i_a_0_downsample_row_w),
        .valid_downsample_o(i_a_0_downsample_valid_w),

        .v_o    (v_0_data_w),
        .w_o    (w_0_data_w),
        .col_o  (v_0_col_w),
        .row_o  (v_0_row_w),
        .valid_o(v_0_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] v_1_data_w;
    logic [FP_WIDTH_REG - 1 : 0] w_1_data_w;
    logic [15:0]                 v_1_col_w;
    logic [15:0]                 v_1_row_w;
    logic                        v_1_valid_w;

    first_scale_fp16 #(
        .IMAGE_WIDTH (IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .BORDER_ENABLE(BORDER_ENABLE),
        .DX_DY_ENABLE(DX_DY_ENABLE)
    ) first_scale (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .w_i(w_i[1]),
        .a_i(a_i[1]),
        .b_i(b_i[1]),

        .i_a_i  (i_a_0_downsample_data_w),
        .i_t_i  (i_t_0_downsample_data_w),
        .col_i  (i_a_0_downsample_col_w),
        .row_i  (i_a_0_downsample_row_w),
        .valid_i(i_a_0_downsample_valid_w),

        .v_o    (v_1_data_w),
        .w_o    (w_1_data_w),
        .col_o  (v_1_col_w),
        .row_o  (v_1_row_w),
        .valid_o(v_1_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] v_bundle_data_w     [2];
    logic [FP_WIDTH_REG - 1 : 0] w_bundle_data_w     [2];
    logic                        v_w_bundle_valids_w [2];

    assign v_bundle_data_w     = '{v_0_data_w, v_1_data_w};
    assign w_bundle_data_w     = '{w_0_data_w, w_1_data_w};
    assign v_w_bundle_valids_w = '{v_0_valid_w, v_1_valid_w};

    logic [FP_WIDTH_REG - 1 : 0] v_added_data_w;
    logic [FP_WIDTH_REG - 1 : 0] w_added_data_w;
    logic [15:0]                 v_added_col_w;
    logic [15:0]                 v_added_row_w;
    logic                        v_added_valid_w;

    dual_scale_adder_fp16 #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .BUFFER_DEPTH(IMAGE_WIDTH * 16)
    ) aligner_and_adder (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .v_i    (v_bundle_data_w),
        .w_i    (w_bundle_data_w),
        .valid_i(v_w_bundle_valids_w),
        .col_i  (v_0_col_w),
        .row_i  (v_0_row_w),

        .v_o    (v_added_data_w),
        .w_o    (w_added_data_w),
        .col_o  (v_added_col_w),
        .row_o  (v_added_row_w),
        .valid_o(v_added_valid_w)
    );

    v_w_divider_0 #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) v_w_divider (
        .clk_i(clk_i),
        .rst_i(rst_i),
        
        .v_i    (v_added_data_w),
        .w_i    (w_added_data_w),
        .w_t_i  (w_t_i),
        .col_i  (v_added_col_w),
        .row_i  (v_added_row_w),
        .valid_i(v_added_valid_w),

        .z_o    (z_o),
        .c_o    (c_o),
        .col_o  (col_o),
        .row_o  (row_o),
        .valid_o(valid_o)
    );

endmodule
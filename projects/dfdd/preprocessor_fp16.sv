/*
 * Zero'ith scale of DFDD core. Tuned to work with
 * FP16.
 *
 */


module preprocessing_fp16 #(
    parameter IMAGE_WIDTH,
    parameter IMAGE_HEIGHT,

    parameter BORDER_ENABLE = 0,

    ////////////////////////////////////////////////////////////////
    // Local parameters
    parameter EXP_WIDTH = 5,
    parameter FRAC_WIDTH = 10,
    parameter FP_WIDTH_REG = 1 + FRAC_WIDTH + EXP_WIDTH
) (
    input clk_i,
    input rst_i,

    input [FP_WIDTH_REG - 1 : 0]  i_rho_plus_i,
    input [FP_WIDTH_REG - 1 : 0]  i_rho_minus_i,
    input [15:0]                  col_i,
    input [15:0]                  row_i,
    input                         valid_i,

    output [FP_WIDTH_REG - 1 : 0] i_a_o,
    output [FP_WIDTH_REG - 1 : 0] i_t_o,
    output [15:0]                 col_o,
    output [15:0]                 row_o,
    output                        valid_o
);

    ////////////////////////////////////////////////////////////////
    // Kernel Value Setups

    logic [FP_WIDTH_REG - 1 : 0] bh_kernel_w [1][5];
    always_comb begin
        bh_kernel_w[0][0] = 16'h2c00;
        bh_kernel_w[0][1] = 16'h3400;
        bh_kernel_w[0][2] = 16'h3600;
        bh_kernel_w[0][3] = 16'h3400;
        bh_kernel_w[0][4] = 16'h2c00;
    end

    logic [FP_WIDTH_REG - 1 : 0] bv_kernel_w [5][1];
    always_comb begin
        bv_kernel_w[0][0] = 16'h2c00;
        bv_kernel_w[1][0] = 16'h3400;
        bv_kernel_w[2][0] = 16'h3600;
        bv_kernel_w[3][0] = 16'h3400;
        bv_kernel_w[4][0] = 16'h2c00;
    end

    logic [FP_WIDTH_REG - 1 : 0] boxh_kernel_w [1][3];
    always_comb begin
        boxh_kernel_w[0][0] = 16'h3555;
        boxh_kernel_w[0][1] = 16'h3555;
        boxh_kernel_w[0][2] = 16'h3555;
    end

    logic [FP_WIDTH_REG - 1 : 0] boxv_kernel_w [3][1];
    always_comb begin
        boxv_kernel_w[0][0] = 16'h3555;
        boxv_kernel_w[1][0] = 16'h3555;
        boxv_kernel_w[2][0] = 16'h3555;
    end

    ////////////////////////////////////////////////////////////////
    // I rho plus 
    //----------------------
    // processing I_rho_plus:
    // window fetcher - 1x5
    // gaussian horizontal
    // window fetcher - 5x1
    // gaussian vertical
    // window fetcher - 1x3
    // box filter horizontal
    // window fetcher - 3x1
    // box filter vertical
    
    logic [FP_WIDTH_REG - 1 : 0] i_rho_plus_wfh_window_w [1][5];
    logic [15:0]                 i_rho_plus_wfh_col_w;
    logic [15:0]                 i_rho_plus_wfh_row_w;
    logic                        i_rho_plus_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_rho_plus_window_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_rho_plus_i),
        .col_i  (col_i),
        .row_i  (row_i),
        .valid_i(valid_i),

        .window_o(i_rho_plus_wfh_window_w),
        .col_o   (i_rho_plus_wfh_col_w),
        .row_o   (i_rho_plus_wfh_row_w),
        .valid_o (i_rho_plus_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_plus_bh_data_w;
    logic [15:0]                 i_rho_plus_bh_col_w;
    logic [15:0]                 i_rho_plus_bh_row_w;
    logic                        i_rho_plus_bh_valid_w;

    burt_h_0_fp16 i_rho_plus_burt_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_rho_plus_wfh_window_w),
        .kernel_i(bh_kernel_w),
        .col_i   (i_rho_plus_wfh_col_w),
        .row_i   (i_rho_plus_wfh_row_w),
        .valid_i (i_rho_plus_wfh_valid_w),

        .data_o (i_rho_plus_bh_data_w),
        .col_o  (i_rho_plus_bh_col_w),
        .row_o  (i_rho_plus_bh_row_w),
        .valid_o(i_rho_plus_bh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_plus_wfv_window_w [5][1];
    logic [15:0]                 i_rho_plus_wfv_col_w;
    logic [15:0]                 i_rho_plus_wfv_row_w;
    logic                        i_rho_plus_wfv_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_rho_plus_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_rho_plus_bh_data_w),
        .col_i  (i_rho_plus_bh_col_w),
        .row_i  (i_rho_plus_bh_row_w),
        .valid_i(i_rho_plus_bh_valid_w),

        .window_o(i_rho_plus_wfv_window_w),
        .col_o   (i_rho_plus_wfv_col_w),
        .row_o   (i_rho_plus_wfv_row_w),
        .valid_o (i_rho_plus_wfv_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_plus_gaussian_data_w;
    logic [15:0]                 i_rho_plus_gaussian_col_w;
    logic [15:0]                 i_rho_plus_gaussian_row_w;
    logic                        i_rho_plus_gaussian_valid_w;

    burt_v_0_fp16 i_rho_plus_burt_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_rho_plus_wfv_window_w),
        .kernel_i(bv_kernel_w),
        .col_i   (i_rho_plus_wfv_col_w),
        .row_i   (i_rho_plus_wfv_row_w),
        .valid_i (i_rho_plus_wfv_valid_w),

        .data_o (i_rho_plus_gaussian_data_w),
        .col_o  (i_rho_plus_gaussian_col_w),
        .row_o  (i_rho_plus_gaussian_row_w),
        .valid_o(i_rho_plus_gaussian_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_plus_gaussian_wfh_window_w [1][3];
    logic [15:0]                 i_rho_plus_gaussian_wfh_col_w;
    logic [15:0]                 i_rho_plus_gaussian_wfh_row_w;
    logic                        i_rho_plus_gaussian_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_rho_plus_gaussian_window_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_rho_plus_gaussian_data_w),
        .col_i  (i_rho_plus_gaussian_col_w),
        .row_i  (i_rho_plus_gaussian_row_w),
        .valid_i(i_rho_plus_gaussian_valid_w),

        .window_o(i_rho_plus_gaussian_wfh_window_w),
        .col_o   (i_rho_plus_gaussian_wfh_col_w),
        .row_o   (i_rho_plus_gaussian_wfh_row_w),
        .valid_o (i_rho_plus_gaussian_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_plus_gaussian_boxh_data_w;
    logic [15:0]                 i_rho_plus_gaussian_boxh_col_w;
    logic [15:0]                 i_rho_plus_gaussian_boxh_row_w;
    logic                        i_rho_plus_gaussian_boxh_valid_w;
    
    box_h_0_fp16 i_rho_plus_gaussian_box_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_rho_plus_gaussian_wfh_window_w),
        .kernel_i(boxh_kernel_w),
        .col_i   (i_rho_plus_gaussian_wfh_col_w),
        .row_i   (i_rho_plus_gaussian_wfh_row_w),
        .valid_i (i_rho_plus_gaussian_wfh_valid_w),

        .data_o (i_rho_plus_gaussian_boxh_data_w),
        .col_o  (i_rho_plus_gaussian_boxh_col_w),
        .row_o  (i_rho_plus_gaussian_boxh_row_w),
        .valid_o(i_rho_plus_gaussian_boxh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_plus_gaussian_wfv_window_w [3][1];
    logic [15:0]                 i_rho_plus_gaussian_wfv_col_w;
    logic [15:0]                 i_rho_plus_gaussian_wfv_row_w;
    logic                        i_rho_plus_gaussian_wfv_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(3),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_rho_plus_gaussian_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_rho_plus_gaussian_boxh_data_w),
        .col_i  (i_rho_plus_gaussian_boxh_col_w),
        .row_i  (i_rho_plus_gaussian_boxh_row_w),
        .valid_i(i_rho_plus_gaussian_boxh_valid_w),

        .window_o(i_rho_plus_gaussian_wfv_window_w),
        .col_o   (i_rho_plus_gaussian_wfv_col_w),
        .row_o   (i_rho_plus_gaussian_wfv_row_w),
        .valid_o (i_rho_plus_gaussian_wfv_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_plus_gaussian_box_data_w;
    logic [15:0]                 i_rho_plus_gaussian_box_col_w;
    logic [15:0]                 i_rho_plus_gaussian_box_row_w;
    logic                        i_rho_plus_gaussian_box_valid_w;

    box_v_0_fp16 i_rho_plus_gaussian_box_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_rho_plus_gaussian_wfv_window_w),
        .kernel_i(boxv_kernel_w),
        .col_i   (i_rho_plus_gaussian_wfv_col_w),
        .row_i   (i_rho_plus_gaussian_wfv_row_w),
        .valid_i (i_rho_plus_gaussian_wfv_valid_w),

        .data_o (i_rho_plus_gaussian_box_data_w),
        .col_o  (i_rho_plus_gaussian_box_col_w),
        .row_o  (i_rho_plus_gaussian_box_row_w),
        .valid_o(i_rho_plus_gaussian_box_valid_w)
    );

    ////////////////////////////////////////////////////////////////
    // I rho minus
    //----------------------
    // processing I_rho_minus:
    // window fetcher - 1x5
    // gaussian horizontal
    // window fetcher - 5x1
    // gaussian vertical
    // window fetcher - 1x3
    // box filter horizontal
    // window fetcher - 3x1
    // box filter vertical

    logic [FP_WIDTH_REG - 1 : 0] i_rho_minus_wfh_window_w [1][5];
    logic [15:0]                 i_rho_minus_wfh_col_w;
    logic [15:0]                 i_rho_minus_wfh_row_w;
    logic                        i_rho_minus_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_rho_minus_window_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_rho_minus_i),
        .col_i  (col_i),
        .row_i  (row_i),
        .valid_i(valid_i),

        .window_o(i_rho_minus_wfh_window_w),
        .col_o   (i_rho_minus_wfh_col_w),
        .row_o   (i_rho_minus_wfh_row_w),
        .valid_o (i_rho_minus_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_minus_bh_data_w;
    logic [15:0]                 i_rho_minus_bh_col_w;
    logic [15:0]                 i_rho_minus_bh_row_w;
    logic                        i_rho_minus_bh_valid_w;

    burt_h_0_fp16 i_rho_minus_burt_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_rho_minus_wfh_window_w),
        .kernel_i(bh_kernel_w),
        .col_i   (i_rho_minus_wfh_col_w),
        .row_i   (i_rho_minus_wfh_row_w),
        .valid_i (i_rho_minus_wfh_valid_w),

        .data_o (i_rho_minus_bh_data_w),
        .col_o  (i_rho_minus_bh_col_w),
        .row_o  (i_rho_minus_bh_row_w),
        .valid_o(i_rho_minus_bh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_minus_wfv_window_w [5][1];
    logic [15:0]                 i_rho_minus_wfv_col_w;
    logic [15:0]                 i_rho_minus_wfv_row_w;
    logic                        i_rho_minus_wfv_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_rho_minus_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_rho_minus_bh_data_w),
        .col_i  (i_rho_minus_bh_col_w),
        .row_i  (i_rho_minus_bh_row_w),
        .valid_i(i_rho_minus_bh_valid_w),

        .window_o(i_rho_minus_wfv_window_w),
        .col_o   (i_rho_minus_wfv_col_w),
        .row_o   (i_rho_minus_wfv_row_w),
        .valid_o (i_rho_minus_wfv_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_minus_gaussian_data_w;
    logic [15:0]                 i_rho_minus_gaussian_col_w;
    logic [15:0]                 i_rho_minus_gaussian_row_w;
    logic                        i_rho_minus_gaussian_valid_w;

    burt_v_0_fp16 i_rho_minus_burt_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_rho_minus_wfv_window_w),
        .kernel_i(bv_kernel_w),
        .col_i   (i_rho_minus_wfv_col_w),
        .row_i   (i_rho_minus_wfv_row_w),
        .valid_i (i_rho_minus_wfv_valid_w),

        .data_o (i_rho_minus_gaussian_data_w),
        .col_o  (i_rho_minus_gaussian_col_w),
        .row_o  (i_rho_minus_gaussian_row_w),
        .valid_o(i_rho_minus_gaussian_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_minus_gaussian_wfh_window_w [1][3];
    logic [15:0]                 i_rho_minus_gaussian_wfh_col_w;
    logic [15:0]                 i_rho_minus_gaussian_wfh_row_w;
    logic                        i_rho_minus_gaussian_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_rho_minus_gaussian_window_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_rho_minus_gaussian_data_w),
        .col_i  (i_rho_minus_gaussian_col_w),
        .row_i  (i_rho_minus_gaussian_row_w),
        .valid_i(i_rho_minus_gaussian_valid_w),

        .window_o(i_rho_minus_gaussian_wfh_window_w),
        .col_o   (i_rho_minus_gaussian_wfh_col_w),
        .row_o   (i_rho_minus_gaussian_wfh_row_w),
        .valid_o (i_rho_minus_gaussian_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_minus_gaussian_boxh_data_w;
    logic [15:0]                 i_rho_minus_gaussian_boxh_col_w;
    logic [15:0]                 i_rho_minus_gaussian_boxh_row_w;
    logic                        i_rho_minus_gaussian_boxh_valid_w;
    
    box_h_0_fp16 i_rho_minus_gaussian_box_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_rho_minus_gaussian_wfh_window_w),
        .kernel_i(boxh_kernel_w),
        .col_i   (i_rho_minus_gaussian_wfh_col_w),
        .row_i   (i_rho_minus_gaussian_wfh_row_w),
        .valid_i (i_rho_minus_gaussian_wfh_valid_w),

        .data_o (i_rho_minus_gaussian_boxh_data_w),
        .col_o  (i_rho_minus_gaussian_boxh_col_w),
        .row_o  (i_rho_minus_gaussian_boxh_row_w),
        .valid_o(i_rho_minus_gaussian_boxh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_minus_gaussian_wfv_window_w[3][1];
    logic [15:0]                 i_rho_minus_gaussian_wfv_col_w;
    logic [15:0]                 i_rho_minus_gaussian_wfv_row_w;
    logic                        i_rho_minus_gaussian_wfv_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(3),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_rho_minus_gaussian_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_rho_minus_gaussian_boxh_data_w),
        .col_i  (i_rho_minus_gaussian_boxh_col_w),
        .row_i  (i_rho_minus_gaussian_boxh_row_w),
        .valid_i(i_rho_minus_gaussian_boxh_valid_w),

        .window_o(i_rho_minus_gaussian_wfv_window_w),
        .col_o   (i_rho_minus_gaussian_wfv_col_w),
        .row_o   (i_rho_minus_gaussian_wfv_row_w),
        .valid_o (i_rho_minus_gaussian_wfv_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_rho_minus_gaussian_box_data_w;
    logic [15:0]                 i_rho_minus_gaussian_box_col_w;
    logic [15:0]                 i_rho_minus_gaussian_box_row_w;
    logic                        i_rho_minus_gaussian_box_valid_w;

    box_v_0_fp16 i_rho_minus_gaussian_box_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_rho_minus_gaussian_wfv_window_w),
        .kernel_i(boxv_kernel_w),
        .col_i   (i_rho_minus_gaussian_wfv_col_w),
        .row_i   (i_rho_minus_gaussian_wfv_row_w),
        .valid_i (i_rho_minus_gaussian_wfv_valid_w),

        .data_o (i_rho_minus_gaussian_box_data_w),
        .col_o  (i_rho_minus_gaussian_box_col_w),
        .row_o  (i_rho_minus_gaussian_box_row_w),
        .valid_o(i_rho_minus_gaussian_box_valid_w)
    );

    ////////////////////////////////////////////////////////////////
    // I_A calculation (and row col delay)
    logic [FP_WIDTH_REG - 1 : 0] i_a_plus_data_w;
    logic [15:0]                 i_a_plus_col_w;
    logic [15:0]                 i_a_plus_row_w;
    logic                        i_a_plus_valid_w;

    floating_point_adder #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) i_a_plus_adder (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .fp_a_i (i_rho_plus_gaussian_box_data_w),
        .fp_b_i (i_rho_minus_gaussian_box_data_w),
        .valid_i(i_rho_plus_gaussian_box_valid_w),

        .fp_o   (i_a_plus_data_w),
        .valid_o(i_a_plus_valid_w)
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_a_plus_col_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .fp_a_i(i_rho_plus_gaussian_box_col_w),
        .fp_o  (i_a_plus_col_w)
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_a_plus_row_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .fp_a_i(i_rho_plus_gaussian_box_row_w),
        .fp_o  (i_a_plus_row_w)
    );

    //----------------------------------------
    logic [FP_WIDTH_REG - 1 : 0] i_a_data_w;
    logic [15:0]                 i_a_col_w;
    logic [15:0]                 i_a_row_w;
    logic                        i_a_valid_w;

    floating_point_multiplier_exponent #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .EXPONENT(-1)
    ) i_a_plus_multiplier (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .fp_a_i (i_a_plus_data_w),
        .valid_i(i_a_plus_valid_w),
        .fp_o   (i_a_data_w),
        .valid_o(i_a_valid_w)
    );

    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_a_col_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .fp_a_i(i_a_plus_col_w),
        .fp_o  (i_a_col_w)
    );

    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_a_row_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .fp_a_i(i_a_plus_row_w),
        .fp_o  (i_a_row_w)
    );

    ////////////////////////////////////////////////////////////////
    // I_T calculation
    logic [FP_WIDTH_REG - 1 : 0] i_t_minus_data_w;

    logic [FP_WIDTH_REG - 1 : 0] i_rho_minus_gaussian_box_data_negative_w;
    always_comb begin
        i_rho_minus_gaussian_box_data_negative_w[FP_WIDTH_REG - 1] = !i_rho_minus_gaussian_box_data_w[FP_WIDTH_REG - 1];
        i_rho_minus_gaussian_box_data_negative_w[FP_WIDTH_REG - 2 : 0] = i_rho_minus_gaussian_box_data_w[FP_WIDTH_REG - 2 : 0];
    end

    floating_point_adder #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) i_t_minus_adder (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i (i_rho_plus_gaussian_box_data_w),
        .fp_b_i (i_rho_minus_gaussian_box_data_negative_w),
        .fp_o   (i_t_minus_data_w)
    );

    //----------------------------------------
    logic [FP_WIDTH_REG - 1 : 0] i_t_data_w;

    floating_point_multiplier_exponent #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .EXPONENT(-1)
    ) i_t_minus_multiplier (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .fp_a_i (i_t_minus_data_w),
        .fp_o   (i_t_data_w)
    );

    assign i_a_o   = i_a_data_w;
    assign i_t_o   = i_t_data_w;
    assign col_o   = i_a_col_w;
    assign row_o   = i_a_row_w;
    assign valid_o = i_a_valid_w;

endmodule
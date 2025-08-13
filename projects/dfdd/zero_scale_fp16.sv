/*
 * Zero'ith scale of DFDD core. Tuned to work with
 * FP16.
 *
 */


module zero_scale_fp16 #(
    parameter IMAGE_WIDTH,
    parameter IMAGE_HEIGHT,

    parameter DX_DY_ENABLE = 0,
    parameter BORDER_ENABLE = 1,

    ////////////////////////////////////////////////////////////////
    // Local parameters
    parameter EXP_WIDTH = 5,
    parameter FRAC_WIDTH = 10,
    parameter FP_WIDTH_REG = 1 + FRAC_WIDTH + EXP_WIDTH
) (
    input clk_i,
    input rst_i,

    input [FP_WIDTH_REG - 1 : 0]  i_a_i,
    input [FP_WIDTH_REG - 1 : 0]  i_t_i,
    input [15:0]                  col_i,
    input [15:0]                  row_i,
    input                         valid_i,

    input [FP_WIDTH_REG - 1 : 0]  w_i [3], // weights
    input [FP_WIDTH_REG - 1 : 0]  a_i,
    input [FP_WIDTH_REG - 1 : 0]  b_i,     

    output [FP_WIDTH_REG - 1 : 0] i_a_downsample_o,
    output [FP_WIDTH_REG - 1 : 0] i_t_downsample_o,
    output [15:0]                 col_downsample_o,
    output [15:0]                 row_downsample_o,
    output                        valid_downsample_o,

    output [FP_WIDTH_REG - 1 : 0] z_o,
    output [FP_WIDTH_REG - 1 : 0] w_o, // big W
    output [FP_WIDTH_REG - 1 : 0] c_o,
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

    logic [FP_WIDTH_REG - 1 : 0] box_2_2_kernel_w [2][2];
    always_comb begin
        box_2_2_kernel_w[0][0] = 16'h3400;
        box_2_2_kernel_w[0][1] = 16'h3400;
        box_2_2_kernel_w[1][0] = 16'h3400;
        box_2_2_kernel_w[0][1] = 16'h3400;
    end

    logic [FP_WIDTH_REG - 1 : 0] upsampler_3_3_kernel_w [3][3];
    always_comb begin
        upsampler_3_3_kernel_w[0][0] = 16'h3400;
        upsampler_3_3_kernel_w[0][1] = 16'h3800;
        upsampler_3_3_kernel_w[0][2] = 16'h3400;
        upsampler_3_3_kernel_w[1][0] = 16'h3800;
        upsampler_3_3_kernel_w[1][1] = 16'h3c00;
        upsampler_3_3_kernel_w[1][2] = 16'h3800;
        upsampler_3_3_kernel_w[2][0] = 16'h3400;
        upsampler_3_3_kernel_w[2][1] = 16'h3800;
        upsampler_3_3_kernel_w[2][2] = 16'h3400;
    end

    logic [FP_WIDTH_REG - 1 : 0] pass_3_3_kernel_w;
    always_comb begin
        pass_3_3_kernel_w[0][0] = 16'h0000;
        pass_3_3_kernel_w[0][1] = 16'h0000;
        pass_3_3_kernel_w[0][2] = 16'h0000;
        pass_3_3_kernel_w[1][0] = 16'h0000;
        pass_3_3_kernel_w[1][1] = 16'h3c00;
        pass_3_3_kernel_w[1][2] = 16'h0000;
        pass_3_3_kernel_w[2][0] = 16'h0000;
        pass_3_3_kernel_w[2][1] = 16'h0000;
        pass_3_3_kernel_w[2][2] = 16'h0000;
    end

    logic [FP_WIDTH_REG - 1 : 0] dx_3_3_kernel_w;
    always_comb begin
        dx_3_3_kernel_w[0][0] = 16'h0000;
        dx_3_3_kernel_w[0][1] = 16'h0000;
        dx_3_3_kernel_w[0][2] = 16'h0000;
        dx_3_3_kernel_w[1][0] = 16'hbc00;
        dx_3_3_kernel_w[1][1] = 16'h0000;
        dx_3_3_kernel_w[1][2] = 16'h3c00;
        dx_3_3_kernel_w[2][0] = 16'h0000;
        dx_3_3_kernel_w[2][1] = 16'h0000;
        dx_3_3_kernel_w[2][2] = 16'h0000;
    end

    logic [FP_WIDTH_REG - 1 : 0] dy_3_3_kernel_w;
    always_comb begin
        dy_3_3_kernel_w[0][0] = 16'h0000;
        dy_3_3_kernel_w[0][1] = 16'hbc00;
        dy_3_3_kernel_w[0][2] = 16'h0000;
        dy_3_3_kernel_w[1][0] = 16'h0000;
        dy_3_3_kernel_w[1][1] = 16'h0000;
        dy_3_3_kernel_w[1][2] = 16'h0000;
        dy_3_3_kernel_w[2][0] = 16'h0000;
        dy_3_3_kernel_w[2][1] = 16'h3c00;
        dy_3_3_kernel_w[2][2] = 16'h0000;
    end

    ////////////////////////////////////////////////////////////////
    // I_A

    //----------------------
    // processing I_A:
    // window fetcher - 1x5
    // gaussian horizontal
    // window fetcher - 5x1
    // gaussian vertical
    // window fetcher - 2x2
    // downsampler
    // zero inserter
    // window fecher  - 3x3
    // upsampler
    
    logic [FP_WIDTH_REG - 1 : 0] i_a_wfh_window_w [1][5];
    logic [15:0]                 i_a_wfh_col_w;
    logic [15:0]                 i_a_wfh_row_w;
    logic                        i_a_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_window_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_i),
        .col_i  (col_i),
        .row_i  (row_i),
        .valid_i(valid_i),

        .window_o(i_a_wfh_window_w),
        .col_o   (i_a_wfh_col_w),
        .row_o   (i_a_wfh_row_w),
        .valid_o (i_a_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_bh_data_w;
    logic [15:0]                 i_a_bh_col_w;
    logic [15:0]                 i_a_bh_row_w;
    logic                        i_a_bh_valid_w;

    burt_h_0_fp16 i_a_burt_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_a_wfh_window_w),
        .kernel_i(bh_kernel_w),
        .col_i   (i_a_wfh_col_w),
        .row_i   (i_a_wfh_row_w),
        .valid_i (i_a_wfh_valid_w),

        .data_o (i_a_bh_data_w),
        .col_o  (i_a_bh_col_w),
        .row_o  (i_a_bh_row_w),
        .valid_o(i_a_bh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_wfv_window_w [5][1];
    logic [15:0]                 i_a_wfv_col_w;
    logic [15:0]                 i_a_wfv_row_w;
    logic                        i_a_wfv_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_bh_data_w),
        .col_i  (i_a_bh_col_w),
        .row_i  (i_a_bh_row_w),
        .valid_i(i_a_bh_valid_w),

        .window_o(i_a_wfv_window_w),
        .col_o   (i_a_wfv_col_w),
        .row_o   (i_a_wfv_row_w),
        .valid_o (i_a_wfv_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_data_w;
    logic [15:0]                 i_a_gaussian_col_w;
    logic [15:0]                 i_a_gaussian_row_w;
    logic                        i_a_gaussian_valid_w;

    burt_v_0_fp16 i_a_burt_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_a_wfv_window_w),
        .kernel_i(bv_kernel_w),
        .col_i   (i_a_wfv_col_w),
        .row_i   (i_a_wfv_row_w),
        .valid_i (i_a_wfv_valid_w),

        .data_o (i_a_gaussian_data_w),
        .col_o  (i_a_gaussian_col_w),
        .row_o  (i_a_gaussian_row_w),
        .valid_o(i_a_gaussian_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gwf_window_w [2][2];
    logic [15:0]                 i_a_gwf_col_w;
    logic [15:0]                 i_a_gwf_row_w;
    logic                        i_a_gwf_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (2),
        .WINDOW_HEIGHT(2),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_window_fetcher (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_data_w),
        .col_i  (i_a_gaussian_col_w),
        .row_i  (i_a_gaussian_row_w),
        .valid_i(i_a_gaussian_valid_w),

        .window_o(i_a_gwf_window_w),
        .col_o   (i_a_gwf_col_w),
        .row_o   (i_a_gwf_row_w),
        .valid_o (i_a_gwf_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gdw_data_w;
    logic [15:0]                 i_a_gdw_col_w;
    logic [15:0]                 i_a_gdw_row_w;
    logic                        i_a_gdw_valid_w;

    downsampler_0_fp16 i_a_gaussian_downsampler (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_a_gwf_window_w),
        .kernel_i(box_2_2_kernel_w),
        .col_i   (i_a_gwf_col_w),
        .row_i   (i_a_gwf_row_w),
        .valid_i (i_a_gwf_valid_w),

        .data_o (i_a_gdw_data_w),
        .col_o  (i_a_gdw_col_w),
        .row_o  (i_a_gdw_row_w),
        .valid_o(i_a_gdw_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gdwz_data_w;
    logic [15:0]                 i_a_gdwz_col_w;
    logic [15:0]                 i_a_gdwz_row_w;
    logic                        i_a_gdwz_valid_w;

    zero_inserter #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .SCALE     (0)
    ) i_a_gaussian_downsampler_zero_inserter (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gdw_data_w),
        .col_i  (i_a_gdw_col_w),
        .row_i  (i_a_gdw_row_w),
        .valid_i(i_a_gdw_valid_w),

        .data_o (i_a_gdwz_data_w),
        .col_o  (i_a_gdwz_col_w),
        .row_o  (i_a_gdwz_row_w),
        .valid_o(i_a_gdwz_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gdwzwf_window_w [3][3];
    logic [15:0]                 i_a_gdwzwf_col_w;
    logic [15:0]                 i_a_gdwzwf_row_w;
    logic                        i_a_gdwzwf_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(3),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_downsampler_zero_fetcher (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gdwz_data_w),
        .col_i  (i_a_gdwz_col_w),
        .row_i  (i_a_gdwz_row_w),
        .valid_i(i_a_gdwz_valid_w),

        .window_o(i_a_gdwzwf_window_w),
        .col_o   (i_a_gdwzwf_col_w),
        .row_o   (i_a_gdwzwf_row_w),
        .valid_o (i_a_gdwzwf_valid_w)
    );


    logic [FP_WIDTH_REG - 1 : 0] i_a_gup_data_w ;
    logic [15:0]                 i_a_gup_col_w;
    logic [15:0]                 i_a_gup_row_w;
    logic                        i_a_gup_valid_w;

    upsampler_0_fp16 i_a_gaussian_upsampler (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_a_gdwzwf_window_w),
        .kernel_i(upsampler_3_3_kernel_w),
        .col_i   (i_a_gdwzwf_col_w),
        .row_i   (i_a_gdwzwf_row_w),
        .valid_i (i_a_gdwzwf_valid_w),

        .data_o (i_a_gup_data_w),
        .col_o  (i_a_gup_col_w),
        .row_o  (i_a_gup_row_w),
        .valid_o(i_a_gup_valid_w)
    );

    //----------------------
    // Buffering I_A (_b):
    // window fetcher - 1x5
    // gaussian horizontal 
    // window fetcher - 5x1
    // gaussian vertical 
    // window fetcher - 2x2
    // downsampler
    // zero inserter
    // window fecher  - 3x3
    // upsampler

    logic [FP_WIDTH_REG - 1 : 0] i_a_wfh_data_b_w;
    logic [15:0]                 i_a_wfh_col_b_w;
    logic [15:0]                 i_a_wfh_row_b_w;
    logic                        i_a_wfh_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_window_fetcher_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_i),
        .col_i  (col_i),
        .row_i  (row_i),
        .valid_i(valid_i),

        .data_o (i_a_wfh_data_b_w),
        .col_o  (i_a_wfh_col_b_w),
        .row_o  (i_a_wfh_row_b_w),
        .valid_o(i_a_wfh_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_bh_data_b_w;
    logic [15:0]                 i_a_bh_col_b_w;
    logic [15:0]                 i_a_bh_row_b_w;
    logic                        i_a_bh_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1)
    ) i_a_burt_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_wfh_data_b_w),
        .col_i  (i_a_wfh_col_b_w),
        .row_i  (i_a_wfh_row_b_w),
        .valid_i(i_a_wfh_valid_b_w),

        .data_o (i_a_bh_data_b_w),
        .col_o  (i_a_bh_col_b_w),
        .row_o  (i_a_bh_row_b_w),
        .valid_o(i_a_bh_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_wfv_data_b_w;
    logic [15:0]                 i_a_wfv_col_b_w;
    logic [15:0]                 i_a_wfv_row_b_w;
    logic                        i_a_wfv_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_window_fetcher_v_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_bh_data_b_w),
        .col_i  (i_a_bh_col_b_w),
        .row_i  (i_a_bh_row_b_w),
        .valid_i(i_a_bh_valid_b_w),

        .data_o (i_a_wfv_data_b_w),
        .col_o  (i_a_wfv_col_b_w),
        .row_o  (i_a_wfv_row_b_w),
        .valid_o(i_a_wfv_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_data_b_w;
    logic [15:0]                 i_a_gaussian_col_b_w;
    logic [15:0]                 i_a_gaussian_row_b_w;
    logic                        i_a_gaussian_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5)
    ) i_a_burt_v_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_wfv_data_b_w),
        .col_i  (i_a_wfv_col_b_w),
        .row_i  (i_a_wfv_row_b_w),
        .valid_i(i_a_wfv_valid_b_w),

        .data_o (i_a_gaussian_data_b_w),
        .col_o  (i_a_gaussian_col_b_w),
        .row_o  (i_a_gaussian_row_b_w),
        .valid_o(i_a_gaussian_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gwf_data_b_w;
    logic [15:0]                 i_a_gwf_col_b_w;
    logic [15:0]                 i_a_gwf_row_b_w;
    logic                        i_a_gwf_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (2),
        .WINDOW_HEIGHT(2),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_window_fetcher_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_data_b_w),
        .col_i  (i_a_gaussian_col_b_w),
        .row_i  (i_a_gaussian_row_b_w),
        .valid_i(i_a_gaussian_valid_b_w),

        .data_o (i_a_gwf_data_b_w),
        .col_o  (i_a_gwf_col_b_w),
        .row_o  (i_a_gwf_row_b_w),
        .valid_o(i_a_gwf_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gdw_data_b_w;
    logic [15:0]                 i_a_gdw_col_b_w;
    logic [15:0]                 i_a_gdw_row_b_w;
    logic                        i_a_gdw_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (2),
        .WINDOW_HEIGHT(2)
    ) i_a_gaussian_downsampler_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gwf_data_b_w),
        .col_i  (i_a_gwf_col_b_w),
        .row_i  (i_a_gwf_row_b_w),
        .valid_i(i_a_gwf_valid_b_w),

        .data_o (i_a_gdw_data_b_w),
        .col_o  (i_a_gdw_col_b_w),
        .row_o  (i_a_gdw_row_b_w),
        .valid_o(i_a_gdw_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gdwz_data_b_w;
    logic [15:0]                 i_a_gdwz_col_b_w;
    logic [15:0]                 i_a_gdwz_row_b_w;
    logic                        i_a_gdwz_valid_b_w;

    zero_inserter #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .SCALE     (0),
        .DISABLE   (1)
    ) i_a_gaussian_downsampler_zero_inserter_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gdw_data_b_w),
        .col_i  (i_a_gdw_col_b_w),
        .row_i  (i_a_gdw_row_b_w),
        .valid_i(i_a_gdw_valid_b_w),

        .data_o (i_a_gdwz_data_b_w),
        .col_o  (i_a_gdwz_col_b_w),
        .row_o  (i_a_gdwz_row_b_w),
        .valid_o(i_a_gdwz_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gdwzwf_data_b_w;
    logic [15:0]                 i_a_gdwzwf_col_b_w;
    logic [15:0]                 i_a_gdwzwf_row_b_w;
    logic                        i_a_gdwzwf_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(3),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_downsampler_zero_fetcher_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gdwz_data_b_w),
        .col_i  (i_a_gdwz_col_b_w),
        .row_i  (i_a_gdwz_row_b_w),
        .valid_i(i_a_gdwz_valid_b_w),

        .data_o (i_a_gdwzwf_data_b_w),
        .col_o  (i_a_gdwzwf_col_b_w),
        .row_o  (i_a_gdwzwf_row_b_w),
        .valid_o(i_a_gdwzwf_valid_b_w)
    );


    logic [FP_WIDTH_REG - 1 : 0] i_a_gup_data_b_w ;
    logic [15:0]                 i_a_gup_col_b_w;
    logic [15:0]                 i_a_gup_row_b_w;
    logic                        i_a_gup_valid_b_w;
    
    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(3)
    ) i_a_gaussian_upsampler_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gdwzwf_data_b_w),
        .col_i  (i_a_gdwzwf_col_b_w),
        .row_i  (i_a_gdwzwf_row_b_w),
        .valid_i(i_a_gdwzwf_valid_b_w),

        .data_o (i_a_gup_data_b_w),
        .col_o  (i_a_gup_col_b_w),
        .row_o  (i_a_gup_row_b_w),
        .valid_o(i_a_gup_valid_b_w)
    );

    ////////////////////////////////////////////////////////////////
    // I_T

    //----------------------
    // processing I_T:
    // window fetcher - 1x5
    // gaussian horizontal
    // window fetcher - 5x1
    // gaussian vertical
    // window fetcher - 2x2
    // downsampler

    logic [FP_WIDTH_REG - 1 : 0] i_t_wfh_window_w [1][5];
    logic [15:0]                 i_t_wfh_col_w;
    logic [15:0]                 i_t_wfh_row_w;
    logic                        i_t_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_window_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_i),
        .col_i  (col_i),
        .row_i  (row_i),
        .valid_i(valid_i),

        .window_o(i_t_wfh_window_w),
        .col_o   (i_t_wfh_col_w),
        .row_o   (i_t_wfh_row_w),
        .valid_o (i_t_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_bh_data_w;
    logic [15:0]                 i_t_bh_col_w;
    logic [15:0]                 i_t_bh_row_w;
    logic                        i_t_bh_valid_w;

    burt_h_0_fp16 i_t_burt_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_t_wfh_window_w),
        .kernel_i(bh_kernel_w),
        .col_i   (i_t_wfh_col_w),
        .row_i   (i_t_wfh_row_w),
        .valid_i (i_t_wfh_valid_w),

        .data_o (i_t_bh_data_w),
        .col_o  (i_t_bh_col_w),
        .row_o  (i_t_bh_row_w),
        .valid_o(i_t_bh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_wfv_window_w [5][1];
    logic [15:0]                 i_t_wfv_col_w;
    logic [15:0]                 i_t_wfv_row_w;
    logic                        i_t_wfv_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_bh_data_w),
        .col_i  (i_t_bh_col_w),
        .row_i  (i_t_bh_row_w),
        .valid_i(i_t_bh_valid_w),

        .window_o(i_t_wfv_window_w),
        .col_o   (i_t_wfv_col_w),
        .row_o   (i_t_wfv_row_w),
        .valid_o (i_t_wfv_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_data_w;
    logic [15:0]                 i_t_gaussian_col_w;
    logic [15:0]                 i_t_gaussian_row_w;
    logic                        i_t_gaussian_valid_w;

    burt_v_0_fp16 i_t_burt_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_t_wfv_window_w),
        .kernel_i(bv_kernel_w),
        .col_i   (i_t_wfv_col_w),
        .row_i   (i_t_wfv_row_w),
        .valid_i (i_t_wfv_valid_w),

        .data_o (i_t_gaussian_data_w),
        .col_o  (i_t_gaussian_col_w),
        .row_o  (i_t_gaussian_row_w),
        .valid_o(i_t_gaussian_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gwf_window_w [2][2];
    logic [15:0]                 i_t_gwf_col_w;
    logic [15:0]                 i_t_gwf_row_w;
    logic                        i_t_gwf_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (2),
        .WINDOW_HEIGHT(2),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_gaussian_window_fetcher (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_data_w),
        .col_i  (i_t_gaussian_col_w),
        .row_i  (i_t_gaussian_row_w),
        .valid_i(i_t_gaussian_valid_w),

        .window_o(i_t_gwf_window_w),
        .col_o   (i_t_gwf_col_w),
        .row_o   (i_t_gwf_row_w),
        .valid_o (i_t_gwf_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gdw_data_w;
    logic [15:0]                 i_t_gdw_col_w;
    logic [15:0]                 i_t_gdw_row_w;
    logic                        i_t_gdw_valid_w;

    downsampler_0_fp16 i_a_gaussian_downsampler (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_t_gwf_window_w),
        .kernel_i(box_2_2_kernel_w),
        .col_i   (i_t_gwf_col_w),
        .row_i   (i_t_gwf_row_w),
        .valid_i (i_t_gwf_valid_w),

        .data_o (i_t_gdw_data_w),
        .col_o  (i_t_gdw_col_w),
        .row_o  (i_t_gdw_row_w),
        .valid_o(i_t_gdw_valid_w)
    );

    //----------------------
    // Buffering I_T:
    // window fetcher - 1x5
    // gaussian horizontal 
    // window fetcher - 5x1
    // gaussian vertical 
    // window fetcher - 2x2
    // downsampler
    // zero inserter
    // window fecher  - 3x3
    // upsampler

    logic [FP_WIDTH_REG - 1 : 0] i_t_wfh_data_b_w;
    logic [15:0]                 i_t_wfh_col_b_w;
    logic [15:0]                 i_t_wfh_row_b_w;
    logic                        i_t_wfh_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_window_fetcher_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_i),
        .col_i  (col_i),
        .row_i  (row_i),
        .valid_i(valid_i),

        .data_o (i_t_wfh_data_b_w),
        .col_o  (i_t_wfh_col_b_w),
        .row_o  (i_t_wfh_row_b_w),
        .valid_o(i_t_wfh_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_bh_data_b_w;
    logic [15:0]                 i_t_bh_col_b_w;
    logic [15:0]                 i_t_bh_row_b_w;
    logic                        i_t_bh_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1)
    ) i_t_burt_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_wfh_data_b_w),
        .col_i  (i_t_wfh_col_b_w),
        .row_i  (i_t_wfh_row_b_w),
        .valid_i(i_t_wfh_valid_b_w),

        .data_o (i_t_bh_data_b_w),
        .col_o  (i_t_bh_col_b_w),
        .row_o  (i_t_bh_row_b_w),
        .valid_o(i_t_bh_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_wfv_data_b_w;
    logic [15:0]                 i_t_wfv_col_b_w;
    logic [15:0]                 i_t_wfv_row_b_w;
    logic                        i_t_wfv_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_window_fetcher_v_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_bh_data_b_w),
        .col_i  (i_t_bh_col_b_w),
        .row_i  (i_t_bh_row_b_w),
        .valid_i(i_t_bh_valid_b_w),

        .data_o (i_t_wfv_data_b_w),
        .col_o  (i_t_wfv_col_b_w),
        .row_o  (i_t_wfv_row_b_w),
        .valid_o(i_t_wfv_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_data_b_w;
    logic [15:0]                 i_t_gaussian_col_b_w;
    logic [15:0]                 i_t_gaussian_row_b_w;
    logic                        i_t_gaussian_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5)
    ) i_t_burt_v_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_wfv_data_b_w),
        .col_i  (i_t_wfv_col_b_w),
        .row_i  (i_t_wfv_row_b_w),
        .valid_i(i_t_wfv_valid_b_w),

        .data_o (i_t_gaussian_data_b_w),
        .col_o  (i_t_gaussian_col_b_w),
        .row_o  (i_t_gaussian_row_b_w),
        .valid_o(i_t_gaussian_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gwf_data_b_w;
    logic [15:0]                 i_t_gwf_col_b_w;
    logic [15:0]                 i_t_gwf_row_b_w;
    logic                        i_t_gwf_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (2),
        .WINDOW_HEIGHT(2),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_gaussian_window_fetcher_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_data_b_w),
        .col_i  (i_t_gaussian_col_b_w),
        .row_i  (i_t_gaussian_row_b_w),
        .valid_i(i_t_gaussian_valid_b_w),

        .data_o (i_t_gwf_data_b_w),
        .col_o  (i_t_gwf_col_b_w),
        .row_o  (i_t_gwf_row_b_w),
        .valid_o(i_t_gwf_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gdw_data_b_w;
    logic [15:0]                 i_t_gdw_col_b_w;
    logic [15:0]                 i_t_gdw_row_b_w;
    logic                        i_t_gdw_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (2),
        .WINDOW_HEIGHT(2)
    ) i_t_gaussian_downsampler_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gwf_data_b_w),
        .col_i  (i_t_gwf_col_b_w),
        .row_i  (i_t_gwf_row_b_w),
        .valid_i(i_t_gwf_valid_b_w),

        .data_o (i_t_gdw_data_b_w),
        .col_o  (i_t_gdw_col_b_w),
        .row_o  (i_t_gdw_row_b_w),
        .valid_o(i_t_gdw_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gdwz_data_b_w;
    logic [15:0]                 i_t_gdwz_col_b_w;
    logic [15:0]                 i_t_gdwz_row_b_w;
    logic                        i_t_gdwz_valid_b_w;

    zero_inserter #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .SCALE     (0),
        .DISABLE   (1)
    ) i_t_gaussian_downsampler_zero_inserter_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gdw_data_b_w),
        .col_i  (i_t_gdw_col_b_w),
        .row_i  (i_t_gdw_row_b_w),
        .valid_i(i_t_gdw_valid_b_w),

        .data_o (i_t_gdwz_data_b_w),
        .col_o  (i_t_gdwz_col_b_w),
        .row_o  (i_t_gdwz_row_b_w),
        .valid_o(i_t_gdwz_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gdwzwf_data_b_w;
    logic [15:0]                 i_t_gdwzwf_col_b_w;
    logic [15:0]                 i_t_gdwzwf_row_b_w;
    logic                        i_t_gdwzwf_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(3),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_gaussian_downsampler_zero_fetcher_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gdwz_data_b_w),
        .col_i  (i_t_gdwz_col_b_w),
        .row_i  (i_t_gdwz_row_b_w),
        .valid_i(i_t_gdwz_valid_b_w),

        .data_o (i_t_gdwzwf_data_b_w),
        .col_o  (i_t_gdwzwf_col_b_w),
        .row_o  (i_t_gdwzwf_row_b_w),
        .valid_o(i_t_gdwzwf_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gup_data_b_w ;
    logic [15:0]                 i_t_gup_col_b_w;
    logic [15:0]                 i_t_gup_row_b_w;
    logic                        i_t_gup_valid_b_w;
    
    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(3)
    ) i_t_gaussian_upsampler_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gdwzwf_data_b_w),
        .col_i  (i_t_gdwzwf_col_b_w),
        .row_i  (i_t_gdwzwf_row_b_w),
        .valid_i(i_t_gdwzwf_valid_b_w),

        .data_o (i_t_gup_data_b_w),
        .col_o  (i_t_gup_col_b_w),
        .row_o  (i_t_gup_row_b_w),
        .valid_o(i_t_gup_valid_b_w)
    );

    ////////////////////////////////////////////////////////////////
    // Laplacian = I_A - (I_A gaussianed, downsampled, then upsampled)

    logic [FP_WIDTH_REG - 1 : 0] i_a_gup_data_negative_w;
    always_comb begin
        i_a_gup_data_negative_w[FP_WIDTH_REG - 1] = !i_a_gup_data_w[FP_WIDTH_REG - 1];
        i_a_gup_data_negative_w[FP_WIDTH_REG - 2 : 0] = i_a_gup_data_w[FP_WIDTH_REG - 2 : 0];
    end

    logic [FP_WIDTH_REG - 1 : 0] laplacian_data_w;
    logic [15:0]                 laplacian_col_w;
    logic [15:0]                 laplacian_row_w;
    logic                        laplacian_valid_w;

    floating_point_adder #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) laplacian_adder (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .fp_a_i (i_a_gup_data_b_w),
        .fp_b_i (i_a_gup_data_negative_w),
        .valid_i(i_a_gup_valid_w),

        .fp_o   (laplacian_data_w),
        .valid_o(laplacian_valid_w)
    ); 

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) laplacian_col_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_a_gup_col_w),
        .fp_o  (laplacian_col_w)
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) laplacian_row_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_a_gup_row_w),
        .fp_o  (laplacian_row_w)
    );

    ////////////////////////////////////////////////////////////////
    // V calculation using A value (a_i)
    // V = laplacian * A
    // includes delays to accomodate W calculating

    logic [FP_WIDTH_REG - 1 : 0] v_data_w [3];
    logic [15:0]                 v_col_w  [3];
    logic [15:0]                 v_row_w  [3];
    logic                        v_valid_w[3];

    floating_point_multiplier #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) v_multiplier (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i (laplacian_data_w),
        .fp_b_i (a_i),
        .valid_i(laplacian_valid_w),
        .fp_o   (v_data_w[0]),
        .valid_o(v_valid_w[0])
    );

    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) v_col_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(laplacian_col_w),
        .fp_o  (v_col_w[0])
    );

    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) v_row_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(laplacian_row_w),
        .fp_o  (v_row_w[0])
    );

    // -----------------------------

    floating_point_multiplier_z #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) v_data_delay_0 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i (v_data_w [0]),
        .valid_i(v_valid_w[0]),
        .fp_o   (v_data_w [1]),
        .valid_o(v_valid_w[1])
    );
    
    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) v_col_delay_0 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(v_col_w[0]),
        .fp_o  (v_col_w[1])
    );

    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) v_row_delay_0 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(v_row_w[0]),
        .fp_o  (v_row_w[1])
    );

    // -----------------------------

    floating_point_adder_z #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) v_data_delay_1 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i (v_data_w [1]),
        .valid_i(v_valid_w[1])
        .fp_o   (v_data_w [2])
        .valid_o(v_valid_w[2])
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) v_col_delay_1 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(v_col_w[1]),
        .fp_o  (v_col_w[2])
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) v_row_delay_1 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(v_row_w[1]),
        .fp_o  (v_row_w[2])
    );

    ////////////////////////////////////////////////////////////////
    // W calculation using A value (b_i)
    // W = (laplacian * A * B) - i_t = (V * B) - i_t
    // includes i_t delays

    logic [FP_WIDTH_REG - 1 : 0] i_t_data_w [3];
    logic [15:0]                 i_t_col_w  [3];
    logic [15:0]                 i_t_row_w  [3];
    logic                        i_t_valid_w[3];

    floating_point_adder_z #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) i_t_delay_0 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i (i_t_gup_data_b_w),
        .valid_i(i_t_gup_valid_b_w)
        .fp_o   (i_t_data_w [0]),
        .valid_o(i_t_valid_w[0])
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_t_col_delay_0 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_t_gup_col_b_w),
        .fp_o  (i_t_col_w[0])
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_t_row_delay_0 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_t_gup_row_b_w),
        .fp_o  (i_t_row_w[0])
    );

    // -----------------------------

    floating_point_multiplier_z #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) i_t_delay_1 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i (i_t_data_w [0]),
        .valid_i(i_t_valid_w[0])
        .fp_o   (i_t_data_w [1]),
        .valid_o(i_t_valid_w[1])
    );

    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_t_col_delay_1 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_t_col_w[0]),
        .fp_o  (i_t_col_w[1])
    );

    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_t_row_delay_1 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_t_row_w[0]),
        .fp_o  (i_t_row_w[1])
    );

    // -----------------------------

    floating_point_multiplier_z #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) i_t_delay_2 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i (i_t_data_w [1]),
        .valid_i(i_t_valid_w[1])
        .fp_o   (i_t_data_w [2]),
        .valid_o(i_t_valid_w[2])
    );

    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_t_col_delay_2 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_t_col_w[1]),
        .fp_o  (i_t_col_w[2])
    );

    floating_point_multiplier_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_t_row_delay_2 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_t_row_w[1]),
        .fp_o  (i_t_row_w[2])
    );

    // ----------------------------- V * B
    logic [FP_WIDTH_REG - 1 : 0] v_b_data_w;

    floating_point_multiplier #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) v_b_multiplier (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(v_data_w[0]),
        .fp_b_i(b_i),
        .fp_o(v_b_data_w),
    );

    // ----------------------------- V_B - i_t
    logic [FP_WIDTH_REG - 1 : 0] i_t_data_negative_w;
    always_comb begin
        i_t_data_negative[FP_WIDTH_REG - 1]     = !i_t_data_w[2][FP_WIDTH_REG - 1];
        i_t_data_negative[FP_WIDTH_REG - 2 : 0] = i_t_data_w[2][FP_WIDTH_REG - 2 : 0];
    end

    logic [FP_WIDTH_REG - 1 : 0] w_data_w;

    floating_point_adder #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) w_adder (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i (v_b_data_w),
        .fp_b_i (i_t_data_negative_w),
        .fp_o   (w_data_w),
    ); 

    ////////////////////////////////////////////////////////////////
    // V and W window fetchers (depending on if DX_DY_ENABLE)
    logic [FP_WIDTH_REG - 1 : 0] v_wf_window_w [3][3];
    logic [15:0]                 v_wf_col_w;
    logic [15:0]                 v_wf_row_w;
    logic                        v_wf_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] w_wf_window_w [3][3];
    logic [15:0]                 w_wf_col_w;
    logic [15:0]                 w_wf_row_w;
    logic                        w_wf_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] v_pass_data_w;
    logic [FP_WIDTH_REG - 1 : 0] v_dx_data_w;
    logic [FP_WIDTH_REG - 1 : 0] v_dy_data_w;
    logic [15:0]                 v_pass_col_w;
    logic [15:0]                 v_pass_row_w;
    logic                        v_pass_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] w_pass_data_w;
    logic [FP_WIDTH_REG - 1 : 0] w_dx_data_w;
    logic [FP_WIDTH_REG - 1 : 0] w_dy_data_w;

    logic [FP_WIDTH_REG - 1 : 0] v_added_data;
    logic [15:0]                 v_added_col_w;
    logic [15:0]                 v_added_row_w;
    logic [15:0]                 v_added_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] w_added_data;

    generate
        if(DX_DY_ENABLE != 0) begin
            window_fetcher #(
                .DATA_WIDTH(FP_WIDTH_REG),
                .IMAGE_WIDTH(IMAGE_WIDTH),
                .IMAGE_HEIGHT(IMAGE_HEIGHT),
                .WINDOW_WIDTH(3),
                .WINDOW_HEIGHT(3)
            ) v_window_fetcher (
                    .clk_i(clk_i),
                    .rst_i(rst_i),

                    .data_i (v_data_w[2]),
                    .col_i  (v_col_w[2]),
                    .row_i  (v_row_w[2]),
                    .valid_i(v_valid_w[2]),

                    .window_o(v_wf_window_w),
                    .col_o   (v_wf_col_w),
                    .row_o   (v_wf_row_w),
                    .valid_o (v_wf_valid_w)
            );

            window_fetcher #(
                .DATA_WIDTH(FP_WIDTH_REG),
                .IMAGE_WIDTH(IMAGE_WIDTH),
                .IMAGE_HEIGHT(IMAGE_HEIGHT),
                .WINDOW_WIDTH(3),
                .WINDOW_HEIGHT(3)
            ) w_window_fetcher (
                .clk_i(clk_i),
                .rst_i(rst_i),

                .data_i (w_data_w),
                .col_i  (v_col_w[2]),
                .row_i  (v_row_w[2]),
                .valid_i(v_valid_w[2]),

                .window_o(w_wf_window_w),
                .col_o   (w_wf_col_w),
                .row_o   (w_wf_row_w),
                .valid_o (w_wf_valid_w)
            );

            pass_0_fp16 v_pass (
                .clk_i(clk_i),
                .rst_i(rst_i),

                .window_i(v_wf_window_w),
                .kernel_i(pass_3_3_kernel_w),
                .col_i   (w_wf_col_w),
                .row_i   (w_wf_row_w),
                .valid_i (w_wf_valid_w),

                .data_o (v_pass_data_w),
                .col_o  (v_pass_col_w),
                .row_o  (v_pass_row_w),
                .valid_o(v_pass_valid_w)
            );

            dx_0_fp16 v_dx (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .window_i(v_wf_window_w),
                .kernel_i(dx_3_3_kernel_w),
                .data_o  (dx_pass_data_w),
            );

            dy_0_fp16 v_dy (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .window_i(v_wf_window_w),
                .kernel_i(dy_3_3_kernel_w),
                .data_o  (dy_pass_data_w),
            );


        end
    endgenerate

    ////////////////////////////////////////////////////////////////
    // Assigning i_a and i_t downsampled outputs
    /*
    assign i_a_downsample_o   = i_a_gdw_data_w;
    assign i_t_downsample_o   = i_t_gdw_data_w;
    assign col_downsample_o   = i_a_gdw_col_w;
    assign row_downsample_o   = i_a_gdw_row_w;
    assign valid_downsample_o = i_a_gdw_valid_w;
    */

    assign i_a_downsample_o   = laplacian_data_w;
    assign col_downsample_o   = laplacian_col_w;
    assign row_downsample_o   = laplacian_row_w;
    assign valid_downsample_o = laplacian_valid_w;

endmodule
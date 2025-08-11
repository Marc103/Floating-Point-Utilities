/*
 * Zero'ith scale of DFDD core. Tuned to work with
 * FP16.
 *
 */


module zero_scale #(
    parameter IMAGE_WIDTH,
    parameter IMAGE_HEIGHT,

    parameter DX_DY_ENABLE = 0

    ////////////////////////////////////////////////////////////////
    // Local parameters
    parameter EXP_WIDTH = 5,
    parameter FRAC_WIDTH = 10,
    parameter FP_WIDTH_REG = 1 + FRAC_WIDTH + EXP_WIDTH,
    
) (
    input [FP_WIDTH_REG - 1 : 0]  i_a_i,
    input [FP_WIDTH_REG - 1 : 0]  i_t_i,
    input [15:0]                  col_i,
    input [15:0]                  row_i,
    input                         valid_i,

    input [FP_WIDTH_REG - 1 : 0]  w_i [3],   

    output [FP_WIDTH_REG - 1 : 0] i_a_downsample_o,
    output [FP_WIDTH_REG - 1 : 0] i_t_downsample_o,
    output [15:0]                 col_downsample_o,
    output [15:0]                 row_downsample_o,
    output                        valid_downsample_o,

    output [FP_WIDTH_REG - 1 : 0] z_o,
    output [FP_WIDTH_REG - 1 : 0] c_o,
    output [15:0]                 col_o,
    output [15:0]                 row_o,
    output                        valid_o,

);

    ////////////////////////////////////////////////////////////////
    // Kernel Value Setups

    logic [FP_WIDTH_REG - 1 : 0] bh_kernel_w [1][5];
    always_comb begin
        i_a_bh_kernel[0][0] = 16'h2c00;
        i_a_bh_kernel[0][1] = 16'h3400;
        i_a_bh_kernel[0][2] = 16'h3600;
        i_a_bh_kernel[0][3] = 16'h3400;
        i_a_bh_kernel[0][4] = 16'h2c00;
    end

    logic [FP_WIDTH_REG - 1 : 0] bv_kernel_w [5][1];
    always_comb begin
        i_a_bh_kernel[0][0] = 16'h2c00;
        i_a_bh_kernel[1][0] = 16'h3400;
        i_a_bh_kernel[2][0] = 16'h3600;
        i_a_bh_kernel[3][0] = 16'h3400;
        i_a_bh_kernel[4][0] = 16'h2c00;
    end

    logic [FP_WIDTH_REG - 1 : 0] box_2_2_kernel_w [2][2];
    always_comb begin
        box_2_2_kernel_w[0][0] = 16'h3400;
        box_2_2_kernel_w[0][1] = 16'h3400;
        box_2_2_kernel_w[1][0] = 16'h3400;
        box_2_2_kernel_w[0][1] = 16'h3400;
    end

    logic [FP_WIDTH_REG - 1 : 0] upsampler_3_3_kernel_w [2][2];
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

    ////////////////////////////////////////////////////////////////
    // I_A

    //----------------------
    // processing:
    // window fetcher
    // gaussian horizontal
    // window fetcher
    // gaussian vertical
    // downsampler
    // zero inserter
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
        .WINDOW_HEIGHT(1)
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

    logic [FP_WIDTH_REG - 1 : 0] i_a_wfv_window_w [1][5];
    logic [15:0]                 i_a_wfv_col_w;
    logic [15:0]                 i_a_wfv_row_w;
    logic                        i_a_wfv_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5)
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
        .valid_o (i_a_wfv_valid_w,)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_data_w;
    logic [15:0]                 i_a_gaussian_col_w;
    logic [15:0]                 i_a_gaussian_row_w;
    logic                        i_a_gaussian_valid_w;

    burt_h_0_fp16 i_a_burt_v (
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
        .WINDOW_WIDTH (WINDOW_WIDTH),
        .WINDOW_HEIGHT(WINDOW_HEIGHT)
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
        .valid_o(i_a_gdwz_valid_w),
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
        .WINDOW_HEIGHT(3)
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
    // buffers (_b) :
    // window fetcher 
    // gaussian horizontal
    // guassian vertical
    // downsample
    // upsample 

    // assigning i_a_downsample
    assign i_a_downsample_o   = i_a_gdw_data_w;
    assign col_downsample_o   = i_a_gdw_col_w;
    assign row_downsample_o   = i_a_gdw_row_w;
    assign valid_downsample_o = i_a_gdw_valid_w;

endmodule
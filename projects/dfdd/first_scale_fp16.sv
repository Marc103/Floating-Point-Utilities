/*
 * First scale of DFDD core. Tuned to work with
 * FP16.
 *
 */


module first_scale_fp16 #(
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

    output [FP_WIDTH_REG - 1 : 0] v_o,
    output [FP_WIDTH_REG - 1 : 0] w_o, // big W
    output [15:0]                 col_o,
    output [15:0]                 row_o,
    output                        valid_o
);

    ////////////////////////////////////////////////////////////////
    // Kernel Value Setups

    logic [FP_WIDTH_REG - 1 : 0] bh_kernel_w [1][9];
    always_comb begin
        bh_kernel_w[0][0] = 16'h2c00;
        bh_kernel_w[0][1] = 16'h0000;
        bh_kernel_w[0][2] = 16'h3400;
        bh_kernel_w[0][3] = 16'h0000;
        bh_kernel_w[0][4] = 16'h3600;
        bh_kernel_w[0][5] = 16'h0000;
        bh_kernel_w[0][6] = 16'h3400;
        bh_kernel_w[0][7] = 16'h0000;
        bh_kernel_w[0][8] = 16'h2c00;
    end

    logic [FP_WIDTH_REG - 1 : 0] bv_kernel_w [9][1];
    always_comb begin
        bv_kernel_w[0][0] = 16'h2c00;
        bv_kernel_w[1][0] = 16'h0000;
        bv_kernel_w[2][0] = 16'h3400;
        bv_kernel_w[3][0] = 16'h0000;
        bv_kernel_w[4][0] = 16'h3600;
        bv_kernel_w[5][0] = 16'h0000;
        bv_kernel_w[6][0] = 16'h3400;
        bv_kernel_w[7][0] = 16'h0000;
        bv_kernel_w[8][0] = 16'h2c00;
    end

    logic [FP_WIDTH_REG - 1 : 0] box_h_kernel_w [1][3];
    always_comb begin
        box_h_kernel_w[0][0] = 16'h3800;
        box_h_kernel_w[0][1] = 16'h0000;
        box_h_kernel_w[0][2] = 16'h3800;
    end

    logic [FP_WIDTH_REG - 1 : 0] box_v_kernel_w [3][1];
    always_comb begin
        box_v_kernel_w[0][0] = 16'h3800;
        box_v_kernel_w[1][0] = 16'h0000;
        box_v_kernel_w[2][0] = 16'h3800;
    end

    logic [FP_WIDTH_REG - 1 : 0] upsampler_h_0_kernel_w [1][3];
    always_comb begin
        upsampler_h_0_kernel_w[0][0] = 16'h3800;
        upsampler_h_0_kernel_w[0][1] = 16'h3c00;
        upsampler_h_0_kernel_w[0][2] = 16'h3800;
    end

    logic [FP_WIDTH_REG - 1 : 0] upsampler_v_0_kernel_w [3][1];
    always_comb begin
        upsampler_v_0_kernel_w[0][0] = 16'h3800;
        upsampler_v_0_kernel_w[1][0] = 16'h3c00;
        upsampler_v_0_kernel_w[2][0] = 16'h3800;
    end

    logic [FP_WIDTH_REG - 1 : 0] upsampler_h_1_kernel_w [1][5];
    always_comb begin
        upsampler_h_1_kernel_w[0][0] = 16'h3800;
        upsampler_h_1_kernel_w[0][1] = 16'h0000;
        upsampler_h_1_kernel_w[0][2] = 16'h3c00;
        upsampler_h_1_kernel_w[0][3] = 16'h0000;
        upsampler_h_1_kernel_w[0][4] = 16'h3800;
    end

    logic [FP_WIDTH_REG - 1 : 0] upsampler_v_1_kernel_w [5][1];
    always_comb begin
        upsampler_v_1_kernel_w[0][0] = 16'h3800;
        upsampler_v_1_kernel_w[1][0] = 16'h0000;
        upsampler_v_1_kernel_w[2][0] = 16'h3c00;
        upsampler_v_1_kernel_w[3][0] = 16'h0000;
        upsampler_v_1_kernel_w[4][0] = 16'h3800;
    end

    logic [FP_WIDTH_REG - 1 : 0] pass_5_5_kernel_w [5][5];
    always_comb begin
        for(int r = 0; r < 5; r++) begin
            for(int c = 0; c < 5; c++) begin
                pass_5_5_kernel_w[r][c] = 16'h0000;
            end
        end
        pass_5_5_kernel_w[2][2] = 16'h3c00;
    end

    logic [FP_WIDTH_REG - 1 : 0] dx_5_5_kernel_w [5][5];
    always_comb begin
        for(int r = 0; r < 5; r++) begin
            for(int c = 0; c < 5; c++) begin
                dx_5_5_kernel_w[r][c] = 16'h0000;
            end
        end
        dx_5_5_kernel_w[2][0] = 16'hbc00;
        dx_5_5_kernel_w[2][4] = 16'h3c00;
    end

    logic [FP_WIDTH_REG - 1 : 0] dy_5_5_kernel_w [5][5];
    always_comb begin
        for(int r = 0; r < 5; r++) begin
            for(int c = 0; c < 5; c++) begin
                dy_5_5_kernel_w[r][c] = 16'h0000;
            end
        end
        dy_5_5_kernel_w[0][2] = 16'hbc00;
        dy_5_5_kernel_w[4][2] = 16'h3c00;
    end

    logic [FP_WIDTH_REG - 1 : 0] acc_kernel_w [1][3];
    always_comb begin
        acc_kernel_w[0][0] = 16'h3c00;
        acc_kernel_w[0][1] = 16'h3c00;
        acc_kernel_w[0][2] = 16'h3c00;
    end

    ////////////////////////////////////////////////////////////////
    // I_A and I_A buffered interleaved (for data zipping)
    // I_A is at MSB, I buffered is at LSB
    //----------------------
    // processing I_A / I_A_B (ia / iab):
    //
    // window fetcher ia - 1x9
    // gaussian horizontal ia
    //
    // window fetcher iab - 1x9
    // gaussian horizontal iab
    //
    //--------------------------------------------
    // window fetcher zipped data - 9x1
    //
    // gaussian vertical ia
    // window fetcher ia - 1x3
    // downsampler horizontal ia
    //
    // gaussian vertical iab
    // window fetcher iab - 1x3
    // downsampler horizontal iab 
    //
    //--------------------------------------------
    // window fetcher zipped data - 3x1
    //
    // downsampler vertical ia
    // zero inserter ia
    // window fetcher ia - 1x5
    // upsampler horizontal ia
    //
    // downsampler vertical iab
    // zero inserter iab
    // window fetcher iab - 1x5
    // upsampler horizontal iab
    //
    //--------------------------------------------
    // window fetcher zipped data - 5x1
    //
    // upsampler vertical ia
    //
    // upsampler vertical iab

    logic [FP_WIDTH_REG - 1 : 0] i_a_wfh_window_w [1][9];
    logic [15:0]                 i_a_wfh_col_w;
    logic [15:0]                 i_a_wfh_row_w;
    logic                        i_a_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (9),
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

    burt_h_1_fp16 i_a_burt_h (
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

    logic [FP_WIDTH_REG - 1 : 0] i_a_wfh_data_b_w;
    logic [15:0]                 i_a_wfh_col_b_w;
    logic [15:0]                 i_a_wfh_row_b_w;
    logic                        i_a_wfh_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (9),
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
        .WINDOW_WIDTH (9),
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

    //--------------------------------------------
    // ------------- zip --------------
    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_a_bh_zip_data_w;
    logic [15:0]                       i_a_bh_zip_col_w;
    logic [15:0]                       i_a_bh_zip_row_w;
    logic                              i_a_bh_zip_valid_w;

    assign i_a_bh_zip_data_w  = {i_a_bh_data_w, i_a_bh_data_b_w};
    assign i_a_bh_zip_col_w   = i_a_bh_col_w;
    assign i_a_bh_zip_row_w   = i_a_bh_row_w;
    assign i_a_bh_zip_valid_w = i_a_bh_valid_w;

    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_a_zip_wfv_window_w [9][1];
    logic [15:0]                       i_a_zip_wfv_col_w;
    logic [15:0]                       i_a_zip_wfv_row_w;
    logic                              i_a_zip_wfv_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_a_wfv_window_w [9][1];
    logic [15:0]                 i_a_wfv_col_w;
    logic [15:0]                 i_a_wfv_row_w;
    logic                        i_a_wfv_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_a_wfv_data_b_w;
    logic [15:0]                 i_a_wfv_col_b_w;
    logic [15:0]                 i_a_wfv_row_b_w;
    logic                        i_a_wfv_valid_b_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG * 2),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(9),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_zip_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_bh_zip_data_w),
        .col_i  (i_a_bh_zip_col_w),
        .row_i  (i_a_bh_zip_row_w),
        .valid_i(i_a_bh_zip_valid_w),

        .window_o(i_a_zip_wfv_window_w),
        .col_o   (i_a_zip_wfv_col_w),
        .row_o   (i_a_zip_wfv_row_w),
        .valid_o (i_a_zip_wfv_valid_w)
    );

    // unzip
    always_comb begin
        for(int c = 0; c < 9; c++) begin
            i_a_wfv_window_w[c][0] = i_a_zip_wfv_window_w[c][0][(FP_WIDTH_REG * 2) - 1 : FP_WIDTH_REG];
        end
        i_a_wfv_data_b_w = i_a_zip_wfv_window_w[4][0][FP_WIDTH_REG - 1 : 0];

        i_a_wfv_col_w   = i_a_zip_wfv_col_w;
        i_a_wfv_row_w   = i_a_zip_wfv_row_w;
        i_a_wfv_valid_w = i_a_zip_wfv_valid_w;

        i_a_wfv_col_b_w   = i_a_zip_wfv_col_w;
        i_a_wfv_row_b_w   = i_a_zip_wfv_row_w;
        i_a_wfv_valid_b_w = i_a_zip_wfv_valid_w;
    end

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_data_w;
    logic [15:0]                 i_a_gaussian_col_w;
    logic [15:0]                 i_a_gaussian_row_w;
    logic                        i_a_gaussian_valid_w;

    burt_v_1_fp16 i_a_burt_v (
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

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_wfh_window_w [1][3];
    logic [15:0]                 i_a_gaussian_wfh_col_w;
    logic [15:0]                 i_a_gaussian_wfh_row_w;
    logic                        i_a_gaussian_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_window_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_data_w),
        .col_i  (i_a_gaussian_col_w),
        .row_i  (i_a_gaussian_row_w),
        .valid_i(i_a_gaussian_valid_w),

        .window_o(i_a_gaussian_wfh_window_w),
        .col_o   (i_a_gaussian_wfh_col_w),
        .row_o   (i_a_gaussian_wfh_row_w),
        .valid_o (i_a_gaussian_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downh_data_w;
    logic [15:0]                 i_a_gaussian_downh_col_w;
    logic [15:0]                 i_a_gaussian_downh_row_w;
    logic                        i_a_gaussian_downh_valid_w;

    downsampler_h_1_fp16 i_a_downsampler_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_a_gaussian_wfh_window_w),
        .kernel_i(box_h_kernel_w),
        .col_i   (i_a_gaussian_wfh_col_w),
        .row_i   (i_a_gaussian_wfh_row_w),
        .valid_i (i_a_gaussian_wfh_valid_w),

        .data_o  (i_a_gaussian_downh_data_w),
        .col_o   (i_a_gaussian_downh_col_w),
        .row_o   (i_a_gaussian_downh_row_w),
        .valid_o (i_a_gaussian_downh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_data_b_w;
    logic [15:0]                 i_a_gaussian_col_b_w;
    logic [15:0]                 i_a_gaussian_row_b_w;
    logic                        i_a_gaussian_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(9)
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

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_wfh_data_b_w;
    logic [15:0]                 i_a_gaussian_wfh_col_b_w;
    logic [15:0]                 i_a_gaussian_wfh_row_b_w;
    logic                        i_a_gaussian_wfh_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_window_fetcher_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_data_b_w),
        .col_i  (i_a_gaussian_col_b_w),
        .row_i  (i_a_gaussian_row_b_w),
        .valid_i(i_a_gaussian_valid_b_w),

        .data_o  (i_a_gaussian_wfh_data_b_w),
        .col_o   (i_a_gaussian_wfh_col_b_w),
        .row_o   (i_a_gaussian_wfh_row_b_w),
        .valid_o (i_a_gaussian_wfh_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downh_data_b_w;
    logic [15:0]                 i_a_gaussian_downh_col_b_w;
    logic [15:0]                 i_a_gaussian_downh_row_b_w;
    logic                        i_a_gaussian_downh_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1)
    ) i_a_downsampler_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i  (i_a_gaussian_wfh_data_b_w),
        .col_i   (i_a_gaussian_wfh_col_b_w),
        .row_i   (i_a_gaussian_wfh_row_b_w),
        .valid_i (i_a_gaussian_wfh_valid_b_w),

        .data_o  (i_a_gaussian_downh_data_b_w),
        .col_o   (i_a_gaussian_downh_col_b_w),
        .row_o   (i_a_gaussian_downh_row_b_w),
        .valid_o (i_a_gaussian_downh_valid_b_w)
    );

    //--------------------------------------------
    // ------------- zip --------------
    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_a_gaussian_downh_zip_data_w;
    logic [15:0]                       i_a_gaussian_downh_zip_col_w;
    logic [15:0]                       i_a_gaussian_downh_zip_row_w;
    logic                              i_a_gaussian_downh_zip_valid_w;

    assign i_a_gaussian_downh_zip_data_w  = {i_a_gaussian_downh_data_w, i_a_gaussian_downh_data_b_w};
    assign i_a_gaussian_downh_zip_col_w   = i_a_gaussian_downh_col_w;
    assign i_a_gaussian_downh_zip_row_w   = i_a_gaussian_downh_row_w;
    assign i_a_gaussian_downh_zip_valid_w = i_a_gaussian_downh_valid_w;

    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_a_gaussian_zip_wfv_window_w [3][1];
    logic [15:0]                       i_a_gaussian_zip_wfv_col_w;
    logic [15:0]                       i_a_gaussian_zip_wfv_row_w;
    logic                              i_a_gaussian_zip_wfv_valid_w;


    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_wfv_window_w [3][1];
    logic [15:0]                 i_a_gaussian_wfv_col_w;
    logic [15:0]                 i_a_gaussian_wfv_row_w;
    logic                        i_a_gaussian_wfv_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_wfv_data_b_w;
    logic [15:0]                 i_a_gaussian_wfv_col_b_w;
    logic [15:0]                 i_a_gaussian_wfv_row_b_w;
    logic                        i_a_gaussian_wfv_valid_b_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG * 2),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(3),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_zip_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_downh_zip_data_w),
        .col_i  (i_a_gaussian_downh_zip_col_w),
        .row_i  (i_a_gaussian_downh_zip_row_w),
        .valid_i(i_a_gaussian_downh_zip_valid_w),

        .window_o(i_a_gaussian_zip_wfv_window_w),
        .col_o   (i_a_gaussian_zip_wfv_col_w),
        .row_o   (i_a_gaussian_zip_wfv_row_w),
        .valid_o (i_a_gaussian_zip_wfv_valid_w)
    );

    // unzip
    always_comb begin
        for(int c = 0; c < 3; c++) begin
            i_a_gaussian_wfv_window_w[c][0] = i_a_gaussian_zip_wfv_window_w[c][0][(FP_WIDTH_REG * 2) - 1 : FP_WIDTH_REG];
        end
        i_a_gaussian_wfv_data_b_w = i_a_gaussian_zip_wfv_window_w[0][0];

        i_a_gaussian_wfv_col_w   = i_a_gaussian_zip_wfv_col_w;
        i_a_gaussian_wfv_row_w   = i_a_gaussian_zip_wfv_row_w;
        i_a_gaussian_wfv_valid_w = i_a_gaussian_zip_wfv_valid_w;

        i_a_gaussian_wfv_col_b_w   = i_a_gaussian_zip_wfv_col_w;
        i_a_gaussian_wfv_row_b_w   = i_a_gaussian_zip_wfv_row_w;
        i_a_gaussian_wfv_valid_b_w = i_a_gaussian_zip_wfv_valid_w;
    end

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downsampled_data_w;
    logic [15:0]                 i_a_gaussian_downsampled_col_w;
    logic [15:0]                 i_a_gaussian_downsampled_row_w;
    logic                        i_a_gaussian_downsampled_valid_w;

    downsampler_v_1_fp16 i_a_downsampler_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_a_gaussian_wfv_window_w),
        .kernel_i(box_v_kernel_w),
        .col_i   (i_a_gaussian_wfv_col_w),
        .row_i   (i_a_gaussian_wfv_row_w),
        .valid_i (i_a_gaussian_wfv_valid_w),

        .data_o  (i_a_gaussian_downsampled_data_w),
        .col_o   (i_a_gaussian_downsampled_col_w),
        .row_o   (i_a_gaussian_downsampled_row_w),
        .valid_o (i_a_gaussian_downsampled_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downsampled_z_data_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_col_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_row_w;
    logic                        i_a_gaussian_downsampled_z_valid_w;

    zero_inserter #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .SCALE     (1)
    ) i_a_gaussian_downsampler_zero_inserter (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_downsampled_data_w),
        .col_i  (i_a_gaussian_downsampled_col_w),
        .row_i  (i_a_gaussian_downsampled_row_w),
        .valid_i(i_a_gaussian_downsampled_valid_w),

        .data_o (i_a_gaussian_downsampled_z_data_w),
        .col_o  (i_a_gaussian_downsampled_z_col_w),
        .row_o  (i_a_gaussian_downsampled_z_row_w),
        .valid_o(i_a_gaussian_downsampled_z_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downsampled_z_wfh_window_w [1][5];
    logic [15:0]                 i_a_gaussian_downsampled_z_wfh_col_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_wfh_row_w;
    logic                        i_a_gaussian_downsampled_z_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_downsampler_zero_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_downsampled_z_data_w),
        .col_i  (i_a_gaussian_downsampled_z_col_w),
        .row_i  (i_a_gaussian_downsampled_z_row_w),
        .valid_i(i_a_gaussian_downsampled_z_valid_w),

        .window_o(i_a_gaussian_downsampled_z_wfh_window_w),
        .col_o   (i_a_gaussian_downsampled_z_wfh_col_w),
        .row_o   (i_a_gaussian_downsampled_z_wfh_row_w),
        .valid_o (i_a_gaussian_downsampled_z_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_upsample_h_data_w ;
    logic [15:0]                 i_a_gaussian_upsample_h_col_w;
    logic [15:0]                 i_a_gaussian_upsample_h_row_w;
    logic                        i_a_gaussian_upsample_h_valid_w;

    upsampler_h_1_fp16 i_a_upsampler_h(
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_a_gaussian_downsampled_z_wfh_window_w),
        .kernel_i(upsampler_h_1_kernel_w),
        .col_i   (i_a_gaussian_downsampled_z_wfh_col_w),
        .row_i   (i_a_gaussian_downsampled_z_wfh_row_w),
        .valid_i (i_a_gaussian_downsampled_z_wfh_valid_w),

        .data_o  (i_a_gaussian_upsample_h_data_w),
        .col_o   (i_a_gaussian_upsample_h_col_w),
        .row_o   (i_a_gaussian_upsample_h_row_w),
        .valid_o (i_a_gaussian_upsample_h_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downsampled_data_b_w;
    logic [15:0]                 i_a_gaussian_downsampled_col_b_w;
    logic [15:0]                 i_a_gaussian_downsampled_row_b_w;
    logic                        i_a_gaussian_downsampled_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(3)
    ) i_a_downsampler_v_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_wfv_data_b_w),
        .col_i  (i_a_gaussian_wfv_col_b_w),
        .row_i  (i_a_gaussian_wfv_row_b_w),
        .valid_i(i_a_gaussian_wfv_valid_b_w),

        .data_o  (i_a_gaussian_downsampled_data_b_w),
        .col_o   (i_a_gaussian_downsampled_col_b_w),
        .row_o   (i_a_gaussian_downsampled_row_b_w),
        .valid_o (i_a_gaussian_downsampled_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downsampled_z_data_b_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_col_b_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_row_b_w;
    logic                        i_a_gaussian_downsampled_z_valid_b_w;

    zero_inserter #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .SCALE     (1),
        .DISABLE   (1)
    ) i_a_gaussian_downsampler_zero_inserter_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_downsampled_data_b_w),
        .col_i  (i_a_gaussian_downsampled_col_b_w),
        .row_i  (i_a_gaussian_downsampled_row_b_w),
        .valid_i(i_a_gaussian_downsampled_valid_b_w),

        .data_o (i_a_gaussian_downsampled_z_data_b_w),
        .col_o  (i_a_gaussian_downsampled_z_col_b_w),
        .row_o  (i_a_gaussian_downsampled_z_row_b_w),
        .valid_o(i_a_gaussian_downsampled_z_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downsampled_z_wfh_data_b_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_wfh_col_b_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_wfh_row_b_w;
    logic                        i_a_gaussian_downsampled_z_wfh_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_downsampler_zero_fetcher_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_downsampled_z_data_b_w),
        .col_i  (i_a_gaussian_downsampled_z_col_b_w),
        .row_i  (i_a_gaussian_downsampled_z_row_b_w),
        .valid_i(i_a_gaussian_downsampled_z_valid_b_w),

        .data_o  (i_a_gaussian_downsampled_z_wfh_data_b_w),
        .col_o   (i_a_gaussian_downsampled_z_wfh_col_b_w),
        .row_o   (i_a_gaussian_downsampled_z_wfh_row_b_w),
        .valid_o (i_a_gaussian_downsampled_z_wfh_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_upsample_h_data_b_w ;
    logic [15:0]                 i_a_gaussian_upsample_h_col_b_w;
    logic [15:0]                 i_a_gaussian_upsample_h_row_b_w;
    logic                        i_a_gaussian_upsample_h_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1)
    ) i_a_upsampler_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_downsampled_z_wfh_data_b_w),
        .col_i  (i_a_gaussian_downsampled_z_wfh_col_b_w),
        .row_i  (i_a_gaussian_downsampled_z_wfh_row_b_w),
        .valid_i(i_a_gaussian_downsampled_z_wfh_valid_b_w),

        .data_o  (i_a_gaussian_upsample_h_data_b_w),
        .col_o   (i_a_gaussian_upsample_h_col_b_w),
        .row_o   (i_a_gaussian_upsample_h_row_b_w),
        .valid_o (i_a_gaussian_upsample_h_valid_b_w)
    );

    //--------------------------------------------
    // ------------- zip --------------
    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_a_gaussian_upsample_h_zip_data_w;
    logic [15:0]                       i_a_gaussian_upsample_h_zip_col_w;
    logic [15:0]                       i_a_gaussian_upsample_h_zip_row_w;
    logic                              i_a_gaussian_upsample_h_zip_valid_w;

    assign i_a_gaussian_upsample_h_zip_data_w  = {i_a_gaussian_upsample_h_data_w, i_a_gaussian_upsample_h_data_b_w};
    assign i_a_gaussian_upsample_h_zip_col_w   = i_a_gaussian_upsample_h_col_w;
    assign i_a_gaussian_upsample_h_zip_row_w   = i_a_gaussian_upsample_h_row_w;
    assign i_a_gaussian_upsample_h_zip_valid_w = i_a_gaussian_upsample_h_valid_w;

    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_a_gaussian_downsampled_z_zip_wfv_window_w [5][1];
    logic [15:0]                       i_a_gaussian_downsampled_z_zip_wfv_col_w;
    logic [15:0]                       i_a_gaussian_downsampled_z_zip_wfv_row_w;
    logic                              i_a_gaussian_downsampled_z_zip_wfv_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downsampled_z_wfv_window_w [5][1];
    logic [15:0]                 i_a_gaussian_downsampled_z_wfv_col_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_wfv_row_w;
    logic                        i_a_gaussian_downsampled_z_wfv_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_downsampled_z_wfv_data_b_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_wfv_col_b_w;
    logic [15:0]                 i_a_gaussian_downsampled_z_wfv_row_b_w;
    logic                        i_a_gaussian_downsampled_z_wfv_valid_b_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG * 2),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_a_gaussian_downsampler_zero_zip_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_a_gaussian_upsample_h_zip_data_w),
        .col_i  (i_a_gaussian_upsample_h_zip_col_w),
        .row_i  (i_a_gaussian_upsample_h_zip_row_w),
        .valid_i(i_a_gaussian_upsample_h_zip_valid_w),

        .window_o(i_a_gaussian_downsampled_z_zip_wfv_window_w),
        .col_o   (i_a_gaussian_downsampled_z_zip_wfv_col_w),
        .row_o   (i_a_gaussian_downsampled_z_zip_wfv_row_w),
        .valid_o (i_a_gaussian_downsampled_z_zip_wfv_valid_w)
    );

    // unzip
    always_comb begin
        for(int c = 0; c < 5; c++) begin
            i_a_gaussian_downsampled_z_wfv_window_w[c][0] = i_a_gaussian_downsampled_z_zip_wfv_window_w[c][0][(FP_WIDTH_REG * 2) - 1 : 0];
        end
        i_a_gaussian_downsampled_z_wfv_data_b_w = i_a_gaussian_downsampled_z_zip_wfv_window_w[2][0][FP_WIDTH_REG - 1 : 0];

        i_a_gaussian_downsampled_z_wfv_col_w     = i_a_gaussian_downsampled_z_zip_wfv_col_w;
        i_a_gaussian_downsampled_z_wfv_row_w     = i_a_gaussian_downsampled_z_zip_wfv_row_w;
        i_a_gaussian_downsampled_z_wfv_valid_w = i_a_gaussian_downsampled_z_zip_wfv_valid_w;

        i_a_gaussian_downsampled_z_wfv_col_b_w     = i_a_gaussian_downsampled_z_zip_wfv_col_w;
        i_a_gaussian_downsampled_z_wfv_row_b_w     = i_a_gaussian_downsampled_z_zip_wfv_row_w;
        i_a_gaussian_downsampled_z_wfv_valid_b_w   = i_a_gaussian_downsampled_z_zip_wfv_valid_w;

    end

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_upsampled_data_w;
    logic [15:0]                 i_a_gaussian_upsampled_col_w;
    logic [15:0]                 i_a_gaussian_upsampled_row_w;
    logic                        i_a_gaussian_upsampled_valid_w;

    upsampler_v_1_fp16 i_a_gaussian_upsampler_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_a_gaussian_downsampled_z_wfv_window_w),
        .kernel_i(upsampler_v_1_kernel_w),
        .col_i   (i_a_gaussian_downsampled_z_wfv_col_w),
        .row_i   (i_a_gaussian_downsampled_z_wfv_row_w),
        .valid_i (i_a_gaussian_downsampled_z_wfv_valid_w),

        .data_o (i_a_gaussian_upsampled_data_w),
        .col_o  (i_a_gaussian_upsampled_col_w),
        .row_o  (i_a_gaussian_upsampled_row_w),
        .valid_o(i_a_gaussian_upsampled_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_upsampled_data_b_w;
    logic [15:0]                 i_a_gaussian_upsampled_col_b_w;
    logic [15:0]                 i_a_gaussian_upsampled_row_b_w;
    logic                        i_a_gaussian_upsampled_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5)
    ) i_a_gaussian_upsampler_v_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i(i_a_gaussian_downsampled_z_wfv_data_b_w),
        .col_i   (i_a_gaussian_downsampled_z_wfv_col_b_w),
        .row_i   (i_a_gaussian_downsampled_z_wfv_row_b_w),
        .valid_i (i_a_gaussian_downsampled_z_wfv_valid_b_w),

        .data_o (i_a_gaussian_upsampled_data_b_w),
        .col_o  (i_a_gaussian_upsampled_col_b_w),
        .row_o  (i_a_gaussian_upsampled_row_b_w),
        .valid_o(i_a_gaussian_upsampled_valid_b_w)
    );

    ////////////////////////////////////////////////////////////////
    // I_T and I_T buffered interleaved (for data zipping)
    // I_T is at MSB, I_T buffered is at LSB
    //
    //----------------------
    // processing I_T / I_T_B (it / itb):
    //
    // window fetcher it - 1x9 
    // gaussian horizontal it
    //
    // window fetcher itb - 1x9
    // gaussian horizontal itb
    //
    //--------------------------------------------
    // window fetcher zipped data - 9x1
    //
    // gaussian vertical it
    // window fetcher it - 1x3
    // downsampler horizontal it
    //
    // gaussian vertical itb
    // window fetcher itb - 1x3
    // downsampler horizontal itb
    //
    //--------------------------------------------
    // window fetcher zipped data - 3x1
    //
    // downsampler vertical it
    //
    // downsampler vertical itb
    // zero inserter itb
    // window fetcher itb - 1x5
    // upsampler horizontal itb
    // window fetcher itb - 5x1
    // upsampler vertical itb

    logic [FP_WIDTH_REG - 1 : 0] i_t_wfh_window_w [1][9];
    logic [15:0]                 i_t_wfh_col_w;
    logic [15:0]                 i_t_wfh_row_w;
    logic                        i_t_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (9),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_window_fetcher_h (
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

    burt_h_1_fp16 i_t_burt_h (
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

    logic [FP_WIDTH_REG - 1 : 0] i_t_wfh_data_b_w;
    logic [15:0]                 i_t_wfh_col_b_w;
    logic [15:0]                 i_t_wfh_row_b_w;
    logic                        i_t_wfh_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (9),
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
        .WINDOW_WIDTH (9),
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

    //--------------------------------------------
    // ------------- zip --------------
    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_t_bh_zip_data_w;
    logic [15:0]                       i_t_bh_zip_col_w;
    logic [15:0]                       i_t_bh_zip_row_w;
    logic                              i_t_bh_zip_valid_w;

    assign i_t_bh_zip_data_w  = {i_t_bh_data_w, i_t_bh_data_b_w};
    assign i_t_bh_zip_col_w   = i_t_bh_col_w;
    assign i_t_bh_zip_row_w   = i_t_bh_row_w;
    assign i_t_bh_zip_valid_w = i_t_bh_valid_w;

    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_t_wfv_zip_window_w [9][1];
    logic [15:0]                       i_t_wfv_zip_col_w;
    logic [15:0]                       i_t_wfv_zip_row_w;
    logic                              i_t_wfv_zip_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_t_wfv_window_w [9][1];
    logic [15:0]                 i_t_wfv_col_w;
    logic [15:0]                 i_t_wfv_row_w;
    logic                        i_t_wfv_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_t_wfv_data_b_w;
    logic [15:0]                 i_t_wfv_col_b_w;
    logic [15:0]                 i_t_wfv_row_b_w;
    logic                        i_t_wfv_valid_b_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG * 2),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(9),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_zip_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_bh_zip_data_w),
        .col_i  (i_t_bh_zip_col_w),
        .row_i  (i_t_bh_zip_row_w),
        .valid_i(i_t_bh_zip_valid_w),

        .window_o(i_t_wfv_zip_window_w),
        .col_o   (i_t_wfv_zip_col_w),
        .row_o   (i_t_wfv_zip_row_w),
        .valid_o (i_t_wfv_zip_valid_w)
    );

    // unzip
    always_comb begin
        for(int c = 0; c < 9; c++) begin
            i_t_wfv_window_w[c][0] = i_t_wfv_zip_window_w[c][0][(FP_WIDTH_REG * 2) - 1 : FP_WIDTH_REG];
        end
        i_t_wfv_data_b_w = i_t_wfv_zip_window_w[4][0][FP_WIDTH_REG - 1 : 0];

        i_t_wfv_col_w   = i_t_wfv_zip_col_w;
        i_t_wfv_row_w   = i_t_wfv_zip_row_w;
        i_t_wfv_valid_w = i_t_wfv_zip_valid_w;

        i_t_wfv_col_b_w   = i_t_wfv_zip_col_w;
        i_t_wfv_row_b_w   = i_t_wfv_zip_row_w;
        i_t_wfv_valid_b_w = i_t_wfv_zip_valid_w;
    end

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_data_w;
    logic [15:0]                 i_t_gaussian_col_w;
    logic [15:0]                 i_t_gaussian_row_w;
    logic                        i_t_gaussian_valid_w;

    burt_v_1_fp16 i_t_burt_v (
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

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_wfh_window_w [1][3];
    logic [15:0]                 i_t_gaussian_wfh_col_w;
    logic [15:0]                 i_t_gaussian_wfh_row_w;
    logic                        i_t_gaussian_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_gaussian_window_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_data_w),
        .col_i  (i_t_gaussian_col_w),
        .row_i  (i_t_gaussian_row_w),
        .valid_i(i_t_gaussian_valid_w),

        .window_o(i_t_gaussian_wfh_window_w),
        .col_o   (i_t_gaussian_wfh_col_w),
        .row_o   (i_t_gaussian_wfh_row_w),
        .valid_o (i_t_gaussian_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_downh_data_w;
    logic [15:0]                 i_t_gaussian_downh_col_w;
    logic [15:0]                 i_t_gaussian_downh_row_w;
    logic                        i_t_gaussian_downh_valid_w;

    downsampler_h_1_fp16 i_t_downsampler_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_t_gaussian_wfh_window_w),
        .kernel_i(box_h_kernel_w),
        .col_i   (i_t_gaussian_wfh_col_w),
        .row_i   (i_t_gaussian_wfh_row_w),
        .valid_i (i_t_gaussian_wfh_valid_w),

        .data_o  (i_t_gaussian_downh_data_w),
        .col_o   (i_t_gaussian_downh_col_w),
        .row_o   (i_t_gaussian_downh_row_w),
        .valid_o (i_t_gaussian_downh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_data_b_w;
    logic [15:0]                 i_t_gaussian_col_b_w;
    logic [15:0]                 i_t_gaussian_row_b_w;
    logic                        i_t_gaussian_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(9)
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

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_wfh_data_b_w;
    logic [15:0]                 i_t_gaussian_wfh_col_b_w;
    logic [15:0]                 i_t_gaussian_wfh_row_b_w;
    logic                        i_t_gaussian_wfh_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_gaussian_window_fetcher_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_data_b_w),
        .col_i  (i_t_gaussian_col_b_w),
        .row_i  (i_t_gaussian_row_b_w),
        .valid_i(i_t_gaussian_valid_b_w),

        .data_o  (i_t_gaussian_wfh_data_b_w),
        .col_o   (i_t_gaussian_wfh_col_b_w),
        .row_o   (i_t_gaussian_wfh_row_b_w),
        .valid_o (i_t_gaussian_wfh_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_downh_data_b_w;
    logic [15:0]                 i_t_gaussian_downh_col_b_w;
    logic [15:0]                 i_t_gaussian_downh_row_b_w;
    logic                        i_t_gaussian_downh_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1)
    ) i_t_downsampler_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i  (i_t_gaussian_wfh_data_b_w),
        .col_i   (i_t_gaussian_wfh_col_b_w),
        .row_i   (i_t_gaussian_wfh_row_b_w),
        .valid_i (i_t_gaussian_wfh_valid_b_w),

        .data_o  (i_t_gaussian_downh_data_b_w),
        .col_o   (i_t_gaussian_downh_col_b_w),
        .row_o   (i_t_gaussian_downh_row_b_w),
        .valid_o (i_t_gaussian_downh_valid_b_w)
    );

    //--------------------------------------------
    // ------------- zip --------------
    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_t_gaussian_downh_zip_data_w;
    logic [15:0]                       i_t_gaussian_downh_zip_col_w;
    logic [15:0]                       i_t_gaussian_downh_zip_row_w;
    logic                              i_t_gaussian_downh_zip_valid_w;

    assign i_t_gaussian_downh_zip_data_w  = {i_t_gaussian_downh_data_w, i_t_gaussian_downh_data_b_w};
    assign i_t_gaussian_downh_zip_col_w   = i_t_gaussian_downh_col_w;
    assign i_t_gaussian_downh_zip_row_w   = i_t_gaussian_downh_row_w;
    assign i_t_gaussian_downh_zip_valid_w = i_t_gaussian_downh_valid_w;

    logic [(FP_WIDTH_REG * 2) - 1 : 0] i_t_gaussian_wfv_zip_window_w [3][1];
    logic [15:0]                       i_t_gaussian_wfv_zip_col_w;
    logic [15:0]                       i_t_gaussian_wfv_zip_row_w;
    logic                              i_t_gaussian_wfv_zip_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_wfv_window_w [3][1];
    logic [15:0]                 i_t_gaussian_wfv_col_w;
    logic [15:0]                 i_t_gaussian_wfv_row_w;
    logic                        i_t_gaussian_wfv_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_wfv_data_b_w;
    logic [15:0]                 i_t_gaussian_wfv_col_b_w;
    logic [15:0]                 i_t_gaussian_wfv_row_b_w;
    logic                        i_t_gaussian_wfv_valid_b_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG * 2),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(3),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_gaussian_zip_window_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_downh_zip_data_w),
        .col_i  (i_t_gaussian_downh_zip_col_w),
        .row_i  (i_t_gaussian_downh_zip_row_w),
        .valid_i(i_t_gaussian_downh_zip_valid_w),

        .window_o(i_t_gaussian_wfv_zip_window_w),
        .col_o   (i_t_gaussian_wfv_zip_col_w),
        .row_o   (i_t_gaussian_wfv_zip_row_w),
        .valid_o (i_t_gaussian_wfv_zip_valid_w)
    );

    // unzip
    always_comb begin
        for(int c = 0; c < 3; c++) begin
            i_t_gaussian_wfv_window_w[c][0] = i_t_gaussian_wfv_zip_window_w[c][0][(FP_WIDTH_REG * 2) - 1 :  FP_WIDTH_REG];
        end
        i_t_gaussian_wfv_data_b_w = i_t_gaussian_wfv_zip_window_w[0][0][FP_WIDTH_REG - 1 : 0];

        i_t_gaussian_wfv_col_w   = i_t_gaussian_wfv_zip_col_w;
        i_t_gaussian_wfv_row_w   = i_t_gaussian_wfv_zip_row_w;
        i_t_gaussian_wfv_valid_w = i_t_gaussian_wfv_zip_valid_w; 

        i_t_gaussian_wfv_col_b_w   = i_t_gaussian_wfv_zip_col_w;
        i_t_gaussian_wfv_row_b_w   = i_t_gaussian_wfv_zip_row_w;
        i_t_gaussian_wfv_valid_b_w = i_t_gaussian_wfv_zip_valid_w; 
    end

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_downsampled_data_w;
    logic [15:0]                 i_t_gaussian_downsampled_col_w;
    logic [15:0]                 i_t_gaussian_downsampled_row_w;
    logic                        i_t_gaussian_downsampled_valid_w;

    downsampler_v_1_fp16 i_t_downsampler_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(i_t_gaussian_wfv_window_w),
        .kernel_i(box_v_kernel_w),
        .col_i   (i_t_gaussian_wfv_col_w),
        .row_i   (i_t_gaussian_wfv_row_w),
        .valid_i (i_t_gaussian_wfv_valid_w),

        .data_o  (i_t_gaussian_downsampled_data_w),
        .col_o   (i_t_gaussian_downsampled_col_w),
        .row_o   (i_t_gaussian_downsampled_row_w),
        .valid_o (i_t_gaussian_downsampled_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_downsampled_data_b_w;
    logic [15:0]                 i_t_gaussian_downsampled_col_b_w;
    logic [15:0]                 i_t_gaussian_downsampled_row_b_w;
    logic                        i_t_gaussian_downsampled_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(3)
    ) i_t_downsampler_v_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_wfv_data_b_w),
        .col_i  (i_t_gaussian_wfv_col_b_w),
        .row_i  (i_t_gaussian_wfv_row_b_w),
        .valid_i(i_t_gaussian_wfv_valid_b_w),

        .data_o  (i_t_gaussian_downsampled_data_b_w),
        .col_o   (i_t_gaussian_downsampled_col_b_w),
        .row_o   (i_t_gaussian_downsampled_row_b_w),
        .valid_o (i_t_gaussian_downsampled_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_downsampled_z_data_b_w;
    logic [15:0]                 i_t_gaussian_downsampled_z_col_b_w;
    logic [15:0]                 i_t_gaussian_downsampled_z_row_b_w;
    logic                        i_t_gaussian_downsampled_z_valid_b_w;

    zero_inserter #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .SCALE     (1),
        .DISABLE   (1)
    ) i_t_gaussian_downsampler_zero_inserter_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_downsampled_data_b_w),
        .col_i  (i_t_gaussian_downsampled_col_b_w),
        .row_i  (i_t_gaussian_downsampled_row_b_w),
        .valid_i(i_t_gaussian_downsampled_valid_b_w),

        .data_o (i_t_gaussian_downsampled_z_data_b_w),
        .col_o  (i_t_gaussian_downsampled_z_col_b_w),
        .row_o  (i_t_gaussian_downsampled_z_row_b_w),
        .valid_o(i_t_gaussian_downsampled_z_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_downsampled_z_wfh_data_b_w;
    logic [15:0]                 i_t_gaussian_downsampled_z_wfh_col_b_w;
    logic [15:0]                 i_t_gaussian_downsampled_z_wfh_row_b_w;
    logic                        i_t_gaussian_downsampled_z_wfh_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_gaussian_downsampler_zero_fetcher_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_downsampled_z_data_b_w),
        .col_i  (i_t_gaussian_downsampled_z_col_b_w),
        .row_i  (i_t_gaussian_downsampled_z_row_b_w),
        .valid_i(i_t_gaussian_downsampled_z_valid_b_w),

        .data_o  (i_t_gaussian_downsampled_z_wfh_data_b_w),
        .col_o   (i_t_gaussian_downsampled_z_wfh_col_b_w),
        .row_o   (i_t_gaussian_downsampled_z_wfh_row_b_w),
        .valid_o (i_t_gaussian_downsampled_z_wfh_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_upsample_h_data_b_w ;
    logic [15:0]                 i_t_gaussian_upsample_h_col_b_w;
    logic [15:0]                 i_t_gaussian_upsample_h_row_b_w;
    logic                        i_t_gaussian_upsample_h_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (5),
        .WINDOW_HEIGHT(1)
    ) i_t_upsampler_h_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_downsampled_z_wfh_data_b_w),
        .col_i  (i_t_gaussian_downsampled_z_wfh_col_b_w),
        .row_i  (i_t_gaussian_downsampled_z_wfh_row_b_w),
        .valid_i(i_t_gaussian_downsampled_z_wfh_valid_b_w),

        .data_o  (i_t_gaussian_upsample_h_data_b_w),
        .col_o   (i_t_gaussian_upsample_h_col_b_w),
        .row_o   (i_t_gaussian_upsample_h_row_b_w),
        .valid_o (i_t_gaussian_upsample_h_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_downsampled_z_wfv_data_b_w;
    logic [15:0]                 i_t_gaussian_downsampled_z_wfv_col_b_w;
    logic [15:0]                 i_t_gaussian_downsampled_z_wfv_row_b_w;
    logic                        i_t_gaussian_downsampled_z_wfv_valid_b_w;

    window_fetcher_z #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) i_t_gaussian_downsampler_zero_fetcher_v_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (i_t_gaussian_upsample_h_data_b_w),
        .col_i  (i_t_gaussian_upsample_h_col_b_w),
        .row_i  (i_t_gaussian_upsample_h_row_b_w),
        .valid_i(i_t_gaussian_upsample_h_valid_b_w),

        .data_o (i_t_gaussian_downsampled_z_wfv_data_b_w),
        .col_o  (i_t_gaussian_downsampled_z_wfv_col_b_w),
        .row_o  (i_t_gaussian_downsampled_z_wfv_row_b_w),
        .valid_o(i_t_gaussian_downsampled_z_wfv_valid_b_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] i_t_gaussian_upsampled_data_b_w;
    logic [15:0]                 i_t_gaussian_upsampled_col_b_w;
    logic [15:0]                 i_t_gaussian_upsampled_row_b_w;
    logic                        i_t_gaussian_upsampled_valid_b_w;

    convolution_floating_point_z #(
        .EXP_WIDTH    (EXP_WIDTH),
        .FRAC_WIDTH   (FRAC_WIDTH),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(5)
    ) i_t_gaussian_upsampler_v_b (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i(i_t_gaussian_downsampled_z_wfv_data_b_w),
        .col_i   (i_t_gaussian_downsampled_z_wfv_col_b_w),
        .row_i   (i_t_gaussian_downsampled_z_wfv_row_b_w),
        .valid_i (i_t_gaussian_downsampled_z_wfv_valid_b_w),

        .data_o (i_t_gaussian_upsampled_data_b_w),
        .col_o  (i_t_gaussian_upsampled_col_b_w),
        .row_o  (i_t_gaussian_upsampled_row_b_w),
        .valid_o(i_t_gaussian_upsampled_valid_b_w)
    );

    ////////////////////////////////////////////////////////////////
    // Laplacian = I_A - (I_A gaussianed, downsampled, then upsampled)

    logic [FP_WIDTH_REG - 1 : 0] i_a_gaussian_upsampled_data_negative_w;
    always_comb begin
        i_a_gaussian_upsampled_data_negative_w[FP_WIDTH_REG - 1] = !i_a_gaussian_upsampled_data_w[FP_WIDTH_REG - 1];
        i_a_gaussian_upsampled_data_negative_w[FP_WIDTH_REG - 2 : 0] = i_a_gaussian_upsampled_data_w[FP_WIDTH_REG - 2 : 0];
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

        .fp_a_i (i_a_gaussian_upsampled_data_b_w),
        .fp_b_i (i_a_gaussian_upsampled_data_negative_w),
        .valid_i(i_a_gaussian_upsampled_valid_w),

        .fp_o   (laplacian_data_w),
        .valid_o(laplacian_valid_w)
    ); 

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) laplacian_col_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_a_gaussian_upsampled_col_w),
        .fp_o  (laplacian_col_w)
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) laplacian_row_delay (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_a_gaussian_upsampled_row_w),
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
        .valid_i(v_valid_w[1]),
        .fp_o   (v_data_w [2]),
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
        .fp_a_i (i_t_gaussian_upsampled_data_b_w),
        .valid_i(i_t_gaussian_upsampled_valid_b_w),
        .fp_o   (i_t_data_w [0]),
        .valid_o(i_t_valid_w[0])
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_t_col_delay_0 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_t_gaussian_upsampled_col_b_w),
        .fp_o  (i_t_col_w[0])
    );

    floating_point_adder_z #(
        .EXP_WIDTH(0),
        .FRAC_WIDTH(15)
    ) i_t_row_delay_0 (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fp_a_i(i_t_gaussian_upsampled_row_b_w),
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
        .valid_i(i_t_valid_w[0]),
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
        .valid_i(i_t_valid_w[1]),
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
        .fp_o(v_b_data_w)
    );

    // ----------------------------- V_B - i_t
    logic [FP_WIDTH_REG - 1 : 0] i_t_data_negative_w;
    always_comb begin
        i_t_data_negative_w[FP_WIDTH_REG - 1]     = !i_t_data_w[2][FP_WIDTH_REG - 1];
        i_t_data_negative_w[FP_WIDTH_REG - 2 : 0] = i_t_data_w[2][FP_WIDTH_REG - 2 : 0];
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
        .fp_o   (w_data_w)
    ); 

    ////////////////////////////////////////////////////////////////
    // V and W window fetchers (depending on if DX_DY_ENABLE)
    // convolutions, multiply by weights and finally accumulate
    logic [(FP_WIDTH_REG * 2) - 1 : 0] v_w_zip_data_w;
    logic [15:0]                       v_w_zip_col_w;
    logic [15:0]                       v_w_zip_row_w;
    logic                              v_w_zip_valid_w;

    assign v_w_zip_data_w  = {v_data_w[2], w_data_w};
    assign v_w_zip_col_w   = v_col_w[2];
    assign v_w_zip_row_w   = v_row_w[2];
    assign v_w_zip_valid_w = v_valid_w[2];

    logic [(FP_WIDTH_REG * 2) - 1 : 0] v_w_wf_zip_window_w [5][5];
    logic [15:0]                       v_w_wf_zip_col_w;
    logic [15:0]                       v_w_wf_zip_row_w;
    logic                              v_w_wf_zip_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] v_wf_window_w [5][5];
    logic [15:0]                 v_wf_col_w;
    logic [15:0]                 v_wf_row_w;
    logic                        v_wf_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] w_wf_window_w [5][5];
    logic [15:0]                 w_wf_col_w;
    logic [15:0]                 w_wf_row_w;
    logic                        w_wf_valid_w;

    // unzip
    always_comb begin
        for(int r = 0; r < 3; r++) begin
            for(int c = 0; c < 3; c++) begin
                v_wf_window_w[r][c] = v_w_wf_zip_window_w[r][c][(FP_WIDTH_REG * 2) - 1 : FP_WIDTH_REG];
                w_wf_window_w[r][c] = v_w_wf_zip_window_w[r][c][FP_WIDTH_REG - 1 : 0];
            end
        end
        
        v_wf_col_w   = v_w_wf_zip_col_w;
        v_wf_row_w   = v_w_wf_zip_row_w;
        v_wf_valid_w = v_w_wf_zip_valid_w;

        w_wf_col_w   = v_w_wf_zip_col_w;
        w_wf_row_w   = v_w_wf_zip_row_w;
        w_wf_valid_w = v_w_wf_zip_valid_w;
    end

    logic [FP_WIDTH_REG - 1 : 0] v_pass_data_w;
    logic [FP_WIDTH_REG - 1 : 0] v_dx_data_w;
    logic [FP_WIDTH_REG - 1 : 0] v_dy_data_w;
    logic [15:0]                 v_pass_col_w;
    logic [15:0]                 v_pass_row_w;
    logic                        v_pass_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] w_pass_data_w;
    logic [FP_WIDTH_REG - 1 : 0] w_dx_data_w;
    logic [FP_WIDTH_REG - 1 : 0] w_dy_data_w;

    logic [FP_WIDTH_REG - 1 : 0] v_pass_data_weighted_w;
    logic [FP_WIDTH_REG - 1 : 0] v_dx_data_weighted_w;
    logic [FP_WIDTH_REG - 1 : 0] v_dy_data_weighted_w;
    logic [15:0]                 v_pass_col_weighted_w;
    logic [15:0]                 v_pass_row_weighted_w;
    logic                        v_pass_valid_weighted_w;

    logic [FP_WIDTH_REG - 1 : 0] w_pass_data_weighted_w;
    logic [FP_WIDTH_REG - 1 : 0] w_dx_data_weighted_w;
    logic [FP_WIDTH_REG - 1 : 0] w_dy_data_weighted_w;

    logic [FP_WIDTH_REG - 1 : 0] v_concat_w [1][3];
    assign v_concat_w[0][0] = v_pass_data_weighted_w;
    assign v_concat_w[0][1] = v_dx_data_weighted_w;
    assign v_concat_w[0][2] = v_dy_data_weighted_w;

    logic [FP_WIDTH_REG - 1 : 0] w_concat_w [1][3];
    assign w_concat_w[0][0] = w_pass_data_weighted_w;
    assign w_concat_w[0][1] = w_dx_data_weighted_w;
    assign w_concat_w[0][2] = w_dy_data_weighted_w;

    logic [FP_WIDTH_REG - 1 : 0] v_added_data_w;
    logic [15:0]                 v_added_col_w;
    logic [15:0]                 v_added_row_w;
    logic [15:0]                 v_added_valid_w;

    logic [FP_WIDTH_REG - 1 : 0] w_added_data_w;

    generate
        if(DX_DY_ENABLE != 0) begin
            window_fetcher #(
                .DATA_WIDTH(FP_WIDTH_REG * 2),
                .IMAGE_WIDTH(IMAGE_WIDTH),
                .IMAGE_HEIGHT(IMAGE_HEIGHT),
                .WINDOW_WIDTH(5),
                .WINDOW_HEIGHT(5)
            ) v_w_zip_window_fetcher (
                    .clk_i(clk_i),
                    .rst_i(rst_i),

                    .data_i (v_w_zip_data_w),
                    .col_i  (v_w_zip_col_w),
                    .row_i  (v_w_zip_row_w),
                    .valid_i(v_w_zip_valid_w),

                    .window_o(v_w_wf_zip_window_w),
                    .col_o   (v_w_wf_zip_col_w),
                    .row_o   (v_w_wf_zip_row_w),
                    .valid_o (v_w_wf_zip_valid_w)
            );


            // ----- V derivatives -------
            pass_1_fp16 v_pass (
                .clk_i(clk_i),
                .rst_i(rst_i),

                .window_i(v_wf_window_w),
                .kernel_i(pass_5_5_kernel_w),
                .col_i   (v_wf_col_w),
                .row_i   (v_wf_row_w),
                .valid_i (v_wf_valid_w),

                .data_o (v_pass_data_w),
                .col_o  (v_pass_col_w),
                .row_o  (v_pass_row_w),
                .valid_o(v_pass_valid_w)
            );

            dx_1_fp16 v_dx (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .window_i(v_wf_window_w),
                .kernel_i(dx_5_5_kernel_w),
                .data_o  (v_dx_data_w)
            );

            dy_1_fp16 v_dy (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .window_i(v_wf_window_w),
                .kernel_i(dy_5_5_kernel_w),
                .data_o  (v_dy_data_w)
            );

            // ----- W derivatives -------
            pass_1_fp16 w_pass (
                .clk_i(clk_i),
                .rst_i(rst_i),

                .window_i(w_wf_window_w),
                .kernel_i(pass_5_5_kernel_w),
                .data_o  (w_pass_data_w)
            );

            dx_1_fp16 w_dx (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .window_i(w_wf_window_w),
                .kernel_i(dx_5_5_kernel_w),
                .data_o  (w_dx_data_w)
            );

            dy_1_fp16 w_dy (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .window_i(w_wf_window_w),
                .kernel_i(dy_5_5_kernel_w),
                .data_o  (w_dy_data_w)
            );

            // ----- V weighted (and row col delay) -------
            floating_point_multiplier #(
                .EXP_WIDTH (EXP_WIDTH),
                .FRAC_WIDTH(FRAC_WIDTH)
            ) v_pass_weighted (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i (v_pass_data_w),
                .fp_b_i (w_i[0]),
                .valid_i(v_pass_valid_w),
                .fp_o   (v_pass_data_weighted_w),
                .valid_o(v_pass_valid_weighted_w)
            );

            floating_point_multiplier #(
                .EXP_WIDTH (EXP_WIDTH),
                .FRAC_WIDTH(FRAC_WIDTH)
            ) v_dx_weighted (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i (v_dx_data_w),
                .fp_b_i (w_i[1]),
                .fp_o   (v_dx_data_weighted_w)
            );

            floating_point_multiplier #(
                .EXP_WIDTH (EXP_WIDTH),
                .FRAC_WIDTH(FRAC_WIDTH)
            ) v_dy_weighted (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i (v_dy_data_w),
                .fp_b_i (w_i[2]),
                .fp_o   (v_dy_data_weighted_w)
            );

            floating_point_multiplier_z #(
                .EXP_WIDTH(0),
                .FRAC_WIDTH(15)
            ) v_pass_col_w_delay (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i(v_pass_col_w),
                .fp_o  (v_pass_col_weighted_w)
            );

            floating_point_multiplier_z #(
                .EXP_WIDTH(0),
                .FRAC_WIDTH(15)
            ) v_pass_row_w_delay (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i(v_pass_row_w),
                .fp_o  (v_pass_row_weighted_w)
            );

            // ----- W weighted -------
            floating_point_multiplier #(
                .EXP_WIDTH (EXP_WIDTH),
                .FRAC_WIDTH(FRAC_WIDTH)
            ) w_pass_weighted (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i (w_pass_data_w),
                .fp_b_i (w_i[0]),
                .fp_o   (w_pass_data_weighted_w)
            );

            floating_point_multiplier #(
                .EXP_WIDTH (EXP_WIDTH),
                .FRAC_WIDTH(FRAC_WIDTH)
            ) w_dx_weighted (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i (w_dx_data_w),
                .fp_b_i (w_i[1]),
                .fp_o   (w_dx_data_weighted_w)
            );

            floating_point_multiplier #(
                .EXP_WIDTH (EXP_WIDTH),
                .FRAC_WIDTH(FRAC_WIDTH)
            ) w_dy_weighted (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i (w_dy_data_w),
                .fp_b_i (w_i[2]),
                .fp_o   (w_dy_data_weighted_w)
            );

            // ----- V Accumulate -------
            pass_dx_dy_adder_fp16 v_accumulate (
                .clk_i(clk_i),
                .rst_i(rst_i),

                .window_i(v_concat_w),
                .kernel_i(acc_kernel_w),
                .col_i   (v_pass_col_weighted_w),
                .row_i   (v_pass_row_weighted_w),
                .valid_i (v_pass_valid_weighted_w),

                .data_o (v_added_data_w),
                .col_o  (v_added_col_w),
                .row_o  (v_added_row_w),
                .valid_o(v_added_valid_w)
            );

            // ----- W Accumulate -------
            pass_dx_dy_adder_fp16 w_accumulate (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .window_i(w_concat_w),
                .kernel_i(acc_kernel_w),
                .data_o  (w_added_data_w)
            );
        end else begin
             // ----- V weighted (and row col delay) -------
            floating_point_multiplier #(
                .EXP_WIDTH (EXP_WIDTH),
                .FRAC_WIDTH(FRAC_WIDTH)
            ) v_pass_weighted (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i (v_data_w[2]),
                .fp_b_i (w_i[0]),
                .valid_i(v_valid_w[2]),
                .fp_o   (v_pass_data_weighted_w),
                .valid_o(v_pass_valid_weighted_w)
            );

            floating_point_multiplier_z #(
                .EXP_WIDTH(0),
                .FRAC_WIDTH(15)
            ) v_pass_col_w_delay (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i(v_col_w[2]),
                .fp_o  (v_pass_col_weighted_w)
            );

            floating_point_multiplier_z #(
                .EXP_WIDTH(0),
                .FRAC_WIDTH(15)
            ) v_pass_row_w_delay (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i(v_row_w[2]),
                .fp_o  (v_pass_row_weighted_w)
            );

            // ----- W weighted -------
            floating_point_multiplier #(
                .EXP_WIDTH (EXP_WIDTH),
                .FRAC_WIDTH(FRAC_WIDTH)
            ) w_pass_weighted (
                .clk_i(clk_i),
                .rst_i(rst_i),
                .fp_a_i (w_data_w),
                .fp_b_i (w_i[0]),
                .fp_o   (w_pass_data_weighted_w)
            );
        end
    endgenerate

    ////////////////////////////////////////////////////////////////
    // Assigning V and W before upsample
    logic [FP_WIDTH_REG - 1 : 0] v_pre_upsample_data_w;
    logic [FP_WIDTH_REG - 1 : 0] w_pre_upsample_data_w;
    logic [15:0]                 v_pre_upsample_col_w;
    logic [15:0]                 v_pre_upsample_row_w;
    logic                        v_pre_upsample_valid_w;

    assign v_pre_upsample_data_w   = DX_DY_ENABLE != 0 ? v_added_data_w : v_pass_data_weighted_w;
    assign w_pre_upsample_data_w   = DX_DY_ENABLE != 0 ? w_added_data_w : w_pass_data_weighted_w;
    assign v_pre_upsample_col_w    = DX_DY_ENABLE != 0 ? v_added_col_w  : v_pass_col_weighted_w;
    assign v_pre_upsample_row_w    = DX_DY_ENABLE != 0 ? v_added_row_w  : v_pass_row_weighted_w;
    assign v_pre_upsample_valid_w  = DX_DY_ENABLE != 0 ? v_added_valid_w: v_pass_valid_weighted_w;

    ////////////////////////////////////////////////////////////////
    // Upsampling V
    //----------------------
    // zero inserter
    // window fetcher - 1x3
    // upsampler horizontal
    // window fetcher - 3x1
    // upsampler vertical

    logic [FP_WIDTH_REG - 1 : 0] v_pre_upsample_z_data_w;
    logic [15:0]                 v_pre_upsample_z_col_w;
    logic [15:0]                 v_pre_upsample_z_row_w;
    logic                        v_pre_upsample_z_valid_w;

    zero_inserter #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .SCALE     (0)
    ) v_pre_upsampler_zero_inserter (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (v_pre_upsample_data_w),
        .col_i  (v_pre_upsample_col_w),
        .row_i  (v_pre_upsample_row_w),
        .valid_i(v_pre_upsample_valid_w),

        .data_o (v_pre_upsample_z_data_w),
        .col_o  (v_pre_upsample_z_col_w),
        .row_o  (v_pre_upsample_z_row_w),
        .valid_o(v_pre_upsample_z_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] v_pre_upsample_z_wfh_window_w [1][3];
    logic [15:0]                 v_pre_upsample_z_wfh_col_w;
    logic [15:0]                 v_pre_upsample_z_wfh_row_w;
    logic                        v_pre_upsample_z_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) v_pre_upsample_zero_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (v_pre_upsample_z_data_w),
        .col_i  (v_pre_upsample_z_col_w),
        .row_i  (v_pre_upsample_z_row_w),
        .valid_i(v_pre_upsample_z_valid_w),

        .window_o(v_pre_upsample_z_wfh_window_w),
        .col_o   (v_pre_upsample_z_wfh_col_w),
        .row_o   (v_pre_upsample_z_wfh_row_w),
        .valid_o (v_pre_upsample_z_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] v_pre_upsample_upsample_h_data_w ;
    logic [15:0]                 v_pre_upsample_upsample_h_col_w;
    logic [15:0]                 v_pre_upsample_upsample_h_row_w;
    logic                        v_pre_upsample_upsample_h_valid_w;

    upsampler_h_0_fp16 v_pre_upsample_upsampler_h(
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(v_pre_upsample_z_wfh_window_w),
        .kernel_i(upsampler_h_0_kernel_w),
        .col_i   (v_pre_upsample_z_wfh_col_w),
        .row_i   (v_pre_upsample_z_wfh_row_w),
        .valid_i (v_pre_upsample_z_wfh_valid_w),

        .data_o  (v_pre_upsample_upsample_h_data_w),
        .col_o   (v_pre_upsample_upsample_h_col_w),
        .row_o   (v_pre_upsample_upsample_h_row_w),
        .valid_o (v_pre_upsample_upsample_h_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] v_pre_upsample_z_wfv_window_w [3][1];
    logic [15:0]                 v_pre_upsample_z_wfv_col_w;
    logic [15:0]                 v_pre_upsample_z_wfv_row_w;
    logic                        v_pre_upsample_z_wfv_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(3),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) v_pre_upsample_zero_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (v_pre_upsample_upsample_h_data_w),
        .col_i  (v_pre_upsample_upsample_h_col_w),
        .row_i  (v_pre_upsample_upsample_h_row_w),
        .valid_i(v_pre_upsample_upsample_h_valid_w),

        .window_o(v_pre_upsample_z_wfv_window_w),
        .col_o   (v_pre_upsample_z_wfv_col_w),
        .row_o   (v_pre_upsample_z_wfv_row_w),
        .valid_o (v_pre_upsample_z_wfv_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] v_upsampled_data_w;
    logic [15:0]                 v_upsampled_col_w;
    logic [15:0]                 v_upsampled_row_w;
    logic                        v_upsampled_valid_w;

    upsampler_v_0_fp16 v_pre_upsample_upsampler_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(v_pre_upsample_z_wfv_window_w),
        .kernel_i(upsampler_v_0_kernel_w),
        .col_i   (v_pre_upsample_z_wfv_col_w),
        .row_i   (v_pre_upsample_z_wfv_row_w),
        .valid_i (v_pre_upsample_z_wfv_valid_w),

        .data_o (v_upsampled_data_w),
        .col_o  (v_upsampled_col_w),
        .row_o  (v_upsampled_row_w),
        .valid_o(v_upsampled_valid_w)
    );

    ////////////////////////////////////////////////////////////////
    // Upsampling W
    //----------------------
    // zero inserter
    // window fetcher - 1x3
    // upsampler horizontal
    // window fetcher - 3x1
    // upsampler vertical

    logic [FP_WIDTH_REG - 1 : 0] w_pre_upsample_z_data_w;
    logic [15:0]                 w_pre_upsample_z_col_w;
    logic [15:0]                 w_pre_upsample_z_row_w;
    logic                        w_pre_upsample_z_valid_w;

    zero_inserter #(
        .EXP_WIDTH (EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .SCALE     (0)
    ) w_pre_upsampler_zero_inserter (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (w_pre_upsample_data_w),
        .col_i  (v_pre_upsample_col_w),
        .row_i  (v_pre_upsample_row_w),
        .valid_i(v_pre_upsample_valid_w),

        .data_o (w_pre_upsample_z_data_w),
        .col_o  (w_pre_upsample_z_col_w),
        .row_o  (w_pre_upsample_z_row_w),
        .valid_o(w_pre_upsample_z_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] w_pre_upsample_z_wfh_window_w [1][3];
    logic [15:0]                 w_pre_upsample_z_wfh_col_w;
    logic [15:0]                 w_pre_upsample_z_wfh_row_w;
    logic                        w_pre_upsample_z_wfh_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (3),
        .WINDOW_HEIGHT(1),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) w_pre_upsample_zero_fetcher_h (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (w_pre_upsample_z_data_w),
        .col_i  (w_pre_upsample_z_col_w),
        .row_i  (w_pre_upsample_z_row_w),
        .valid_i(w_pre_upsample_z_valid_w),

        .window_o(w_pre_upsample_z_wfh_window_w),
        .col_o   (w_pre_upsample_z_wfh_col_w),
        .row_o   (w_pre_upsample_z_wfh_row_w),
        .valid_o (w_pre_upsample_z_wfh_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] w_pre_upsample_upsample_h_data_w ;
    logic [15:0]                 w_pre_upsample_upsample_h_col_w;
    logic [15:0]                 w_pre_upsample_upsample_h_row_w;
    logic                        w_pre_upsample_upsample_h_valid_w;

    upsampler_h_0_fp16 w_pre_upsample_upsampler_h(
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(w_pre_upsample_z_wfh_window_w),
        .kernel_i(upsampler_h_0_kernel_w),
        .col_i   (w_pre_upsample_z_wfh_col_w),
        .row_i   (w_pre_upsample_z_wfh_row_w),
        .valid_i (w_pre_upsample_z_wfh_valid_w),

        .data_o  (w_pre_upsample_upsample_h_data_w),
        .col_o   (w_pre_upsample_upsample_h_col_w),
        .row_o   (w_pre_upsample_upsample_h_row_w),
        .valid_o (w_pre_upsample_upsample_h_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] w_pre_upsample_z_wfv_window_w [3][1];
    logic [15:0]                 w_pre_upsample_z_wfv_col_w;
    logic [15:0]                 w_pre_upsample_z_wfv_row_w;
    logic                        w_pre_upsample_z_wfv_valid_w;

    window_fetcher #(
        .DATA_WIDTH   (FP_WIDTH_REG),
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (IMAGE_HEIGHT),
        .WINDOW_WIDTH (1),
        .WINDOW_HEIGHT(3),
        .BORDER_ENABLE(BORDER_ENABLE)
    ) w_pre_upsample_zero_fetcher_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i (w_pre_upsample_upsample_h_data_w),
        .col_i  (w_pre_upsample_upsample_h_col_w),
        .row_i  (w_pre_upsample_upsample_h_row_w),
        .valid_i(w_pre_upsample_upsample_h_valid_w),

        .window_o(w_pre_upsample_z_wfv_window_w),
        .col_o   (w_pre_upsample_z_wfv_col_w),
        .row_o   (w_pre_upsample_z_wfv_row_w),
        .valid_o (w_pre_upsample_z_wfv_valid_w)
    );

    logic [FP_WIDTH_REG - 1 : 0] w_upsampled_data_w;
    logic [15:0]                 w_upsampled_col_w;
    logic [15:0]                 w_upsampled_row_w;
    logic                        w_upsampled_valid_w;

    upsampler_v_0_fp16 w_pre_upsample_upsampler_v (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .window_i(w_pre_upsample_z_wfv_window_w),
        .kernel_i(upsampler_v_0_kernel_w),
        .col_i   (w_pre_upsample_z_wfv_col_w),
        .row_i   (w_pre_upsample_z_wfv_row_w),
        .valid_i (w_pre_upsample_z_wfv_valid_w),

        .data_o (w_upsampled_data_w),
        .col_o  (w_upsampled_col_w),
        .row_o  (w_upsampled_row_w),
        .valid_o(w_upsampled_valid_w)
    );

    ////////////////////////////////////////////////////////////////
    // Assigning V and W outs
    assign v_o     = v_upsampled_data_w;
    assign w_o     = w_upsampled_data_w;
    assign col_o   = v_upsampled_col_w;
    assign row_o   = v_upsampled_row_w;
    assign valid_o = v_upsampled_valid_w;
    
    ////////////////////////////////////////////////////////////////
    // Assigning i_a and i_t downsampled outputs
    assign i_a_downsample_o   = i_a_gaussian_downsampled_data_w;
    assign i_t_downsample_o   = i_t_gaussian_downsampled_data_w;
    assign col_downsample_o   = i_a_gaussian_downsampled_col_w;
    assign row_downsample_o   = i_a_gaussian_downsampled_row_w;
    assign valid_downsample_o = i_a_gaussian_downsampled_valid_w;

endmodule
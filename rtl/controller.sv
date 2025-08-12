/*
 * Simple Controller that drives the constants
 * and two bilinear xform matrix values
 * Memory Map:
 * DfDD constants
 * ----------------------------
 * 0x00 - k1
 * 0x01 - k2
 * 0x02 - k3
 *
 * Homography matricies
 * ----------------------------
 * 0x10 -> 0x18 - Bilinear transform matrix for camera 0
 * 0x20 -> 0x28 - Bilinear transform matrix for camera 1
 *
 * Roi boundaries
 * ----------------------------
 * All roi's are fixed size - their dims are determined
 * (0x80, 0x81) - top-left corner of roi pre-bilinear-xform roi (y, x). roi is fixed-size
 * (0x82, 0x83) - top-left corner of roi post-bilinear-xform roi (y, x).
 *
 * Confidence minimum
 * ----------------------------
 * 0x50 - 1 byte for confidence minimum threshold
 *
 *
 * rest has no effect.
 *
 * Default (reset) parameters should be fully defined.
 */

module controller #(
    parameter FP_M_K = 2,
    parameter FP_N_K = 12,
    parameter FP_S_K = 1,

    parameter PRECISION = 0,

    // Default Values for Constants
    parameter [FP_M_K + FP_N_K + FP_S_K-1:0] K1 = 1 << FP_N_K,
    parameter [FP_M_K + FP_N_K + FP_S_K-1:0] K2 = 1 << FP_N_K,
    parameter [FP_M_K + FP_N_K + FP_S_K-1:0] K3 = 1 << FP_N_K,

    parameter [7:0] DEFAULT_CONFIDENCE_MINIMUM = 8'h00,

    // default values for ROIs
    parameter logic [15:0] DEFAULT_PRE_XFORM_ROI_CORNER [2] = '{ 0, 0},
    parameter logic [15:0] DEFAULT_POST_XFORM_ROI_CORNER [2] = '{ 0, 0},

    // fixed height and width for ROIs
    parameter logic [15:0] PRE_XFORM_ROI_DIMS [2] = '{480, 512},
    parameter logic [15:0] POST_XFORM_ROI_DIMS [2] = '{480, 512},

    // default values for bilinear matrices
    parameter [11+PRECISION-1:0] BILINEAR_1 = 19'b000_0000_0001_0000_0000,
    parameter [11+PRECISION-1:0] DEFAULT_BILINEAR_MATRICES [3][3]
        = '{{BILINEAR_1,0,0},{0,BILINEAR_1,0},{0,0,BILINEAR_1}}
) (
    input rst_n_i,

    command_interface.writer in,

    output [FP_M_K + FP_N_K + FP_S_K-1:0] k1_o,
    output [FP_M_K + FP_N_K + FP_S_K-1:0] k2_o,
    output [FP_M_K + FP_N_K + FP_S_K-1:0] k3_o,

    output [11+PRECISION-1:0] bilinear_matrices_o [2][3][3],

    // top, bottom, left, right
    output logic [15:0] pre_bilinear_roi_boundaries_o [4],
    output logic [15:0] post_bilinear_roi_boundaries_o [4],

    output [7:0] confidence_minimum_o
);
    localparam CONST_WIDTH = FP_M_K + FP_N_K + FP_S_K;
    localparam MATRIX_WIDTH = 11 + PRECISION;

    logic [in.ADDR_WIDTH-1:0] addr;
    logic [in.DATA_WIDTH-1:0] data;
    logic valid;

    logic [15:0] addr_next;
    logic [31:0] data_next;
    logic valid_next;

    logic [CONST_WIDTH-1:0] k1;
    logic [CONST_WIDTH-1:0] k2;
    logic [CONST_WIDTH-1:0] k3;

    logic [CONST_WIDTH-1:0] k1_next;
    logic [CONST_WIDTH-1:0] k2_next;
    logic [CONST_WIDTH-1:0] k3_next;

    logic [MATRIX_WIDTH-1:0] bilinear_matrices [2][3][3];
    logic [MATRIX_WIDTH-1:0] bilinear_matrices_next [2][3][3];

    logic [15:0] pre_bilinear_roi_corner [2];
    logic [15:0] post_bilinear_roi_corner [2];
    logic [15:0] pre_bilinear_roi_corner_next [2];
    logic [15:0] post_bilinear_roi_corner_next [2];

    logic [7:0] conf_min;
    logic [7:0] conf_min_next;

    always_comb begin
        addr_next = in.addr;
        data_next = in.data;
        valid_next = in.valid;

        k1_next = k1;
        k2_next = k2;
        k3_next = k3;

        bilinear_matrices_next = bilinear_matrices;

        pre_bilinear_roi_corner_next = pre_bilinear_roi_corner;
        post_bilinear_roi_corner_next = post_bilinear_roi_corner;

        conf_min_next = conf_min;

        // Memory Mappings
        if(valid) begin
            case(addr)
                // k1
                16'h00: k1_next = data[CONST_WIDTH-1:0];
                // k2
                16'h01: k2_next = data[CONST_WIDTH-1:0];
                // k3
                16'h02: k3_next = data[CONST_WIDTH-1:0];

                // matrix A
                16'h10: bilinear_matrices_next[0][0][0] = data[MATRIX_WIDTH-1:0];
                16'h11: bilinear_matrices_next[0][0][1] = data[MATRIX_WIDTH-1:0];
                16'h12: bilinear_matrices_next[0][0][2] = data[MATRIX_WIDTH-1:0];

                16'h13: bilinear_matrices_next[0][1][0] = data[MATRIX_WIDTH-1:0];
                16'h14: bilinear_matrices_next[0][1][1] = data[MATRIX_WIDTH-1:0];
                16'h15: bilinear_matrices_next[0][1][2] = data[MATRIX_WIDTH-1:0];

                16'h16: bilinear_matrices_next[0][2][0] = data[MATRIX_WIDTH-1:0];
                16'h17: bilinear_matrices_next[0][2][1] = data[MATRIX_WIDTH-1:0];
                16'h18: bilinear_matrices_next[0][2][2] = data[MATRIX_WIDTH-1:0];

                // matrix B
                16'h20: bilinear_matrices_next[1][0][0] = data[MATRIX_WIDTH-1:0];
                16'h21: bilinear_matrices_next[1][0][1] = data[MATRIX_WIDTH-1:0];
                16'h22: bilinear_matrices_next[1][0][2] = data[MATRIX_WIDTH-1:0];

                16'h23: bilinear_matrices_next[1][1][0] = data[MATRIX_WIDTH-1:0];
                16'h24: bilinear_matrices_next[1][1][1] = data[MATRIX_WIDTH-1:0];
                16'h25: bilinear_matrices_next[1][1][2] = data[MATRIX_WIDTH-1:0];

                16'h26: bilinear_matrices_next[1][2][0] = data[MATRIX_WIDTH-1:0];
                16'h27: bilinear_matrices_next[1][2][1] = data[MATRIX_WIDTH-1:0];
                16'h28: bilinear_matrices_next[1][2][2] = data[MATRIX_WIDTH-1:0];

                // confidence minimum
                16'h50: conf_min_next = data[7:0];

                // camera 0 ROI settings
                16'h80: pre_bilinear_roi_corner_next[0] = data[15:0];
                16'h81: pre_bilinear_roi_corner_next[1] = data[15:0];
                16'h82: post_bilinear_roi_corner_next[0] = data[15:0];
                16'h83: post_bilinear_roi_corner_next[1] = data[15:0];
                default: ;
            endcase
        end

        if(!rst_n_i) begin
            valid_next = 0;
            addr_next = 0;
            data_next = 0;

            k1_next = K1;
            k2_next = K2;
            k3_next = K3;

            conf_min_next = DEFAULT_CONFIDENCE_MINIMUM;

            bilinear_matrices_next[0] = DEFAULT_BILINEAR_MATRICES;
            bilinear_matrices_next[1] = DEFAULT_BILINEAR_MATRICES;

            pre_bilinear_roi_corner_next = DEFAULT_PRE_XFORM_ROI_CORNER;
            post_bilinear_roi_corner_next = DEFAULT_POST_XFORM_ROI_CORNER;
        end
    end

    always@(posedge in.clk) begin
        addr <= addr_next;
        data <= data_next;
        valid <= valid_next;

        k1 <= k1_next;
        k2 <= k2_next;
        k3 <= k3_next;

        bilinear_matrices <= bilinear_matrices_next;

        conf_min <= conf_min_next;

        pre_bilinear_roi_corner <= pre_bilinear_roi_corner_next;
        post_bilinear_roi_corner <= post_bilinear_roi_corner_next;

        pre_bilinear_roi_boundaries_o[0] <= pre_bilinear_roi_corner[0];
        pre_bilinear_roi_boundaries_o[1] <= pre_bilinear_roi_corner[0] + PRE_XFORM_ROI_DIMS[0];
        pre_bilinear_roi_boundaries_o[2] <= pre_bilinear_roi_corner[1];
        pre_bilinear_roi_boundaries_o[3] <= pre_bilinear_roi_corner[1] + PRE_XFORM_ROI_DIMS[1];

        post_bilinear_roi_boundaries_o[0] <= post_bilinear_roi_corner[0];
        post_bilinear_roi_boundaries_o[1] <= post_bilinear_roi_corner[0] + POST_XFORM_ROI_DIMS[0];
        post_bilinear_roi_boundaries_o[2] <= post_bilinear_roi_corner[1];
        post_bilinear_roi_boundaries_o[3] <= post_bilinear_roi_corner[1] + POST_XFORM_ROI_DIMS[1];
    end

    assign k1_o = k1;
    assign k2_o = k2;
    assign k3_o = k3;

    assign bilinear_matrices_o = bilinear_matrices;

    assign confidence_minimum_o = conf_min;
endmodule

/*
 * Simple Controller that drives the constants
 * and two bilinear xform matrix values
 * Memory Map:
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
 *
 * DfDD constants - each 2 bytes
 * ----------------------------
 * 0xA0 -> 0xA2 - A
 * 0xB0 -> 0xB2 - B
 * 0xC0 -> 0xC2 - w0
 * 0xD0 -> 0xD2 - w1
 * 0xE0 -> 0xE2 - w2
 * 
 *
 * Confidence minimum
 * ----------------------------
 * 0x50 - 2 bytes
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
    parameter [15:0] A  [3] = '{16'h3c00, 16'h3c00, 16'h3c00},
    parameter [15:0] B  [3] = '{16'h3c00, 16'h3c00, 16'h3c00},
    parameter [15:0] W0 [3] = '{16'h3c00, 16'h3c00, 16'h3c00},
    parameter [15:0] W1 [3] = '{16'h3c00, 16'h3c00, 16'h3c00},
    parameter [15:0] W2 [3] = '{16'h3c00, 16'h3c00, 16'h3c00},

    parameter [15:0] DEFAULT_CONFIDENCE_MINIMUM = 0,

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

    output [15:0] a_o  [3],
    output [15:0] b_o  [3],
    output [15:0] w0_o [3],
    output [15:0] w1_o [3],
    output [15:0] w2_o [3],

    output [11+PRECISION-1:0] bilinear_matrices_o [2][3][3],

    // top, bottom, left, right
    output logic [15:0] pre_bilinear_roi_boundaries_o [4],
    output logic [15:0] post_bilinear_roi_boundaries_o [4],

    output [15:0] confidence_o
);
    localparam CONST_WIDTH = FP_M_K + FP_N_K + FP_S_K;
    localparam MATRIX_WIDTH = 11 + PRECISION;

    logic [in.ADDR_WIDTH-1:0] addr;
    logic [in.DATA_WIDTH-1:0] data;
    logic valid;

    logic [15:0] addr_next;
    logic [31:0] data_next;
    logic valid_next;

    logic [15:0] a  [3];
    logic [15:0] b  [3];
    logic [15:0] w0 [3];
    logic [15:0] w1 [3];
    logic [15:0] w2 [3];

    logic [15:0] a_next  [3];
    logic [15:0] b_next  [3];
    logic [15:0] w0_next [3];
    logic [15:0] w1_next [3];
    logic [15:0] w2_next [3];

    logic [MATRIX_WIDTH-1:0] bilinear_matrices [2][3][3];
    logic [MATRIX_WIDTH-1:0] bilinear_matrices_next [2][3][3];

    logic [15:0] pre_bilinear_roi_corner [2];
    logic [15:0] post_bilinear_roi_corner [2];
    logic [15:0] pre_bilinear_roi_corner_next [2];
    logic [15:0] post_bilinear_roi_corner_next [2];

    logic [15:0] confidence;
    logic [15:0] confidence_next;

    always_comb begin
        addr_next = in.addr;
        data_next = in.data;
        valid_next = in.valid;

        a_next = a;
        b_next = b;
        w0_next = w0;
        w1_next = w1;
        w2_next = w2;

        bilinear_matrices_next = bilinear_matrices;

        pre_bilinear_roi_corner_next = pre_bilinear_roi_corner;
        post_bilinear_roi_corner_next = post_bilinear_roi_corner;

        confidence_next = confidence;

        // Memory Mappings
        if(valid) begin
            case(addr)
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

                // scale 0
                16'ha0: a_next [0] = data[15:0];
                16'hb0: b_next [0] = data[15:0];
                16'hc0: w0_next[0] = data[15:0];
                16'hd0: w1_next[0] = data[15:0];
                16'he0: w2_next[0] = data[15:0];

                // scale 1
                16'ha1: a_next [1] = data[15:0];
                16'hb1: b_next [1] = data[15:0];
                16'hc1: w0_next[1] = data[15:0];
                16'hd1: w1_next[1] = data[15:0];
                16'he1: w2_next[1] = data[15:0];

                // scale 2
                16'ha2: a_next [2] = data[15:0];
                16'hb2: b_next [2] = data[15:0];
                16'hc2: w0_next[2] = data[15:0];
                16'hd2: w1_next[2] = data[15:0];
                16'he2: w2_next[2] = data[15:0];

                // confidence minimum
                16'h50: confidence_next = data[15:0];

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

            a_next  = A;
            b_next  = B;
            w0_next = W0;
            w1_next = W1;
            w2_next = W2;

            confidence_next = DEFAULT_CONFIDENCE_MINIMUM;

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

        a  <= a_next;
        b  <= b_next;
        w0 <= w0_next;
        w1 <= w1_next;
        w2 <= w2_next;

        bilinear_matrices <= bilinear_matrices_next;

        confidence <= confidence_next;

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

    assign a_o  = a;
    assign b_o  = b;
    assign w0_o = w0;
    assign w1_o = w1;
    assign w2_o = w2;

    assign bilinear_matrices_o = bilinear_matrices;

    assign confidence_o = confidence;
endmodule

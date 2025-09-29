module radial_a_b_fp16 #(
    parameter NO_ZONES = 1,
) (
    input [15:0] a_i         [NO_ZONES],
    input [15:0] b_i         [NO_ZONES],
    input [15:0] r_squared_i [NO_ZONES],

    input [15:0] col_i,
    input [15:0] row_i,
    input [15:0] col_center_i,
    input [15:0] row_center_i,

    output [15:0] a_o,
    output [15:0] b_o
);

    logic signed [15:0] col; 
    logic signed [15:0] row;

    logic [15:0] distance_squared;

    always_comb begin
        col = col_i[15:0];
        row = row_i[15:0];

        col = col - col_center_i;
        row = row - row_center_i;

        col = col * col;
        row = row * row;

        distance_squared = col + row;

        a_o = a_i[NO_ZONES - 1];
        b_o = b_i[NO_ZONES - 1];

        for(int z = 0; z < (NO_ZONES - 1); z++) begin
            if(distance_squared >= r_squared_i[z]) begin
                a_o = a_i[z];
                b_o = b_i[z];
            end
        end
    end
endmodule
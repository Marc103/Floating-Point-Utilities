/*
 * Encapsulates an image
 */

class Image #(
    parameter DATA_WIDTH   = 0,
    parameter IMAGE_WIDTH  = 0,
    parameter IMAGE_HEIGHT = 0
);
    logic [DATA_WIDTH - 1 : 0] image [IMAGE_HEIGHT][IMAGE_WIDTH];
    int data_width;
    int width;
    int height;
    logic [15:0] col_center;
    logic [15:0] row_center;
    
    function new();
        this.data_width  = DATA_WIDTH;
        this.width       = IMAGE_WIDTH;
        this.height      = IMAGE_HEIGHT;
    endfunction

    function void generate_random_image();
        for(int r = 0; r < IMAGE_HEIGHT; r++) begin
            for(int c = 0; c < IMAGE_WIDTH; c++) begin
                this.image[r][c] = $urandom;
            end
        end
    endfunction

    function void generate_constant_image(int constant);
        for(int r = 0; r < IMAGE_HEIGHT; r++) begin
            for(int c = 0; c < IMAGE_WIDTH; c++) begin
                this.image[r][c] = constant;
            end
        end
    endfunction

    function void generate_increasing_image();
        int i = 0;
        for(int r = 0; r < IMAGE_HEIGHT; r++) begin
            for(int c = 0; c < IMAGE_WIDTH; c++) begin
                this.image[r][c] = i;
                i++;
            end
        end
    endfunction 

    function void print();
        $display();
        for(int r = 0; r < IMAGE_HEIGHT; r++) begin
            for(int c = 0; c < IMAGE_WIDTH; c++) begin
                $write("%h ", image[r][c]);
            end
            $display();
        end
        $display();
    endfunction   

endclass
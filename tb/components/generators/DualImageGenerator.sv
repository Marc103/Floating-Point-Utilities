import utilities_pkg::*;

class DualImageGenerator #(type T_0, type T_1);
    TriggerableQueueBroadcaster #(T_0) out_broadcaster_0;
    TriggerableQueueBroadcaster #(T_1) out_broadcaster_1;
    logic [15:0] col_center;
    logic [15:0] row_center;

    function new(TriggerableQueueBroadcaster #(T_0) out_broadcaster_0 ,
                 TriggerableQueueBroadcaster #(T_1) out_broadcaster_1);
        this.out_broadcaster_0 = out_broadcaster_0;
        this.out_broadcaster_1 = out_broadcaster_1;
    endfunction
    
    task automatic run();
        T_0 img_0;
        T_1 img_1;
        int seq;
        seq = 0;
        
        for(int i = 0; i < 2; i++) begin
            img_0 = new();
            img_1 = new();
            case(seq)
                0: begin
                    img_0.file_path = "";
                    img_1.file_path = "";
                end
                1: begin
                    img_0.file_path = "";
                    img_1.file_path = "";
                end
                2: begin
                    img_0.file_path = "";
                    img_1.file_path = "";
                end
                default: begin
                    img_0.file_path = "../test_images/default_image_gen.ppm";
                    img_1.file_path = "../test_images/default_image_gen.ppm";
                end
            endcase
            seq++;
            img_0.generate_image_from_ppm();
            img_1.generate_image_from_ppm();
            out_broadcaster_0.push(img_0);
            out_broadcaster_1.push(img_1);
        end
        
        $display("All values generated.");
        
    endtask
endclass
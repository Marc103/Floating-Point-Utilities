import utilities_pkg::*;

class DualImageMonitor #(type T_0, type T_1, type I);
    TriggerableQueueBroadcaster #(T) out_broadcaster_0;
    TriggerableQueueBroadcaster #(T) out_broadcaster_1
    I inf;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster,
                 I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T_0 depth;
        T_1 confidence;
        int seq;
        depth = new();
        confidence = new();
        seq = 0;
        forever begin
            @(negedge inf.clk_i);
            if(inf.valid_o) begin
                depth.image[inf.row_o][inf.col_o] = inf.z_o;
                confidence.image[inf.row_o][inf.col_o] = inf.c_o;

                if((inf.row_o == (depth.height - 1)) && (inf.col_o == (depth.col - 1))) begin
                    case(seq)
                        0 : begin 
                            depth.file_path = "";
                            confidence.file_path = "";
                        end
                        1 : begin
                            depth.file_path = "";
                            confidence.file_path = "";
                        end
                        2: begin
                            depth.file_path = "";
                            confidence.file_path = "";
                        end
                        default: begin
                            depth.file_path = "../result_images/default_depth_image.ppm";
                            confidence.file_path = "../result_images/default_confidence_image.ppm";
                        end
                    endcase
                    seq++;
                    depth.generate_ppm_from_image();
                    confidence.generate_ppm_from_image();

                    if(seq > 2) $finish;

                    //out_broadcaster_0.push(depth);
                    //out_broadcaster_1.push(confidence);
                    depth = new();
                    confidence = new();
                end
            end
        end
    endtask

endclass
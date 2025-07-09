import utilities_pkg::*;

class FpGenerator32 #(type T);
    localparam FP_WIDTH_REG = 32;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
    endfunction
    
    task automatic run();
        real a_r = 3;
        real b_r = 1;
        real r_r = 0;
        logic [FP_WIDTH_REG - 1 : 0] a = $shortrealtobits(a_r);
        logic [FP_WIDTH_REG - 1 : 0] b = $shortrealtobits(b_r);
        logic [FP_WIDTH_REG - 1 : 0] r = $shortrealtobits(r_r);
        T points = new(a, b, r);
        out_broadcaster.push(points);
    endtask
endclass
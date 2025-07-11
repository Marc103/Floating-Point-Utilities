class FpGenerator32 #(type T);
    localparam FP_WIDTH_REG = 1 + T.EXP_WIDTH + T.FRAC_WIDTH;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
    endfunction
    
    task automatic run();
        logic [FP_WIDTH_REG - 1 : 0] a = $shortrealtobits(1);
        logic [FP_WIDTH_REG - 1 : 0] b = $shortrealtobits(-1);
        logic [FP_WIDTH_REG - 1 : 0] r = $shortrealtobits(0);
        T points = new T(a, b, r);
        out_broadcaster.push(points);
    endtask
endclass
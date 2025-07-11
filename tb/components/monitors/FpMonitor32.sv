class FpMonitor32 #(type T, type I);
    localparam FP_WIDTH_REG = 1 + T.EXP_WIDTH + T.FRAC_WIDTH;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    virtual I inf;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster,
                 virtual I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T floating_points;
        forever begin
            @(negedge inf.clk_i);
            if(inf.valid_o) begin
                floating_points = new FloatingPoint(0, 0, inf.fp_o);
                out_broadcaster.push(floating_points);
            end
        end
    endtask

endclass
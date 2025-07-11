class FpMode32 #(type T);
    localparam FP_WIDTH_REG = 1 + T.EXP_WIDTH + T.FRAC_WIDTH;
    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    function new(
        TriggerableQueue in_queue,
        TriggerableQueue out_broadcaster
    );
        this.in_queue;
        this.out_broadcaster = out_broadcaster;
    endfunction

    task automatic run();
        T floating_points;
        shortreal a;
        shortreal b;
        shortreal r;
        logic [FP_WIDTH_REG - 1 : 0] a_bits;
        logic [FP_WIDTH_REG - 1 : 0] b_bits;
        logic [FP_WIDTH_REG - 1 : 0] r_bits;

        forever begin
            floating_points = in_queue.pop();
            a = $bitstoshortreal(floating_points.a);
            b = $bitstoshortreal(floating_points.b);
            r = a + b;
            a_bits = $shortrealtobits(a);
            b_bits = $shortrealtobits(b);
            r_bits = $shortrealtobits(r);
            floating_points = new FloatingPoint(a,b,r);
            out_broadcaster.push(floating_points);
        end
    endtask
endclass
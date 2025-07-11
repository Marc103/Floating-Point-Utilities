class FpDriver32 #(type T, type I);

    TriggerableQueue #(T) in_queue;
    virtual I inf;

    function new(
        TriggerableQueue #(T) in_queue,
        virtual I inf
    );
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive_fp(T floating_points);
        this.inf.fp_a_i  <= floating_points.floating_point_a;
        this.inf.fp_b_i  <= floating_points.floating_point_b;
        this.inf.valid_i <= 1;
        @(posedge this.inf.clk_i);
    endtask;

    task automatic invalidate();
        this.inf.valid_i <= 0;
    endtask;

    task automatic run();
        T floating_points;
        invalidate();

        forever begin
            floating_points = in_queue.pop();
            drive_fp(floating_points);
            invalidate();
        end
    endtask

endclass
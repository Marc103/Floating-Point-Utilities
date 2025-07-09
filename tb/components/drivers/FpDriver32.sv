import utilities_pkg::*;

class FpDriver32 #(type T, type I);

    TriggerableQueue #(T) in_queue;
    I inf;

    function new(
        TriggerableQueue #(T) in_queue,
        I inf
    );
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive_fp(T floating_points);
        this.inf.fp_a_i  <= floating_points.a;
        this.inf.fp_b_i  <= floating_points.b;
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
            in_queue.pop(floating_points);
            drive_fp(floating_points);
            invalidate();
        end
    endtask

endclass
import utilities_pkg::*;

class FpScoreboard32 #(type T);
    TriggerableQueue #(T) in_queue_dut;
    TriggerableQueue #(T) in_queue_golden;

    function new(
        TriggerableQueue #(T) in_queue_dut,
        TriggerableQueue #(T) in_queue_golden
    );
        this.in_queue_dut = in_queue_dut;
        this.in_queue_golden = in_queue_golden;
    endfunction

    task automatic run();
        T floating_points_dut;
        T floating_points_golden;
        forever begin
            in_queue_dut.pop(floating_points_dut);
            in_queue_golden.pop(floating_points_golden);
            if(floating_points_golden.r == floating_points_dut.r) begin
                /*
                $display("Pass expected: %h got %h", floating_points_golden.r, floating_points_dut.r);
                $display("A, B: %h %h",floating_points_golden.a, floating_points_golden.b);
                $display($bitstoshortreal(floating_points_golden.a));
                $display($bitstoshortreal(floating_points_golden.b));
                $display($bitstoshortreal(floating_points_golden.r));
                $display($bitstoshortreal(floating_points_dut.r));
                */
            end else begin
                if(((floating_points_dut.r - floating_points_golden.r) == 1) ||
                   ((floating_points_dut.r[30:23] == 255) && (floating_points_golden.r[30:23] == 255))) begin

                end else begin
                    $display("Error expected: %h got %h", floating_points_golden.r, floating_points_dut.r);
                    $display("A, B: %h %h",floating_points_golden.a, floating_points_golden.b);
                    $display($bitstoshortreal(floating_points_golden.a));
                    $display($bitstoshortreal(floating_points_golden.b));
                    $display($bitstoshortreal(floating_points_golden.r));
                    $display($bitstoshortreal(floating_points_dut.r));
                end
            end
        end

    endtask
endclass
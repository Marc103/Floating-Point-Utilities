
////////////////////////////////////////////////////////////////
// imports
import utilities_pkg::*;
import interfaces_pkg::*;
import drivers_pkg::*;
import generators_pkg::*;
import golden_models_pkg::*;
import monitors_pkg::*;
import scoreboards_pkg::*;

////////////////////////////////////////////////////////////////
// RTL includes
`include "floating_point_adder.sv"

module floating_point_adder_32_tb();

    ////////////////////////////////////////////////////////////////
    // localparams
    localparameter EXP_WIDTH = 8;
    localparameter FRAC_WIDTH = 23;
    
    localparam real CLK_PERIOD = 10;

    type localparam T = FloatingPoint #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    );

    type localparam I = floating_point_inf #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    );

    ////////////////////////////////////////////////////////////////
    // clock generation and reset
    logic clk = 0;
    logic rst = 0;
    always begin #(CLK_PERIOD/2); clk = ~clk; end

    ////////////////////////////////////////////////////////////////
    // interface
    I bfm;
    
    ////////////////////////////////////////////////////////////////
    // DUT
    floating_point_adder #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) dut (
        .clk_i(clk),
        .rst_i(rst),

        .fp_a_i(bfm.fp_a_i),
        .fp_b_i(bfm.fp_b_i),
        .valid_i(bfm.valid_i),

        .fp_o(bfm.fp_o),
        .valid_o(bfm.valid_o)
    );

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, floating_point_adder_32_tb);

        ////////////////////////////////////////////////////////////////
        // generator
        TriggerableQueueBroadcaster #(T) generator_out_broadcast = new();
        FpGenerator32 #(T) generator = new(generator_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // driver
        TriggerableQueue #(T) driver_in_queue = new();
        generator_out_broadcast.add_queue(driver_in_queue);

        FpDriver32 #(T) driver = new(driver_in_queue, bfm);

        ////////////////////////////////////////////////////////////////
        // golden model
        TriggerableQueue #(T) golden_in_queue = new();
        generator_out_broadcast.add_queue(golden_in_queue);
        TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();

        FpModel32 #(T) golden = new(golden_in_queue, golden_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // monitor
        TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();

        FpMonitor32 #(T) monitor = new(monitor_out_broadcast, bfm);


        ////////////////////////////////////////////////////////////////
        // scoreboard
        TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        FpScoreboard32 #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);
        ////////////////////////////////////////////////////////////////
        // watch dog

        // Run
        fork
            //generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
            //watchdog.run();
        join_none

        #1000;
    end



endmodule
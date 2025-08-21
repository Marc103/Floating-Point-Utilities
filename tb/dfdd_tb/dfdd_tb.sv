////////////////////////////////////////////////////////////////
// interface include 
`include "dfdd_fetcher_inf.svh"

////////////////////////////////////////////////////////////////
// package includes
`include "utilities_pkg.svh"
`include "drivers_pkg.svh"
`include "generators_pkg.svh"
`include "golden_models_pkg.svh"
`include "monitors_pkg.svh"
`include "scoreboards_pkg.svh"

////////////////////////////////////////////////////////////////
// imports
import utilities_pkg::*;
import drivers_pkg::*;
import generators_pkg::*;
import golden_models_pkg::*;
import monitors_pkg::*;
import scoreboards_pkg::*;

////////////////////////////////////////////////////////////////
// RTL includes
// third party
`include "async_fifo.v"
// main
`include "convolution_floating_point_z.sv"
`include "convolution_floating_point.sv"
`include "floating_point_adder_z.sv"
`include "floating_point_adder.sv"
`include "floating_point_divider_z.sv"
`include "floating_point_divider.sv"
`include "floating_point_multiplier_exponent.sv"
`include "floating_point_multiplier_z.sv"
`include "floating_point_multiplier.sv"
`include "stream_buffer.sv"
`include "stream_deserializer"
`include "uint8_fp16_converter.sv"
`include "window_fetcher_z.sv"
`include "window_fetcher.sv"
`include "zero_latency_buffer.sv"
// project/dfdd
`include "box_h_0_fp16.sv"
`include "box_v_0_fp16.sv"
`include "burt_h_0_fp16.sv"
`include "burt_v_0_fp16.sv"
`include "burt_h_1_fp16.sv"
`include "burt_v_1_fp16.sv"
`include "downsampler_0_fp16.sv"
`include "downsampler_h_0_fp16.sv"
`include "downsampler_v_0_fp16.sv"
`include "downsampler_h_1_fp16.sv"
`include "downsampler_v_1_fp16.sv"
`include "dual_scale_adder_fp16.sv"
`include "dx_0_fp16.sv"
`include "dy_0_fp16.sv"
`include "pass_0_fp16.sv"
`include "dx_1_fp16.sv"
`include "dy_1_fp16.sv"
`include "pass_1_fp16.sv"
`include "first_scale_fp16.sv"
`include "pass_dx_dy_adder_fp16.sv"
`include "preprocessor_fp16.sv"
`include "upsampler_0_fp16.sv"
`include "upsampler_h_0_fp16.sv"
`include "upsampler_h_1_fp16.sv"
`include "upsampler_v_0_fp16.sv"
`include "upsampler_v_1_fp16.sv"
`include "v_w_adder_1_fp16.sv"
`include "v_w_divider_0.sv"
`include "zero_inserter.sv"
`include "zero_scale_fp16.sv"

////////////////////////////////////////////////////////////////
// timescale 

module dfdd_tb();

    ////////////////////////////////////////////////////////////////
    // localparams
    localparam IMAGE_WIDTH  = 400;
    localparam IMAGE_HEIGHT = 400;

    localparam EXP_WIDTH = 5;
    localparam FRAC_WIDTH = 10;
    localparam FP_WIDTH_REG = 1 + FRAC_WIDTH + EXP_WIDTH;

    localparam BORDER_EXTENSION_CONSTANT = 0;
    localparam BORDER_ENABLE             = 1;
    
    localparam real CLK_PERIOD = 10;

    localparam type T_image = Image #(
        .DATA_WIDTH(FP_WIDTH_REG),
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    );

    localparam type I = virtual dfdd_inf #(
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
    dfdd_inf #(
        .EXP_WIDTH(EXP_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) bfm (.clk_i(clk), .rst_i(rst));
    
    ////////////////////////////////////////////////////////////////
    // DUT
    
    // dual_scale_wrapper.sv here

    initial begin
        ////////////////////////////////////////////////////////////////
        // generator
        static TriggerableQueueBroadcaster #(T_image) generator_out_broadcast_0 = new();
        static TriggerableQueueBroadcaster #(T_image) generator_out_broadcast_1 = new();
        static DualImageGenerator #(T_image, T_image) generator = new(generator_out_broadcast_0, generator_out_broadcast_1);

        ////////////////////////////////////////////////////////////////
        // driver
        static TriggerableQueue #(T_image) driver_in_queue_0 = new();
        static TriggerableQueue #(T_image) driver_in_queue_1 = new();
        static DualImageDriver #(T_image, T_image, I) driver = new(driver_in_queue_0, driver_in_queue_1, bfm);

        ////////////////////////////////////////////////////////////////
        // monitor
        static TriggerableQueueBroadcaster #(T_image) monitor_out_broadcast = new();
        static DualImageMonitor #(T_image, I) monitor = new(monitor_out_broadcast, bfm);

        ////////////////////////////////////////////////////////////////
        // Queue Linkage
        generator_out_broadcast_0.add_queue(driver_in_queue_0)
        generator_out_broadcast_1.add_queue(driver_in_queue_1);
        generator_out_broadcast.add_queue(golden_in_queue);

        ////////////////////////////////////////////////////////////////
        // Set up dump 
        $dumpfile("waves.vcd");
        $dumpvars(0, dfdd_tb);

        ////////////////////////////////////////////////////////////////
        // Reset logic
        bfm.valid_i <= 0;
        rst <= 0;
        repeat(5) @(posedge clk)
        rst <= 1;
        repeat(7) @(posedge clk)
        rst <= 0;
        // Run
        fork
            generator.run();
            driver.run();
            golden.run();
            monitor.run();
            //watchdog.run();
        join_none

        #4000000000;
        $finish;
    end



endmodule
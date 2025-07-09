import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

/**
 * Test the Floating Point Adder
 */

////////////////////////////////////////////////////////////////
// Test bench
/*
 * "Forked threads provide a concurrency abstraction for writing
 *  testbenches only, without real parallelism. The test
 *  infrastructure schedules threads one at a time, with threads
 *  running once per simulation cycle."
 *
 * "Thread order is deterministic, and attempts to follow lexical
 *  order (as it would appear from the code text): forked (child)
 *  threads run immediately, then return to the spawning (parent)
 *  thread. On future cycles, child threads run before their
 *  parent, in the order they were spawned."
 *
 * see https://github.com/ucb-bar/chiseltest
 *
 * I tried creating a testbench with a traditional driver, monitor,
 * and scoreboard using multithreading. The problems are
 * - forking in this context is just an abstraction
 * - couldn't find a single multithreaded example that employs the
 *   regular driver, monitor, scoreboard combo
 * - it really isn't clear how everything gets synchronized with the
 *   step of clock
 * - Although there are thread safe queues, they are not fork safe
 *   (so what are we supposed to do??)
 *
 * Just to make sure, i checked out UC Berkeley's own hard floating
 * test suite, they use C... I don't think anybody actually uses
 * chisel test for testing.
 *
 * I'm going to swap over to System Verilog. What really sucks is that
 * chisel does support FV within the toolchain by using the Z3 theorem
 * solver.
 */


class FloatingPointAdderTest extends AnyFlatSpec  with ChiselScalatestTester {
  "Simple FP32 Manual A + B add test" should "pass" in {
    test(new FloatingPointAdder(8,23)).withAnnotations(Seq(WriteVcdAnnotation)) { dut =>
      // Reset
      dut.reset.poke(true.B)
      dut.clock.step()
      dut.reset.poke(false.B)

      val a_0: Float =  64.toFloat
      val a_0_long = java.lang.Float.floatToIntBits(a_0).toLong & 0xFFFFFFFFL
      val b_0: Float =  32.toFloat
      val b_0_long = java.lang.Float.floatToIntBits(b_0).toLong & 0xFFFFFFFFL
      val r = a_0 + b_0
      val r_long = java.lang.Float.floatToIntBits(r).toLong & 0xFFFFFFFFL

      dut.io.fp_a_i.poke(a_0_long.U(32.W))
      dut.io.fp_b_i.poke(b_0_long.U(32.W))
      dut.io.valid_i.poke(1.U)
      dut.clock.step()

      dut.io.valid_i.poke(0.U)
      dut.clock.step(5)
      dut.io.fp_out_o.expect(r_long.U(32.W))
      dut.io.valid_o.expect(1.U)

      println("---------")
      println(r)
      println(r_long.toInt)


    }
  }
}

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

/**
 * Test the Floating Point Adder
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

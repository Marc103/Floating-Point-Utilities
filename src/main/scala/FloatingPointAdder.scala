

/* Floating Point Adder
 * Follows the IEEE 754 specification but has been parameterized
 * so that you can adjust how many exponent bits and fraction bits
 * you want.
 *
 * The total number of bits including the sign bit is
 * 1 + exp_bits + frac_bits.
 *
 * The total precision is 1 + frac_bits due to the leading bit being
 * 1 (also called hidden bit).
 *
 * The bias for the exponent is 2^(exp_bits - 1) - 1
 *
 * Zero or subnormal is represented when the exponent == 0. This means
 * that the leading bit becomes 0.
 *
 * Infinity or NaN is represented when the exponent == 2^(exp_bits) - 1
 *
 * This means the effective range of exponents are (unsigned --> signed)
 * normal:       [1, 2^(exp_bits) - 2]  --> [1 - (2^(exp_bits - 1) - 1), 2^(exp_bits - 1) - 1]
 * subnormal:    [0]                    --> [- 2^(exp_bits - 1)]
 * Infinity/NaN: [2^(exp_bits) - 1]     --> [  2^(exp_bits - 1)]
 *
 * Everything is stored as unsigned, then the bias is subtracted to get the real
 * exponent.
 */

import chisel3._

class FloatingPointAdder (exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle {
    val fp_a   = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_b   = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_out = Output(UInt((1 + exp_bits + frac_bits).W))
  })

  // Select Greater Magnitude       (sgm) - stage 1

  // Normalize to Greater magnitude (ngm) - stage 2

  // Round off Normalized Value     (rnv) - stage 3

  // Add Values Together            (avt) - stage 4

  // Normalize Result               (nr)  - stage 5

}

// Select Greater Magnitude
/* We have to identify the greater magnitude value by looking
 * at the exponent (sign doesn't matter) and reorder. We also
 * calculate the difference and pass that down.
 * [ < ] - exp_bits
 * [ - ] - exp_bits
 *
 */
class SGM(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_a     = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_b     = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_big   = Output(UInt((1 + exp_bits + frac_bits).W))
    val fp_small = Output(UInt((1 + exp_bits + frac_bits).W))
    val exp_diff = Output(UInt(exp_bits.W))
  })


}

class NGM(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_big   = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_small = Input(UInt((1 + exp_bits + frac_bits).W))
  })
}


object FloatingPointAdderMain extends App {
  println("Generating Floating Pointer Adder hardware.")
}

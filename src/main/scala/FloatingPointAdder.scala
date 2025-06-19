

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

  // Select Greater Magnitude          (SGM)  - stage 1

  // Normalize to Greater Magnitude    (NGM)  - stage 2

  // Round off Normalized Value        (RNV)  - stage 3

  // Select Greater Fraction and Sign  (SGFS) - stage 4

  // Add Values Together               (AVT)  - stage 5

  // Normalize Result                  (NR)   - stage 6

  // Round off Result                  (RR)   - stage 7

}

// Select Greater Magnitude
/* We have to identify the greater magnitude value by looking
 * at the exponent (sign doesn't matter) and reorder. We also
 * calculate the difference of the exponents and pass that down.
 * We also will determine if either. Also check for exponent
 * == 0 and pass that information (if exponent == 0 then lead
 * bit is 0)
 *
 * [ < ] - exp_bits
 * [ - ] - exp_bits
 * [ == 0] [ == 0] - exp_bits
 */
class SGM(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_a              = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_b              = Input(UInt((1 + exp_bits + frac_bits).W))

    val fp_big            = Output(UInt((1 + exp_bits + frac_bits).W))
    val fp_big_lead_bit   = Output(UInt(1.W))
    val fp_small          = Output(UInt((1 + exp_bits + frac_bits).W))
    val fp_small_lead_bit = Output(UInt(1.W))
    val exp_diff          = Output(UInt(exp_bits.W))
  })


}

// Normalize to Greater Magnitude
/* Using the exponent difference, we take fp_small
 * and right shift it so that it matches the same
 * magnitude. This could potentially put it in a
 * subnormal form since the leading bit would become
 * 0 (but that's fine). We need to pass the round bit
 * as well. Use lead bit to check if subnormal.
 * [ variable right shifter ]
 */
class NGM(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_big            = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_big_lead_bit   = Input(UInt(1.W))
    val fp_small          = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_small_lead_bit = Input(UInt(1.W))
    val exp_diff          = Input(UInt(exp_bits.W))

    val fp_a              = Output(UInt((1 + exp_bits + frac_bits).W))
    val fp_a_lead_bit     = Output(UInt(1.W))
    val fp_b              = Output(UInt((1 + exp_bits + frac_bits).W))
    val fp_b_lead_bit     = Output(UInt(1.W))
    val fp_b_round_bit    = Output(UInt(1.W))
  })
}

// Round off Normalized Value
/* We need to round the normalized value. If no shift occurred, then
 * no rounding is needed. If a shift occurred, then that same shift
 * of at least 1 will prevent the rounding itself to overflow. Instead
 * of checking, a simpler way is to always add a round bit anyway.
 * [+] - frac_bits
 */

class RNV(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_a               = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_a_lead_bit      = Input(UInt(1.W))
    val fp_b               = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_b_lead_bit      = Input(UInt(1.W))
    val fp_b_round_bit     = Input(UInt(1.W))

    val fp_a_norm          = Output(UInt((1 + exp_bits + frac_bits).W))
    val fp_a_norm_lead_bit = Output(UInt(1.W))
    val fp_b_norm          = Output(UInt((1 + exp_bits + frac_bits).W))
    val fp_b_norm_lead_bit = Output(UInt(1.W))
  })
}

// Add Values Together
/* Now that the two values are on the same order of magnitudes,
 * we can add them together. This involves selecting the bigger
 * fraction of the two if the signs aren't equal and subtracting.
 * Otherwise, we just add.
 * [ > ] - frac_bits
 * [ + ] - frac_bits
 */
class AVT(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_a_norm           = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_a_norm_lead_bit  = Input(UInt(1.W))
    val fp_b_norm           = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_b_norm_lead_bit  = Input(UInt(1.W))

    val fp_result_exp      = Output(UInt((1 + exp_bits + frac_bits).W))
    val fp_result_frac
    val fp_result_lead_bit
    val fp_result_round_bit = Output(UInt(1.W))
  })
}

// Normalize Results
/* We need to take the result and normalize it. This is also
 * a variable shifter depending on where the first 1 value is
 * found. If the frac bits turn out to be 0, set output exponent
 * also to 0.
 * [variable shifter, either 1 right or multiple left] - frac_bits
 *
 */

// Round Results
/* Finally, using the round bit, round the results.
 *
 */


object FloatingPointAdderMain extends App {
  println("Generating Floating Pointer Adder hardware.")
}

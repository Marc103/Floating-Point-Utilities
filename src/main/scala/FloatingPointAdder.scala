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
 *
 * 'Regular form' : [sign bit | exponent bits | fractional bits]
 * but to fully encapsulate information for the coming operation, I've come up with a
 *
 * 'Total form'   : [sign bit | exponent bits | carry bit | lead bit | fractional bits | round bit ].
 * We encode 3 additional bits of information, carry, lead and round bit. The order of the bits
 * is most convenient. Originally I wanted to call it 'Full form' but that abbreviates as FF
 * which can be confused with flip-flop.
 *
 * SGM - stage 1, is also in charge of placing everything in its full form. So for example,
 * if the exponent is 0, it is actually set to 1 and the lead bit is set to 0. The carry bit
 * and round bit start off as 0.
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
 * If the exponent == 0 then lead bit is 0 and the exponent is
 * set to 1. This is the value that should be used to calculate
 * the exponent difference. Output in total form.
 * [ == 0] [ == 0] - exp_bits
 * [ < ] - exp_bits
 * [ - ] - exp_bits
 */
class SGM(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_a     = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_b     = Input(UInt((1 + exp_bits + frac_bits).W))

    val fp_big   = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_small = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val exp_diff = Output(UInt(exp_bits.W))
  })

  ////////////////////////////////////////////////////////////////
  // Local parameters
  val sign_idx = frac_bits + exp_bits
  val exp_idx  = frac_bits
  val frac_idx = 0

  ////////////////////////////////////////////////////////////////
  // Setting up Registers and initial values
  val fp_a_reg = RegInit(UInt((1 + exp_bits + frac_bits).W))
  val fp_b_reg = RegInit(UInt((1 + exp_bits + frac_bits).W))

  fp_a_reg := io.fp_a
  fp_b_reg := io.fp_b

  ////////////////////////////////////////////////////////////////
  // Setting up wires and default values
  val fp_a_sign  = Wire(UInt(1.W))
  val fp_a_exp   = Wire(UInt(exp_bits.W))
  val fp_a_carry = Wire(UInt(1.W))
  val fp_a_lead  = Wire(UInt(1.W))
  val fp_a_frac  = Wire(UInt(frac_bits.W))
  val fp_a_round = Wire(UInt(1.W))

  val fp_b_sign  = Wire(UInt(1.W))
  val fp_b_exp   = Wire(UInt(exp_bits.W))
  val fp_b_carry = Wire(UInt(1.W))
  val fp_b_lead  = Wire(UInt(1.W))
  val fp_b_frac  = Wire(UInt(frac_bits.W))
  val fp_b_round = Wire(UInt(1.W))

  fp_a_sign  := fp_a_reg(sign_idx)
  fp_a_exp   := fp_a_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_a_carry := 0.U
  fp_a_lead  := 1.U
  fp_a_frac  := fp_a_reg(frac_idx + frac_bits - 1, frac_idx)
  fp_a_round := 0.U

  fp_b_sign  := fp_b_reg(sign_idx)
  fp_b_exp   := fp_b_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_b_carry := 0.U
  fp_b_lead  := 1.U
  fp_b_frac  := fp_b_reg(frac_idx + frac_bits - 1, frac_idx)
  fp_b_round := 0.U

  ////////////////////////////////////////////////////////////////
  // checking for zero exponents and setting accordingly
  when(fp_a_exp === 0.U) {
    fp_a_exp := 1.U
    fp_a_lead := 0.U
  }
  when(fp_b_exp === 0.U){
    fp_b_exp  := 1.U
    fp_b_lead := 0.U
  }

  ////////////////////////////////////////////////////////////////
  // Find bigger magnitude, flip if so
  val tmp_sign  = Wire(UInt(1.W))
  val tmp_exp   = Wire(UInt(exp_bits.W))
  val tmp_carry = Wire(UInt(1.W))
  val tmp_lead  = Wire(UInt(1.W))
  val tmp_frac  = Wire(UInt(frac_bits.W))
  val tmp_round = Wire(UInt(1.W))

  tmp_sign  := fp_a_sign
  tmp_exp   := fp_a_exp
  tmp_carry := fp_a_carry
  tmp_lead  := fp_a_lead
  tmp_frac  := fp_a_frac
  tmp_round := fp_a_round
  when(fp_b_exp > fp_a_exp) {
    fp_a_sign  := fp_b_sign
    fp_a_exp   := fp_b_exp
    fp_a_carry := fp_b_carry
    fp_a_lead  := fp_b_lead
    fp_a_frac  := fp_b_frac
    fp_a_round := fp_b_round

    fp_b_sign  := tmp_sign
    fp_b_exp   := tmp_exp
    fp_b_carry := tmp_carry
    fp_b_lead  := tmp_lead
    fp_b_frac  := tmp_frac
    fp_b_round := tmp_round
  }

  ////////////////////////////////////////////////////////////////
  // Set out in total form and find exponent difference
  io.fp_big   := (fp_a_sign  ##
                  fp_a_exp   ##
                  fp_a_carry ##
                  fp_a_lead  ##
                  fp_a_frac  ##
                  fp_a_round)
  io.fp_small := (fp_b_sign  ##
                  fp_b_exp   ##
                  fp_b_carry ##
                  fp_b_lead  ##
                  fp_b_frac  ##
                  fp_b_round)
  io.exp_diff := (fp_a_exp - fp_b_exp)

}

// Normalize to Greater Magnitude
/* Using the exponent difference, we take fp_small
 * and right shift it so that it matches the same
 * magnitude. Since everything is in the total form,
 * maintaining lead, carry and round bit needs to be
 * kept in mind.
 * [ variable right shifter ]
 */
class NGM(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_big   = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_small = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val exp_diff = Input(UInt(exp_bits.W))

    val fp_a     = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_b     = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  })

  ////////////////////////////////////////////////////////////////
  // Local parameters
  val sign_idx       = exp_bits + 1 + 1 + frac_bits + 1
  val exp_idx        = 1 + 1 + frac_bits + 1
  val carry_idx      = 1 + frac_bits + 1
  val lead_idx       = frac_bits + 1
  val frac_idx       = 1
  val round_idx      = 0
  val frac_total_idx = 0
  val frac_total_bits = 1 + 1 + frac_bits + 1

  ////////////////////////////////////////////////////////////////
  // Setting up Registers and initial values
  val fp_big_reg   = RegInit(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val fp_small_reg = RegInit(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val exp_diff_reg = RegInit(UInt(exp_bits.W))

  fp_big_reg   := io.fp_big
  fp_small_reg := io.fp_small
  exp_diff_reg := io.exp_diff

  ////////////////////////////////////////////////////////////////
  // Setting up wires and default values
  val fp_big_exp                  = Wire(UInt(exp_bits.W))

  val fp_small_sign               = Wire(UInt(1.W))
  val fp_small_exp                = Wire(UInt(exp_bits.W))
  val fp_small_carry              = Wire(UInt(1.W))
  val fp_small_lead               = Wire(UInt(1.W))
  val fp_small_frac               = Wire(UInt(frac_bits.W))
  val fp_small_round              = Wire(UInt(1.W))
  val fp_small_frac_total         = Wire(UInt((1 + 1 + frac_bits + 1).W))
  val fp_small_frac_total_shifted = Wire(UInt((1 + 1 + frac_bits + 1).W))

  fp_big_exp                  := fp_big_reg(exp_idx + exp_bits - 1, exp_idx)

  fp_small_sign               := fp_small_reg(sign_idx)
  fp_small_exp                := fp_small_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_small_carry              := fp_small_reg(carry_idx)
  fp_small_lead               := fp_small_reg(lead_idx)
  fp_small_frac               := fp_small_reg(frac_idx + frac_bits - 1, frac_idx)
  fp_small_round              := fp_small_reg(round_idx)
  fp_small_frac_total         := fp_small_reg(frac_total_idx + frac_total_bits - 1, frac_total_idx)
  fp_small_frac_total_shifted := fp_small_frac_total

  ////////////////////////////////////////////////////////////////
  // Variable Right Shifter
  // if it's all 0, set exponent to 0 and lead to 0
  // if we are shifting
  when(fp_small_frac_total =/= 0.U){
    fp_small_frac_total_shifted := 0.U
    // need to consider lead bit and round bit
    when(exp_diff_reg <= (frac_bits + 1).U){
      // variable right shifter
      fp_small_frac_total_shifted := fp_small_frac_total >> exp_diff_reg
    }
  }

  ////////////////////////////////////////////////////////////////
  // Set out
  io.fp_a := fp_big_reg
  io.fp_b := (fp_small_sign ##
              fp_big_exp ##
              fp_small_frac_total_shifted)

}

// Round off Normalized Value
/* We need to round the normalized value by using the round bit. Although,
 * we maintain a carry bit, if a shift occurred, rounding will not cause the
 * carry bit to become 1. This is important because if the carry bit became one
 * that would signal having to increment the exponent by 1 (which would throw
 * away all our efforts at normalize the magnitudes) Using total form, this just
 * means adding 1 to
 * 'frac_total' - carry bit, lead bit, frac_bits, round_bit to fp_b.
 * [+] - frac_bits
 */
class RNV(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_a              = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_b              = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))

    val fp_a_norm          = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_b_norm          = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  })
  ////////////////////////////////////////////////////////////////
  // Local parameters
  val sign_idx       = exp_bits + 1 + 1 + frac_bits + 1
  val exp_idx        = 1 + 1 + frac_bits + 1
  val frac_total_idx = 0
  val frac_total_bits = 1 + 1 + frac_bits + 1

  ////////////////////////////////////////////////////////////////
  // Setting up Registers and initial values
  val fp_a_reg = RegInit(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val fp_b_reg = RegInit(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))

  fp_a_reg := io.fp_a
  fp_b_reg := io.fp_b

  ////////////////////////////////////////////////////////////////
  // Setting up wires and default values
  val fp_b_sign       = Wire(UInt(1.W))
  val fp_b_exp        = Wire(UInt(exp_bits.W))
  val fp_b_frac_total = Wire(UInt((1 + 1 + frac_bits + 1).W))

  fp_b_sign       := fp_b_reg(sign_idx)
  fp_b_exp        := fp_b_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_b_frac_total := fp_b_reg(frac_total_idx + frac_total_bits - 1, frac_total_idx)

  ////////////////////////////////////////////////////////////////
  // Round
  fp_b_frac_total := fp_b_frac_total + 1.U

  ////////////////////////////////////////////////////////////////
  // Set out
  io.fp_a_norm := fp_a_reg
  io.fp_b_norm := (fp_b_sign ##
                   fp_b_exp ##
                   fp_b_frac_total)
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
    val fp_a_norm  = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_b_norm  = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))

    val fp_result  = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  })
}

// Normalize Results
/* We need to take the result and normalize it. This is also
 * a variable shifter depending on where the first 1 value is
 * found. If the frac bits turn out to be 0, set output exponent
 * also to 0. If exponent underflow, set to 0, if exponent overflow,
 * set to max value.
 * [variable shifter, either 1 right or multiple left] - frac_bits, [add exponent] - 8 bits
 * [ < ] - exp_bits
 *
 */
class NR(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle {
    val fp_result      = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))

    val fp_result_norm  = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  })
}

// Round Results
/* Finally, using the round bit, round the results.
 * In this case an overflow could happen which would cause the exponent to increase by 1.
 * Which means we would also have to check exponent overflow, which if it does happen,
 * we just set the exponent to max value.
 * [ + ] - frac_bits
 * [ < ] - exp_bits
 */
class RR(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle {
    val fp_result_norm  = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))

    val fp_out          = Output(UInt((1 + exp_bits + frac_bits).W))
  })
}


object FloatingPointAdderMain extends App {
  println("Generating Floating Pointer Adder hardware.")
}

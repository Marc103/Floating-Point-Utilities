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
import scala.math.pow

class FloatingPointAdder (exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle {
    val fp_a_i    = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_b_i    = Input(UInt((1 + exp_bits + frac_bits).W))
    val valid_i   = Input(UInt(1.W))
    val fp_out_o  = Output(UInt((1 + exp_bits + frac_bits).W))
    val valid_o   = Output(UInt(1.W))
  })

  // Select Greater Magnitude          (SGM)  - stage 1
  val SGM = Module(new SGM(exp_bits, frac_bits))
  SGM.io.fp_a_i  := io.fp_a_i
  SGM.io.fp_b_i  := io.fp_b_i
  SGM.io.valid_i := io.valid_i

  // Normalize to Greater Magnitude    (NGM)  - stage 2
  val NGM = Module(new NGM(exp_bits, frac_bits))
  NGM.io.fp_big   := SGM.io.fp_big
  NGM.io.fp_small := SGM.io.fp_small
  NGM.io.exp_diff := SGM.io.exp_diff
  NGM.io.valid_0  := SGM.io.valid_0

  // Round off Normalized Value        (RNV)  - stage 3
  val RNV = Module(new RNV(exp_bits, frac_bits))
  RNV.io.fp_a    := NGM.io.fp_a
  RNV.io.fp_b    := NGM.io.fp_b
  RNV.io.valid_1 := NGM.io.valid_1

  // Add Values Together               (AVT)  - stage 4
  val AVT = Module(new AVT(exp_bits, frac_bits))
  AVT.io.fp_a_norm := RNV.io.fp_a_norm
  AVT.io.fp_b_norm := RNV.io.fp_b_norm
  AVT.io.valid_0   := RNV.io.valid_0

  // Normalize Result                  (NR)   - stage 5
  val NR = Module(new NR(exp_bits, frac_bits))
  NR.io.fp_result := AVT.io.fp_result
  NR.io.valid_1   := AVT.io.valid_1

  // Round off Result                  (RR)   - stage 6
  val RR = Module(new RR(exp_bits, frac_bits))
  RR.io.fp_result_norm := NR.io.fp_result_norm
  RR.io.valid_0        := NR.io.valid_0

  // out
  io.fp_out_o := RR.io.fp_out_o
  io.valid_o := RR.io.valid_o

}

// Select Greater Magnitude (SGM) - stage 1
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
    val fp_a_i     = Input(UInt((1 + exp_bits + frac_bits).W))
    val fp_b_i     = Input(UInt((1 + exp_bits + frac_bits).W))
    val valid_i    = Input(UInt(1.W))

    val fp_big   = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_small = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val exp_diff = Output(UInt(exp_bits.W))
    val valid_0  = Output(UInt(1.W))

  })

  ////////////////////////////////////////////////////////////////
  // Local parameters
  val sign_idx = frac_bits + exp_bits
  val exp_idx  = frac_bits
  val frac_idx = 0

  ////////////////////////////////////////////////////////////////
  // Setting up Registers and initial values
  val fp_a_i_reg = Reg(UInt((1 + exp_bits + frac_bits).W))
  val fp_b_i_reg = Reg(UInt((1 + exp_bits + frac_bits).W))
  val valid_reg  = RegInit(0.U(1.W))

  fp_a_i_reg := io.fp_a_i
  fp_b_i_reg := io.fp_b_i
  valid_reg  := io.valid_i

  ////////////////////////////////////////////////////////////////
  // Setting up wires and default values
  val fp_a_i_sign  = Wire(UInt(1.W))
  val fp_a_i_exp   = Wire(UInt(exp_bits.W))
  val fp_a_i_carry = Wire(UInt(1.W))
  val fp_a_i_lead  = Wire(UInt(1.W))
  val fp_a_i_frac  = Wire(UInt(frac_bits.W))
  val fp_a_i_round = Wire(UInt(1.W))

  val fp_b_i_sign  = Wire(UInt(1.W))
  val fp_b_i_exp   = Wire(UInt(exp_bits.W))
  val fp_b_i_carry = Wire(UInt(1.W))
  val fp_b_i_lead  = Wire(UInt(1.W))
  val fp_b_i_frac  = Wire(UInt(frac_bits.W))
  val fp_b_i_round = Wire(UInt(1.W))

  fp_a_i_sign  := fp_a_i_reg(sign_idx)
  fp_a_i_exp   := fp_a_i_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_a_i_carry := 0.U
  fp_a_i_lead  := 1.U
  fp_a_i_frac  := fp_a_i_reg(frac_idx + frac_bits - 1, frac_idx)
  fp_a_i_round := 0.U

  fp_b_i_sign  := fp_b_i_reg(sign_idx)
  fp_b_i_exp   := fp_b_i_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_b_i_carry := 0.U
  fp_b_i_lead  := 1.U
  fp_b_i_frac  := fp_b_i_reg(frac_idx + frac_bits - 1, frac_idx)
  fp_b_i_round := 0.U

  ////////////////////////////////////////////////////////////////
  // checking for zero exponents and setting accordingly
  val fp_a_i_exp_const = Wire(UInt(exp_bits.W))
  fp_a_i_exp_const := fp_a_i_reg(exp_idx + exp_bits - 1, exp_idx)
  when(fp_a_i_exp_const === 0.U) {
    fp_a_i_exp := 1.U
    fp_a_i_lead := 0.U
  }
  val fp_b_i_exp_const = Wire(UInt(exp_bits.W))
  fp_b_i_exp_const := fp_b_i_reg(exp_idx + exp_bits - 1, exp_idx)
  when(fp_b_i_exp_const === 0.U){
    fp_b_i_exp  := 1.U
    fp_b_i_lead := 0.U
  }


  ////////////////////////////////////////////////////////////////
  // Find bigger magnitude, flip if so
  val tmp_0_sign  = Wire(UInt(1.W))
  val tmp_0_exp   = Wire(UInt(exp_bits.W))
  val tmp_0_carry = Wire(UInt(1.W))
  val tmp_0_lead  = Wire(UInt(1.W))
  val tmp_0_frac  = Wire(UInt(frac_bits.W))
  val tmp_0_round = Wire(UInt(1.W))

  val tmp_1_sign  = Wire(UInt(1.W))
  val tmp_1_exp   = Wire(UInt(exp_bits.W))
  val tmp_1_carry = Wire(UInt(1.W))
  val tmp_1_lead  = Wire(UInt(1.W))
  val tmp_1_frac  = Wire(UInt(frac_bits.W))
  val tmp_1_round = Wire(UInt(1.W))

  tmp_0_sign  := fp_a_i_sign
  tmp_0_exp   := fp_a_i_exp
  tmp_0_carry := fp_a_i_carry
  tmp_0_lead  := fp_a_i_lead
  tmp_0_frac  := fp_a_i_frac
  tmp_0_round := fp_a_i_round

  tmp_1_sign  := fp_b_i_sign
  tmp_1_exp   := fp_b_i_exp
  tmp_1_carry := fp_b_i_carry
  tmp_1_lead  := fp_b_i_lead
  tmp_1_frac  := fp_b_i_frac
  tmp_1_round := fp_b_i_round

  when(fp_b_i_exp > fp_a_i_exp) {
    tmp_1_sign  := fp_a_i_sign
    tmp_1_exp   := fp_a_i_exp
    tmp_1_carry := fp_a_i_carry
    tmp_1_lead  := fp_a_i_lead
    tmp_1_frac  := fp_a_i_frac
    tmp_1_round := fp_a_i_round

    tmp_0_sign  := fp_b_i_sign
    tmp_0_exp   := fp_b_i_exp
    tmp_0_carry := fp_b_i_carry
    tmp_0_lead  := fp_b_i_lead
    tmp_0_frac  := fp_b_i_frac
    tmp_0_round := fp_b_i_round
   }




  ////////////////////////////////////////////////////////////////
  // Set out in total form and find exponent difference
  io.fp_big   := (tmp_0_sign  ##
                  tmp_0_exp   ##
                  tmp_0_carry ##
                  tmp_0_lead  ##
                  tmp_0_frac  ##
                  tmp_0_round)
  io.fp_small := (tmp_1_sign  ##
                  tmp_1_exp   ##
                  tmp_1_carry ##
                  tmp_1_lead  ##
                  tmp_1_frac  ##
                  tmp_1_round)
  io.exp_diff := (tmp_0_exp - tmp_1_exp)
  io.valid_0 := valid_reg
}

// Normalize to Greater Magnitude (NGM) - stage 2
/* Using the exponent difference, we take fp_small
 * and right shift it so that it matches the same
 * magnitude. Since everything is in the total form,
 * maintaining lead, carry and round bit needs to be
 * kept in mind.
 * [ variable right shifter ] - frac_bits
 */
class NGM(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_big   = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_small = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val exp_diff = Input(UInt(exp_bits.W))
    val valid_0  = Input(UInt(1.W))

    val fp_a     = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_b     = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val valid_1  = Output(UInt(1.W))
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
  val fp_big_reg   = Reg(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val fp_small_reg = Reg(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val exp_diff_reg = Reg(UInt(exp_bits.W))
  val valid_reg    = RegInit(0.U(1.W))

  fp_big_reg   := io.fp_big
  fp_small_reg := io.fp_small
  exp_diff_reg := io.exp_diff
  valid_reg    := io.valid_0

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
  io.valid_1 := valid_reg

}

// Round off Normalized Value (RNV) - stage 3
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
    val fp_a      = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_b      = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val valid_1   = Input(UInt(1.W))

    val fp_a_norm = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_b_norm = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val valid_0   = Output(UInt(1.W))
  })
  ////////////////////////////////////////////////////////////////
  // Local parameters
  val sign_idx       = exp_bits + 1 + 1 + frac_bits + 1
  val exp_idx        = 1 + 1 + frac_bits + 1
  val round_idx      = 0
  val frac_total_idx = 0
  val frac_total_bits = 1 + 1 + frac_bits + 1

  ////////////////////////////////////////////////////////////////
  // Setting up Registers and initial values
  val fp_a_reg = Reg(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val fp_b_reg = Reg(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val valid_reg = RegInit(0.U(1.W))

  fp_a_reg := io.fp_a
  fp_b_reg := io.fp_b
  valid_reg := io.valid_1

  ////////////////////////////////////////////////////////////////
  // Setting up wires and default values
  val fp_b_sign         = Wire(UInt(1.W))
  val fp_b_exp          = Wire(UInt(exp_bits.W))
  val fp_b_frac_total   = Wire(UInt((1 + 1 + frac_bits + 1).W))
  val fp_b_frac_total_0 = Wire(UInt((1 + 1 + frac_bits + 1).W))

  fp_b_sign       := fp_b_reg(sign_idx)
  fp_b_exp        := fp_b_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_b_frac_total := fp_b_reg(frac_total_idx + frac_total_bits - 1, frac_total_idx)

  ////////////////////////////////////////////////////////////////
  // Round
  when(fp_b_frac_total(round_idx)) {
    fp_b_frac_total_0 := fp_b_frac_total + 1.U
  } .otherwise {
    fp_b_frac_total_0 := fp_b_frac_total
  }


  ////////////////////////////////////////////////////////////////
  // Set out
  io.fp_a_norm := fp_a_reg
  io.fp_b_norm := (fp_b_sign ##
                   fp_b_exp ##
                   fp_b_frac_total_0)
  io.valid_0 := valid_reg
}

// Add Values Together (AVT) - stage 4
/* Now that the two values are on the same order of magnitudes,
 * we can add them together. If the sign bits are the same, simply add
 * them. If they are different, it might seem complicated but actually
 * there's an elegant solution. If the negative value is bigger, still
 * add them. The carry bit will act as the sign bit and simply setting
 * it to 0 will convert the underflowed now signed result to its unsigned
 * equivalent (unsigned to signed conversion is easy). We also set the
 * result sign bit to 1 if the carry bit is 1 (pre converting) in this
 * condition of adding different signs.
 * [ + ] - frac_bits
 */
class AVT(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle{
    val fp_a_norm = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val fp_b_norm = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val valid_0   = Input(UInt(1.W))

    val fp_result = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val valid_1   = Output(UInt(1.W))
  })

  ////////////////////////////////////////////////////////////////
  // Local parameters
  val sign_idx       = exp_bits + 1 + 1 + frac_bits + 1
  val exp_idx        = 1 + 1 + frac_bits + 1
  val carry_idx      = 1 + frac_bits + 1
  val frac_total_idx = 0
  val frac_total_bits = 1 + 1 + frac_bits + 1

  ////////////////////////////////////////////////////////////////
  // Setting up Registers and initial values
  val fp_a_norm_reg = Reg(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val fp_b_norm_reg = Reg(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val valid_reg     = RegInit(0.U(1.W))

  fp_a_norm_reg := io.fp_a_norm
  fp_b_norm_reg := io.fp_b_norm
  valid_reg     := io.valid_0

  ////////////////////////////////////////////////////////////////
  // Setting up wires and default values
  val fp_a_norm_sign       = Wire(UInt(1.W))
  val fp_a_norm_exp        = Wire(UInt(exp_bits.W))
  val fp_a_norm_frac_total = Wire(UInt((1 + 1 + frac_bits + 1).W))

  val fp_b_norm_sign       = Wire(UInt(1.W))
  val fp_b_norm_exp        = Wire(UInt(exp_bits.W))
  val fp_b_norm_frac_total = Wire(UInt((1 + 1 + frac_bits + 1).W))

  val fp_result_sign         = Wire(UInt(1.W))
  val fp_result_exp          = Wire(UInt(exp_bits.W))
  val fp_result_frac_total   = Wire(UInt((1 + 1 + frac_bits + 1).W))
  val fp_result_frac_total_0 = Wire(UInt((1 + 1 + frac_bits + 1).W))

  fp_a_norm_sign        := fp_a_norm_reg(sign_idx)
  fp_a_norm_exp         := fp_a_norm_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_a_norm_frac_total  := fp_a_norm_reg(frac_total_idx + frac_total_bits - 1, frac_total_idx)

  fp_b_norm_sign        := fp_b_norm_reg(sign_idx)
  fp_b_norm_exp         := fp_b_norm_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_b_norm_frac_total  := fp_b_norm_reg(frac_total_idx + frac_total_bits - 1, frac_total_idx)

  fp_result_sign       := 0.U
  fp_result_exp        := fp_a_norm_exp
  fp_result_frac_total := 0.U

  ////////////////////////////////////////////////////////////////
  // Adding Values together
  val fp_a_norm_frac_total_n = Wire(UInt((1 + 1 + frac_bits + 1).W))
  val fp_b_norm_frac_total_n = Wire(UInt((1 + 1 + frac_bits + 1).W))
  fp_a_norm_frac_total_n := ~fp_a_norm_frac_total
  fp_b_norm_frac_total_n := ~fp_b_norm_frac_total

  val fp_a_norm_frac_total_s   = Wire(UInt((1 + 1 + frac_bits + 1).W))
  val fp_b_norm_frac_total_s   = Wire(UInt((1 + 1 + frac_bits + 1).W))
  fp_a_norm_frac_total_s := fp_a_norm_frac_total
  fp_b_norm_frac_total_s := fp_b_norm_frac_total

  when(fp_a_norm_sign === 1.U){
    fp_a_norm_frac_total_s := fp_a_norm_frac_total_n + 1.U
  }
  when(fp_b_norm_sign === 1.U){
    fp_b_norm_frac_total_s := fp_b_norm_frac_total_n + 1.U
  }

  fp_result_frac_total_0 := fp_a_norm_frac_total_s + fp_b_norm_frac_total_s
  fp_result_frac_total := fp_result_frac_total_0

  val fp_result_frac_total_0_n  = Wire(UInt((1 + 1 + frac_bits + 1).W))
  fp_result_frac_total_0_n := ~fp_result_frac_total_0

  when(fp_a_norm_sign === fp_b_norm_sign){
    fp_result_sign := fp_a_norm_sign
  } .otherwise {
    fp_result_sign := 0.U
    // if the carry bit is 1, the result is negative, convert to unsigned
    // (this will clear the carry as well)
    when(fp_result_frac_total_0(carry_idx)){
      fp_result_sign := 1.U
      fp_result_frac_total := fp_result_frac_total_0_n + 1.U
    }
    // otherwise it is a positive value and the carry bit
    // will be 0
  }

  ////////////////////////////////////////////////////////////////
  // Set out
  io.fp_result := (fp_result_sign ##
                   fp_result_exp ##
                   fp_result_frac_total)
  io.valid_1 := valid_reg

}

// Normalize Results (NR) - stage 5
/* We need to take the result and normalize it. This is also
 * a variable shifter depending on where the first 1 value is
 * found. If the frac bits turn out to be 0, set output exponent
 * also to 0. If exponent underflow, set to 0, if exponent overflow,
 * set to max value.
 * [variable shifter, either 1 right or multiple left]
 * [ < ] - exp_bits
 * [ + ] - exp_bits
 *
 */
class NR(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle {
    val fp_result      = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val valid_1        = Input(UInt(1.W))

    val fp_result_norm = Output(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val valid_0        = Output(UInt(1.W))
  })

  ////////////////////////////////////////////////////////////////
  // Local parameters
  val sign_idx       = exp_bits + 1 + 1 + frac_bits + 1
  val exp_idx        = 1 + 1 + frac_bits + 1
  val frac_total_idx = 0
  val frac_total_bits = 1 + 1 + frac_bits + 1

  ////////////////////////////////////////////////////////////////
  // Setting up Registers and initial values
  val fp_result_reg = Reg(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val valid_reg     = RegInit(0.U(1.W))

  fp_result_reg := io.fp_result
  valid_reg     := io.valid_1

  ////////////////////////////////////////////////////////////////
  // Setting up wires and default values
  val fp_result_sign       = Wire(UInt(1.W))
  val fp_result_exp        = Wire(UInt(exp_bits.W))
  val fp_result_frac_total = Wire(UInt((1 + 1 + frac_bits + 1).W))
  val tmp_frac_total       = Wire(UInt((1 + 1 + frac_bits + 1).W))
  val tmp_exp              = Wire(UInt((exp_bits + 1).W)) // +1 bit width for underflow or overflow
  val tmp_of_uf            = Wire(UInt(1.W)) // underflow 0, overflow 1

  fp_result_sign        := fp_result_reg(sign_idx)
  fp_result_exp         := fp_result_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_result_frac_total  := fp_result_reg(frac_total_idx + frac_total_bits - 1, frac_total_idx)
  tmp_frac_total        := 0.U
  tmp_exp               := 0.U
  tmp_of_uf             := 0.U

  ////////////////////////////////////////////////////////////////
  // Right 1 or Variable Left shifter
  when(fp_result_frac_total === 0.U){
    fp_result_sign := 0.U
    tmp_exp := 0.U
    tmp_frac_total := 0.U
  } .otherwise {
    // checking left shift until lead bit
    for(bit_idx <- 0 until (frac_total_bits - 1)) {
      // frac_total_bits - 2 - bit_idx
      when(fp_result_frac_total(bit_idx)) {
        tmp_frac_total := fp_result_frac_total << (frac_total_bits - 2 - bit_idx)
        tmp_exp        := fp_result_exp - (frac_total_bits - 2 - bit_idx).U
        tmp_of_uf      := 0.U
      }
    }

    // if carry bit, perform right shift
    when(fp_result_frac_total(frac_total_bits - 1)){
      tmp_frac_total := fp_result_frac_total >> 1
      tmp_exp        := fp_result_exp + 1.U
      tmp_of_uf      := 0.U
    }

  }
  // signals overflow or underflow
  val tmp_exp_0 = Wire(UInt((exp_bits + 1).W))
  tmp_exp_0 := tmp_exp(exp_bits-1,0)
  when(tmp_exp(exp_bits)){
    // overflow
    when(tmp_of_uf === 1.U){
      tmp_exp_0 := (pow(2,exp_bits).intValue - 1).U
    // underflow
    } .otherwise {
      tmp_exp_0 := 0.U
    }
  }

  ////////////////////////////////////////////////////////////////
  // Set out
  io.fp_result_norm := (fp_result_sign ##
                        tmp_exp_0(exp_bits-1,0) ##
                        tmp_frac_total)
  io.valid_0 := valid_reg
}

// Round Results (RR) - stage 6
/* Finally, using the round bit, round the results.
 * In this case an overflow could happen which would cause the exponent to increase by 1.
 * Which means we would also have to check exponent overflow, can only happen if the exponent
 * is already at max value.
 * [ + ] - frac_bits
 * [ < ] - exp_bits
 * [ + ] - exp_bits
 */
class RR(exp_bits: Int, frac_bits: Int) extends Module {
  val io = IO(new Bundle {
    val fp_result_norm  = Input(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
    val valid_0         = Input(UInt(1.W))

    val fp_out_o        = Output(UInt((1 + exp_bits + frac_bits).W))
    val valid_o         = Output(UInt(1.W))
  })

  ////////////////////////////////////////////////////////////////
  // Local parameters
  val sign_idx       = exp_bits + 1 + 1 + frac_bits + 1
  val exp_idx        = 1 + 1 + frac_bits + 1
  val carry_idx      = 1 + frac_bits + 1
  val round_idx      = 0
  val frac_total_idx = 0
  val frac_total_bits = 1 + 1 + frac_bits + 1

  ////////////////////////////////////////////////////////////////
  // Setting up Registers and initial values
  val fp_result_norm_reg = Reg(UInt((1 + exp_bits + 1 + 1 + frac_bits + 1).W))
  val valid_reg = RegInit(0.U(1.W))

  fp_result_norm_reg := io.fp_result_norm
  valid_reg := io.valid_0

  ////////////////////////////////////////////////////////////////
  // Setting up wires and default values
  val fp_result_norm_sign       = Wire(UInt(1.W))
  val fp_result_norm_exp        = Wire(UInt(exp_bits.W))
  val fp_result_norm_frac_total = Wire(UInt((1 + 1 + frac_bits + 1).W))

  fp_result_norm_sign        := fp_result_norm_reg(sign_idx)
  fp_result_norm_exp         := fp_result_norm_reg(exp_idx + exp_bits - 1, exp_idx)
  fp_result_norm_frac_total  := fp_result_norm_reg(frac_total_idx + frac_total_bits - 1, frac_total_idx)

  ////////////////////////////////////////////////////////////////
  // Rounding
  val fp_result_norm_frac_total_0 = Wire(UInt((1 + 1 + frac_bits + 1).W))
  when(fp_result_norm_frac_total(round_idx)){
    fp_result_norm_frac_total_0 := fp_result_norm_frac_total + 1.U
  } .otherwise {
    fp_result_norm_frac_total_0 := fp_result_norm_frac_total
  }

  val fp_result_norm_exp_0 = Wire(UInt(exp_bits.W))
  fp_result_norm_exp_0 := fp_result_norm_reg(exp_idx + exp_bits - 1, exp_idx)

  when(fp_result_norm_frac_total_0(carry_idx)){
    // if not max value, increment by 1, else maintain
    when(fp_result_norm_exp =/= (pow(2,exp_bits).intValue - 1).U){
      fp_result_norm_exp_0 := fp_result_norm_exp + 1.U
    }
  }

  ////////////////////////////////////////////////////////////////
  // Set out
  io.fp_out_o := (fp_result_norm_sign ##
                  fp_result_norm_exp_0 ##
                  fp_result_norm_frac_total_0(frac_total_bits - 3,1)) // w/o carr, lead and round
  io.valid_o := valid_reg
}

object FloatingPointAdderMain extends App {
  println("Generating Floating Pointer Adder hardware.")
  // fp32 - 8, 23
  // binary16 - 5,10
  emitVerilog(new FloatingPointAdder(5,10), Array("--target-dir","generated"))
}

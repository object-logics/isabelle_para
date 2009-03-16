(* Author:     Johannes Hoelzl <hoelzl@in.tum.de> 2008 / 2009 *)

header {* Prove unequations about real numbers by computation *}

theory Approximation
imports Complex_Main Float Reflection Dense_Linear_Order Efficient_Nat
begin

section "Horner Scheme"

subsection {* Define auxiliary helper @{text horner} function *}

fun horner :: "(nat \<Rightarrow> nat) \<Rightarrow> (nat \<Rightarrow> nat \<Rightarrow> nat) \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> real \<Rightarrow> real" where
"horner F G 0 i k x       = 0" |
"horner F G (Suc n) i k x = 1 / real k - x * horner F G n (F i) (G i k) x"

lemma horner_schema': fixes x :: real  and a :: "nat \<Rightarrow> real"
  shows "a 0 - x * (\<Sum> i=0..<n. (-1)^i * a (Suc i) * x^i) = (\<Sum> i=0..<Suc n. (-1)^i * a i * x^i)"
proof -
  have shift_pow: "\<And>i. - (x * ((-1)^i * a (Suc i) * x ^ i)) = (-1)^(Suc i) * a (Suc i) * x ^ (Suc i)" by auto
  show ?thesis unfolding setsum_right_distrib shift_pow real_diff_def setsum_negf[symmetric] setsum_head_upt_Suc[OF zero_less_Suc]
    setsum_reindex[OF inj_Suc, unfolded comp_def, symmetric, of "\<lambda> n. (-1)^n  *a n * x^n"] by auto
qed

lemma horner_schema: fixes f :: "nat \<Rightarrow> nat" and G :: "nat \<Rightarrow> nat \<Rightarrow> nat" and F :: "nat \<Rightarrow> nat"
  assumes f_Suc: "\<And>n. f (Suc n) = G ((F^n) s) (f n)"
  shows "horner F G n ((F^j') s) (f j') x = (\<Sum> j = 0..< n. -1^j * (1 / real (f (j' + j))) * x^j)"
proof (induct n arbitrary: i k j')
  case (Suc n)

  show ?case unfolding horner.simps Suc[where j'="Suc j'", unfolded funpow.simps comp_def f_Suc]
    using horner_schema'[of "\<lambda> j. 1 / real (f (j' + j))"] by auto
qed auto

lemma horner_bounds':
  assumes "0 \<le> Ifloat x" and f_Suc: "\<And>n. f (Suc n) = G ((F^n) s) (f n)"
  and lb_0: "\<And> i k x. lb 0 i k x = 0"
  and lb_Suc: "\<And> n i k x. lb (Suc n) i k x = lapprox_rat prec 1 (int k) - x * (ub n (F i) (G i k) x)"
  and ub_0: "\<And> i k x. ub 0 i k x = 0"
  and ub_Suc: "\<And> n i k x. ub (Suc n) i k x = rapprox_rat prec 1 (int k) - x * (lb n (F i) (G i k) x)"
  shows "Ifloat (lb n ((F^j') s) (f j') x) \<le> horner F G n ((F^j') s) (f j') (Ifloat x) \<and> 
         horner F G n ((F^j') s) (f j') (Ifloat x) \<le> Ifloat (ub n ((F^j') s) (f j') x)"
  (is "?lb n j' \<le> ?horner n j' \<and> ?horner n j' \<le> ?ub n j'")
proof (induct n arbitrary: j')
  case 0 thus ?case unfolding lb_0 ub_0 horner.simps by auto
next
  case (Suc n)
  have "?lb (Suc n) j' \<le> ?horner (Suc n) j'" unfolding lb_Suc ub_Suc horner.simps Ifloat_sub diff_def
  proof (rule add_mono)
    show "Ifloat (lapprox_rat prec 1 (int (f j'))) \<le> 1 / real (f j')" using lapprox_rat[of prec 1  "int (f j')"] by auto
    from Suc[where j'="Suc j'", unfolded funpow.simps comp_def f_Suc, THEN conjunct2] `0 \<le> Ifloat x`
    show "- Ifloat (x * ub n (F ((F ^ j') s)) (G ((F ^ j') s) (f j')) x) \<le> - (Ifloat x * horner F G n (F ((F ^ j') s)) (G ((F ^ j') s) (f j')) (Ifloat x))"
      unfolding Ifloat_mult neg_le_iff_le by (rule mult_left_mono)
  qed
  moreover have "?horner (Suc n) j' \<le> ?ub (Suc n) j'" unfolding ub_Suc ub_Suc horner.simps Ifloat_sub diff_def
  proof (rule add_mono)
    show "1 / real (f j') \<le> Ifloat (rapprox_rat prec 1 (int (f j')))" using rapprox_rat[of 1 "int (f j')" prec] by auto
    from Suc[where j'="Suc j'", unfolded funpow.simps comp_def f_Suc, THEN conjunct1] `0 \<le> Ifloat x`
    show "- (Ifloat x * horner F G n (F ((F ^ j') s)) (G ((F ^ j') s) (f j')) (Ifloat x)) \<le> 
          - Ifloat (x * lb n (F ((F ^ j') s)) (G ((F ^ j') s) (f j')) x)"
      unfolding Ifloat_mult neg_le_iff_le by (rule mult_left_mono)
  qed
  ultimately show ?case by blast
qed

subsection "Theorems for floating point functions implementing the horner scheme"

text {*

Here @{term_type "f :: nat \<Rightarrow> nat"} is the sequence defining the Taylor series, the coefficients are
all alternating and reciprocs. We use @{term G} and @{term F} to describe the computation of @{term f}.

*}

lemma horner_bounds: fixes F :: "nat \<Rightarrow> nat" and G :: "nat \<Rightarrow> nat \<Rightarrow> nat"
  assumes "0 \<le> Ifloat x" and f_Suc: "\<And>n. f (Suc n) = G ((F^n) s) (f n)"
  and lb_0: "\<And> i k x. lb 0 i k x = 0"
  and lb_Suc: "\<And> n i k x. lb (Suc n) i k x = lapprox_rat prec 1 (int k) - x * (ub n (F i) (G i k) x)"
  and ub_0: "\<And> i k x. ub 0 i k x = 0"
  and ub_Suc: "\<And> n i k x. ub (Suc n) i k x = rapprox_rat prec 1 (int k) - x * (lb n (F i) (G i k) x)"
  shows "Ifloat (lb n ((F^j') s) (f j') x) \<le> (\<Sum>j=0..<n. -1^j * (1 / real (f (j' + j))) * (Ifloat x)^j)" (is "?lb") and 
        "(\<Sum>j=0..<n. -1^j * (1 / real (f (j' + j))) * (Ifloat x)^j) \<le> Ifloat (ub n ((F^j') s) (f j') x)" (is "?ub")
proof -
  have "?lb  \<and> ?ub" 
    using horner_bounds'[where lb=lb, OF `0 \<le> Ifloat x` f_Suc lb_0 lb_Suc ub_0 ub_Suc]
    unfolding horner_schema[where f=f, OF f_Suc] .
  thus "?lb" and "?ub" by auto
qed

lemma horner_bounds_nonpos: fixes F :: "nat \<Rightarrow> nat" and G :: "nat \<Rightarrow> nat \<Rightarrow> nat"
  assumes "Ifloat x \<le> 0" and f_Suc: "\<And>n. f (Suc n) = G ((F^n) s) (f n)"
  and lb_0: "\<And> i k x. lb 0 i k x = 0"
  and lb_Suc: "\<And> n i k x. lb (Suc n) i k x = lapprox_rat prec 1 (int k) + x * (ub n (F i) (G i k) x)"
  and ub_0: "\<And> i k x. ub 0 i k x = 0"
  and ub_Suc: "\<And> n i k x. ub (Suc n) i k x = rapprox_rat prec 1 (int k) + x * (lb n (F i) (G i k) x)"
  shows "Ifloat (lb n ((F^j') s) (f j') x) \<le> (\<Sum>j=0..<n. (1 / real (f (j' + j))) * (Ifloat x)^j)" (is "?lb") and 
        "(\<Sum>j=0..<n. (1 / real (f (j' + j))) * (Ifloat x)^j) \<le> Ifloat (ub n ((F^j') s) (f j') x)" (is "?ub")
proof -
  { fix x y z :: float have "x - y * z = x + - y * z"
      by (cases x, cases y, cases z, simp add: plus_float.simps minus_float.simps uminus_float.simps times_float.simps algebra_simps)
  } note diff_mult_minus = this

  { fix x :: float have "- (- x) = x" by (cases x, auto simp add: uminus_float.simps) } note minus_minus = this

  have move_minus: "Ifloat (-x) = -1 * Ifloat x" by auto

  have sum_eq: "(\<Sum>j=0..<n. (1 / real (f (j' + j))) * (Ifloat x)^j) = 
    (\<Sum>j = 0..<n. -1 ^ j * (1 / real (f (j' + j))) * Ifloat (- x) ^ j)"
  proof (rule setsum_cong, simp)
    fix j assume "j \<in> {0 ..< n}"
    show "1 / real (f (j' + j)) * Ifloat x ^ j = -1 ^ j * (1 / real (f (j' + j))) * Ifloat (- x) ^ j"
      unfolding move_minus power_mult_distrib real_mult_assoc[symmetric]
      unfolding real_mult_commute unfolding real_mult_assoc[of "-1^j", symmetric] power_mult_distrib[symmetric]
      by auto
  qed

  have "0 \<le> Ifloat (-x)" using assms by auto
  from horner_bounds[where G=G and F=F and f=f and s=s and prec=prec
    and lb="\<lambda> n i k x. lb n i k (-x)" and ub="\<lambda> n i k x. ub n i k (-x)", unfolded lb_Suc ub_Suc diff_mult_minus,
    OF this f_Suc lb_0 refl ub_0 refl]
  show "?lb" and "?ub" unfolding minus_minus sum_eq
    by auto
qed

subsection {* Selectors for next even or odd number *}

text {*

The horner scheme computes alternating series. To get the upper and lower bounds we need to
guarantee to access a even or odd member. To do this we use @{term get_odd} and @{term get_even}.

*}

definition get_odd :: "nat \<Rightarrow> nat" where
  "get_odd n = (if odd n then n else (Suc n))"

definition get_even :: "nat \<Rightarrow> nat" where
  "get_even n = (if even n then n else (Suc n))"

lemma get_odd[simp]: "odd (get_odd n)" unfolding get_odd_def by (cases "odd n", auto)
lemma get_even[simp]: "even (get_even n)" unfolding get_even_def by (cases "even n", auto)
lemma get_odd_ex: "\<exists> k. Suc k = get_odd n \<and> odd (Suc k)"
proof (cases "odd n")
  case True hence "0 < n" by (rule odd_pos)
  from gr0_implies_Suc[OF this] obtain k where "Suc k = n" by auto 
  thus ?thesis unfolding get_odd_def if_P[OF True] using True[unfolded `Suc k = n`[symmetric]] by blast
next
  case False hence "odd (Suc n)" by auto
  thus ?thesis unfolding get_odd_def if_not_P[OF False] by blast
qed

lemma get_even_double: "\<exists>i. get_even n = 2 * i" using get_even[unfolded even_mult_two_ex] .
lemma get_odd_double: "\<exists>i. get_odd n = 2 * i + 1" using get_odd[unfolded odd_Suc_mult_two_ex] by auto

section "Power function"

definition float_power_bnds :: "nat \<Rightarrow> float \<Rightarrow> float \<Rightarrow> float * float" where
"float_power_bnds n l u = (if odd n \<or> 0 < l then (l ^ n, u ^ n)
                      else if u < 0         then (u ^ n, l ^ n)
                                            else (0, (max (-l) u) ^ n))"

lemma float_power_bnds: assumes "(l1, u1) = float_power_bnds n l u" and "x \<in> {Ifloat l .. Ifloat u}"
  shows "x^n \<in> {Ifloat l1..Ifloat u1}"
proof (cases "even n")
  case True 
  show ?thesis
  proof (cases "0 < l")
    case True hence "odd n \<or> 0 < l" and "0 \<le> Ifloat l" unfolding less_float_def by auto
    have u1: "u1 = u ^ n" and l1: "l1 = l ^ n" using assms unfolding float_power_bnds_def if_P[OF `odd n \<or> 0 < l`] by auto
    have "Ifloat l^n \<le> x^n" and "x^n \<le> Ifloat u^n " using `0 \<le> Ifloat l` and assms unfolding atLeastAtMost_iff using power_mono[of "Ifloat l" x] power_mono[of x "Ifloat u"] by auto
    thus ?thesis using assms `0 < l` unfolding atLeastAtMost_iff l1 u1 float_power less_float_def by auto
  next
    case False hence P: "\<not> (odd n \<or> 0 < l)" using `even n` by auto
    show ?thesis
    proof (cases "u < 0")
      case True hence "0 \<le> - Ifloat u" and "- Ifloat u \<le> - x" and "0 \<le> - x" and "-x \<le> - Ifloat l" using assms unfolding less_float_def by auto
      hence "Ifloat u^n \<le> x^n" and "x^n \<le> Ifloat l^n" using power_mono[of  "-x" "-Ifloat l" n] power_mono[of "-Ifloat u" "-x" n] 
	unfolding power_minus_even[OF `even n`] by auto
      moreover have u1: "u1 = l ^ n" and l1: "l1 = u ^ n" using assms unfolding float_power_bnds_def if_not_P[OF P] if_P[OF True] by auto
      ultimately show ?thesis using float_power by auto
    next
      case False 
      have "\<bar>x\<bar> \<le> Ifloat (max (-l) u)"
      proof (cases "-l \<le> u")
	case True thus ?thesis unfolding max_def if_P[OF True] using assms unfolding le_float_def by auto
      next
	case False thus ?thesis unfolding max_def if_not_P[OF False] using assms unfolding le_float_def by auto
      qed
      hence x_abs: "\<bar>x\<bar> \<le> \<bar>Ifloat (max (-l) u)\<bar>" by auto
      have u1: "u1 = (max (-l) u) ^ n" and l1: "l1 = 0" using assms unfolding float_power_bnds_def if_not_P[OF P] if_not_P[OF False] by auto
      show ?thesis unfolding atLeastAtMost_iff l1 u1 float_power using zero_le_even_power[OF `even n`] power_mono_even[OF `even n` x_abs] by auto
    qed
  qed
next
  case False hence "odd n \<or> 0 < l" by auto
  have u1: "u1 = u ^ n" and l1: "l1 = l ^ n" using assms unfolding float_power_bnds_def if_P[OF `odd n \<or> 0 < l`] by auto
  have "Ifloat l^n \<le> x^n" and "x^n \<le> Ifloat u^n " using assms unfolding atLeastAtMost_iff using power_mono_odd[OF False] by auto
  thus ?thesis unfolding atLeastAtMost_iff l1 u1 float_power less_float_def by auto
qed

lemma bnds_power: "\<forall> x l u. (l1, u1) = float_power_bnds n l u \<and> x \<in> {Ifloat l .. Ifloat u} \<longrightarrow> Ifloat l1 \<le> x^n \<and> x^n \<le> Ifloat u1"
  using float_power_bnds by auto

section "Square root"

text {*

The square root computation is implemented as newton iteration. As first first step we use the
nearest power of two greater than the square root.

*}

fun sqrt_iteration :: "nat \<Rightarrow> nat \<Rightarrow> float \<Rightarrow> float" where
"sqrt_iteration prec 0 (Float m e) = Float 1 ((e + bitlen m) div 2 + 1)" |
"sqrt_iteration prec (Suc m) x = (let y = sqrt_iteration prec m x 
                                  in Float 1 -1 * (y + float_divr prec x y))"

definition ub_sqrt :: "nat \<Rightarrow> float \<Rightarrow> float option" where 
"ub_sqrt prec x = (if 0 < x then Some (sqrt_iteration prec prec x) else if x < 0 then None else Some 0)"

definition lb_sqrt :: "nat \<Rightarrow> float \<Rightarrow> float option" where
"lb_sqrt prec x = (if 0 < x then Some (float_divl prec x (sqrt_iteration prec prec x)) else if x < 0 then None else Some 0)"

lemma sqrt_ub_pos_pos_1:
  assumes "sqrt x < b" and "0 < b" and "0 < x"
  shows "sqrt x < (b + x / b)/2"
proof -
  from assms have "0 < (b - sqrt x) ^ 2 " by simp
  also have "\<dots> = b ^ 2 - 2 * b * sqrt x + (sqrt x) ^ 2" by algebra
  also have "\<dots> = b ^ 2 - 2 * b * sqrt x + x" using assms by (simp add: real_sqrt_pow2)
  finally have "0 < b ^ 2 - 2 * b * sqrt x + x" by assumption
  hence "0 < b / 2 - sqrt x + x / (2 * b)" using assms
    by (simp add: field_simps power2_eq_square)
  thus ?thesis by (simp add: field_simps)
qed

lemma sqrt_iteration_bound: assumes "0 < Ifloat x"
  shows "sqrt (Ifloat x) < Ifloat (sqrt_iteration prec n x)"
proof (induct n)
  case 0
  show ?case
  proof (cases x)
    case (Float m e)
    hence "0 < m" using float_pos_m_pos[unfolded less_float_def] assms by auto
    hence "0 < sqrt (real m)" by auto

    have int_nat_bl: "int (nat (bitlen m)) = bitlen m" using bitlen_ge0 by auto

    have "Ifloat x = (real m / 2^nat (bitlen m)) * pow2 (e + int (nat (bitlen m)))"
      unfolding pow2_add pow2_int Float Ifloat.simps by auto
    also have "\<dots> < 1 * pow2 (e + int (nat (bitlen m)))"
    proof (rule mult_strict_right_mono, auto)
      show "real m < 2^nat (bitlen m)" using bitlen_bounds[OF `0 < m`, THEN conjunct2] 
	unfolding real_of_int_less_iff[of m, symmetric] by auto
    qed
    finally have "sqrt (Ifloat x) < sqrt (pow2 (e + bitlen m))" unfolding int_nat_bl by auto
    also have "\<dots> \<le> pow2 ((e + bitlen m) div 2 + 1)"
    proof -
      let ?E = "e + bitlen m"
      have E_mod_pow: "pow2 (?E mod 2) < 4"
      proof (cases "?E mod 2 = 1")
	case True thus ?thesis by auto
      next
	case False 
	have "0 \<le> ?E mod 2" by auto 
	have "?E mod 2 < 2" by auto
	from this[THEN zless_imp_add1_zle]
	have "?E mod 2 \<le> 0" using False by auto
	from xt1(5)[OF `0 \<le> ?E mod 2` this]
	show ?thesis by auto
      qed
      hence "sqrt (pow2 (?E mod 2)) < sqrt (2 * 2)" by auto
      hence E_mod_pow: "sqrt (pow2 (?E mod 2)) < 2" unfolding real_sqrt_abs2 by auto

      have E_eq: "pow2 ?E = pow2 (?E div 2 + ?E div 2 + ?E mod 2)" by auto
      have "sqrt (pow2 ?E) = sqrt (pow2 (?E div 2) * pow2 (?E div 2) * pow2 (?E mod 2))"
	unfolding E_eq unfolding pow2_add ..
      also have "\<dots> = pow2 (?E div 2) * sqrt (pow2 (?E mod 2))"
	unfolding real_sqrt_mult[of _ "pow2 (?E mod 2)"] real_sqrt_abs2 by auto
      also have "\<dots> < pow2 (?E div 2) * 2" 
	by (rule mult_strict_left_mono, auto intro: E_mod_pow)
      also have "\<dots> = pow2 (?E div 2 + 1)" unfolding zadd_commute[of _ 1] pow2_add1 by auto
      finally show ?thesis by auto
    qed
    finally show ?thesis 
      unfolding Float sqrt_iteration.simps Ifloat.simps by auto
  qed
next
  case (Suc n)
  let ?b = "sqrt_iteration prec n x"
  have "0 < sqrt (Ifloat x)" using `0 < Ifloat x` by auto
  also have "\<dots> < Ifloat ?b" using Suc .
  finally have "sqrt (Ifloat x) < (Ifloat ?b + Ifloat x / Ifloat ?b)/2" using sqrt_ub_pos_pos_1[OF Suc _ `0 < Ifloat x`] by auto
  also have "\<dots> \<le> (Ifloat ?b + Ifloat (float_divr prec x ?b))/2" by (rule divide_right_mono, auto simp add: float_divr)
  also have "\<dots> = Ifloat (Float 1 -1) * (Ifloat ?b + Ifloat (float_divr prec x ?b))" by auto
  finally show ?case unfolding sqrt_iteration.simps Let_def Ifloat_mult Ifloat_add right_distrib .
qed

lemma sqrt_iteration_lower_bound: assumes "0 < Ifloat x"
  shows "0 < Ifloat (sqrt_iteration prec n x)" (is "0 < ?sqrt")
proof -
  have "0 < sqrt (Ifloat x)" using assms by auto
  also have "\<dots> < ?sqrt" using sqrt_iteration_bound[OF assms] .
  finally show ?thesis .
qed

lemma lb_sqrt_lower_bound: assumes "0 \<le> Ifloat x"
  shows "0 \<le> Ifloat (the (lb_sqrt prec x))"
proof (cases "0 < x")
  case True hence "0 < Ifloat x" and "0 \<le> x" using `0 \<le> Ifloat x` unfolding less_float_def le_float_def by auto
  hence "0 < sqrt_iteration prec prec x" unfolding less_float_def using sqrt_iteration_lower_bound by auto 
  hence "0 \<le> Ifloat (float_divl prec x (sqrt_iteration prec prec x))" using float_divl_lower_bound[OF `0 \<le> x`] unfolding le_float_def by auto
  thus ?thesis unfolding lb_sqrt_def using True by auto
next
  case False with `0 \<le> Ifloat x` have "Ifloat x = 0" unfolding less_float_def by auto
  thus ?thesis unfolding lb_sqrt_def less_float_def by auto
qed

lemma lb_sqrt_upper_bound: assumes "0 \<le> Ifloat x"
  shows "Ifloat (the (lb_sqrt prec x)) \<le> sqrt (Ifloat x)"
proof (cases "0 < x")
  case True hence "0 < Ifloat x" and "0 \<le> Ifloat x" unfolding less_float_def by auto
  hence sqrt_gt0: "0 < sqrt (Ifloat x)" by auto
  hence sqrt_ub: "sqrt (Ifloat x) < Ifloat (sqrt_iteration prec prec x)" using sqrt_iteration_bound by auto
  
  have "Ifloat (float_divl prec x (sqrt_iteration prec prec x)) \<le> Ifloat x / Ifloat (sqrt_iteration prec prec x)" by (rule float_divl)
  also have "\<dots> < Ifloat x / sqrt (Ifloat x)" 
    by (rule divide_strict_left_mono[OF sqrt_ub `0 < Ifloat x` mult_pos_pos[OF order_less_trans[OF sqrt_gt0 sqrt_ub] sqrt_gt0]])
  also have "\<dots> = sqrt (Ifloat x)" unfolding inverse_eq_iff_eq[of _ "sqrt (Ifloat x)", symmetric] sqrt_divide_self_eq[OF `0 \<le> Ifloat x`, symmetric] by auto
  finally show ?thesis unfolding lb_sqrt_def if_P[OF `0 < x`] by auto
next
  case False with `0 \<le> Ifloat x`
  have "\<not> x < 0" unfolding less_float_def le_float_def by auto
  show ?thesis unfolding lb_sqrt_def if_not_P[OF False] if_not_P[OF `\<not> x < 0`] using assms by auto
qed

lemma lb_sqrt: assumes "Some y = lb_sqrt prec x"
  shows "Ifloat y \<le> sqrt (Ifloat x)" and "0 \<le> Ifloat x"
proof -
  show "0 \<le> Ifloat x"
  proof (rule ccontr)
    assume "\<not> 0 \<le> Ifloat x"
    hence "lb_sqrt prec x = None" unfolding lb_sqrt_def less_float_def by auto
    thus False using assms by auto
  qed
  from lb_sqrt_upper_bound[OF this, of prec]
  show "Ifloat y \<le> sqrt (Ifloat x)" unfolding assms[symmetric] by auto
qed

lemma ub_sqrt_lower_bound: assumes "0 \<le> Ifloat x"
  shows "sqrt (Ifloat x) \<le> Ifloat (the (ub_sqrt prec x))"
proof (cases "0 < x")
  case True hence "0 < Ifloat x" unfolding less_float_def by auto
  hence "0 < sqrt (Ifloat x)" by auto
  hence "sqrt (Ifloat x) < Ifloat (sqrt_iteration prec prec x)" using sqrt_iteration_bound by auto
  thus ?thesis unfolding ub_sqrt_def if_P[OF `0 < x`] by auto
next
  case False with `0 \<le> Ifloat x`
  have "Ifloat x = 0" unfolding less_float_def le_float_def by auto
  thus ?thesis unfolding ub_sqrt_def less_float_def le_float_def by auto
qed

lemma ub_sqrt: assumes "Some y = ub_sqrt prec x"
  shows "sqrt (Ifloat x) \<le> Ifloat y" and "0 \<le> Ifloat x"
proof -
  show "0 \<le> Ifloat x"
  proof (rule ccontr)
    assume "\<not> 0 \<le> Ifloat x"
    hence "ub_sqrt prec x = None" unfolding ub_sqrt_def less_float_def by auto
    thus False using assms by auto
  qed
  from ub_sqrt_lower_bound[OF this, of prec]
  show "sqrt (Ifloat x) \<le> Ifloat y" unfolding assms[symmetric] by auto
qed

lemma bnds_sqrt: "\<forall> x lx ux. (Some l, Some u) = (lb_sqrt prec lx, ub_sqrt prec ux) \<and> x \<in> {Ifloat lx .. Ifloat ux} \<longrightarrow> Ifloat l \<le> sqrt x \<and> sqrt x \<le> Ifloat u"
proof (rule allI, rule allI, rule allI, rule impI)
  fix x lx ux
  assume "(Some l, Some u) = (lb_sqrt prec lx, ub_sqrt prec ux) \<and> x \<in> {Ifloat lx .. Ifloat ux}"
  hence l: "Some l = lb_sqrt prec lx " and u: "Some u = ub_sqrt prec ux" and x: "x \<in> {Ifloat lx .. Ifloat ux}" by auto
  
  have "Ifloat lx \<le> x" and "x \<le> Ifloat ux" using x by auto

  from lb_sqrt(1)[OF l] real_sqrt_le_mono[OF `Ifloat lx \<le> x`]
  have "Ifloat l \<le> sqrt x" by (rule order_trans)
  moreover
  from real_sqrt_le_mono[OF `x \<le> Ifloat ux`] ub_sqrt(1)[OF u]
  have "sqrt x \<le> Ifloat u" by (rule order_trans)
  ultimately show "Ifloat l \<le> sqrt x \<and> sqrt x \<le> Ifloat u" ..
qed

section "Arcus tangens and \<pi>"

subsection "Compute arcus tangens series"

text {*

As first step we implement the computation of the arcus tangens series. This is only valid in the range
@{term "{-1 :: real .. 1}"}. This is used to compute \<pi> and then the entire arcus tangens.

*}

fun ub_arctan_horner :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> float \<Rightarrow> float"
and lb_arctan_horner :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> float \<Rightarrow> float" where
  "ub_arctan_horner prec 0 k x = 0"
| "ub_arctan_horner prec (Suc n) k x = 
    (rapprox_rat prec 1 (int k)) - x * (lb_arctan_horner prec n (k + 2) x)"
| "lb_arctan_horner prec 0 k x = 0"
| "lb_arctan_horner prec (Suc n) k x = 
    (lapprox_rat prec 1 (int k)) - x * (ub_arctan_horner prec n (k + 2) x)"

lemma arctan_0_1_bounds': assumes "0 \<le> Ifloat x" "Ifloat x \<le> 1" and "even n"
  shows "arctan (Ifloat x) \<in> {Ifloat (x * lb_arctan_horner prec n 1 (x * x)) .. Ifloat (x * ub_arctan_horner prec (Suc n) 1 (x * x))}"
proof -
  let "?c i" = "-1^i * (1 / real (i * 2 + 1) * Ifloat x ^ (i * 2 + 1))"
  let "?S n" = "\<Sum> i=0..<n. ?c i"

  have "0 \<le> Ifloat (x * x)" by auto
  from `even n` obtain m where "2 * m = n" unfolding even_mult_two_ex by auto
  
  have "arctan (Ifloat x) \<in> { ?S n .. ?S (Suc n) }"
  proof (cases "Ifloat x = 0")
    case False
    hence "0 < Ifloat x" using `0 \<le> Ifloat x` by auto
    hence prem: "0 < 1 / real (0 * 2 + (1::nat)) * Ifloat x ^ (0 * 2 + 1)" by auto 

    have "\<bar> Ifloat x \<bar> \<le> 1"  using `0 \<le> Ifloat x` `Ifloat x \<le> 1` by auto
    from mp[OF summable_Leibniz(2)[OF zeroseq_arctan_series[OF this] monoseq_arctan_series[OF this]] prem, THEN spec, of m, unfolded `2 * m = n`]
    show ?thesis unfolding arctan_series[OF `\<bar> Ifloat x \<bar> \<le> 1`] Suc_plus1  .
  qed auto
  note arctan_bounds = this[unfolded atLeastAtMost_iff]

  have F: "\<And>n. 2 * Suc n + 1 = 2 * n + 1 + 2" by auto

  note bounds = horner_bounds[where s=1 and f="\<lambda>i. 2 * i + 1" and j'=0 
    and lb="\<lambda>n i k x. lb_arctan_horner prec n k x"
    and ub="\<lambda>n i k x. ub_arctan_horner prec n k x", 
    OF `0 \<le> Ifloat (x*x)` F lb_arctan_horner.simps ub_arctan_horner.simps]

  { have "Ifloat (x * lb_arctan_horner prec n 1 (x*x)) \<le> ?S n"
      using bounds(1) `0 \<le> Ifloat x`
      unfolding Ifloat_mult power_add power_one_right real_mult_assoc[symmetric] setsum_left_distrib[symmetric]
      unfolding real_mult_commute mult_commute[of _ "2::nat"] power_mult power2_eq_square[of "Ifloat x"]
      by (auto intro!: mult_left_mono)
    also have "\<dots> \<le> arctan (Ifloat x)" using arctan_bounds ..
    finally have "Ifloat (x * lb_arctan_horner prec n 1 (x*x)) \<le> arctan (Ifloat x)" . }
  moreover
  { have "arctan (Ifloat x) \<le> ?S (Suc n)" using arctan_bounds ..
    also have "\<dots> \<le> Ifloat (x * ub_arctan_horner prec (Suc n) 1 (x*x))"
      using bounds(2)[of "Suc n"] `0 \<le> Ifloat x`
      unfolding Ifloat_mult power_add power_one_right real_mult_assoc[symmetric] setsum_left_distrib[symmetric]
      unfolding real_mult_commute mult_commute[of _ "2::nat"] power_mult power2_eq_square[of "Ifloat x"]
      by (auto intro!: mult_left_mono)
    finally have "arctan (Ifloat x) \<le> Ifloat (x * ub_arctan_horner prec (Suc n) 1 (x*x))" . }
  ultimately show ?thesis by auto
qed

lemma arctan_0_1_bounds: assumes "0 \<le> Ifloat x" "Ifloat x \<le> 1"
  shows "arctan (Ifloat x) \<in> {Ifloat (x * lb_arctan_horner prec (get_even n) 1 (x * x)) .. Ifloat (x * ub_arctan_horner prec (get_odd n) 1 (x * x))}"
proof (cases "even n")
  case True
  obtain n' where "Suc n' = get_odd n" and "odd (Suc n')" using get_odd_ex by auto
  hence "even n'" unfolding even_nat_Suc by auto
  have "arctan (Ifloat x) \<le> Ifloat (x * ub_arctan_horner prec (get_odd n) 1 (x * x))"
    unfolding `Suc n' = get_odd n`[symmetric] using arctan_0_1_bounds'[OF `0 \<le> Ifloat x` `Ifloat x \<le> 1` `even n'`] by auto
  moreover
  have "Ifloat (x * lb_arctan_horner prec (get_even n) 1 (x * x)) \<le> arctan (Ifloat x)"
    unfolding get_even_def if_P[OF True] using arctan_0_1_bounds'[OF `0 \<le> Ifloat x` `Ifloat x \<le> 1` `even n`] by auto
  ultimately show ?thesis by auto
next
  case False hence "0 < n" by (rule odd_pos)
  from gr0_implies_Suc[OF this] obtain n' where "n = Suc n'" ..
  from False[unfolded this even_nat_Suc]
  have "even n'" and "even (Suc (Suc n'))" by auto
  have "get_odd n = Suc n'" unfolding get_odd_def if_P[OF False] using `n = Suc n'` .

  have "arctan (Ifloat x) \<le> Ifloat (x * ub_arctan_horner prec (get_odd n) 1 (x * x))"
    unfolding `get_odd n = Suc n'` using arctan_0_1_bounds'[OF `0 \<le> Ifloat x` `Ifloat x \<le> 1` `even n'`] by auto
  moreover
  have "Ifloat (x * lb_arctan_horner prec (get_even n) 1 (x * x)) \<le> arctan (Ifloat x)"
    unfolding get_even_def if_not_P[OF False] unfolding `n = Suc n'` using arctan_0_1_bounds'[OF `0 \<le> Ifloat x` `Ifloat x \<le> 1` `even (Suc (Suc n'))`] by auto
  ultimately show ?thesis by auto
qed

subsection "Compute \<pi>"

definition ub_pi :: "nat \<Rightarrow> float" where
  "ub_pi prec = (let A = rapprox_rat prec 1 5 ; 
                     B = lapprox_rat prec 1 239
                 in ((Float 1 2) * ((Float 1 2) * A * (ub_arctan_horner prec (get_odd (prec div 4 + 1)) 1 (A * A)) - 
                                                  B * (lb_arctan_horner prec (get_even (prec div 14 + 1)) 1 (B * B)))))"

definition lb_pi :: "nat \<Rightarrow> float" where
  "lb_pi prec = (let A = lapprox_rat prec 1 5 ; 
                     B = rapprox_rat prec 1 239
                 in ((Float 1 2) * ((Float 1 2) * A * (lb_arctan_horner prec (get_even (prec div 4 + 1)) 1 (A * A)) - 
                                                  B * (ub_arctan_horner prec (get_odd (prec div 14 + 1)) 1 (B * B)))))"

lemma pi_boundaries: "pi \<in> {Ifloat (lb_pi n) .. Ifloat (ub_pi n)}"
proof -
  have machin_pi: "pi = 4 * (4 * arctan (1 / 5) - arctan (1 / 239))" unfolding machin[symmetric] by auto

  { fix prec n :: nat fix k :: int assume "1 < k" hence "0 \<le> k" and "0 < k" and "1 \<le> k" by auto
    let ?k = "rapprox_rat prec 1 k"
    have "1 div k = 0" using div_pos_pos_trivial[OF _ `1 < k`] by auto
      
    have "0 \<le> Ifloat ?k" by (rule order_trans[OF _ rapprox_rat], auto simp add: `0 \<le> k`)
    have "Ifloat ?k \<le> 1" unfolding rapprox_rat.simps(2)[OF zero_le_one `0 < k`]
      by (rule rapprox_posrat_le1, auto simp add: `0 < k` `1 \<le> k`)

    have "1 / real k \<le> Ifloat ?k" using rapprox_rat[where x=1 and y=k] by auto
    hence "arctan (1 / real k) \<le> arctan (Ifloat ?k)" by (rule arctan_monotone')
    also have "\<dots> \<le> Ifloat (?k * ub_arctan_horner prec (get_odd n) 1 (?k * ?k))"
      using arctan_0_1_bounds[OF `0 \<le> Ifloat ?k` `Ifloat ?k \<le> 1`] by auto
    finally have "arctan (1 / (real k)) \<le> Ifloat (?k * ub_arctan_horner prec (get_odd n) 1 (?k * ?k))" .
  } note ub_arctan = this

  { fix prec n :: nat fix k :: int assume "1 < k" hence "0 \<le> k" and "0 < k" by auto
    let ?k = "lapprox_rat prec 1 k"
    have "1 div k = 0" using div_pos_pos_trivial[OF _ `1 < k`] by auto
    have "1 / real k \<le> 1" using `1 < k` by auto

    have "\<And>n. 0 \<le> Ifloat ?k" using lapprox_rat_bottom[where x=1 and y=k, OF zero_le_one `0 < k`] by (auto simp add: `1 div k = 0`)
    have "\<And>n. Ifloat ?k \<le> 1" using lapprox_rat by (rule order_trans, auto simp add: `1 / real k \<le> 1`)

    have "Ifloat ?k \<le> 1 / real k" using lapprox_rat[where x=1 and y=k] by auto

    have "Ifloat (?k * lb_arctan_horner prec (get_even n) 1 (?k * ?k)) \<le> arctan (Ifloat ?k)"
      using arctan_0_1_bounds[OF `0 \<le> Ifloat ?k` `Ifloat ?k \<le> 1`] by auto
    also have "\<dots> \<le> arctan (1 / real k)" using `Ifloat ?k \<le> 1 / real k` by (rule arctan_monotone')
    finally have "Ifloat (?k * lb_arctan_horner prec (get_even n) 1 (?k * ?k)) \<le> arctan (1 / (real k))" .
  } note lb_arctan = this

  have "pi \<le> Ifloat (ub_pi n)"
    unfolding ub_pi_def machin_pi Let_def Ifloat_mult Ifloat_sub unfolding Float_num
    using lb_arctan[of 239] ub_arctan[of 5]
    by (auto intro!: mult_left_mono add_mono simp add: diff_minus simp del: lapprox_rat.simps rapprox_rat.simps)
  moreover
  have "Ifloat (lb_pi n) \<le> pi"
    unfolding lb_pi_def machin_pi Let_def Ifloat_mult Ifloat_sub Float_num
    using lb_arctan[of 5] ub_arctan[of 239]
    by (auto intro!: mult_left_mono add_mono simp add: diff_minus simp del: lapprox_rat.simps rapprox_rat.simps)
  ultimately show ?thesis by auto
qed

subsection "Compute arcus tangens in the entire domain"

function lb_arctan :: "nat \<Rightarrow> float \<Rightarrow> float" and ub_arctan :: "nat \<Rightarrow> float \<Rightarrow> float" where 
  "lb_arctan prec x = (let ub_horner = \<lambda> x. x * ub_arctan_horner prec (get_odd (prec div 4 + 1)) 1 (x * x) ;
                           lb_horner = \<lambda> x. x * lb_arctan_horner prec (get_even (prec div 4 + 1)) 1 (x * x)
    in (if x < 0          then - ub_arctan prec (-x) else
        if x \<le> Float 1 -1 then lb_horner x else
        if x \<le> Float 1 1  then Float 1 1 * lb_horner (float_divl prec x (1 + the (ub_sqrt prec (1 + x * x))))
                          else (let inv = float_divr prec 1 x 
                                in if inv > 1 then 0 
                                              else lb_pi prec * Float 1 -1 - ub_horner inv)))"

| "ub_arctan prec x = (let lb_horner = \<lambda> x. x * lb_arctan_horner prec (get_even (prec div 4 + 1)) 1 (x * x) ;
                           ub_horner = \<lambda> x. x * ub_arctan_horner prec (get_odd (prec div 4 + 1)) 1 (x * x)
    in (if x < 0          then - lb_arctan prec (-x) else
        if x \<le> Float 1 -1 then ub_horner x else
        if x \<le> Float 1 1  then let y = float_divr prec x (1 + the (lb_sqrt prec (1 + x * x)))
                               in if y > 1 then ub_pi prec * Float 1 -1 
                                           else Float 1 1 * ub_horner y 
                          else ub_pi prec * Float 1 -1 - lb_horner (float_divl prec 1 x)))"
by pat_completeness auto
termination by (relation "measure (\<lambda> v. let (prec, x) = sum_case id id v in (if x < 0 then 1 else 0))", auto simp add: less_float_def)

declare ub_arctan_horner.simps[simp del]
declare lb_arctan_horner.simps[simp del]

lemma lb_arctan_bound': assumes "0 \<le> Ifloat x"
  shows "Ifloat (lb_arctan prec x) \<le> arctan (Ifloat x)"
proof -
  have "\<not> x < 0" and "0 \<le> x" unfolding less_float_def le_float_def using `0 \<le> Ifloat x` by auto
  let "?ub_horner x" = "x * ub_arctan_horner prec (get_odd (prec div 4 + 1)) 1 (x * x)"
    and "?lb_horner x" = "x * lb_arctan_horner prec (get_even (prec div 4 + 1)) 1 (x * x)"

  show ?thesis
  proof (cases "x \<le> Float 1 -1")
    case True hence "Ifloat x \<le> 1" unfolding le_float_def Float_num by auto
    show ?thesis unfolding lb_arctan.simps Let_def if_not_P[OF `\<not> x < 0`] if_P[OF True]
      using arctan_0_1_bounds[OF `0 \<le> Ifloat x` `Ifloat x \<le> 1`] by auto
  next
    case False hence "0 < Ifloat x" unfolding le_float_def Float_num by auto
    let ?R = "1 + sqrt (1 + Ifloat x * Ifloat x)"
    let ?fR = "1 + the (ub_sqrt prec (1 + x * x))"
    let ?DIV = "float_divl prec x ?fR"
    
    have sqr_ge0: "0 \<le> 1 + Ifloat x * Ifloat x" using sum_power2_ge_zero[of 1 "Ifloat x", unfolded numeral_2_eq_2] by auto
    hence divisor_gt0: "0 < ?R" by (auto intro: add_pos_nonneg)

    have "sqrt (Ifloat (1 + x * x)) \<le> Ifloat (the (ub_sqrt prec (1 + x * x)))" by (rule ub_sqrt_lower_bound, auto simp add: sqr_ge0)
    hence "?R \<le> Ifloat ?fR" by auto
    hence "0 < ?fR" and "0 < Ifloat ?fR" unfolding less_float_def using `0 < ?R` by auto

    have monotone: "Ifloat (float_divl prec x ?fR) \<le> Ifloat x / ?R"
    proof -
      have "Ifloat ?DIV \<le> Ifloat x / Ifloat ?fR" by (rule float_divl)
      also have "\<dots> \<le> Ifloat x / ?R" by (rule divide_left_mono[OF `?R \<le> Ifloat ?fR` `0 \<le> Ifloat x` mult_pos_pos[OF order_less_le_trans[OF divisor_gt0 `?R \<le> Ifloat ?fR`] divisor_gt0]])
      finally show ?thesis .
    qed

    show ?thesis
    proof (cases "x \<le> Float 1 1")
      case True
      
      have "Ifloat x \<le> sqrt (Ifloat (1 + x * x))" using real_sqrt_sum_squares_ge2[where x=1, unfolded numeral_2_eq_2] by auto
      also have "\<dots> \<le> Ifloat (the (ub_sqrt prec (1 + x * x)))" by (rule ub_sqrt_lower_bound, auto simp add: sqr_ge0)
      finally have "Ifloat x \<le> Ifloat ?fR" by auto
      moreover have "Ifloat ?DIV \<le> Ifloat x / Ifloat ?fR" by (rule float_divl)
      ultimately have "Ifloat ?DIV \<le> 1" unfolding divide_le_eq_1_pos[OF `0 < Ifloat ?fR`, symmetric] by auto

      have "0 \<le> Ifloat ?DIV" using float_divl_lower_bound[OF `0 \<le> x` `0 < ?fR`] unfolding le_float_def by auto

      have "Ifloat (Float 1 1 * ?lb_horner ?DIV) \<le> 2 * arctan (Ifloat (float_divl prec x ?fR))" unfolding Ifloat_mult[of "Float 1 1"] Float_num
	using arctan_0_1_bounds[OF `0 \<le> Ifloat ?DIV` `Ifloat ?DIV \<le> 1`] by auto
      also have "\<dots> \<le> 2 * arctan (Ifloat x / ?R)"
	using arctan_monotone'[OF monotone] by (auto intro!: mult_left_mono)
      also have "2 * arctan (Ifloat x / ?R) = arctan (Ifloat x)" using arctan_half[symmetric] unfolding numeral_2_eq_2 power_Suc2 power_0 real_mult_1 . 
      finally show ?thesis unfolding lb_arctan.simps Let_def if_not_P[OF `\<not> x < 0`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_P[OF True] .
    next
      case False
      hence "2 < Ifloat x" unfolding le_float_def Float_num by auto
      hence "1 \<le> Ifloat x" by auto

      let "?invx" = "float_divr prec 1 x"
      have "0 \<le> arctan (Ifloat x)" using arctan_monotone'[OF `0 \<le> Ifloat x`] using arctan_tan[of 0, unfolded tan_zero] by auto

      show ?thesis
      proof (cases "1 < ?invx")
	case True
	show ?thesis unfolding lb_arctan.simps Let_def if_not_P[OF `\<not> x < 0`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_not_P[OF False] if_P[OF True] 
	  using `0 \<le> arctan (Ifloat x)` by auto
      next
	case False
	hence "Ifloat ?invx \<le> 1" unfolding less_float_def by auto
	have "0 \<le> Ifloat ?invx" by (rule order_trans[OF _ float_divr], auto simp add: `0 \<le> Ifloat x`)

	have "1 / Ifloat x \<noteq> 0" and "0 < 1 / Ifloat x" using `0 < Ifloat x` by auto
	
	have "arctan (1 / Ifloat x) \<le> arctan (Ifloat ?invx)" unfolding Ifloat_1[symmetric] by (rule arctan_monotone', rule float_divr)
	also have "\<dots> \<le> Ifloat (?ub_horner ?invx)" using arctan_0_1_bounds[OF `0 \<le> Ifloat ?invx` `Ifloat ?invx \<le> 1`] by auto
	finally have "pi / 2 - Ifloat (?ub_horner ?invx) \<le> arctan (Ifloat x)" 
	  using `0 \<le> arctan (Ifloat x)` arctan_inverse[OF `1 / Ifloat x \<noteq> 0`] 
	  unfolding real_sgn_pos[OF `0 < 1 / Ifloat x`] le_diff_eq by auto
	moreover
	have "Ifloat (lb_pi prec * Float 1 -1) \<le> pi / 2" unfolding Ifloat_mult Float_num times_divide_eq_right real_mult_1 using pi_boundaries by auto
	ultimately
	show ?thesis unfolding lb_arctan.simps Let_def if_not_P[OF `\<not> x < 0`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_not_P[OF `\<not> x \<le> Float 1 1`] if_not_P[OF False]
	  by auto
      qed
    qed
  qed
qed

lemma ub_arctan_bound': assumes "0 \<le> Ifloat x"
  shows "arctan (Ifloat x) \<le> Ifloat (ub_arctan prec x)"
proof -
  have "\<not> x < 0" and "0 \<le> x" unfolding less_float_def le_float_def using `0 \<le> Ifloat x` by auto

  let "?ub_horner x" = "x * ub_arctan_horner prec (get_odd (prec div 4 + 1)) 1 (x * x)"
    and "?lb_horner x" = "x * lb_arctan_horner prec (get_even (prec div 4 + 1)) 1 (x * x)"

  show ?thesis
  proof (cases "x \<le> Float 1 -1")
    case True hence "Ifloat x \<le> 1" unfolding le_float_def Float_num by auto
    show ?thesis unfolding ub_arctan.simps Let_def if_not_P[OF `\<not> x < 0`] if_P[OF True]
      using arctan_0_1_bounds[OF `0 \<le> Ifloat x` `Ifloat x \<le> 1`] by auto
  next
    case False hence "0 < Ifloat x" unfolding le_float_def Float_num by auto
    let ?R = "1 + sqrt (1 + Ifloat x * Ifloat x)"
    let ?fR = "1 + the (lb_sqrt prec (1 + x * x))"
    let ?DIV = "float_divr prec x ?fR"
    
    have sqr_ge0: "0 \<le> 1 + Ifloat x * Ifloat x" using sum_power2_ge_zero[of 1 "Ifloat x", unfolded numeral_2_eq_2] by auto
    hence "0 \<le> Ifloat (1 + x*x)" by auto
    
    hence divisor_gt0: "0 < ?R" by (auto intro: add_pos_nonneg)

    have "Ifloat (the (lb_sqrt prec (1 + x * x))) \<le> sqrt (Ifloat (1 + x * x))" by (rule lb_sqrt_upper_bound, auto simp add: sqr_ge0)
    hence "Ifloat ?fR \<le> ?R" by auto
    have "0 < Ifloat ?fR" unfolding Ifloat_add Ifloat_1 by (rule order_less_le_trans[OF zero_less_one], auto simp add: lb_sqrt_lower_bound[OF `0 \<le> Ifloat (1 + x*x)`])

    have monotone: "Ifloat x / ?R \<le> Ifloat (float_divr prec x ?fR)"
    proof -
      from divide_left_mono[OF `Ifloat ?fR \<le> ?R` `0 \<le> Ifloat x` mult_pos_pos[OF divisor_gt0 `0 < Ifloat ?fR`]]
      have "Ifloat x / ?R \<le> Ifloat x / Ifloat ?fR" .
      also have "\<dots> \<le> Ifloat ?DIV" by (rule float_divr)
      finally show ?thesis .
    qed

    show ?thesis
    proof (cases "x \<le> Float 1 1")
      case True
      show ?thesis
      proof (cases "?DIV > 1")
	case True
	have "pi / 2 \<le> Ifloat (ub_pi prec * Float 1 -1)" unfolding Ifloat_mult Float_num times_divide_eq_right real_mult_1 using pi_boundaries by auto
	from order_less_le_trans[OF arctan_ubound this, THEN less_imp_le]
	show ?thesis unfolding ub_arctan.simps Let_def if_not_P[OF `\<not> x < 0`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_P[OF `x \<le> Float 1 1`] if_P[OF True] .
      next
	case False
	hence "Ifloat ?DIV \<le> 1" unfolding less_float_def by auto
      
	have "0 \<le> Ifloat x / ?R" using `0 \<le> Ifloat x` `0 < ?R` unfolding real_0_le_divide_iff by auto
	hence "0 \<le> Ifloat ?DIV" using monotone by (rule order_trans)

	have "arctan (Ifloat x) = 2 * arctan (Ifloat x / ?R)" using arctan_half unfolding numeral_2_eq_2 power_Suc2 power_0 real_mult_1 .
	also have "\<dots> \<le> 2 * arctan (Ifloat ?DIV)"
	  using arctan_monotone'[OF monotone] by (auto intro!: mult_left_mono)
	also have "\<dots> \<le> Ifloat (Float 1 1 * ?ub_horner ?DIV)" unfolding Ifloat_mult[of "Float 1 1"] Float_num
	  using arctan_0_1_bounds[OF `0 \<le> Ifloat ?DIV` `Ifloat ?DIV \<le> 1`] by auto
	finally show ?thesis unfolding ub_arctan.simps Let_def if_not_P[OF `\<not> x < 0`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_P[OF `x \<le> Float 1 1`] if_not_P[OF False] .
      qed
    next
      case False
      hence "2 < Ifloat x" unfolding le_float_def Float_num by auto
      hence "1 \<le> Ifloat x" by auto
      hence "0 < Ifloat x" by auto
      hence "0 < x" unfolding less_float_def by auto

      let "?invx" = "float_divl prec 1 x"
      have "0 \<le> arctan (Ifloat x)" using arctan_monotone'[OF `0 \<le> Ifloat x`] using arctan_tan[of 0, unfolded tan_zero] by auto

      have "Ifloat ?invx \<le> 1" unfolding less_float_def by (rule order_trans[OF float_divl], auto simp add: `1 \<le> Ifloat x` divide_le_eq_1_pos[OF `0 < Ifloat x`])
      have "0 \<le> Ifloat ?invx" unfolding Ifloat_0[symmetric] by (rule float_divl_lower_bound[unfolded le_float_def], auto simp add: `0 < x`)
	
      have "1 / Ifloat x \<noteq> 0" and "0 < 1 / Ifloat x" using `0 < Ifloat x` by auto
      
      have "Ifloat (?lb_horner ?invx) \<le> arctan (Ifloat ?invx)" using arctan_0_1_bounds[OF `0 \<le> Ifloat ?invx` `Ifloat ?invx \<le> 1`] by auto
      also have "\<dots> \<le> arctan (1 / Ifloat x)" unfolding Ifloat_1[symmetric] by (rule arctan_monotone', rule float_divl)
      finally have "arctan (Ifloat x) \<le> pi / 2 - Ifloat (?lb_horner ?invx)"
	using `0 \<le> arctan (Ifloat x)` arctan_inverse[OF `1 / Ifloat x \<noteq> 0`] 
	unfolding real_sgn_pos[OF `0 < 1 / Ifloat x`] le_diff_eq by auto
      moreover
      have "pi / 2 \<le> Ifloat (ub_pi prec * Float 1 -1)" unfolding Ifloat_mult Float_num times_divide_eq_right mult_1_right using pi_boundaries by auto
      ultimately
      show ?thesis unfolding ub_arctan.simps Let_def if_not_P[OF `\<not> x < 0`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_not_P[OF `\<not> x \<le> Float 1 1`] if_not_P[OF False]
	by auto
    qed
  qed
qed

lemma arctan_boundaries:
  "arctan (Ifloat x) \<in> {Ifloat (lb_arctan prec x) .. Ifloat (ub_arctan prec x)}"
proof (cases "0 \<le> x")
  case True hence "0 \<le> Ifloat x" unfolding le_float_def by auto
  show ?thesis using ub_arctan_bound'[OF `0 \<le> Ifloat x`] lb_arctan_bound'[OF `0 \<le> Ifloat x`] unfolding atLeastAtMost_iff by auto
next
  let ?mx = "-x"
  case False hence "x < 0" and "0 \<le> Ifloat ?mx" unfolding le_float_def less_float_def by auto
  hence bounds: "Ifloat (lb_arctan prec ?mx) \<le> arctan (Ifloat ?mx) \<and> arctan (Ifloat ?mx) \<le> Ifloat (ub_arctan prec ?mx)"
    using ub_arctan_bound'[OF `0 \<le> Ifloat ?mx`] lb_arctan_bound'[OF `0 \<le> Ifloat ?mx`] by auto
  show ?thesis unfolding Ifloat_minus arctan_minus lb_arctan.simps[where x=x] ub_arctan.simps[where x=x] Let_def if_P[OF `x < 0`]
    unfolding atLeastAtMost_iff using bounds[unfolded Ifloat_minus arctan_minus] by auto
qed

lemma bnds_arctan: "\<forall> x lx ux. (l, u) = (lb_arctan prec lx, ub_arctan prec ux) \<and> x \<in> {Ifloat lx .. Ifloat ux} \<longrightarrow> Ifloat l \<le> arctan x \<and> arctan x \<le> Ifloat u"
proof (rule allI, rule allI, rule allI, rule impI)
  fix x lx ux
  assume "(l, u) = (lb_arctan prec lx, ub_arctan prec ux) \<and> x \<in> {Ifloat lx .. Ifloat ux}"
  hence l: "lb_arctan prec lx = l " and u: "ub_arctan prec ux = u" and x: "x \<in> {Ifloat lx .. Ifloat ux}" by auto

  { from arctan_boundaries[of lx prec, unfolded l]
    have "Ifloat l \<le> arctan (Ifloat lx)" by (auto simp del: lb_arctan.simps)
    also have "\<dots> \<le> arctan x" using x by (auto intro: arctan_monotone')
    finally have "Ifloat l \<le> arctan x" .
  } moreover
  { have "arctan x \<le> arctan (Ifloat ux)" using x by (auto intro: arctan_monotone')
    also have "\<dots> \<le> Ifloat u" using arctan_boundaries[of ux prec, unfolded u] by (auto simp del: ub_arctan.simps)
    finally have "arctan x \<le> Ifloat u" .
  } ultimately show "Ifloat l \<le> arctan x \<and> arctan x \<le> Ifloat u" ..
qed

section "Sinus and Cosinus"

subsection "Compute the cosinus and sinus series"

fun ub_sin_cos_aux :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> float \<Rightarrow> float"
and lb_sin_cos_aux :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> float \<Rightarrow> float" where
  "ub_sin_cos_aux prec 0 i k x = 0"
| "ub_sin_cos_aux prec (Suc n) i k x = 
    (rapprox_rat prec 1 (int k)) - x * (lb_sin_cos_aux prec n (i + 2) (k * i * (i + 1)) x)"
| "lb_sin_cos_aux prec 0 i k x = 0"
| "lb_sin_cos_aux prec (Suc n) i k x = 
    (lapprox_rat prec 1 (int k)) - x * (ub_sin_cos_aux prec n (i + 2) (k * i * (i + 1)) x)"

lemma cos_aux:
  shows "Ifloat (lb_sin_cos_aux prec n 1 1 (x * x)) \<le> (\<Sum> i=0..<n. -1^i * (1/real (fact (2 * i))) * (Ifloat x)^(2 * i))" (is "?lb")
  and "(\<Sum> i=0..<n. -1^i * (1/real (fact (2 * i))) * (Ifloat x)^(2 * i)) \<le> Ifloat (ub_sin_cos_aux prec n 1 1 (x * x))" (is "?ub")
proof -
  have "0 \<le> Ifloat (x * x)" unfolding Ifloat_mult by auto
  let "?f n" = "fact (2 * n)"

  { fix n 
    have F: "\<And>m. ((\<lambda>i. i + 2) ^ n) m = m + 2 * n" by (induct n arbitrary: m, auto)
    have "?f (Suc n) = ?f n * ((\<lambda>i. i + 2) ^ n) 1 * (((\<lambda>i. i + 2) ^ n) 1 + 1)"
      unfolding F by auto } note f_eq = this
    
  from horner_bounds[where lb="lb_sin_cos_aux prec" and ub="ub_sin_cos_aux prec" and j'=0, 
    OF `0 \<le> Ifloat (x * x)` f_eq lb_sin_cos_aux.simps ub_sin_cos_aux.simps]
  show "?lb" and "?ub" by (auto simp add: power_mult power2_eq_square[of "Ifloat x"])
qed

lemma cos_boundaries: assumes "0 \<le> Ifloat x" and "Ifloat x \<le> pi / 2"
  shows "cos (Ifloat x) \<in> {Ifloat (lb_sin_cos_aux prec (get_even n) 1 1 (x * x)) .. Ifloat (ub_sin_cos_aux prec (get_odd n) 1 1 (x * x))}"
proof (cases "Ifloat x = 0")
  case False hence "Ifloat x \<noteq> 0" by auto
  hence "0 < x" and "0 < Ifloat x" using `0 \<le> Ifloat x` unfolding less_float_def by auto
  have "0 < x * x" using `0 < x` unfolding less_float_def Ifloat_mult Ifloat_0
    using mult_pos_pos[where a="Ifloat x" and b="Ifloat x"] by auto

  { fix x n have "(\<Sum> i=0..<n. -1^i * (1/real (fact (2 * i))) * x^(2 * i))
    = (\<Sum> i = 0 ..< 2 * n. (if even(i) then (-1 ^ (i div 2))/(real (fact i)) else 0) * x ^ i)" (is "?sum = ?ifsum")
  proof -
    have "?sum = ?sum + (\<Sum> j = 0 ..< n. 0)" by auto
    also have "\<dots> = 
      (\<Sum> j = 0 ..< n. -1 ^ ((2 * j) div 2) / (real (fact (2 * j))) * x ^(2 * j)) + (\<Sum> j = 0 ..< n. 0)" by auto
    also have "\<dots> = (\<Sum> i = 0 ..< 2 * n. if even i then -1 ^ (i div 2) / (real (fact i)) * x ^ i else 0)"
      unfolding sum_split_even_odd ..
    also have "\<dots> = (\<Sum> i = 0 ..< 2 * n. (if even i then -1 ^ (i div 2) / (real (fact i)) else 0) * x ^ i)"
      by (rule setsum_cong2) auto
    finally show ?thesis by assumption
  qed } note morph_to_if_power = this


  { fix n :: nat assume "0 < n"
    hence "0 < 2 * n" by auto
    obtain t where "0 < t" and "t < Ifloat x" and
      cos_eq: "cos (Ifloat x) = (\<Sum> i = 0 ..< 2 * n. (if even(i) then (-1 ^ (i div 2))/(real (fact i)) else 0) * (Ifloat x) ^ i) 
      + (cos (t + 1/2 * real (2 * n) * pi) / real (fact (2*n))) * (Ifloat x)^(2*n)" 
      (is "_ = ?SUM + ?rest / ?fact * ?pow")
      using Maclaurin_cos_expansion2[OF `0 < Ifloat x` `0 < 2 * n`] by auto

    have "cos t * -1^n = cos t * cos (real n * pi) + sin t * sin (real n * pi)" by auto
    also have "\<dots> = cos (t + real n * pi)"  using cos_add by auto
    also have "\<dots> = ?rest" by auto
    finally have "cos t * -1^n = ?rest" .
    moreover
    have "t \<le> pi / 2" using `t < Ifloat x` and `Ifloat x \<le> pi / 2` by auto
    hence "0 \<le> cos t" using `0 < t` and cos_ge_zero by auto
    ultimately have even: "even n \<Longrightarrow> 0 \<le> ?rest" and odd: "odd n \<Longrightarrow> 0 \<le> - ?rest " by auto

    have "0 < ?fact" by auto
    have "0 < ?pow" using `0 < Ifloat x` by auto

    {
      assume "even n"
      have "Ifloat (lb_sin_cos_aux prec n 1 1 (x * x)) \<le> ?SUM"
	unfolding morph_to_if_power[symmetric] using cos_aux by auto 
      also have "\<dots> \<le> cos (Ifloat x)"
      proof -
	from even[OF `even n`] `0 < ?fact` `0 < ?pow`
	have "0 \<le> (?rest / ?fact) * ?pow" by (metis mult_nonneg_nonneg divide_nonneg_pos less_imp_le)
	thus ?thesis unfolding cos_eq by auto
      qed
      finally have "Ifloat (lb_sin_cos_aux prec n 1 1 (x * x)) \<le> cos (Ifloat x)" .
    } note lb = this

    {
      assume "odd n"
      have "cos (Ifloat x) \<le> ?SUM"
      proof -
	from `0 < ?fact` and `0 < ?pow` and odd[OF `odd n`]
	have "0 \<le> (- ?rest) / ?fact * ?pow"
	  by (metis mult_nonneg_nonneg divide_nonneg_pos less_imp_le)
	thus ?thesis unfolding cos_eq by auto
      qed
      also have "\<dots> \<le> Ifloat (ub_sin_cos_aux prec n 1 1 (x * x))"
	unfolding morph_to_if_power[symmetric] using cos_aux by auto
      finally have "cos (Ifloat x) \<le> Ifloat (ub_sin_cos_aux prec n 1 1 (x * x))" .
    } note ub = this and lb
  } note ub = this(1) and lb = this(2)

  have "cos (Ifloat x) \<le> Ifloat (ub_sin_cos_aux prec (get_odd n) 1 1 (x * x))" using ub[OF odd_pos[OF get_odd] get_odd] .
  moreover have "Ifloat (lb_sin_cos_aux prec (get_even n) 1 1 (x * x)) \<le> cos (Ifloat x)" 
  proof (cases "0 < get_even n")
    case True show ?thesis using lb[OF True get_even] .
  next
    case False
    hence "get_even n = 0" by auto
    have "- (pi / 2) \<le> Ifloat x" by (rule order_trans[OF _ `0 < Ifloat x`[THEN less_imp_le]], auto)
    with `Ifloat x \<le> pi / 2`
    show ?thesis unfolding `get_even n = 0` lb_sin_cos_aux.simps Ifloat_minus Ifloat_0 using cos_ge_zero by auto
  qed
  ultimately show ?thesis by auto
next
  case True
  show ?thesis
  proof (cases "n = 0")
    case True 
    thus ?thesis unfolding `n = 0` get_even_def get_odd_def using `Ifloat x = 0` lapprox_rat[where x="-1" and y=1] by auto
  next
    case False with not0_implies_Suc obtain m where "n = Suc m" by blast
    thus ?thesis unfolding `n = Suc m` get_even_def get_odd_def using `Ifloat x = 0` rapprox_rat[where x=1 and y=1] lapprox_rat[where x=1 and y=1] by (cases "even (Suc m)", auto)
  qed
qed

lemma sin_aux: assumes "0 \<le> Ifloat x"
  shows "Ifloat (x * lb_sin_cos_aux prec n 2 1 (x * x)) \<le> (\<Sum> i=0..<n. -1^i * (1/real (fact (2 * i + 1))) * (Ifloat x)^(2 * i + 1))" (is "?lb")
  and "(\<Sum> i=0..<n. -1^i * (1/real (fact (2 * i + 1))) * (Ifloat x)^(2 * i + 1)) \<le> Ifloat (x * ub_sin_cos_aux prec n 2 1 (x * x))" (is "?ub")
proof -
  have "0 \<le> Ifloat (x * x)" unfolding Ifloat_mult by auto
  let "?f n" = "fact (2 * n + 1)"

  { fix n 
    have F: "\<And>m. ((\<lambda>i. i + 2) ^ n) m = m + 2 * n" by (induct n arbitrary: m, auto)
    have "?f (Suc n) = ?f n * ((\<lambda>i. i + 2) ^ n) 2 * (((\<lambda>i. i + 2) ^ n) 2 + 1)"
      unfolding F by auto } note f_eq = this
    
  from horner_bounds[where lb="lb_sin_cos_aux prec" and ub="ub_sin_cos_aux prec" and j'=0,
    OF `0 \<le> Ifloat (x * x)` f_eq lb_sin_cos_aux.simps ub_sin_cos_aux.simps]
  show "?lb" and "?ub" using `0 \<le> Ifloat x` unfolding Ifloat_mult
    unfolding power_add power_one_right real_mult_assoc[symmetric] setsum_left_distrib[symmetric]
    unfolding real_mult_commute
    by (auto intro!: mult_left_mono simp add: power_mult power2_eq_square[of "Ifloat x"])
qed

lemma sin_boundaries: assumes "0 \<le> Ifloat x" and "Ifloat x \<le> pi / 2"
  shows "sin (Ifloat x) \<in> {Ifloat (x * lb_sin_cos_aux prec (get_even n) 2 1 (x * x)) .. Ifloat (x * ub_sin_cos_aux prec (get_odd n) 2 1 (x * x))}"
proof (cases "Ifloat x = 0")
  case False hence "Ifloat x \<noteq> 0" by auto
  hence "0 < x" and "0 < Ifloat x" using `0 \<le> Ifloat x` unfolding less_float_def by auto
  have "0 < x * x" using `0 < x` unfolding less_float_def Ifloat_mult Ifloat_0
    using mult_pos_pos[where a="Ifloat x" and b="Ifloat x"] by auto

  { fix x n have "(\<Sum> j = 0 ..< n. -1 ^ (((2 * j + 1) - Suc 0) div 2) / (real (fact (2 * j + 1))) * x ^(2 * j + 1))
    = (\<Sum> i = 0 ..< 2 * n. (if even(i) then 0 else (-1 ^ ((i - Suc 0) div 2))/(real (fact i))) * x ^ i)" (is "?SUM = _")
    proof -
      have pow: "!!i. x ^ (2 * i + 1) = x * x ^ (2 * i)" by auto
      have "?SUM = (\<Sum> j = 0 ..< n. 0) + ?SUM" by auto
      also have "\<dots> = (\<Sum> i = 0 ..< 2 * n. if even i then 0 else -1 ^ ((i - Suc 0) div 2) / (real (fact i)) * x ^ i)"
	unfolding sum_split_even_odd ..
      also have "\<dots> = (\<Sum> i = 0 ..< 2 * n. (if even i then 0 else -1 ^ ((i - Suc 0) div 2) / (real (fact i))) * x ^ i)"
	by (rule setsum_cong2) auto
      finally show ?thesis by assumption
    qed } note setsum_morph = this

  { fix n :: nat assume "0 < n"
    hence "0 < 2 * n + 1" by auto
    obtain t where "0 < t" and "t < Ifloat x" and
      sin_eq: "sin (Ifloat x) = (\<Sum> i = 0 ..< 2 * n + 1. (if even(i) then 0 else (-1 ^ ((i - Suc 0) div 2))/(real (fact i))) * (Ifloat x) ^ i) 
      + (sin (t + 1/2 * real (2 * n + 1) * pi) / real (fact (2*n + 1))) * (Ifloat x)^(2*n + 1)" 
      (is "_ = ?SUM + ?rest / ?fact * ?pow")
      using Maclaurin_sin_expansion3[OF `0 < 2 * n + 1` `0 < Ifloat x`] by auto

    have "?rest = cos t * -1^n" unfolding sin_add cos_add real_of_nat_add left_distrib right_distrib by auto
    moreover
    have "t \<le> pi / 2" using `t < Ifloat x` and `Ifloat x \<le> pi / 2` by auto
    hence "0 \<le> cos t" using `0 < t` and cos_ge_zero by auto
    ultimately have even: "even n \<Longrightarrow> 0 \<le> ?rest" and odd: "odd n \<Longrightarrow> 0 \<le> - ?rest " by auto

    have "0 < ?fact" by (rule real_of_nat_fact_gt_zero)
    have "0 < ?pow" using `0 < Ifloat x` by (rule zero_less_power)

    {
      assume "even n"
      have "Ifloat (x * lb_sin_cos_aux prec n 2 1 (x * x)) \<le> 
            (\<Sum> i = 0 ..< 2 * n. (if even(i) then 0 else (-1 ^ ((i - Suc 0) div 2))/(real (fact i))) * (Ifloat x) ^ i)"
	using sin_aux[OF `0 \<le> Ifloat x`] unfolding setsum_morph[symmetric] by auto
      also have "\<dots> \<le> ?SUM" by auto
      also have "\<dots> \<le> sin (Ifloat x)"
      proof -
	from even[OF `even n`] `0 < ?fact` `0 < ?pow`
	have "0 \<le> (?rest / ?fact) * ?pow" by (metis mult_nonneg_nonneg divide_nonneg_pos less_imp_le)
	thus ?thesis unfolding sin_eq by auto
      qed
      finally have "Ifloat (x * lb_sin_cos_aux prec n 2 1 (x * x)) \<le> sin (Ifloat x)" .
    } note lb = this

    {
      assume "odd n"
      have "sin (Ifloat x) \<le> ?SUM"
      proof -
	from `0 < ?fact` and `0 < ?pow` and odd[OF `odd n`]
	have "0 \<le> (- ?rest) / ?fact * ?pow"
	  by (metis mult_nonneg_nonneg divide_nonneg_pos less_imp_le)
	thus ?thesis unfolding sin_eq by auto
      qed
      also have "\<dots> \<le> (\<Sum> i = 0 ..< 2 * n. (if even(i) then 0 else (-1 ^ ((i - Suc 0) div 2))/(real (fact i))) * (Ifloat x) ^ i)"
	 by auto
      also have "\<dots> \<le> Ifloat (x * ub_sin_cos_aux prec n 2 1 (x * x))" 
	using sin_aux[OF `0 \<le> Ifloat x`] unfolding setsum_morph[symmetric] by auto
      finally have "sin (Ifloat x) \<le> Ifloat (x * ub_sin_cos_aux prec n 2 1 (x * x))" .
    } note ub = this and lb
  } note ub = this(1) and lb = this(2)

  have "sin (Ifloat x) \<le> Ifloat (x * ub_sin_cos_aux prec (get_odd n) 2 1 (x * x))" using ub[OF odd_pos[OF get_odd] get_odd] .
  moreover have "Ifloat (x * lb_sin_cos_aux prec (get_even n) 2 1 (x * x)) \<le> sin (Ifloat x)" 
  proof (cases "0 < get_even n")
    case True show ?thesis using lb[OF True get_even] .
  next
    case False
    hence "get_even n = 0" by auto
    with `Ifloat x \<le> pi / 2` `0 \<le> Ifloat x`
    show ?thesis unfolding `get_even n = 0` ub_sin_cos_aux.simps Ifloat_minus Ifloat_0 using sin_ge_zero by auto
  qed
  ultimately show ?thesis by auto
next
  case True
  show ?thesis
  proof (cases "n = 0")
    case True 
    thus ?thesis unfolding `n = 0` get_even_def get_odd_def using `Ifloat x = 0` lapprox_rat[where x="-1" and y=1] by auto
  next
    case False with not0_implies_Suc obtain m where "n = Suc m" by blast
    thus ?thesis unfolding `n = Suc m` get_even_def get_odd_def using `Ifloat x = 0` rapprox_rat[where x=1 and y=1] lapprox_rat[where x=1 and y=1] by (cases "even (Suc m)", auto)
  qed
qed

subsection "Compute the cosinus in the entire domain"

definition lb_cos :: "nat \<Rightarrow> float \<Rightarrow> float" where
"lb_cos prec x = (let
    horner = \<lambda> x. lb_sin_cos_aux prec (get_even (prec div 4 + 1)) 1 1 (x * x) ;
    half = \<lambda> x. if x < 0 then - 1 else Float 1 1 * x * x - 1
  in if x < Float 1 -1 then horner x
else if x < 1          then half (horner (x * Float 1 -1))
                       else half (half (horner (x * Float 1 -2))))"

definition ub_cos :: "nat \<Rightarrow> float \<Rightarrow> float" where
"ub_cos prec x = (let
    horner = \<lambda> x. ub_sin_cos_aux prec (get_odd (prec div 4 + 1)) 1 1 (x * x) ;
    half = \<lambda> x. Float 1 1 * x * x - 1
  in if x < Float 1 -1 then horner x
else if x < 1          then half (horner (x * Float 1 -1))
                       else half (half (horner (x * Float 1 -2))))"

definition bnds_cos :: "nat \<Rightarrow> float \<Rightarrow> float \<Rightarrow> float * float" where
"bnds_cos prec lx ux = (let  lpi = lb_pi prec
  in   if lx < -lpi \<or> ux > lpi   then (Float -1 0, Float 1 0)
  else if ux \<le> 0                 then (lb_cos prec (-lx), ub_cos prec (-ux))
  else if 0 \<le> lx                 then (lb_cos prec ux, ub_cos prec lx)
                                 else (min (lb_cos prec (-lx)) (lb_cos prec ux), Float 1 0))"

lemma lb_cos: assumes "0 \<le> Ifloat x" and "Ifloat x \<le> pi" 
  shows "cos (Ifloat x) \<in> {Ifloat (lb_cos prec x) .. Ifloat (ub_cos prec x)}" (is "?cos x \<in> { Ifloat (?lb x) .. Ifloat (?ub x) }")
proof -
  { fix x :: real
    have "cos x = cos (x / 2 + x / 2)" by auto
    also have "\<dots> = cos (x / 2) * cos (x / 2) + sin (x / 2) * sin (x / 2) - sin (x / 2) * sin (x / 2) + cos (x / 2) * cos (x / 2) - 1"
      unfolding cos_add by auto
    also have "\<dots> = 2 * cos (x / 2) * cos (x / 2) - 1" by algebra
    finally have "cos x = 2 * cos (x / 2) * cos (x / 2) - 1" .
  } note x_half = this[symmetric]

  have "\<not> x < 0" using `0 \<le> Ifloat x` unfolding less_float_def by auto
  let "?ub_horner x" = "ub_sin_cos_aux prec (get_odd (prec div 4 + 1)) 1 1 (x * x)"
  let "?lb_horner x" = "lb_sin_cos_aux prec (get_even (prec div 4 + 1)) 1 1 (x * x)"
  let "?ub_half x" = "Float 1 1 * x * x - 1"
  let "?lb_half x" = "if x < 0 then - 1 else Float 1 1 * x * x - 1"

  show ?thesis
  proof (cases "x < Float 1 -1")
    case True hence "Ifloat x \<le> pi / 2" unfolding less_float_def using pi_ge_two by auto
    show ?thesis unfolding lb_cos_def[where x=x] ub_cos_def[where x=x] if_not_P[OF `\<not> x < 0`] if_P[OF `x < Float 1 -1`] Let_def
      using cos_boundaries[OF `0 \<le> Ifloat x` `Ifloat x \<le> pi / 2`] .
  next
    case False
    
    { fix y x :: float let ?x2 = "Ifloat (x * Float 1 -1)"
      assume "Ifloat y \<le> cos ?x2" and "-pi \<le> Ifloat x" and "Ifloat x \<le> pi"
      hence "- (pi / 2) \<le> ?x2" and "?x2 \<le> pi / 2" using pi_ge_two unfolding Ifloat_mult Float_num by auto
      hence "0 \<le> cos ?x2" by (rule cos_ge_zero)
      
      have "Ifloat (?lb_half y) \<le> cos (Ifloat x)"
      proof (cases "y < 0")
	case True show ?thesis using cos_ge_minus_one unfolding if_P[OF True] by auto
      next
	case False
	hence "0 \<le> Ifloat y" unfolding less_float_def by auto
	from mult_mono[OF `Ifloat y \<le> cos ?x2` `Ifloat y \<le> cos ?x2` `0 \<le> cos ?x2` this]
	have "Ifloat y * Ifloat y \<le> cos ?x2 * cos ?x2" .
	hence "2 * Ifloat y * Ifloat y \<le> 2 * cos ?x2 * cos ?x2" by auto
	hence "2 * Ifloat y * Ifloat y - 1 \<le> 2 * cos (Ifloat x / 2) * cos (Ifloat x / 2) - 1" unfolding Float_num Ifloat_mult by auto
	thus ?thesis unfolding if_not_P[OF False] x_half Float_num Ifloat_mult Ifloat_sub by auto
      qed
    } note lb_half = this
    
    { fix y x :: float let ?x2 = "Ifloat (x * Float 1 -1)"
      assume ub: "cos ?x2 \<le> Ifloat y" and "- pi \<le> Ifloat x" and "Ifloat x \<le> pi"
      hence "- (pi / 2) \<le> ?x2" and "?x2 \<le> pi / 2" using pi_ge_two unfolding Ifloat_mult Float_num by auto
      hence "0 \<le> cos ?x2" by (rule cos_ge_zero)
      
      have "cos (Ifloat x) \<le> Ifloat (?ub_half y)"
      proof -
	have "0 \<le> Ifloat y" using `0 \<le> cos ?x2` ub by (rule order_trans)
	from mult_mono[OF ub ub this `0 \<le> cos ?x2`]
	have "cos ?x2 * cos ?x2 \<le> Ifloat y * Ifloat y" .
	hence "2 * cos ?x2 * cos ?x2 \<le> 2 * Ifloat y * Ifloat y" by auto
	hence "2 * cos (Ifloat x / 2) * cos (Ifloat x / 2) - 1 \<le> 2 * Ifloat y * Ifloat y - 1" unfolding Float_num Ifloat_mult by auto
	thus ?thesis unfolding x_half Ifloat_mult Float_num Ifloat_sub by auto
      qed
    } note ub_half = this
    
    let ?x2 = "x * Float 1 -1"
    let ?x4 = "x * Float 1 -1 * Float 1 -1"
    
    have "-pi \<le> Ifloat x" using pi_ge_zero[THEN le_imp_neg_le, unfolded minus_zero] `0 \<le> Ifloat x` by (rule order_trans)
    
    show ?thesis
    proof (cases "x < 1")
      case True hence "Ifloat x \<le> 1" unfolding less_float_def by auto
      have "0 \<le> Ifloat ?x2" and "Ifloat ?x2 \<le> pi / 2" using pi_ge_two `0 \<le> Ifloat x` unfolding Ifloat_mult Float_num using assms by auto
      from cos_boundaries[OF this]
      have lb: "Ifloat (?lb_horner ?x2) \<le> ?cos ?x2" and ub: "?cos ?x2 \<le> Ifloat (?ub_horner ?x2)" by auto
      
      have "Ifloat (?lb x) \<le> ?cos x"
      proof -
	from lb_half[OF lb `-pi \<le> Ifloat x` `Ifloat x \<le> pi`]
	show ?thesis unfolding lb_cos_def[where x=x] Let_def using `\<not> x < 0` `\<not> x < Float 1 -1` `x < 1` by auto
      qed
      moreover have "?cos x \<le> Ifloat (?ub x)"
      proof -
	from ub_half[OF ub `-pi \<le> Ifloat x` `Ifloat x \<le> pi`]
	show ?thesis unfolding ub_cos_def[where x=x] Let_def using `\<not> x < 0` `\<not> x < Float 1 -1` `x < 1` by auto 
      qed
      ultimately show ?thesis by auto
    next
      case False
      have "0 \<le> Ifloat ?x4" and "Ifloat ?x4 \<le> pi / 2" using pi_ge_two `0 \<le> Ifloat x` `Ifloat x \<le> pi` unfolding Ifloat_mult Float_num by auto
      from cos_boundaries[OF this]
      have lb: "Ifloat (?lb_horner ?x4) \<le> ?cos ?x4" and ub: "?cos ?x4 \<le> Ifloat (?ub_horner ?x4)" by auto
      
      have eq_4: "?x2 * Float 1 -1 = x * Float 1 -2" by (cases x, auto simp add: times_float.simps)
      
      have "Ifloat (?lb x) \<le> ?cos x"
      proof -
	have "-pi \<le> Ifloat ?x2" and "Ifloat ?x2 \<le> pi" unfolding Ifloat_mult Float_num using pi_ge_two `0 \<le> Ifloat x` `Ifloat x \<le> pi` by auto
	from lb_half[OF lb_half[OF lb this] `-pi \<le> Ifloat x` `Ifloat x \<le> pi`, unfolded eq_4]
	show ?thesis unfolding lb_cos_def[where x=x] if_not_P[OF `\<not> x < 0`] if_not_P[OF `\<not> x < Float 1 -1`] if_not_P[OF `\<not> x < 1`] Let_def .
      qed
      moreover have "?cos x \<le> Ifloat (?ub x)"
      proof -
	have "-pi \<le> Ifloat ?x2" and "Ifloat ?x2 \<le> pi" unfolding Ifloat_mult Float_num using pi_ge_two `0 \<le> Ifloat x` `Ifloat x \<le> pi` by auto
	from ub_half[OF ub_half[OF ub this] `-pi \<le> Ifloat x` `Ifloat x \<le> pi`, unfolded eq_4]
	show ?thesis unfolding ub_cos_def[where x=x] if_not_P[OF `\<not> x < 0`] if_not_P[OF `\<not> x < Float 1 -1`] if_not_P[OF `\<not> x < 1`] Let_def .
      qed
      ultimately show ?thesis by auto
    qed
  qed
qed

lemma lb_cos_minus: assumes "-pi \<le> Ifloat x" and "Ifloat x \<le> 0" 
  shows "cos (Ifloat (-x)) \<in> {Ifloat (lb_cos prec (-x)) .. Ifloat (ub_cos prec (-x))}"
proof -
  have "0 \<le> Ifloat (-x)" and "Ifloat (-x) \<le> pi" using `-pi \<le> Ifloat x` `Ifloat x \<le> 0` by auto
  from lb_cos[OF this] show ?thesis .
qed

lemma bnds_cos: "\<forall> x lx ux. (l, u) = bnds_cos prec lx ux \<and> x \<in> {Ifloat lx .. Ifloat ux} \<longrightarrow> Ifloat l \<le> cos x \<and> cos x \<le> Ifloat u"
proof (rule allI, rule allI, rule allI, rule impI)
  fix x lx ux
  assume "(l, u) = bnds_cos prec lx ux \<and> x \<in> {Ifloat lx .. Ifloat ux}"
  hence bnds: "(l, u) = bnds_cos prec lx ux" and x: "x \<in> {Ifloat lx .. Ifloat ux}" by auto

  let ?lpi = "lb_pi prec"  
  have [intro!]: "Ifloat lx \<le> Ifloat ux" using x by auto
  hence "lx \<le> ux" unfolding le_float_def .

  show "Ifloat l \<le> cos x \<and> cos x \<le> Ifloat u"
  proof (cases "lx < -?lpi \<or> ux > ?lpi")
    case True
    show ?thesis using bnds unfolding bnds_cos_def if_P[OF True] Let_def using cos_le_one cos_ge_minus_one by auto
  next
    case False note not_out = this
    hence lpi_lx: "- Ifloat ?lpi \<le> Ifloat lx" and lpi_ux: "Ifloat ux \<le> Ifloat ?lpi" unfolding le_float_def less_float_def by auto

    from pi_boundaries[unfolded atLeastAtMost_iff, THEN conjunct1, THEN le_imp_neg_le] lpi_lx
    have "- pi \<le> Ifloat lx" by (rule order_trans)
    hence "- pi \<le> x" and "- pi \<le> Ifloat ux" and "x \<le> Ifloat ux" using x by auto
    
    from lpi_ux pi_boundaries[unfolded atLeastAtMost_iff, THEN conjunct1]
    have "Ifloat ux \<le> pi" by (rule order_trans)
    hence "x \<le> pi" and "Ifloat lx \<le> pi" and "Ifloat lx \<le> x" using x by auto

    note lb_cos_minus_bottom = lb_cos_minus[unfolded atLeastAtMost_iff, THEN conjunct1]
    note lb_cos_minus_top = lb_cos_minus[unfolded atLeastAtMost_iff, THEN conjunct2]
    note lb_cos_bottom = lb_cos[unfolded atLeastAtMost_iff, THEN conjunct1]
    note lb_cos_top = lb_cos[unfolded atLeastAtMost_iff, THEN conjunct2]

    show ?thesis
    proof (cases "ux \<le> 0")
      case True hence "Ifloat ux \<le> 0" unfolding le_float_def by auto
      hence "x \<le> 0" and "Ifloat lx \<le> 0" using x by auto
      
      { have "Ifloat (lb_cos prec (-lx)) \<le> cos (Ifloat (-lx))" using lb_cos_minus_bottom[OF `-pi \<le> Ifloat lx` `Ifloat lx \<le> 0`] .
	also have "\<dots> \<le> cos x" unfolding Ifloat_minus cos_minus using cos_monotone_minus_pi_0'[OF `- pi \<le> Ifloat lx` `Ifloat lx \<le> x` `x \<le> 0`] .
	finally have "Ifloat (lb_cos prec (-lx)) \<le> cos x" . }
      moreover
      { have "cos x \<le> cos (Ifloat (-ux))" unfolding Ifloat_minus cos_minus using cos_monotone_minus_pi_0'[OF `- pi \<le> x` `x \<le> Ifloat ux` `Ifloat ux \<le> 0`] .
	also have "\<dots> \<le> Ifloat (ub_cos prec (-ux))" using lb_cos_minus_top[OF `-pi \<le> Ifloat ux` `Ifloat ux \<le> 0`] .
	finally have "cos x \<le> Ifloat (ub_cos prec (-ux))" . }
      ultimately show ?thesis using bnds unfolding bnds_cos_def Let_def if_not_P[OF not_out] if_P[OF True] by auto
    next
      case False note not_ux = this
      
      show ?thesis
      proof (cases "0 \<le> lx")
	case True hence "0 \<le> Ifloat lx" unfolding le_float_def by auto
	hence "0 \<le> x" and "0 \<le> Ifloat ux" using x by auto
      
	{ have "Ifloat (lb_cos prec ux) \<le> cos (Ifloat ux)" using lb_cos_bottom[OF `0 \<le> Ifloat ux` `Ifloat ux \<le> pi`] .
	  also have "\<dots> \<le> cos x" using cos_monotone_0_pi'[OF `0 \<le> x` `x \<le> Ifloat ux` `Ifloat ux \<le> pi`] .
	  finally have "Ifloat (lb_cos prec ux) \<le> cos x" . }
	moreover
	{ have "cos x \<le> cos (Ifloat lx)" using cos_monotone_0_pi'[OF `0 \<le> Ifloat lx` `Ifloat lx \<le> x` `x \<le> pi`] .
	  also have "\<dots> \<le> Ifloat (ub_cos prec lx)" using lb_cos_top[OF `0 \<le> Ifloat lx` `Ifloat lx \<le> pi`] .
	  finally have "cos x \<le> Ifloat (ub_cos prec lx)" . }
	ultimately show ?thesis using bnds unfolding bnds_cos_def Let_def if_not_P[OF not_out] if_not_P[OF not_ux] if_P[OF True] by auto
      next
	case False with not_ux
	have "Ifloat lx \<le> 0" and "0 \<le> Ifloat ux" unfolding le_float_def by auto

	have "Ifloat (min (lb_cos prec (-lx)) (lb_cos prec ux)) \<le> cos x"
	proof (cases "x \<le> 0")
	  case True
	  have "Ifloat (lb_cos prec (-lx)) \<le> cos (Ifloat (-lx))" using lb_cos_minus_bottom[OF `-pi \<le> Ifloat lx` `Ifloat lx \<le> 0`] .
	  also have "\<dots> \<le> cos x" unfolding Ifloat_minus cos_minus using cos_monotone_minus_pi_0'[OF `- pi \<le> Ifloat lx` `Ifloat lx \<le> x` `x \<le> 0`] .
	  finally show ?thesis unfolding Ifloat_min by auto
	next
	  case False hence "0 \<le> x" by auto
	  have "Ifloat (lb_cos prec ux) \<le> cos (Ifloat ux)" using lb_cos_bottom[OF `0 \<le> Ifloat ux` `Ifloat ux \<le> pi`] .
	  also have "\<dots> \<le> cos x" using cos_monotone_0_pi'[OF `0 \<le> x` `x \<le> Ifloat ux` `Ifloat ux \<le> pi`] .
	  finally show ?thesis unfolding Ifloat_min by auto
	qed
	moreover have "cos x \<le> Ifloat (Float 1 0)" by auto
	ultimately show ?thesis using bnds unfolding bnds_cos_def Let_def if_not_P[OF not_out] if_not_P[OF not_ux] if_not_P[OF False] by auto
      qed
    qed
  qed
qed

subsection "Compute the sinus in the entire domain"

function lb_sin :: "nat \<Rightarrow> float \<Rightarrow> float" and ub_sin :: "nat \<Rightarrow> float \<Rightarrow> float" where
"lb_sin prec x = (let sqr_diff = \<lambda> x. if x > 1 then 0 else 1 - x * x 
  in if x < 0           then - ub_sin prec (- x)
else if x \<le> Float 1 -1  then x * lb_sin_cos_aux prec (get_even (prec div 4 + 1)) 2 1 (x * x)
                        else the (lb_sqrt prec (sqr_diff (ub_cos prec x))))" |

"ub_sin prec x = (let sqr_diff = \<lambda> x. if x < 0 then 1 else 1 - x * x
  in if x < 0           then - lb_sin prec (- x)
else if x \<le> Float 1 -1  then x * ub_sin_cos_aux prec (get_odd (prec div 4 + 1)) 2 1 (x * x)
                        else the (ub_sqrt prec (sqr_diff (lb_cos prec x))))"
by pat_completeness auto
termination by (relation "measure (\<lambda> v. let (prec, x) = sum_case id id v in (if x < 0 then 1 else 0))", auto simp add: less_float_def)

definition bnds_sin :: "nat \<Rightarrow> float \<Rightarrow> float \<Rightarrow> float * float" where
"bnds_sin prec lx ux = (let 
    lpi = lb_pi prec ;
    half_pi = lpi * Float 1 -1
  in if lx \<le> - half_pi \<or> half_pi \<le> ux then (Float -1 0, Float 1 0)
                                       else (lb_sin prec lx, ub_sin prec ux))"

lemma lb_sin: assumes "- (pi / 2) \<le> Ifloat x" and "Ifloat x \<le> pi / 2"
  shows "sin (Ifloat x) \<in> { Ifloat (lb_sin prec x) .. Ifloat (ub_sin prec x) }" (is "?sin x \<in> { ?lb x .. ?ub x}")
proof -
  { fix x :: float assume "0 \<le> Ifloat x" and "Ifloat x \<le> pi / 2"
    hence "\<not> (x < 0)" and "- (pi / 2) \<le> Ifloat x" unfolding less_float_def using pi_ge_two by auto

    have "Ifloat x \<le> pi" using `Ifloat x \<le> pi / 2` using pi_ge_two by auto

    have "?sin x \<in> { ?lb x .. ?ub x}"
    proof (cases "x \<le> Float 1 -1")
      case True from sin_boundaries[OF `0 \<le> Ifloat x` `Ifloat x \<le> pi / 2`]
      show ?thesis unfolding lb_sin.simps[of prec x] ub_sin.simps[of prec x] if_not_P[OF `\<not> (x < 0)`] if_P[OF True] Let_def .
    next
      case False
      have "0 \<le> cos (Ifloat x)" using cos_ge_zero[OF _ `Ifloat x \<le> pi /2`] `0 \<le> Ifloat x` pi_ge_two by auto
      have "0 \<le> sin (Ifloat x)" using `0 \<le> Ifloat x` and `Ifloat x \<le> pi / 2` using sin_ge_zero by auto
      
      have "?sin x \<le> ?ub x"
      proof (cases "lb_cos prec x < 0")
	case True
	have "?sin x \<le> 1" using sin_le_one .
	also have "\<dots> \<le> Ifloat (the (ub_sqrt prec 1))" using ub_sqrt_lower_bound[where prec=prec and x=1] unfolding Ifloat_1 by auto
	finally show ?thesis unfolding ub_sin.simps if_not_P[OF `\<not> (x < 0)`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_P[OF True] Let_def .
      next
	case False hence "0 \<le> Ifloat (lb_cos prec x)" unfolding less_float_def by auto
	
	have "sin (Ifloat x) = sqrt (1 - cos (Ifloat x) ^ 2)" unfolding sin_squared_eq[symmetric] real_sqrt_abs using `0 \<le> sin (Ifloat x)` by auto
	also have "\<dots> \<le> sqrt (Ifloat (1 - lb_cos prec x * lb_cos prec x))" 
	proof (rule real_sqrt_le_mono)
	  have "Ifloat (lb_cos prec x * lb_cos prec x) \<le> cos (Ifloat x) ^ 2" unfolding numeral_2_eq_2 power_Suc2 power_0 Ifloat_mult
	    using `0 \<le> Ifloat (lb_cos prec x)` lb_cos[OF `0 \<le> Ifloat x` `Ifloat x \<le> pi`] `0 \<le> cos (Ifloat x)` by(auto intro!: mult_mono)
	  thus "1 - cos (Ifloat x) ^ 2 \<le> Ifloat (1 - lb_cos prec x * lb_cos prec x)" unfolding Ifloat_sub Ifloat_1 by auto
	qed
	also have "\<dots> \<le> Ifloat (the (ub_sqrt prec (1 - lb_cos prec x * lb_cos prec x)))"
	proof (rule ub_sqrt_lower_bound)
	  have "Ifloat (lb_cos prec x) \<le> cos (Ifloat x)" using lb_cos[OF `0 \<le> Ifloat x` `Ifloat x \<le> pi`] by auto
	  from mult_mono[OF order_trans[OF this cos_le_one] order_trans[OF this cos_le_one]]
	  have "Ifloat (lb_cos prec x) * Ifloat (lb_cos prec x) \<le> 1" using `0 \<le> Ifloat (lb_cos prec x)` by auto
	  thus "0 \<le> Ifloat (1 - lb_cos prec x * lb_cos prec x)" by auto
	qed
	finally show ?thesis unfolding ub_sin.simps if_not_P[OF `\<not> (x < 0)`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_not_P[OF False] Let_def .
      qed
      moreover
      have "?lb x \<le> ?sin x"
      proof (cases "1 < ub_cos prec x")
	case True
	show ?thesis unfolding lb_sin.simps if_not_P[OF `\<not> (x < 0)`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_P[OF True] Let_def 
	  by (rule order_trans[OF _ sin_ge_zero[OF `0 \<le> Ifloat x` `Ifloat x \<le> pi`]]) 
        (auto simp add: lb_sqrt_upper_bound[where prec=prec and x=0, unfolded Ifloat_0 real_sqrt_zero])
      next
	case False hence "Ifloat (ub_cos prec x) \<le> 1" unfolding less_float_def by auto
	have "0 \<le> Ifloat (ub_cos prec x)" using order_trans[OF `0 \<le> cos (Ifloat x)`] lb_cos `0 \<le> Ifloat x` `Ifloat x \<le> pi` by auto
	
	have "Ifloat (the (lb_sqrt prec (1 - ub_cos prec x * ub_cos prec x))) \<le> sqrt (Ifloat (1 - ub_cos prec x * ub_cos prec x))"
	proof (rule lb_sqrt_upper_bound)
	  from mult_mono[OF `Ifloat (ub_cos prec x) \<le> 1` `Ifloat (ub_cos prec x) \<le> 1`] `0 \<le> Ifloat (ub_cos prec x)`
	  have "Ifloat (ub_cos prec x) * Ifloat (ub_cos prec x) \<le> 1" by auto
	  thus "0 \<le> Ifloat (1 - ub_cos prec x * ub_cos prec x)" by auto
	qed
	also have "\<dots> \<le> sqrt (1 - cos (Ifloat x) ^ 2)"
	proof (rule real_sqrt_le_mono)
	  have "cos (Ifloat x) ^ 2 \<le> Ifloat (ub_cos prec x * ub_cos prec x)" unfolding numeral_2_eq_2 power_Suc2 power_0 Ifloat_mult
	    using `0 \<le> Ifloat (ub_cos prec x)` lb_cos[OF `0 \<le> Ifloat x` `Ifloat x \<le> pi`] `0 \<le> cos (Ifloat x)` by(auto intro!: mult_mono)
	  thus "Ifloat (1 - ub_cos prec x * ub_cos prec x) \<le> 1 - cos (Ifloat x) ^ 2" unfolding Ifloat_sub Ifloat_1 by auto
	qed
	also have "\<dots> = sin (Ifloat x)" unfolding sin_squared_eq[symmetric] real_sqrt_abs using `0 \<le> sin (Ifloat x)` by auto
	finally show ?thesis unfolding lb_sin.simps if_not_P[OF `\<not> (x < 0)`] if_not_P[OF `\<not> x \<le> Float 1 -1`] if_not_P[OF False] Let_def .
      qed
      ultimately show ?thesis by auto
    qed
  } note for_pos = this

  show ?thesis
  proof (cases "x < 0")
    case True 
    hence "0 \<le> Ifloat (-x)" and "Ifloat (- x) \<le> pi / 2" using `-(pi/2) \<le> Ifloat x` unfolding less_float_def by auto
    from for_pos[OF this]
    show ?thesis unfolding Ifloat_minus sin_minus lb_sin.simps[of prec x] ub_sin.simps[of prec x] if_P[OF True] Let_def atLeastAtMost_iff by auto
  next
    case False hence "0 \<le> Ifloat x" unfolding less_float_def by auto
    from for_pos[OF this `Ifloat x \<le> pi /2`]
    show ?thesis .
  qed
qed

lemma bnds_sin: "\<forall> x lx ux. (l, u) = bnds_sin prec lx ux \<and> x \<in> {Ifloat lx .. Ifloat ux} \<longrightarrow> Ifloat l \<le> sin x \<and> sin x \<le> Ifloat u"
proof (rule allI, rule allI, rule allI, rule impI)
  fix x lx ux
  assume "(l, u) = bnds_sin prec lx ux \<and> x \<in> {Ifloat lx .. Ifloat ux}"
  hence bnds: "(l, u) = bnds_sin prec lx ux" and x: "x \<in> {Ifloat lx .. Ifloat ux}" by auto
  show "Ifloat l \<le> sin x \<and> sin x \<le> Ifloat u"
  proof (cases "lx \<le> - (lb_pi prec * Float 1 -1) \<or> lb_pi prec * Float 1 -1 \<le> ux")
    case True show ?thesis using bnds unfolding bnds_sin_def if_P[OF True] Let_def by auto
  next
    case False
    hence "- lb_pi prec * Float 1 -1 \<le> lx" and "ux \<le> lb_pi prec * Float 1 -1" unfolding le_float_def by auto
    moreover have "Ifloat (lb_pi prec * Float 1 -1) \<le> pi / 2" unfolding Ifloat_mult using pi_boundaries by auto
    ultimately have "- (pi / 2) \<le> Ifloat lx" and "Ifloat ux \<le> pi / 2" and "Ifloat lx \<le> Ifloat ux" unfolding le_float_def using x by auto
    hence "- (pi / 2) \<le> Ifloat ux" and "Ifloat lx \<le> pi / 2" by auto
    
    have "- (pi / 2) \<le> x""x \<le> pi / 2" using `Ifloat ux \<le> pi / 2` `- (pi /2) \<le> Ifloat lx` x by auto
    
    { have "Ifloat (lb_sin prec lx) \<le> sin (Ifloat lx)" using lb_sin[OF `- (pi / 2) \<le> Ifloat lx` `Ifloat lx \<le> pi / 2`] unfolding atLeastAtMost_iff by auto
      also have "\<dots> \<le> sin x" using sin_monotone_2pi' `- (pi / 2) \<le> Ifloat lx` x `x \<le> pi / 2` by auto
      finally have "Ifloat (lb_sin prec lx) \<le> sin x" . }
    moreover
    { have "sin x \<le> sin (Ifloat ux)" using sin_monotone_2pi' `- (pi / 2) \<le> x` x `Ifloat ux \<le> pi / 2` by auto
      also have "\<dots> \<le> Ifloat (ub_sin prec ux)" using lb_sin[OF `- (pi / 2) \<le> Ifloat ux` `Ifloat ux \<le> pi / 2`] unfolding atLeastAtMost_iff by auto
      finally have "sin x \<le> Ifloat (ub_sin prec ux)" . }
    ultimately
    show ?thesis using bnds unfolding bnds_sin_def if_not_P[OF False] Let_def by auto
  qed
qed

section "Exponential function"

subsection "Compute the series of the exponential function"

fun ub_exp_horner :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> float \<Rightarrow> float" and lb_exp_horner :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> float \<Rightarrow> float" where
"ub_exp_horner prec 0 i k x       = 0" |
"ub_exp_horner prec (Suc n) i k x = rapprox_rat prec 1 (int k) + x * lb_exp_horner prec n (i + 1) (k * i) x" |
"lb_exp_horner prec 0 i k x       = 0" |
"lb_exp_horner prec (Suc n) i k x = lapprox_rat prec 1 (int k) + x * ub_exp_horner prec n (i + 1) (k * i) x"

lemma bnds_exp_horner: assumes "Ifloat x \<le> 0"
  shows "exp (Ifloat x) \<in> { Ifloat (lb_exp_horner prec (get_even n) 1 1 x) .. Ifloat (ub_exp_horner prec (get_odd n) 1 1 x) }"
proof -
  { fix n
    have F: "\<And> m. ((\<lambda>i. i + 1) ^ n) m = n + m" by (induct n, auto)
    have "fact (Suc n) = fact n * ((\<lambda>i. i + 1) ^ n) 1" unfolding F by auto } note f_eq = this
    
  note bounds = horner_bounds_nonpos[where f="fact" and lb="lb_exp_horner prec" and ub="ub_exp_horner prec" and j'=0 and s=1,
    OF assms f_eq lb_exp_horner.simps ub_exp_horner.simps]

  { have "Ifloat (lb_exp_horner prec (get_even n) 1 1 x) \<le> (\<Sum>j = 0..<get_even n. 1 / real (fact j) * Ifloat x ^ j)"
      using bounds(1) by auto
    also have "\<dots> \<le> exp (Ifloat x)"
    proof -
      obtain t where "\<bar>t\<bar> \<le> \<bar>Ifloat x\<bar>" and "exp (Ifloat x) = (\<Sum>m = 0..<get_even n. (Ifloat x) ^ m / real (fact m)) + exp t / real (fact (get_even n)) * (Ifloat x) ^ (get_even n)"
	using Maclaurin_exp_le by blast
      moreover have "0 \<le> exp t / real (fact (get_even n)) * (Ifloat x) ^ (get_even n)"
	by (auto intro!: mult_nonneg_nonneg divide_nonneg_pos simp add: get_even zero_le_even_power exp_gt_zero)
      ultimately show ?thesis
	using get_odd exp_gt_zero by (auto intro!: pordered_cancel_semiring_class.mult_nonneg_nonneg)
    qed
    finally have "Ifloat (lb_exp_horner prec (get_even n) 1 1 x) \<le> exp (Ifloat x)" .
  } moreover
  { 
    have x_less_zero: "Ifloat x ^ get_odd n \<le> 0"
    proof (cases "Ifloat x = 0")
      case True
      have "(get_odd n) \<noteq> 0" using get_odd[THEN odd_pos] by auto
      thus ?thesis unfolding True power_0_left by auto
    next
      case False hence "Ifloat x < 0" using `Ifloat x \<le> 0` by auto
      show ?thesis by (rule less_imp_le, auto simp add: power_less_zero_eq get_odd `Ifloat x < 0`)
    qed

    obtain t where "\<bar>t\<bar> \<le> \<bar>Ifloat x\<bar>" and "exp (Ifloat x) = (\<Sum>m = 0..<get_odd n. (Ifloat x) ^ m / real (fact m)) + exp t / real (fact (get_odd n)) * (Ifloat x) ^ (get_odd n)"
      using Maclaurin_exp_le by blast
    moreover have "exp t / real (fact (get_odd n)) * (Ifloat x) ^ (get_odd n) \<le> 0"
      by (auto intro!: mult_nonneg_nonpos divide_nonpos_pos simp add: x_less_zero exp_gt_zero)
    ultimately have "exp (Ifloat x) \<le> (\<Sum>j = 0..<get_odd n. 1 / real (fact j) * Ifloat x ^ j)"
      using get_odd exp_gt_zero by (auto intro!: pordered_cancel_semiring_class.mult_nonneg_nonneg)
    also have "\<dots> \<le> Ifloat (ub_exp_horner prec (get_odd n) 1 1 x)"
      using bounds(2) by auto
    finally have "exp (Ifloat x) \<le> Ifloat (ub_exp_horner prec (get_odd n) 1 1 x)" .
  } ultimately show ?thesis by auto
qed

subsection "Compute the exponential function on the entire domain"

function ub_exp :: "nat \<Rightarrow> float \<Rightarrow> float" and lb_exp :: "nat \<Rightarrow> float \<Rightarrow> float" where
"lb_exp prec x = (if 0 < x then float_divl prec 1 (ub_exp prec (-x))
             else let 
                horner = (\<lambda> x. let  y = lb_exp_horner prec (get_even (prec + 2)) 1 1 x  in if y \<le> 0 then Float 1 -2 else y)
             in if x < - 1 then (case floor_fl x of (Float m e) \<Rightarrow> (horner (float_divl prec x (- Float m e))) ^ (nat (-m) * 2 ^ nat e))
                           else horner x)" |
"ub_exp prec x = (if 0 < x    then float_divr prec 1 (lb_exp prec (-x))
             else if x < - 1  then (case floor_fl x of (Float m e) \<Rightarrow> 
                                    (ub_exp_horner prec (get_odd (prec + 2)) 1 1 (float_divr prec x (- Float m e))) ^ (nat (-m) * 2 ^ nat e))
                              else ub_exp_horner prec (get_odd (prec + 2)) 1 1 x)"
by pat_completeness auto
termination by (relation "measure (\<lambda> v. let (prec, x) = sum_case id id v in (if 0 < x then 1 else 0))", auto simp add: less_float_def)

lemma exp_m1_ge_quarter: "(1 / 4 :: real) \<le> exp (- 1)"
proof -
  have eq4: "4 = Suc (Suc (Suc (Suc 0)))" by auto

  have "1 / 4 = Ifloat (Float 1 -2)" unfolding Float_num by auto
  also have "\<dots> \<le> Ifloat (lb_exp_horner 1 (get_even 4) 1 1 (- 1))"
    unfolding get_even_def eq4 
    by (auto simp add: lapprox_posrat_def rapprox_posrat_def normfloat.simps)
  also have "\<dots> \<le> exp (Ifloat (- 1))" using bnds_exp_horner[where x="- 1"] by auto
  finally show ?thesis unfolding Ifloat_minus Ifloat_1 . 
qed

lemma lb_exp_pos: assumes "\<not> 0 < x" shows "0 < lb_exp prec x"
proof -
  let "?lb_horner x" = "lb_exp_horner prec (get_even (prec + 2)) 1 1 x"
  let "?horner x" = "let  y = ?lb_horner x  in if y \<le> 0 then Float 1 -2 else y"
  have pos_horner: "\<And> x. 0 < ?horner x" unfolding Let_def by (cases "?lb_horner x \<le> 0", auto simp add: le_float_def less_float_def)
  moreover { fix x :: float fix num :: nat
    have "0 < Ifloat (?horner x) ^ num" using `0 < ?horner x`[unfolded less_float_def Ifloat_0] by (rule zero_less_power)
    also have "\<dots> = Ifloat ((?horner x) ^ num)" using float_power by auto
    finally have "0 < Ifloat ((?horner x) ^ num)" .
  }
  ultimately show ?thesis
    unfolding lb_exp.simps if_not_P[OF `\<not> 0 < x`] Let_def by (cases "floor_fl x", cases "x < - 1", auto simp add: le_float_def less_float_def normfloat) 
qed

lemma exp_boundaries': assumes "x \<le> 0"
  shows "exp (Ifloat x) \<in> { Ifloat (lb_exp prec x) .. Ifloat (ub_exp prec x)}"
proof -
  let "?lb_exp_horner x" = "lb_exp_horner prec (get_even (prec + 2)) 1 1 x"
  let "?ub_exp_horner x" = "ub_exp_horner prec (get_odd (prec + 2)) 1 1 x"

  have "Ifloat x \<le> 0" and "\<not> x > 0" using `x \<le> 0` unfolding le_float_def less_float_def by auto
  show ?thesis
  proof (cases "x < - 1")
    case False hence "- 1 \<le> Ifloat x" unfolding less_float_def by auto
    show ?thesis
    proof (cases "?lb_exp_horner x \<le> 0")
      from `\<not> x < - 1` have "- 1 \<le> Ifloat x" unfolding less_float_def by auto
      hence "exp (- 1) \<le> exp (Ifloat x)" unfolding exp_le_cancel_iff .
      from order_trans[OF exp_m1_ge_quarter this]
      have "Ifloat (Float 1 -2) \<le> exp (Ifloat x)" unfolding Float_num .
      moreover case True
      ultimately show ?thesis using bnds_exp_horner `Ifloat x \<le> 0` `\<not> x > 0` `\<not> x < - 1` by auto
    next
      case False thus ?thesis using bnds_exp_horner `Ifloat x \<le> 0` `\<not> x > 0` `\<not> x < - 1` by (auto simp add: Let_def)
    qed
  next
    case True
    
    obtain m e where Float_floor: "floor_fl x = Float m e" by (cases "floor_fl x", auto)
    let ?num = "nat (- m) * 2 ^ nat e"
    
    have "Ifloat (floor_fl x) < - 1" using floor_fl `x < - 1` unfolding le_float_def less_float_def Ifloat_minus Ifloat_1 by (rule order_le_less_trans)
    hence "Ifloat (floor_fl x) < 0" unfolding Float_floor Ifloat.simps using zero_less_pow2[of xe] by auto
    hence "m < 0"
      unfolding less_float_def Ifloat_0 Float_floor Ifloat.simps
      unfolding pos_prod_lt[OF zero_less_pow2[of e], unfolded real_mult_commute] by auto
    hence "1 \<le> - m" by auto
    hence "0 < nat (- m)" by auto
    moreover
    have "0 \<le> e" using floor_pos_exp Float_floor[symmetric] by auto
    hence "(0::nat) < 2 ^ nat e" by auto
    ultimately have "0 < ?num"  by auto
    hence "real ?num \<noteq> 0" by auto
    have e_nat: "int (nat e) = e" using `0 \<le> e` by auto
    have num_eq: "real ?num = Ifloat (- floor_fl x)" using `0 < nat (- m)`
      unfolding Float_floor Ifloat_minus Ifloat.simps real_of_nat_mult pow2_int[of "nat e", unfolded e_nat] realpow_real_of_nat[symmetric] by auto
    have "0 < - floor_fl x" using `0 < ?num`[unfolded real_of_nat_less_iff[symmetric]] unfolding less_float_def num_eq[symmetric] Ifloat_0 real_of_nat_zero .
    hence "Ifloat (floor_fl x) < 0" unfolding less_float_def by auto
    
    have "exp (Ifloat x) \<le> Ifloat (ub_exp prec x)"
    proof -
      have div_less_zero: "Ifloat (float_divr prec x (- floor_fl x)) \<le> 0" 
	using float_divr_nonpos_pos_upper_bound[OF `x \<le> 0` `0 < - floor_fl x`] unfolding le_float_def Ifloat_0 .
      
      have "exp (Ifloat x) = exp (real ?num * (Ifloat x / real ?num))" using `real ?num \<noteq> 0` by auto
      also have "\<dots> = exp (Ifloat x / real ?num) ^ ?num" unfolding exp_real_of_nat_mult ..
      also have "\<dots> \<le> exp (Ifloat (float_divr prec x (- floor_fl x))) ^ ?num" unfolding num_eq
	by (rule power_mono, rule exp_le_cancel_iff[THEN iffD2], rule float_divr) auto
      also have "\<dots> \<le> Ifloat ((?ub_exp_horner (float_divr prec x (- floor_fl x))) ^ ?num)" unfolding float_power
	by (rule power_mono, rule bnds_exp_horner[OF div_less_zero, unfolded atLeastAtMost_iff, THEN conjunct2], auto)
      finally show ?thesis unfolding ub_exp.simps if_not_P[OF `\<not> 0 < x`] if_P[OF `x < - 1`] float.cases Float_floor Let_def .
    qed
    moreover 
    have "Ifloat (lb_exp prec x) \<le> exp (Ifloat x)"
    proof -
      let ?divl = "float_divl prec x (- Float m e)"
      let ?horner = "?lb_exp_horner ?divl"
      
      show ?thesis
      proof (cases "?horner \<le> 0")
	case False hence "0 \<le> Ifloat ?horner" unfolding le_float_def by auto
	
	have div_less_zero: "Ifloat (float_divl prec x (- floor_fl x)) \<le> 0"
	  using `Ifloat (floor_fl x) < 0` `Ifloat x \<le> 0` by (auto intro!: order_trans[OF float_divl] divide_nonpos_neg)
	
	have "Ifloat ((?lb_exp_horner (float_divl prec x (- floor_fl x))) ^ ?num) \<le>  
          exp (Ifloat (float_divl prec x (- floor_fl x))) ^ ?num" unfolding float_power 
	  using `0 \<le> Ifloat ?horner`[unfolded Float_floor[symmetric]] bnds_exp_horner[OF div_less_zero, unfolded atLeastAtMost_iff, THEN conjunct1] by (auto intro!: power_mono)
	also have "\<dots> \<le> exp (Ifloat x / real ?num) ^ ?num" unfolding num_eq
	  using float_divl by (auto intro!: power_mono simp del: Ifloat_minus)
	also have "\<dots> = exp (real ?num * (Ifloat x / real ?num))" unfolding exp_real_of_nat_mult ..
	also have "\<dots> = exp (Ifloat x)" using `real ?num \<noteq> 0` by auto
	finally show ?thesis
	  unfolding lb_exp.simps if_not_P[OF `\<not> 0 < x`] if_P[OF `x < - 1`] float.cases Float_floor Let_def if_not_P[OF False] by auto
      next
	case True
	have "Ifloat (floor_fl x) \<noteq> 0" and "Ifloat (floor_fl x) \<le> 0" using `Ifloat (floor_fl x) < 0` by auto
	from divide_right_mono_neg[OF floor_fl[of x] `Ifloat (floor_fl x) \<le> 0`, unfolded divide_self[OF `Ifloat (floor_fl x) \<noteq> 0`]]
	have "- 1 \<le> Ifloat x / Ifloat (- floor_fl x)" unfolding Ifloat_minus by auto
	from order_trans[OF exp_m1_ge_quarter this[unfolded exp_le_cancel_iff[where x="- 1", symmetric]]]
	have "Ifloat (Float 1 -2) \<le> exp (Ifloat x / Ifloat (- floor_fl x))" unfolding Float_num .
	hence "Ifloat (Float 1 -2) ^ ?num \<le> exp (Ifloat x / Ifloat (- floor_fl x)) ^ ?num"
	  by (auto intro!: power_mono simp add: Float_num)
	also have "\<dots> = exp (Ifloat x)" unfolding num_eq exp_real_of_nat_mult[symmetric] using `Ifloat (floor_fl x) \<noteq> 0` by auto
	finally show ?thesis
	  unfolding lb_exp.simps if_not_P[OF `\<not> 0 < x`] if_P[OF `x < - 1`] float.cases Float_floor Let_def if_P[OF True] float_power .
      qed
    qed
    ultimately show ?thesis by auto
  qed
qed

lemma exp_boundaries: "exp (Ifloat x) \<in> { Ifloat (lb_exp prec x) .. Ifloat (ub_exp prec x)}"
proof -
  show ?thesis
  proof (cases "0 < x")
    case False hence "x \<le> 0" unfolding less_float_def le_float_def by auto 
    from exp_boundaries'[OF this] show ?thesis .
  next
    case True hence "-x \<le> 0" unfolding less_float_def le_float_def by auto
    
    have "Ifloat (lb_exp prec x) \<le> exp (Ifloat x)"
    proof -
      from exp_boundaries'[OF `-x \<le> 0`]
      have ub_exp: "exp (- Ifloat x) \<le> Ifloat (ub_exp prec (-x))" unfolding atLeastAtMost_iff Ifloat_minus by auto
      
      have "Ifloat (float_divl prec 1 (ub_exp prec (-x))) \<le> Ifloat 1 / Ifloat (ub_exp prec (-x))" using float_divl .
      also have "Ifloat 1 / Ifloat (ub_exp prec (-x)) \<le> exp (Ifloat x)"
	using ub_exp[unfolded inverse_le_iff_le[OF order_less_le_trans[OF exp_gt_zero ub_exp] exp_gt_zero, symmetric]]
	unfolding exp_minus nonzero_inverse_inverse_eq[OF exp_not_eq_zero] inverse_eq_divide by auto
      finally show ?thesis unfolding lb_exp.simps if_P[OF True] .
    qed
    moreover
    have "exp (Ifloat x) \<le> Ifloat (ub_exp prec x)"
    proof -
      have "\<not> 0 < -x" using `0 < x` unfolding less_float_def by auto
      
      from exp_boundaries'[OF `-x \<le> 0`]
      have lb_exp: "Ifloat (lb_exp prec (-x)) \<le> exp (- Ifloat x)" unfolding atLeastAtMost_iff Ifloat_minus by auto
      
      have "exp (Ifloat x) \<le> Ifloat 1 / Ifloat (lb_exp prec (-x))"
	using lb_exp[unfolded inverse_le_iff_le[OF exp_gt_zero lb_exp_pos[OF `\<not> 0 < -x`, unfolded less_float_def Ifloat_0], symmetric]]
	unfolding exp_minus nonzero_inverse_inverse_eq[OF exp_not_eq_zero] inverse_eq_divide Ifloat_1 by auto
      also have "\<dots> \<le> Ifloat (float_divr prec 1 (lb_exp prec (-x)))" using float_divr .
      finally show ?thesis unfolding ub_exp.simps if_P[OF True] .
    qed
    ultimately show ?thesis by auto
  qed
qed

lemma bnds_exp: "\<forall> x lx ux. (l, u) = (lb_exp prec lx, ub_exp prec ux) \<and> x \<in> {Ifloat lx .. Ifloat ux} \<longrightarrow> Ifloat l \<le> exp x \<and> exp x \<le> Ifloat u"
proof (rule allI, rule allI, rule allI, rule impI)
  fix x lx ux
  assume "(l, u) = (lb_exp prec lx, ub_exp prec ux) \<and> x \<in> {Ifloat lx .. Ifloat ux}"
  hence l: "lb_exp prec lx = l " and u: "ub_exp prec ux = u" and x: "x \<in> {Ifloat lx .. Ifloat ux}" by auto

  { from exp_boundaries[of lx prec, unfolded l]
    have "Ifloat l \<le> exp (Ifloat lx)" by (auto simp del: lb_exp.simps)
    also have "\<dots> \<le> exp x" using x by auto
    finally have "Ifloat l \<le> exp x" .
  } moreover
  { have "exp x \<le> exp (Ifloat ux)" using x by auto
    also have "\<dots> \<le> Ifloat u" using exp_boundaries[of ux prec, unfolded u] by (auto simp del: ub_exp.simps)
    finally have "exp x \<le> Ifloat u" .
  } ultimately show "Ifloat l \<le> exp x \<and> exp x \<le> Ifloat u" ..
qed

section "Logarithm"

subsection "Compute the logarithm series"

fun ub_ln_horner :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> float \<Rightarrow> float" 
and lb_ln_horner :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> float \<Rightarrow> float" where
"ub_ln_horner prec 0 i x       = 0" |
"ub_ln_horner prec (Suc n) i x = rapprox_rat prec 1 (int i) - x * lb_ln_horner prec n (Suc i) x" |
"lb_ln_horner prec 0 i x       = 0" |
"lb_ln_horner prec (Suc n) i x = lapprox_rat prec 1 (int i) - x * ub_ln_horner prec n (Suc i) x"

lemma ln_bounds:
  assumes "0 \<le> x" and "x < 1"
  shows "(\<Sum>i=0..<2*n. -1^i * (1 / real (i + 1)) * x^(Suc i)) \<le> ln (x + 1)" (is "?lb")
  and "ln (x + 1) \<le> (\<Sum>i=0..<2*n + 1. -1^i * (1 / real (i + 1)) * x^(Suc i))" (is "?ub")
proof -
  let "?a n" = "(1/real (n +1)) * x^(Suc n)"

  have ln_eq: "(\<Sum> i. -1^i * ?a i) = ln (x + 1)"
    using ln_series[of "x + 1"] `0 \<le> x` `x < 1` by auto

  have "norm x < 1" using assms by auto
  have "?a ----> 0" unfolding Suc_plus1[symmetric] inverse_eq_divide[symmetric] 
    using LIMSEQ_mult[OF LIMSEQ_inverse_real_of_nat LIMSEQ_Suc[OF LIMSEQ_power_zero[OF `norm x < 1`]]] by auto
  { fix n have "0 \<le> ?a n" by (rule mult_nonneg_nonneg, auto intro!: mult_nonneg_nonneg simp add: `0 \<le> x`) }
  { fix n have "?a (Suc n) \<le> ?a n" unfolding inverse_eq_divide[symmetric]
    proof (rule mult_mono)
      show "0 \<le> x ^ Suc (Suc n)" by (auto intro!: mult_nonneg_nonneg simp add: `0 \<le> x`)
      have "x ^ Suc (Suc n) \<le> x ^ Suc n * 1" unfolding power_Suc2 real_mult_assoc[symmetric] 
	by (rule mult_left_mono, fact less_imp_le[OF `x < 1`], auto intro!: mult_nonneg_nonneg simp add: `0 \<le> x`)
      thus "x ^ Suc (Suc n) \<le> x ^ Suc n" by auto
    qed auto }
  from summable_Leibniz'(2,4)[OF `?a ----> 0` `\<And>n. 0 \<le> ?a n`, OF `\<And>n. ?a (Suc n) \<le> ?a n`, unfolded ln_eq]
  show "?lb" and "?ub" by auto
qed

lemma ln_float_bounds: 
  assumes "0 \<le> Ifloat x" and "Ifloat x < 1"
  shows "Ifloat (x * lb_ln_horner prec (get_even n) 1 x) \<le> ln (Ifloat x + 1)" (is "?lb \<le> ?ln")
  and "ln (Ifloat x + 1) \<le> Ifloat (x * ub_ln_horner prec (get_odd n) 1 x)" (is "?ln \<le> ?ub")
proof -
  obtain ev where ev: "get_even n = 2 * ev" using get_even_double ..
  obtain od where od: "get_odd n = 2 * od + 1" using get_odd_double ..

  let "?s n" = "-1^n * (1 / real (1 + n)) * (Ifloat x)^(Suc n)"

  have "?lb \<le> setsum ?s {0 ..< 2 * ev}" unfolding power_Suc2 real_mult_assoc[symmetric] Ifloat_mult setsum_left_distrib[symmetric] unfolding real_mult_commute[of "Ifloat x"] ev
    using horner_bounds(1)[where G="\<lambda> i k. Suc k" and F="\<lambda>x. x" and f="\<lambda>x. x" and lb="\<lambda>n i k x. lb_ln_horner prec n k x" and ub="\<lambda>n i k x. ub_ln_horner prec n k x" and j'=1 and n="2*ev",
      OF `0 \<le> Ifloat x` refl lb_ln_horner.simps ub_ln_horner.simps] `0 \<le> Ifloat x`
    by (rule mult_right_mono)
  also have "\<dots> \<le> ?ln" using ln_bounds(1)[OF `0 \<le> Ifloat x` `Ifloat x < 1`] by auto
  finally show "?lb \<le> ?ln" . 

  have "?ln \<le> setsum ?s {0 ..< 2 * od + 1}" using ln_bounds(2)[OF `0 \<le> Ifloat x` `Ifloat x < 1`] by auto
  also have "\<dots> \<le> ?ub" unfolding power_Suc2 real_mult_assoc[symmetric] Ifloat_mult setsum_left_distrib[symmetric] unfolding real_mult_commute[of "Ifloat x"] od
    using horner_bounds(2)[where G="\<lambda> i k. Suc k" and F="\<lambda>x. x" and f="\<lambda>x. x" and lb="\<lambda>n i k x. lb_ln_horner prec n k x" and ub="\<lambda>n i k x. ub_ln_horner prec n k x" and j'=1 and n="2*od+1",
      OF `0 \<le> Ifloat x` refl lb_ln_horner.simps ub_ln_horner.simps] `0 \<le> Ifloat x`
    by (rule mult_right_mono)
  finally show "?ln \<le> ?ub" . 
qed

lemma ln_add: assumes "0 < x" and "0 < y" shows "ln (x + y) = ln x + ln (1 + y / x)"
proof -
  have "x \<noteq> 0" using assms by auto
  have "x + y = x * (1 + y / x)" unfolding right_distrib times_divide_eq_right nonzero_mult_divide_cancel_left[OF `x \<noteq> 0`] by auto
  moreover 
  have "0 < y / x" using assms divide_pos_pos by auto
  hence "0 < 1 + y / x" by auto
  ultimately show ?thesis using ln_mult assms by auto
qed

subsection "Compute the logarithm of 2"

definition ub_ln2 where "ub_ln2 prec = (let third = rapprox_rat (max prec 1) 1 3 
                                        in (Float 1 -1 * ub_ln_horner prec (get_odd prec) 1 (Float 1 -1)) + 
                                           (third * ub_ln_horner prec (get_odd prec) 1 third))"
definition lb_ln2 where "lb_ln2 prec = (let third = lapprox_rat prec 1 3 
                                        in (Float 1 -1 * lb_ln_horner prec (get_even prec) 1 (Float 1 -1)) + 
                                           (third * lb_ln_horner prec (get_even prec) 1 third))"

lemma ub_ln2: "ln 2 \<le> Ifloat (ub_ln2 prec)" (is "?ub_ln2")
  and lb_ln2: "Ifloat (lb_ln2 prec) \<le> ln 2" (is "?lb_ln2")
proof -
  let ?uthird = "rapprox_rat (max prec 1) 1 3"
  let ?lthird = "lapprox_rat prec 1 3"

  have ln2_sum: "ln 2 = ln (1/2 + 1) + ln (1 / 3 + 1)"
    using ln_add[of "3 / 2" "1 / 2"] by auto
  have lb3: "Ifloat ?lthird \<le> 1 / 3" using lapprox_rat[of prec 1 3] by auto
  hence lb3_ub: "Ifloat ?lthird < 1" by auto
  have lb3_lb: "0 \<le> Ifloat ?lthird" using lapprox_rat_bottom[of 1 3] by auto
  have ub3: "1 / 3 \<le> Ifloat ?uthird" using rapprox_rat[of 1 3] by auto
  hence ub3_lb: "0 \<le> Ifloat ?uthird" by auto

  have lb2: "0 \<le> Ifloat (Float 1 -1)" and ub2: "Ifloat (Float 1 -1) < 1" unfolding Float_num by auto

  have "0 \<le> (1::int)" and "0 < (3::int)" by auto
  have ub3_ub: "Ifloat ?uthird < 1" unfolding rapprox_rat.simps(2)[OF `0 \<le> 1` `0 < 3`]
    by (rule rapprox_posrat_less1, auto)

  have third_gt0: "(0 :: real) < 1 / 3 + 1" by auto
  have uthird_gt0: "0 < Ifloat ?uthird + 1" using ub3_lb by auto
  have lthird_gt0: "0 < Ifloat ?lthird + 1" using lb3_lb by auto

  show ?ub_ln2 unfolding ub_ln2_def Let_def Ifloat_add ln2_sum Float_num(4)[symmetric]
  proof (rule add_mono, fact ln_float_bounds(2)[OF lb2 ub2])
    have "ln (1 / 3 + 1) \<le> ln (Ifloat ?uthird + 1)" unfolding ln_le_cancel_iff[OF third_gt0 uthird_gt0] using ub3 by auto
    also have "\<dots> \<le> Ifloat (?uthird * ub_ln_horner prec (get_odd prec) 1 ?uthird)"
      using ln_float_bounds(2)[OF ub3_lb ub3_ub] .
    finally show "ln (1 / 3 + 1) \<le> Ifloat (?uthird * ub_ln_horner prec (get_odd prec) 1 ?uthird)" .
  qed
  show ?lb_ln2 unfolding lb_ln2_def Let_def Ifloat_add ln2_sum Float_num(4)[symmetric]
  proof (rule add_mono, fact ln_float_bounds(1)[OF lb2 ub2])
    have "Ifloat (?lthird * lb_ln_horner prec (get_even prec) 1 ?lthird) \<le> ln (Ifloat ?lthird + 1)"
      using ln_float_bounds(1)[OF lb3_lb lb3_ub] .
    also have "\<dots> \<le> ln (1 / 3 + 1)" unfolding ln_le_cancel_iff[OF lthird_gt0 third_gt0] using lb3 by auto
    finally show "Ifloat (?lthird * lb_ln_horner prec (get_even prec) 1 ?lthird) \<le> ln (1 / 3 + 1)" .
  qed
qed

subsection "Compute the logarithm in the entire domain"

function ub_ln :: "nat \<Rightarrow> float \<Rightarrow> float option" and lb_ln :: "nat \<Rightarrow> float \<Rightarrow> float option" where
"ub_ln prec x = (if x \<le> 0         then None
            else if x < 1         then Some (- the (lb_ln prec (float_divl (max prec 1) 1 x)))
            else let horner = \<lambda>x. (x - 1) * ub_ln_horner prec (get_odd prec) 1 (x - 1) in
                 if x < Float 1 1 then Some (horner x)
                                  else let l = bitlen (mantissa x) - 1 in 
                                       Some (ub_ln2 prec * (Float (scale x + l) 0) + horner (Float (mantissa x) (- l))))" |
"lb_ln prec x = (if x \<le> 0         then None
            else if x < 1         then Some (- the (ub_ln prec (float_divr prec 1 x)))
            else let horner = \<lambda>x. (x - 1) * lb_ln_horner prec (get_even prec) 1 (x - 1) in
                 if x < Float 1 1 then Some (horner x)
                                  else let l = bitlen (mantissa x) - 1 in 
                                       Some (lb_ln2 prec * (Float (scale x + l) 0) + horner (Float (mantissa x) (- l))))"
by pat_completeness auto

termination proof (relation "measure (\<lambda> v. let (prec, x) = sum_case id id v in (if x < 1 then 1 else 0))", auto)
  fix prec x assume "\<not> x \<le> 0" and "x < 1" and "float_divl (max prec (Suc 0)) 1 x < 1"
  hence "0 < x" and "0 < max prec (Suc 0)" unfolding less_float_def le_float_def by auto
  from float_divl_pos_less1_bound[OF `0 < x` `x < 1` `0 < max prec (Suc 0)`]
  show False using `float_divl (max prec (Suc 0)) 1 x < 1` unfolding less_float_def le_float_def by auto
next
  fix prec x assume "\<not> x \<le> 0" and "x < 1" and "float_divr prec 1 x < 1"
  hence "0 < x" unfolding less_float_def le_float_def by auto
  from float_divr_pos_less1_lower_bound[OF `0 < x` `x < 1`, of prec]
  show False using `float_divr prec 1 x < 1` unfolding less_float_def le_float_def by auto
qed

lemma ln_shifted_float: assumes "0 < m" shows "ln (Ifloat (Float m e)) = ln 2 * real (e + (bitlen m - 1)) + ln (Ifloat (Float m (- (bitlen m - 1))))"
proof -
  let ?B = "2^nat (bitlen m - 1)"
  have "0 < real m" and "\<And>X. (0 :: real) < 2^X" and "0 < (2 :: real)" and "m \<noteq> 0" using assms by auto
  hence "0 \<le> bitlen m - 1" using bitlen_ge1[OF `m \<noteq> 0`] by auto
  show ?thesis 
  proof (cases "0 \<le> e")
    case True
    show ?thesis unfolding normalized_float[OF `m \<noteq> 0`]
      unfolding ln_div[OF `0 < real m` `0 < ?B`] real_of_int_add ln_realpow[OF `0 < 2`] 
      unfolding Ifloat_ge0_exp[OF True] ln_mult[OF `0 < real m` `0 < 2^nat e`] 
      ln_realpow[OF `0 < 2`] algebra_simps using `0 \<le> bitlen m - 1` True by auto
  next
    case False hence "0 < -e" by auto
    hence pow_gt0: "(0::real) < 2^nat (-e)" by auto
    hence inv_gt0: "(0::real) < inverse (2^nat (-e))" by auto
    show ?thesis unfolding normalized_float[OF `m \<noteq> 0`]
      unfolding ln_div[OF `0 < real m` `0 < ?B`] real_of_int_add ln_realpow[OF `0 < 2`] 
      unfolding Ifloat_nge0_exp[OF False] ln_mult[OF `0 < real m` inv_gt0] ln_inverse[OF pow_gt0]
      ln_realpow[OF `0 < 2`] algebra_simps using `0 \<le> bitlen m - 1` False by auto
  qed
qed

lemma ub_ln_lb_ln_bounds': assumes "1 \<le> x"
  shows "Ifloat (the (lb_ln prec x)) \<le> ln (Ifloat x) \<and> ln (Ifloat x) \<le> Ifloat (the (ub_ln prec x))"
  (is "?lb \<le> ?ln \<and> ?ln \<le> ?ub")
proof (cases "x < Float 1 1")
  case True hence "Ifloat (x - 1) < 1" unfolding less_float_def Float_num by auto
  have "\<not> x \<le> 0" and "\<not> x < 1" using `1 \<le> x` unfolding less_float_def le_float_def by auto
  hence "0 \<le> Ifloat (x - 1)" using `1 \<le> x` unfolding less_float_def Float_num by auto
  show ?thesis unfolding lb_ln.simps unfolding ub_ln.simps Let_def
    using ln_float_bounds[OF `0 \<le> Ifloat (x - 1)` `Ifloat (x - 1) < 1`] `\<not> x \<le> 0` `\<not> x < 1` True by auto
next
  case False
  have "\<not> x \<le> 0" and "\<not> x < 1" "0 < x" using `1 \<le> x` unfolding less_float_def le_float_def by auto
  show ?thesis
  proof (cases x)
    case (Float m e)
    let ?s = "Float (e + (bitlen m - 1)) 0"
    let ?x = "Float m (- (bitlen m - 1))"

    have "0 < m" and "m \<noteq> 0" using float_pos_m_pos `0 < x` Float by auto

    {
      have "Ifloat (lb_ln2 prec * ?s) \<le> ln 2 * real (e + (bitlen m - 1))" (is "?lb2 \<le> _")
	unfolding Ifloat_mult Ifloat_ge0_exp[OF order_refl] nat_0 power_0 mult_1_right
	using lb_ln2[of prec]
      proof (rule mult_right_mono)
	have "1 \<le> Float m e" using `1 \<le> x` Float unfolding le_float_def by auto
	from float_gt1_scale[OF this]
	show "0 \<le> real (e + (bitlen m - 1))" by auto
      qed
      moreover
      from bitlen_div[OF `0 < m`, unfolded normalized_float[OF `m \<noteq> 0`, symmetric]]
      have "0 \<le> Ifloat (?x - 1)" and "Ifloat (?x - 1) < 1" by auto
      from ln_float_bounds(1)[OF this]
      have "Ifloat ((?x - 1) * lb_ln_horner prec (get_even prec) 1 (?x - 1)) \<le> ln (Ifloat ?x)" (is "?lb_horner \<le> _") by auto
      ultimately have "?lb2 + ?lb_horner \<le> ln (Ifloat x)"
	unfolding Float ln_shifted_float[OF `0 < m`, of e] by auto
    } 
    moreover
    {
      from bitlen_div[OF `0 < m`, unfolded normalized_float[OF `m \<noteq> 0`, symmetric]]
      have "0 \<le> Ifloat (?x - 1)" and "Ifloat (?x - 1) < 1" by auto
      from ln_float_bounds(2)[OF this]
      have "ln (Ifloat ?x) \<le> Ifloat ((?x - 1) * ub_ln_horner prec (get_odd prec) 1 (?x - 1))" (is "_ \<le> ?ub_horner") by auto
      moreover
      have "ln 2 * real (e + (bitlen m - 1)) \<le> Ifloat (ub_ln2 prec * ?s)" (is "_ \<le> ?ub2")
	unfolding Ifloat_mult Ifloat_ge0_exp[OF order_refl] nat_0 power_0 mult_1_right
	using ub_ln2[of prec] 
      proof (rule mult_right_mono)
	have "1 \<le> Float m e" using `1 \<le> x` Float unfolding le_float_def by auto
	from float_gt1_scale[OF this]
	show "0 \<le> real (e + (bitlen m - 1))" by auto
      qed
      ultimately have "ln (Ifloat x) \<le> ?ub2 + ?ub_horner"
	unfolding Float ln_shifted_float[OF `0 < m`, of e] by auto
    }
    ultimately show ?thesis unfolding lb_ln.simps unfolding ub_ln.simps
      unfolding if_not_P[OF `\<not> x \<le> 0`] if_not_P[OF `\<not> x < 1`] if_not_P[OF False] Let_def
      unfolding scale.simps[of m e, unfolded Float[symmetric]] mantissa.simps[of m e, unfolded Float[symmetric]] Ifloat_add by auto
  qed
qed

lemma ub_ln_lb_ln_bounds: assumes "0 < x"
  shows "Ifloat (the (lb_ln prec x)) \<le> ln (Ifloat x) \<and> ln (Ifloat x) \<le> Ifloat (the (ub_ln prec x))"
  (is "?lb \<le> ?ln \<and> ?ln \<le> ?ub")
proof (cases "x < 1")
  case False hence "1 \<le> x" unfolding less_float_def le_float_def by auto
  show ?thesis using ub_ln_lb_ln_bounds'[OF `1 \<le> x`] .
next
  case True have "\<not> x \<le> 0" using `0 < x` unfolding less_float_def le_float_def by auto

  have "0 < Ifloat x" and "Ifloat x \<noteq> 0" using `0 < x` unfolding less_float_def by auto
  hence A: "0 < 1 / Ifloat x" by auto

  {
    let ?divl = "float_divl (max prec 1) 1 x"
    have A': "1 \<le> ?divl" using float_divl_pos_less1_bound[OF `0 < x` `x < 1`] unfolding le_float_def less_float_def by auto
    hence B: "0 < Ifloat ?divl" unfolding le_float_def by auto
    
    have "ln (Ifloat ?divl) \<le> ln (1 / Ifloat x)" unfolding ln_le_cancel_iff[OF B A] using float_divl[of _ 1 x] by auto
    hence "ln (Ifloat x) \<le> - ln (Ifloat ?divl)" unfolding nonzero_inverse_eq_divide[OF `Ifloat x \<noteq> 0`, symmetric] ln_inverse[OF `0 < Ifloat x`] by auto
    from this ub_ln_lb_ln_bounds'[OF A', THEN conjunct1, THEN le_imp_neg_le] 
    have "?ln \<le> Ifloat (- the (lb_ln prec ?divl))" unfolding Ifloat_minus by (rule order_trans)
  } moreover
  {
    let ?divr = "float_divr prec 1 x"
    have A': "1 \<le> ?divr" using float_divr_pos_less1_lower_bound[OF `0 < x` `x < 1`] unfolding le_float_def less_float_def by auto
    hence B: "0 < Ifloat ?divr" unfolding le_float_def by auto
    
    have "ln (1 / Ifloat x) \<le> ln (Ifloat ?divr)" unfolding ln_le_cancel_iff[OF A B] using float_divr[of 1 x] by auto
    hence "- ln (Ifloat ?divr) \<le> ln (Ifloat x)" unfolding nonzero_inverse_eq_divide[OF `Ifloat x \<noteq> 0`, symmetric] ln_inverse[OF `0 < Ifloat x`] by auto
    from ub_ln_lb_ln_bounds'[OF A', THEN conjunct2, THEN le_imp_neg_le] this
    have "Ifloat (- the (ub_ln prec ?divr)) \<le> ?ln" unfolding Ifloat_minus by (rule order_trans)
  }
  ultimately show ?thesis unfolding lb_ln.simps[where x=x]  ub_ln.simps[where x=x]
    unfolding if_not_P[OF `\<not> x \<le> 0`] if_P[OF True] by auto
qed

lemma lb_ln: assumes "Some y = lb_ln prec x"
  shows "Ifloat y \<le> ln (Ifloat x)" and "0 < Ifloat x"
proof -
  have "0 < x"
  proof (rule ccontr)
    assume "\<not> 0 < x" hence "x \<le> 0" unfolding le_float_def less_float_def by auto
    thus False using assms by auto
  qed
  thus "0 < Ifloat x" unfolding less_float_def by auto
  have "Ifloat (the (lb_ln prec x)) \<le> ln (Ifloat x)" using ub_ln_lb_ln_bounds[OF `0 < x`] ..
  thus "Ifloat y \<le> ln (Ifloat x)" unfolding assms[symmetric] by auto
qed

lemma ub_ln: assumes "Some y = ub_ln prec x"
  shows "ln (Ifloat x) \<le> Ifloat y" and "0 < Ifloat x"
proof -
  have "0 < x"
  proof (rule ccontr)
    assume "\<not> 0 < x" hence "x \<le> 0" unfolding le_float_def less_float_def by auto
    thus False using assms by auto
  qed
  thus "0 < Ifloat x" unfolding less_float_def by auto
  have "ln (Ifloat x) \<le> Ifloat (the (ub_ln prec x))" using ub_ln_lb_ln_bounds[OF `0 < x`] ..
  thus "ln (Ifloat x) \<le> Ifloat y" unfolding assms[symmetric] by auto
qed

lemma bnds_ln: "\<forall> x lx ux. (Some l, Some u) = (lb_ln prec lx, ub_ln prec ux) \<and> x \<in> {Ifloat lx .. Ifloat ux} \<longrightarrow> Ifloat l \<le> ln x \<and> ln x \<le> Ifloat u"
proof (rule allI, rule allI, rule allI, rule impI)
  fix x lx ux
  assume "(Some l, Some u) = (lb_ln prec lx, ub_ln prec ux) \<and> x \<in> {Ifloat lx .. Ifloat ux}"
  hence l: "Some l = lb_ln prec lx " and u: "Some u = ub_ln prec ux" and x: "x \<in> {Ifloat lx .. Ifloat ux}" by auto

  have "ln (Ifloat ux) \<le> Ifloat u" and "0 < Ifloat ux" using ub_ln u by auto
  have "Ifloat l \<le> ln (Ifloat lx)" and "0 < Ifloat lx" and "0 < x" using lb_ln[OF l] x by auto

  from ln_le_cancel_iff[OF `0 < Ifloat lx` `0 < x`] `Ifloat l \<le> ln (Ifloat lx)` 
  have "Ifloat l \<le> ln x" using x unfolding atLeastAtMost_iff by auto
  moreover
  from ln_le_cancel_iff[OF `0 < x` `0 < Ifloat ux`] `ln (Ifloat ux) \<le> Ifloat u` 
  have "ln x \<le> Ifloat u" using x unfolding atLeastAtMost_iff by auto
  ultimately show "Ifloat l \<le> ln x \<and> ln x \<le> Ifloat u" ..
qed


section "Implement floatarith"

subsection "Define syntax and semantics"

datatype floatarith
  = Add floatarith floatarith
  | Minus floatarith
  | Mult floatarith floatarith
  | Inverse floatarith
  | Sin floatarith
  | Cos floatarith
  | Arctan floatarith
  | Abs floatarith
  | Max floatarith floatarith
  | Min floatarith floatarith
  | Pi
  | Sqrt floatarith
  | Exp floatarith
  | Ln floatarith
  | Power floatarith nat
  | Atom nat
  | Num float

fun Ifloatarith :: "floatarith \<Rightarrow> real list \<Rightarrow> real"
where
"Ifloatarith (Add a b) vs   = (Ifloatarith a vs) + (Ifloatarith b vs)" |
"Ifloatarith (Minus a) vs    = - (Ifloatarith a vs)" |
"Ifloatarith (Mult a b) vs   = (Ifloatarith a vs) * (Ifloatarith b vs)" |
"Ifloatarith (Inverse a) vs  = inverse (Ifloatarith a vs)" |
"Ifloatarith (Sin a) vs      = sin (Ifloatarith a vs)" |
"Ifloatarith (Cos a) vs      = cos (Ifloatarith a vs)" |
"Ifloatarith (Arctan a) vs   = arctan (Ifloatarith a vs)" |
"Ifloatarith (Min a b) vs    = min (Ifloatarith a vs) (Ifloatarith b vs)" |
"Ifloatarith (Max a b) vs    = max (Ifloatarith a vs) (Ifloatarith b vs)" |
"Ifloatarith (Abs a) vs      = abs (Ifloatarith a vs)" |
"Ifloatarith Pi vs           = pi" |
"Ifloatarith (Sqrt a) vs     = sqrt (Ifloatarith a vs)" |
"Ifloatarith (Exp a) vs      = exp (Ifloatarith a vs)" |
"Ifloatarith (Ln a) vs       = ln (Ifloatarith a vs)" |
"Ifloatarith (Power a n) vs  = (Ifloatarith a vs)^n" |
"Ifloatarith (Num f) vs      = Ifloat f" |
"Ifloatarith (Atom n) vs     = vs ! n"

subsection "Implement approximation function"

fun lift_bin :: "(float * float) option \<Rightarrow> (float * float) option \<Rightarrow> (float \<Rightarrow> float \<Rightarrow> float \<Rightarrow> float \<Rightarrow> (float option * float option)) \<Rightarrow> (float * float) option" where
"lift_bin (Some (l1, u1)) (Some (l2, u2)) f = (case (f l1 u1 l2 u2) of (Some l, Some u) \<Rightarrow> Some (l, u)
                                                                     | t \<Rightarrow> None)" |
"lift_bin a b f = None"

fun lift_bin' :: "(float * float) option \<Rightarrow> (float * float) option \<Rightarrow> (float \<Rightarrow> float \<Rightarrow> float \<Rightarrow> float \<Rightarrow> (float * float)) \<Rightarrow> (float * float) option" where
"lift_bin' (Some (l1, u1)) (Some (l2, u2)) f = Some (f l1 u1 l2 u2)" |
"lift_bin' a b f = None"

fun lift_un :: "(float * float) option \<Rightarrow> (float \<Rightarrow> float \<Rightarrow> ((float option) * (float option))) \<Rightarrow> (float * float) option" where
"lift_un (Some (l1, u1)) f = (case (f l1 u1) of (Some l, Some u) \<Rightarrow> Some (l, u)
                                             | t \<Rightarrow> None)" |
"lift_un b f = None"

fun lift_un' :: "(float * float) option \<Rightarrow> (float \<Rightarrow> float \<Rightarrow> (float * float)) \<Rightarrow> (float * float) option" where
"lift_un' (Some (l1, u1)) f = Some (f l1 u1)" |
"lift_un' b f = None"

fun bounded_by :: "real list \<Rightarrow> (float * float) list \<Rightarrow> bool " where
bounded_by_Cons: "bounded_by (v#vs) ((l, u)#bs) = ((Ifloat l \<le> v \<and> v \<le> Ifloat u) \<and> bounded_by vs bs)" |
bounded_by_Nil: "bounded_by [] [] = True" |
"bounded_by _ _ = False"

lemma bounded_by: assumes "bounded_by vs bs" and "i < length bs"
  shows "Ifloat (fst (bs ! i)) \<le> vs ! i \<and> vs ! i \<le> Ifloat (snd (bs ! i))"
  using `bounded_by vs bs` and `i < length bs`
proof (induct arbitrary: i rule: bounded_by.induct)
  fix v :: real and vs :: "real list" and l u :: float and bs :: "(float * float) list" and i :: nat
  assume hyp: "\<And>i. \<lbrakk>bounded_by vs bs; i < length bs\<rbrakk> \<Longrightarrow> Ifloat (fst (bs ! i)) \<le> vs ! i \<and> vs ! i \<le> Ifloat (snd (bs ! i))"
  assume bounded: "bounded_by (v # vs) ((l, u) # bs)" and length: "i < length ((l, u) # bs)"
  show "Ifloat (fst (((l, u) # bs) ! i)) \<le> (v # vs) ! i \<and> (v # vs) ! i \<le> Ifloat (snd (((l, u) # bs) ! i))"
  proof (cases i)
    case 0
    show ?thesis using bounded unfolding 0 nth_Cons_0 fst_conv snd_conv bounded_by.simps ..
  next
    case (Suc i) with length have "i < length bs" by auto
    show ?thesis unfolding Suc nth_Cons_Suc bounded_by.simps
      using hyp[OF bounded[unfolded bounded_by.simps, THEN conjunct2] `i < length bs`] .
  qed
qed auto

fun approx approx' :: "nat \<Rightarrow> floatarith \<Rightarrow> (float * float) list \<Rightarrow> (float * float) option" where
"approx' prec a bs          = (case (approx prec a bs) of Some (l, u) \<Rightarrow> Some (round_down prec l, round_up prec u) | None \<Rightarrow> None)" |
"approx prec (Add a b) bs  = lift_bin' (approx' prec a bs) (approx' prec b bs) (\<lambda> l1 u1 l2 u2. (l1 + l2, u1 + u2))" | 
"approx prec (Minus a) bs   = lift_un' (approx' prec a bs) (\<lambda> l u. (-u, -l))" |
"approx prec (Mult a b) bs  = lift_bin' (approx' prec a bs) (approx' prec b bs)
                                    (\<lambda> a1 a2 b1 b2. (float_nprt a1 * float_pprt b2 + float_nprt a2 * float_nprt b2 + float_pprt a1 * float_pprt b1 + float_pprt a2 * float_nprt b1, 
                                                     float_pprt a2 * float_pprt b2 + float_pprt a1 * float_nprt b2 + float_nprt a2 * float_pprt b1 + float_nprt a1 * float_nprt b1))" |
"approx prec (Inverse a) bs = lift_un (approx' prec a bs) (\<lambda> l u. if (0 < l \<or> u < 0) then (Some (float_divl prec 1 u), Some (float_divr prec 1 l)) else (None, None))" |
"approx prec (Sin a) bs     = lift_un' (approx' prec a bs) (bnds_sin prec)" |
"approx prec (Cos a) bs     = lift_un' (approx' prec a bs) (bnds_cos prec)" |
"approx prec Pi bs          = Some (lb_pi prec, ub_pi prec)" |
"approx prec (Min a b) bs   = lift_bin' (approx' prec a bs) (approx' prec b bs) (\<lambda> l1 u1 l2 u2. (min l1 l2, min u1 u2))" |
"approx prec (Max a b) bs   = lift_bin' (approx' prec a bs) (approx' prec b bs) (\<lambda> l1 u1 l2 u2. (max l1 l2, max u1 u2))" |
"approx prec (Abs a) bs     = lift_un' (approx' prec a bs) (\<lambda>l u. (if l < 0 \<and> 0 < u then 0 else min \<bar>l\<bar> \<bar>u\<bar>, max \<bar>l\<bar> \<bar>u\<bar>))" |
"approx prec (Arctan a) bs  = lift_un' (approx' prec a bs) (\<lambda> l u. (lb_arctan prec l, ub_arctan prec u))" |
"approx prec (Sqrt a) bs    = lift_un (approx' prec a bs) (\<lambda> l u. (lb_sqrt prec l, ub_sqrt prec u))" |
"approx prec (Exp a) bs     = lift_un' (approx' prec a bs) (\<lambda> l u. (lb_exp prec l, ub_exp prec u))" |
"approx prec (Ln a) bs      = lift_un (approx' prec a bs) (\<lambda> l u. (lb_ln prec l, ub_ln prec u))" |
"approx prec (Power a n) bs = lift_un' (approx' prec a bs) (float_power_bnds n)" |
"approx prec (Num f) bs     = Some (f, f)" |
"approx prec (Atom i) bs    = (if i < length bs then Some (bs ! i) else None)"

lemma lift_bin'_ex:
  assumes lift_bin'_Some: "Some (l, u) = lift_bin' a b f"
  shows "\<exists> l1 u1 l2 u2. Some (l1, u1) = a \<and> Some (l2, u2) = b"
proof (cases a)
  case None hence "None = lift_bin' a b f" unfolding None lift_bin'.simps ..
  thus ?thesis using lift_bin'_Some by auto
next
  case (Some a')
  show ?thesis
  proof (cases b)
    case None hence "None = lift_bin' a b f" unfolding None lift_bin'.simps ..
    thus ?thesis using lift_bin'_Some by auto
  next
    case (Some b')
    obtain la ua where a': "a' = (la, ua)" by (cases a', auto)
    obtain lb ub where b': "b' = (lb, ub)" by (cases b', auto)
    thus ?thesis unfolding `a = Some a'` `b = Some b'` a' b' by auto
  qed
qed

lemma lift_bin'_f:
  assumes lift_bin'_Some: "Some (l, u) = lift_bin' (g a) (g b) f"
  and Pa: "\<And>l u. Some (l, u) = g a \<Longrightarrow> P l u a" and Pb: "\<And>l u. Some (l, u) = g b \<Longrightarrow> P l u b"
  shows "\<exists> l1 u1 l2 u2. P l1 u1 a \<and> P l2 u2 b \<and> l = fst (f l1 u1 l2 u2) \<and> u = snd (f l1 u1 l2 u2)"
proof -
  obtain l1 u1 l2 u2
    where Sa: "Some (l1, u1) = g a" and Sb: "Some (l2, u2) = g b" using lift_bin'_ex[OF assms(1)] by auto
  have lu: "(l, u) = f l1 u1 l2 u2" using lift_bin'_Some[unfolded Sa[symmetric] Sb[symmetric] lift_bin'.simps] by auto 
  have "l = fst (f l1 u1 l2 u2)" and "u = snd (f l1 u1 l2 u2)" unfolding lu[symmetric] by auto
  thus ?thesis using Pa[OF Sa] Pb[OF Sb] by auto 
qed

lemma approx_approx':
  assumes Pa: "\<And>l u. Some (l, u) = approx prec a vs \<Longrightarrow> Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u"
  and approx': "Some (l, u) = approx' prec a vs"
  shows "Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u"
proof -
  obtain l' u' where S: "Some (l', u') = approx prec a vs"
    using approx' unfolding approx'.simps by (cases "approx prec a vs", auto)
  have l': "l = round_down prec l'" and u': "u = round_up prec u'"
    using approx' unfolding approx'.simps S[symmetric] by auto
  show ?thesis unfolding l' u' 
    using order_trans[OF Pa[OF S, THEN conjunct2] round_up[of u']]
    using order_trans[OF round_down[of _ l'] Pa[OF S, THEN conjunct1]] by auto
qed

lemma lift_bin':
  assumes lift_bin'_Some: "Some (l, u) = lift_bin' (approx' prec a bs) (approx' prec b bs) f"
  and Pa: "\<And>l u. Some (l, u) = approx prec a bs \<Longrightarrow> Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u" (is "\<And>l u. _ = ?g a \<Longrightarrow> ?P l u a")
  and Pb: "\<And>l u. Some (l, u) = approx prec b bs \<Longrightarrow> Ifloat l \<le> Ifloatarith b xs \<and> Ifloatarith b xs \<le> Ifloat u"
  shows "\<exists> l1 u1 l2 u2. (Ifloat l1 \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u1) \<and> 
                        (Ifloat l2 \<le> Ifloatarith b xs \<and> Ifloatarith b xs \<le> Ifloat u2) \<and> 
                        l = fst (f l1 u1 l2 u2) \<and> u = snd (f l1 u1 l2 u2)"
proof -
  { fix l u assume "Some (l, u) = approx' prec a bs"
    with approx_approx'[of prec a bs, OF _ this] Pa
    have "Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u" by auto } note Pa = this
  { fix l u assume "Some (l, u) = approx' prec b bs"
    with approx_approx'[of prec b bs, OF _ this] Pb
    have "Ifloat l \<le> Ifloatarith b xs \<and> Ifloatarith b xs \<le> Ifloat u" by auto } note Pb = this

  from lift_bin'_f[where g="\<lambda>a. approx' prec a bs" and P = ?P, OF lift_bin'_Some, OF Pa Pb]
  show ?thesis by auto
qed

lemma lift_un'_ex:
  assumes lift_un'_Some: "Some (l, u) = lift_un' a f"
  shows "\<exists> l u. Some (l, u) = a"
proof (cases a)
  case None hence "None = lift_un' a f" unfolding None lift_un'.simps ..
  thus ?thesis using lift_un'_Some by auto
next
  case (Some a')
  obtain la ua where a': "a' = (la, ua)" by (cases a', auto)
  thus ?thesis unfolding `a = Some a'` a' by auto
qed

lemma lift_un'_f:
  assumes lift_un'_Some: "Some (l, u) = lift_un' (g a) f"
  and Pa: "\<And>l u. Some (l, u) = g a \<Longrightarrow> P l u a"
  shows "\<exists> l1 u1. P l1 u1 a \<and> l = fst (f l1 u1) \<and> u = snd (f l1 u1)"
proof -
  obtain l1 u1 where Sa: "Some (l1, u1) = g a" using lift_un'_ex[OF assms(1)] by auto
  have lu: "(l, u) = f l1 u1" using lift_un'_Some[unfolded Sa[symmetric] lift_un'.simps] by auto
  have "l = fst (f l1 u1)" and "u = snd (f l1 u1)" unfolding lu[symmetric] by auto
  thus ?thesis using Pa[OF Sa] by auto
qed

lemma lift_un':
  assumes lift_un'_Some: "Some (l, u) = lift_un' (approx' prec a bs) f"
  and Pa: "\<And>l u. Some (l, u) = approx prec a bs \<Longrightarrow> Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u" (is "\<And>l u. _ = ?g a \<Longrightarrow> ?P l u a")
  shows "\<exists> l1 u1. (Ifloat l1 \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u1) \<and> 
                        l = fst (f l1 u1) \<and> u = snd (f l1 u1)"
proof -
  { fix l u assume "Some (l, u) = approx' prec a bs"
    with approx_approx'[of prec a bs, OF _ this] Pa
    have "Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u" by auto } note Pa = this
  from lift_un'_f[where g="\<lambda>a. approx' prec a bs" and P = ?P, OF lift_un'_Some, OF Pa]
  show ?thesis by auto
qed

lemma lift_un'_bnds:
  assumes bnds: "\<forall> x lx ux. (l, u) = f lx ux \<and> x \<in> { Ifloat lx .. Ifloat ux } \<longrightarrow> Ifloat l \<le> f' x \<and> f' x \<le> Ifloat u"
  and lift_un'_Some: "Some (l, u) = lift_un' (approx' prec a bs) f"
  and Pa: "\<And>l u. Some (l, u) = approx prec a bs \<Longrightarrow> Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u"
  shows "Ifloat l \<le> f' (Ifloatarith a xs) \<and> f' (Ifloatarith a xs) \<le> Ifloat u"
proof -
  from lift_un'[OF lift_un'_Some Pa]
  obtain l1 u1 where "Ifloat l1 \<le> Ifloatarith a xs" and "Ifloatarith a xs \<le> Ifloat u1" and "l = fst (f l1 u1)" and "u = snd (f l1 u1)" by blast
  hence "(l, u) = f l1 u1" and "Ifloatarith a xs \<in> {Ifloat l1 .. Ifloat u1}" by auto
  thus ?thesis using bnds by auto
qed

lemma lift_un_ex:
  assumes lift_un_Some: "Some (l, u) = lift_un a f"
  shows "\<exists> l u. Some (l, u) = a"
proof (cases a)
  case None hence "None = lift_un a f" unfolding None lift_un.simps ..
  thus ?thesis using lift_un_Some by auto
next
  case (Some a')
  obtain la ua where a': "a' = (la, ua)" by (cases a', auto)
  thus ?thesis unfolding `a = Some a'` a' by auto
qed

lemma lift_un_f:
  assumes lift_un_Some: "Some (l, u) = lift_un (g a) f"
  and Pa: "\<And>l u. Some (l, u) = g a \<Longrightarrow> P l u a"
  shows "\<exists> l1 u1. P l1 u1 a \<and> Some l = fst (f l1 u1) \<and> Some u = snd (f l1 u1)"
proof -
  obtain l1 u1 where Sa: "Some (l1, u1) = g a" using lift_un_ex[OF assms(1)] by auto
  have "fst (f l1 u1) \<noteq> None \<and> snd (f l1 u1) \<noteq> None"
  proof (rule ccontr)
    assume "\<not> (fst (f l1 u1) \<noteq> None \<and> snd (f l1 u1) \<noteq> None)"
    hence or: "fst (f l1 u1) = None \<or> snd (f l1 u1) = None" by auto
    hence "lift_un (g a) f = None" 
    proof (cases "fst (f l1 u1) = None")
      case True
      then obtain b where b: "f l1 u1 = (None, b)" by (cases "f l1 u1", auto)
      thus ?thesis unfolding Sa[symmetric] lift_un.simps b by auto
    next
      case False hence "snd (f l1 u1) = None" using or by auto
      with False obtain b where b: "f l1 u1 = (Some b, None)" by (cases "f l1 u1", auto)
      thus ?thesis unfolding Sa[symmetric] lift_un.simps b by auto
    qed
    thus False using lift_un_Some by auto
  qed
  then obtain a' b' where f: "f l1 u1 = (Some a', Some b')" by (cases "f l1 u1", auto)
  from lift_un_Some[unfolded Sa[symmetric] lift_un.simps f]
  have "Some l = fst (f l1 u1)" and "Some u = snd (f l1 u1)" unfolding f by auto
  thus ?thesis unfolding Sa[symmetric] lift_un.simps using Pa[OF Sa] by auto
qed

lemma lift_un:
  assumes lift_un_Some: "Some (l, u) = lift_un (approx' prec a bs) f"
  and Pa: "\<And>l u. Some (l, u) = approx prec a bs \<Longrightarrow> Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u" (is "\<And>l u. _ = ?g a \<Longrightarrow> ?P l u a")
  shows "\<exists> l1 u1. (Ifloat l1 \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u1) \<and> 
                  Some l = fst (f l1 u1) \<and> Some u = snd (f l1 u1)"
proof -
  { fix l u assume "Some (l, u) = approx' prec a bs"
    with approx_approx'[of prec a bs, OF _ this] Pa
    have "Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u" by auto } note Pa = this
  from lift_un_f[where g="\<lambda>a. approx' prec a bs" and P = ?P, OF lift_un_Some, OF Pa]
  show ?thesis by auto
qed

lemma lift_un_bnds:
  assumes bnds: "\<forall> x lx ux. (Some l, Some u) = f lx ux \<and> x \<in> { Ifloat lx .. Ifloat ux } \<longrightarrow> Ifloat l \<le> f' x \<and> f' x \<le> Ifloat u"
  and lift_un_Some: "Some (l, u) = lift_un (approx' prec a bs) f"
  and Pa: "\<And>l u. Some (l, u) = approx prec a bs \<Longrightarrow> Ifloat l \<le> Ifloatarith a xs \<and> Ifloatarith a xs \<le> Ifloat u"
  shows "Ifloat l \<le> f' (Ifloatarith a xs) \<and> f' (Ifloatarith a xs) \<le> Ifloat u"
proof -
  from lift_un[OF lift_un_Some Pa]
  obtain l1 u1 where "Ifloat l1 \<le> Ifloatarith a xs" and "Ifloatarith a xs \<le> Ifloat u1" and "Some l = fst (f l1 u1)" and "Some u = snd (f l1 u1)" by blast
  hence "(Some l, Some u) = f l1 u1" and "Ifloatarith a xs \<in> {Ifloat l1 .. Ifloat u1}" by auto
  thus ?thesis using bnds by auto
qed

lemma approx:
  assumes "bounded_by xs vs"
  and "Some (l, u) = approx prec arith vs" (is "_ = ?g arith")
  shows "Ifloat l \<le> Ifloatarith arith xs \<and> Ifloatarith arith xs \<le> Ifloat u" (is "?P l u arith")
  using `Some (l, u) = approx prec arith vs` 
proof (induct arith arbitrary: l u x)
  case (Add a b)
  from lift_bin'[OF Add.prems[unfolded approx.simps]] Add.hyps
  obtain l1 u1 l2 u2 where "l = l1 + l2" and "u = u1 + u2"
    "Ifloat l1 \<le> Ifloatarith a xs" and "Ifloatarith a xs \<le> Ifloat u1"
    "Ifloat l2 \<le> Ifloatarith b xs" and "Ifloatarith b xs \<le> Ifloat u2" unfolding fst_conv snd_conv by blast
  thus ?case unfolding Ifloatarith.simps by auto
next
  case (Minus a)
  from lift_un'[OF Minus.prems[unfolded approx.simps]] Minus.hyps
  obtain l1 u1 where "l = -u1" and "u = -l1"
    "Ifloat l1 \<le> Ifloatarith a xs" and "Ifloatarith a xs \<le> Ifloat u1" unfolding fst_conv snd_conv by blast
  thus ?case unfolding Ifloatarith.simps using Ifloat_minus by auto
next
  case (Mult a b)
  from lift_bin'[OF Mult.prems[unfolded approx.simps]] Mult.hyps
  obtain l1 u1 l2 u2 
    where l: "l = float_nprt l1 * float_pprt u2 + float_nprt u1 * float_nprt u2 + float_pprt l1 * float_pprt l2 + float_pprt u1 * float_nprt l2"
    and u: "u = float_pprt u1 * float_pprt u2 + float_pprt l1 * float_nprt u2 + float_nprt u1 * float_pprt l2 + float_nprt l1 * float_nprt l2"
    and "Ifloat l1 \<le> Ifloatarith a xs" and "Ifloatarith a xs \<le> Ifloat u1"
    and "Ifloat l2 \<le> Ifloatarith b xs" and "Ifloatarith b xs \<le> Ifloat u2" unfolding fst_conv snd_conv by blast
  thus ?case unfolding Ifloatarith.simps l u Ifloat_add Ifloat_mult Ifloat_nprt Ifloat_pprt 
    using mult_le_prts mult_ge_prts by auto
next
  case (Inverse a)
  from lift_un[OF Inverse.prems[unfolded approx.simps], unfolded if_distrib[of fst] if_distrib[of snd] fst_conv snd_conv] Inverse.hyps
  obtain l1 u1 where l': "Some l = (if 0 < l1 \<or> u1 < 0 then Some (float_divl prec 1 u1) else None)" 
    and u': "Some u = (if 0 < l1 \<or> u1 < 0 then Some (float_divr prec 1 l1) else None)"
    and l1: "Ifloat l1 \<le> Ifloatarith a xs" and u1: "Ifloatarith a xs \<le> Ifloat u1" by blast
  have either: "0 < l1 \<or> u1 < 0" proof (rule ccontr) assume P: "\<not> (0 < l1 \<or> u1 < 0)" show False using l' unfolding if_not_P[OF P] by auto qed
  moreover have l1_le_u1: "Ifloat l1 \<le> Ifloat u1" using l1 u1 by auto
  ultimately have "Ifloat l1 \<noteq> 0" and "Ifloat u1 \<noteq> 0" unfolding less_float_def by auto

  have inv: "inverse (Ifloat u1) \<le> inverse (Ifloatarith a xs)
           \<and> inverse (Ifloatarith a xs) \<le> inverse (Ifloat l1)"
  proof (cases "0 < l1")
    case True hence "0 < Ifloat u1" and "0 < Ifloat l1" "0 < Ifloatarith a xs" 
      unfolding less_float_def using l1_le_u1 l1 by auto
    show ?thesis
      unfolding inverse_le_iff_le[OF `0 < Ifloat u1` `0 < Ifloatarith a xs`]
	inverse_le_iff_le[OF `0 < Ifloatarith a xs` `0 < Ifloat l1`]
      using l1 u1 by auto
  next
    case False hence "u1 < 0" using either by blast
    hence "Ifloat u1 < 0" and "Ifloat l1 < 0" "Ifloatarith a xs < 0" 
      unfolding less_float_def using l1_le_u1 u1 by auto
    show ?thesis
      unfolding inverse_le_iff_le_neg[OF `Ifloat u1 < 0` `Ifloatarith a xs < 0`]
	inverse_le_iff_le_neg[OF `Ifloatarith a xs < 0` `Ifloat l1 < 0`]
      using l1 u1 by auto
  qed
    
  from l' have "l = float_divl prec 1 u1" by (cases "0 < l1 \<or> u1 < 0", auto)
  hence "Ifloat l \<le> inverse (Ifloat u1)" unfolding nonzero_inverse_eq_divide[OF `Ifloat u1 \<noteq> 0`] using float_divl[of prec 1 u1] by auto
  also have "\<dots> \<le> inverse (Ifloatarith a xs)" using inv by auto
  finally have "Ifloat l \<le> inverse (Ifloatarith a xs)" .
  moreover
  from u' have "u = float_divr prec 1 l1" by (cases "0 < l1 \<or> u1 < 0", auto)
  hence "inverse (Ifloat l1) \<le> Ifloat u" unfolding nonzero_inverse_eq_divide[OF `Ifloat l1 \<noteq> 0`] using float_divr[of 1 l1 prec] by auto
  hence "inverse (Ifloatarith a xs) \<le> Ifloat u" by (rule order_trans[OF inv[THEN conjunct2]])
  ultimately show ?case unfolding Ifloatarith.simps using l1 u1 by auto
next
  case (Abs x)
  from lift_un'[OF Abs.prems[unfolded approx.simps], unfolded fst_conv snd_conv] Abs.hyps
  obtain l1 u1 where l': "l = (if l1 < 0 \<and> 0 < u1 then 0 else min \<bar>l1\<bar> \<bar>u1\<bar>)" and u': "u = max \<bar>l1\<bar> \<bar>u1\<bar>"
    and l1: "Ifloat l1 \<le> Ifloatarith x xs" and u1: "Ifloatarith x xs \<le> Ifloat u1" by blast
  thus ?case unfolding l' u' by (cases "l1 < 0 \<and> 0 < u1", auto simp add: Ifloat_min Ifloat_max Ifloat_abs less_float_def)
next
  case (Min a b)
  from lift_bin'[OF Min.prems[unfolded approx.simps], unfolded fst_conv snd_conv] Min.hyps
  obtain l1 u1 l2 u2 where l': "l = min l1 l2" and u': "u = min u1 u2"
    and l1: "Ifloat l1 \<le> Ifloatarith a xs" and u1: "Ifloatarith a xs \<le> Ifloat u1"
    and l1: "Ifloat l2 \<le> Ifloatarith b xs" and u1: "Ifloatarith b xs \<le> Ifloat u2" by blast
  thus ?case unfolding l' u' by (auto simp add: Ifloat_min)
next
  case (Max a b)
  from lift_bin'[OF Max.prems[unfolded approx.simps], unfolded fst_conv snd_conv] Max.hyps
  obtain l1 u1 l2 u2 where l': "l = max l1 l2" and u': "u = max u1 u2"
    and l1: "Ifloat l1 \<le> Ifloatarith a xs" and u1: "Ifloatarith a xs \<le> Ifloat u1"
    and l1: "Ifloat l2 \<le> Ifloatarith b xs" and u1: "Ifloatarith b xs \<le> Ifloat u2" by blast
  thus ?case unfolding l' u' by (auto simp add: Ifloat_max)
next case (Sin a) with lift_un'_bnds[OF bnds_sin] show ?case by auto
next case (Cos a) with lift_un'_bnds[OF bnds_cos] show ?case by auto
next case (Arctan a) with lift_un'_bnds[OF bnds_arctan] show ?case by auto
next case Pi with pi_boundaries show ?case by auto
next case (Sqrt a) with lift_un_bnds[OF bnds_sqrt] show ?case by auto
next case (Exp a) with lift_un'_bnds[OF bnds_exp] show ?case by auto
next case (Ln a) with lift_un_bnds[OF bnds_ln] show ?case by auto
next case (Power a n) with lift_un'_bnds[OF bnds_power] show ?case by auto
next case (Num f) thus ?case by auto
next
  case (Atom n) 
  show ?case
  proof (cases "n < length vs")
    case True
    with Atom have "vs ! n = (l, u)" by auto
    thus ?thesis using bounded_by[OF assms(1) True] by auto
  next
    case False thus ?thesis using Atom by auto
  qed
qed

datatype ApproxEq = Less floatarith floatarith 
                  | LessEqual floatarith floatarith 

fun uneq :: "ApproxEq \<Rightarrow> real list \<Rightarrow> bool" where 
"uneq (Less a b) vs                   = (Ifloatarith a vs < Ifloatarith b vs)" |
"uneq (LessEqual a b) vs              = (Ifloatarith a vs \<le> Ifloatarith b vs)"

fun uneq' :: "nat \<Rightarrow> ApproxEq \<Rightarrow> (float * float) list \<Rightarrow> bool" where 
"uneq' prec (Less a b) bs = (case (approx prec a bs, approx prec b bs) of (Some (l, u), Some (l', u')) \<Rightarrow> u < l' | _ \<Rightarrow> False)" |
"uneq' prec (LessEqual a b) bs = (case (approx prec a bs, approx prec b bs) of (Some (l, u), Some (l', u')) \<Rightarrow> u \<le> l' | _ \<Rightarrow> False)"

lemma uneq_approx: fixes m :: nat assumes "bounded_by vs bs" and "uneq' prec eq bs"
  shows "uneq eq vs"
proof (cases eq)
  case (Less a b)
  show ?thesis
  proof (cases "\<exists> u l u' l'. approx prec a bs = Some (l, u) \<and> 
                             approx prec b bs = Some (l', u')")
    case True
    then obtain l u l' u' where a_approx: "approx prec a bs = Some (l, u)"
      and b_approx: "approx prec b bs = Some (l', u') " by auto
    with `uneq' prec eq bs` have "Ifloat u < Ifloat l'"
      unfolding Less uneq'.simps less_float_def by auto
    moreover from a_approx[symmetric] and b_approx[symmetric] and `bounded_by vs bs`
    have "Ifloatarith a vs \<le> Ifloat u" and "Ifloat l' \<le> Ifloatarith b vs"
      using approx by auto
    ultimately show ?thesis unfolding uneq.simps Less by auto
  next
    case False
    hence "approx prec a bs = None \<or> approx prec b bs = None"
      unfolding not_Some_eq[symmetric] by auto
    hence "\<not> uneq' prec eq bs" unfolding Less uneq'.simps 
      by (cases "approx prec a bs = None", auto)
    thus ?thesis using assms by auto
  qed
next
  case (LessEqual a b)
  show ?thesis
  proof (cases "\<exists> u l u' l'. approx prec a bs = Some (l, u) \<and> 
                             approx prec b bs = Some (l', u')")
    case True
    then obtain l u l' u' where a_approx: "approx prec a bs = Some (l, u)"
      and b_approx: "approx prec b bs = Some (l', u') " by auto
    with `uneq' prec eq bs` have "Ifloat u \<le> Ifloat l'"
      unfolding LessEqual uneq'.simps le_float_def by auto
    moreover from a_approx[symmetric] and b_approx[symmetric] and `bounded_by vs bs`
    have "Ifloatarith a vs \<le> Ifloat u" and "Ifloat l' \<le> Ifloatarith b vs"
      using approx by auto
    ultimately show ?thesis unfolding uneq.simps LessEqual by auto
  next
    case False
    hence "approx prec a bs = None \<or> approx prec b bs = None"
      unfolding not_Some_eq[symmetric] by auto
    hence "\<not> uneq' prec eq bs" unfolding LessEqual uneq'.simps 
      by (cases "approx prec a bs = None", auto)
    thus ?thesis using assms by auto
  qed
qed

lemma Ifloatarith_divide: "Ifloatarith (Mult a (Inverse b)) vs = (Ifloatarith a vs) / (Ifloatarith b vs)"
  unfolding real_divide_def Ifloatarith.simps ..

lemma Ifloatarith_diff: "Ifloatarith (Add a (Minus b)) vs = (Ifloatarith a vs) - (Ifloatarith b vs)"
  unfolding real_diff_def Ifloatarith.simps ..

lemma Ifloatarith_tan: "Ifloatarith (Mult (Sin a) (Inverse (Cos a))) vs = tan (Ifloatarith a vs)"
  unfolding tan_def Ifloatarith.simps real_divide_def ..

lemma Ifloatarith_powr: "Ifloatarith (Exp (Mult b (Ln a))) vs = (Ifloatarith a vs) powr (Ifloatarith b vs)"
  unfolding powr_def Ifloatarith.simps ..

lemma Ifloatarith_log: "Ifloatarith ((Mult (Ln x) (Inverse (Ln b)))) vs = log (Ifloatarith b vs) (Ifloatarith x vs)"
  unfolding log_def Ifloatarith.simps real_divide_def ..

lemma Ifloatarith_num: shows "Ifloatarith (Num (Float 0 0)) vs = 0" and "Ifloatarith (Num (Float 1 0)) vs = 1" and "Ifloatarith (Num (Float (number_of a) 0)) vs = number_of a" by auto

subsection {* Implement proof method \texttt{approximation} *}

lemma bounded_divl: assumes "Ifloat a / Ifloat b \<le> x" shows "Ifloat (float_divl p a b) \<le> x" by (rule order_trans[OF _ assms], rule float_divl)
lemma bounded_divr: assumes "x \<le> Ifloat a / Ifloat b" shows "x \<le> Ifloat (float_divr p a b)" by (rule order_trans[OF assms _], rule float_divr)
lemma bounded_num: shows "Ifloat (Float 5 1) = 10" and "Ifloat (Float 0 0) = 0" and "Ifloat (Float 1 0) = 1" and "Ifloat (Float (number_of n) 0) = (number_of n)"
                     and "0 * pow2 e = Ifloat (Float 0 e)" and "1 * pow2 e = Ifloat (Float 1 e)" and "number_of m * pow2 e = Ifloat (Float (number_of m) e)"
                     and "Ifloat (Float (number_of A) (int B)) = (number_of A) * 2^B"
                     and "Ifloat (Float 1 (int B)) = 2^B"
                     and "Ifloat (Float (number_of A) (- int B)) = (number_of A) / 2^B"
                     and "Ifloat (Float 1 (- int B)) = 1 / 2^B"
  by (auto simp add: Ifloat.simps pow2_def real_divide_def)

lemmas bounded_by_equations = bounded_by_Cons bounded_by_Nil float_power bounded_divl bounded_divr bounded_num HOL.simp_thms
lemmas uneq_equations = uneq.simps Ifloatarith.simps Ifloatarith_num Ifloatarith_divide Ifloatarith_diff Ifloatarith_tan Ifloatarith_powr Ifloatarith_log

ML {*
  val uneq_equations = PureThy.get_thms @{theory} "uneq_equations";
  val bounded_by_equations = PureThy.get_thms @{theory} "bounded_by_equations";
  val bounded_by_simpset = (HOL_basic_ss addsimps bounded_by_equations)

  fun reify_uneq ctxt i = (fn st =>
    let
      val to = HOLogic.dest_Trueprop (Logic.strip_imp_concl (List.nth (prems_of st, i - 1)))
    in (Reflection.genreify_tac ctxt uneq_equations (SOME to) i) st
    end)

  fun rule_uneq ctxt prec i thm = let
    fun conv_num typ = HOLogic.dest_number #> snd #> HOLogic.mk_number typ
    val to_natc = conv_num @{typ "nat"} #> Thm.cterm_of (ProofContext.theory_of ctxt)
    val to_nat = conv_num @{typ "nat"}
    val to_int = conv_num @{typ "int"}
    fun int_to_float A = @{term "Float"} $ to_int A $ @{term "0 :: int"}

    val prec' = to_nat prec

    fun bot_float (Const (@{const_name "times"}, _) $ mantisse $ (Const (@{const_name "pow2"}, _) $ exp))
                   = @{term "Float"} $ to_int mantisse $ to_int exp
      | bot_float (Const (@{const_name "divide"}, _) $ mantisse $ (@{term "power 2 :: nat \<Rightarrow> real"} $ exp))
                   = @{term "Float"} $ to_int mantisse $ (@{term "uminus :: int \<Rightarrow> int"} $ (@{term "int :: nat \<Rightarrow> int"} $ to_nat exp))
      | bot_float (Const (@{const_name "times"}, _) $ mantisse $ (@{term "power 2 :: nat \<Rightarrow> real"} $ exp))
                   = @{term "Float"} $ to_int mantisse $ (@{term "int :: nat \<Rightarrow> int"} $ to_nat exp)
      | bot_float (Const (@{const_name "divide"}, _) $ A $ (@{term "power 10 :: nat \<Rightarrow> real"} $ exp))
                   = @{term "float_divl"} $ prec' $ (int_to_float A) $ (@{term "power (Float 5 1)"} $ to_nat exp)
      | bot_float (Const (@{const_name "divide"}, _) $ A $ B)
                   = @{term "float_divl"} $ prec' $ int_to_float A $ int_to_float B
      | bot_float (@{term "power 2 :: nat \<Rightarrow> real"} $ exp)
                   = @{term "Float 1"} $ (@{term "int :: nat \<Rightarrow> int"} $ to_nat exp)
      | bot_float A = int_to_float A

    fun top_float (Const (@{const_name "times"}, _) $ mantisse $ (Const (@{const_name "pow2"}, _) $ exp))
                   = @{term "Float"} $ to_int mantisse $ to_int exp
      | top_float (Const (@{const_name "divide"}, _) $ mantisse $ (@{term "power 2 :: nat \<Rightarrow> real"} $ exp))
                   = @{term "Float"} $ to_int mantisse $ (@{term "uminus :: int \<Rightarrow> int"} $ (@{term "int :: nat \<Rightarrow> int"} $ to_nat exp))
      | top_float (Const (@{const_name "times"}, _) $ mantisse $ (@{term "power 2 :: nat \<Rightarrow> real"} $ exp))
                   = @{term "Float"} $ to_int mantisse $ (@{term "int :: nat \<Rightarrow> int"} $ to_nat exp)
      | top_float (Const (@{const_name "divide"}, _) $ A $ (@{term "power 10 :: nat \<Rightarrow> real"} $ exp))
                   = @{term "float_divr"} $ prec' $ (int_to_float A) $ (@{term "power (Float 5 1)"} $ to_nat exp)
      | top_float (Const (@{const_name "divide"}, _) $ A $ B)
                   = @{term "float_divr"} $ prec' $ int_to_float A $ int_to_float B
      | top_float (@{term "power 2 :: nat \<Rightarrow> real"} $ exp)
                   = @{term "Float 1"} $ (@{term "int :: nat \<Rightarrow> int"} $ to_nat exp)
      | top_float A = int_to_float A

    val goal' : term = List.nth (prems_of thm, i - 1)

    fun lift_bnd (t as (Const (@{const_name "op &"}, _) $ 
                        (Const (@{const_name "less_eq"}, _) $ 
                         bottom $ (Free (name, _))) $ 
                        (Const (@{const_name "less_eq"}, _) $ _ $ top)))
         = ((name, HOLogic.mk_prod (bot_float bottom, top_float top))
            handle TERM (txt, ts) => raise TERM ("Invalid bound number format: " ^
                                  (Syntax.string_of_term ctxt t), [t]))
      | lift_bnd t = raise TERM ("Premisse needs format '<num> <= <var> & <var> <= <num>', but found " ^
                                 (Syntax.string_of_term ctxt t), [t])
    val bound_eqs = map (HOLogic.dest_Trueprop #> lift_bnd)  (Logic.strip_imp_prems goal')

    fun lift_var (Free (varname, _)) = (case AList.lookup (op =) bound_eqs varname of
                                          SOME bound => bound
                                        | NONE => raise TERM ("No bound equations found for " ^ varname, []))
      | lift_var t = raise TERM ("Can not convert expression " ^ 
                                 (Syntax.string_of_term ctxt t), [t])

    val _ $ vs = HOLogic.dest_Trueprop (Logic.strip_imp_concl goal')

    val bs = (HOLogic.dest_list #> map lift_var #> HOLogic.mk_list @{typ "float * float"}) vs
    val map = [(@{cpat "?prec::nat"}, to_natc prec),
               (@{cpat "?bs::(float * float) list"}, Thm.cterm_of (ProofContext.theory_of ctxt) bs)]
  in rtac (Thm.instantiate ([], map) @{thm "uneq_approx"}) i thm end

  val eval_tac = CSUBGOAL (fn (ct, i) => rtac (eval_oracle ct) i)

  fun gen_eval_tac conv ctxt = CONVERSION (Conv.params_conv (~1) (K (Conv.concl_conv (~1) conv)) ctxt)
                               THEN' rtac TrueI

*}

method_setup approximation = {*
  Args.term >>
  (fn prec => fn ctxt =>
    SIMPLE_METHOD' (fn i =>
     (DETERM (reify_uneq ctxt i)
      THEN rule_uneq ctxt prec i
      THEN Simplifier.asm_full_simp_tac bounded_by_simpset i 
      THEN (TRY (filter_prems_tac (fn t => false) i))
      THEN (gen_eval_tac eval_oracle ctxt) i)))
*} "real number approximation"
 
end

(*  Title:      HOL/Library/Bit.thy
    Author:     Brian Huffman
*)

header {* The Field of Integers mod 2 *}

theory Bit
imports Main
begin

subsection {* Bits as a datatype *}

typedef bit = "UNIV :: bool set"
  morphisms set Bit
  ..

instantiation bit :: "{zero, one}"
begin

definition zero_bit_def:
  "0 = Bit False"

definition one_bit_def:
  "1 = Bit True"

instance ..

end

rep_datatype "0::bit" "1::bit"
proof -
  fix P and x :: bit
  assume "P (0::bit)" and "P (1::bit)"
  then have "\<forall>b. P (Bit b)"
    unfolding zero_bit_def one_bit_def
    by (simp add: all_bool_eq)
  then show "P x"
    by (induct x) simp
next
  show "(0::bit) \<noteq> (1::bit)"
    unfolding zero_bit_def one_bit_def
    by (simp add: Bit_inject)
qed

lemma Bit_set_eq [simp]:
  "Bit (set b) = b"
  by (fact set_inverse)
  
lemma set_Bit_eq [simp]:
  "set (Bit P) = P"
  by (rule Bit_inverse) rule

lemma bit_eq_iff:
  "x = y \<longleftrightarrow> (set x \<longleftrightarrow> set y)"
  by (auto simp add: set_inject)

lemma Bit_inject [simp]:
  "Bit P = Bit Q \<longleftrightarrow> (P \<longleftrightarrow> Q)"
  by (auto simp add: Bit_inject)  

lemma set [iff]:
  "\<not> set 0"
  "set 1"
  by (simp_all add: zero_bit_def one_bit_def Bit_inverse)

lemma [code]:
  "set 0 \<longleftrightarrow> False"
  "set 1 \<longleftrightarrow> True"
  by simp_all

lemma set_iff:
  "set b \<longleftrightarrow> b = 1"
  by (cases b) simp_all

lemma bit_eq_iff_set:
  "b = 0 \<longleftrightarrow> \<not> set b"
  "b = 1 \<longleftrightarrow> set b"
  by (simp_all add: bit_eq_iff)

lemma Bit [simp, code]:
  "Bit False = 0"
  "Bit True = 1"
  by (simp_all add: zero_bit_def one_bit_def)

lemma bit_not_0_iff [iff]:
  "(x::bit) \<noteq> 0 \<longleftrightarrow> x = 1"
  by (simp add: bit_eq_iff)

lemma bit_not_1_iff [iff]:
  "(x::bit) \<noteq> 1 \<longleftrightarrow> x = 0"
  by (simp add: bit_eq_iff)

lemma [code]:
  "HOL.equal 0 b \<longleftrightarrow> \<not> set b"
  "HOL.equal 1 b \<longleftrightarrow> set b"
  by (simp_all add: equal set_iff)  

  
subsection {* Type @{typ bit} forms a field *}

instantiation bit :: field_inverse_zero
begin

definition plus_bit_def:
  "x + y = case_bit y (case_bit 1 0 y) x"

definition times_bit_def:
  "x * y = case_bit 0 y x"

definition uminus_bit_def [simp]:
  "- x = (x :: bit)"

definition minus_bit_def [simp]:
  "x - y = (x + y :: bit)"

definition inverse_bit_def [simp]:
  "inverse x = (x :: bit)"

definition divide_bit_def [simp]:
  "x / y = (x * y :: bit)"

lemmas field_bit_defs =
  plus_bit_def times_bit_def minus_bit_def uminus_bit_def
  divide_bit_def inverse_bit_def

instance proof
qed (unfold field_bit_defs, auto split: bit.split)

end

lemma bit_add_self: "x + x = (0 :: bit)"
  unfolding plus_bit_def by (simp split: bit.split)

lemma bit_mult_eq_1_iff [simp]: "x * y = (1 :: bit) \<longleftrightarrow> x = 1 \<and> y = 1"
  unfolding times_bit_def by (simp split: bit.split)

text {* Not sure whether the next two should be simp rules. *}

lemma bit_add_eq_0_iff: "x + y = (0 :: bit) \<longleftrightarrow> x = y"
  unfolding plus_bit_def by (simp split: bit.split)

lemma bit_add_eq_1_iff: "x + y = (1 :: bit) \<longleftrightarrow> x \<noteq> y"
  unfolding plus_bit_def by (simp split: bit.split)


subsection {* Numerals at type @{typ bit} *}

text {* All numerals reduce to either 0 or 1. *}

lemma bit_minus1 [simp]: "- 1 = (1 :: bit)"
  by (simp only: uminus_bit_def)

lemma bit_neg_numeral [simp]: "(- numeral w :: bit) = numeral w"
  by (simp only: uminus_bit_def)

lemma bit_numeral_even [simp]: "numeral (Num.Bit0 w) = (0 :: bit)"
  by (simp only: numeral_Bit0 bit_add_self)

lemma bit_numeral_odd [simp]: "numeral (Num.Bit1 w) = (1 :: bit)"
  by (simp only: numeral_Bit1 bit_add_self add_0_left)


subsection {* Conversion from @{typ bit} *}

context zero_neq_one
begin

definition of_bit :: "bit \<Rightarrow> 'a"
where
  "of_bit b = case_bit 0 1 b" 

lemma of_bit_eq [simp, code]:
  "of_bit 0 = 0"
  "of_bit 1 = 1"
  by (simp_all add: of_bit_def)

lemma of_bit_eq_iff:
  "of_bit x = of_bit y \<longleftrightarrow> x = y"
  by (cases x) (cases y, simp_all)+

end  

context semiring_1
begin

lemma of_nat_of_bit_eq:
  "of_nat (of_bit b) = of_bit b"
  by (cases b) simp_all

end

context ring_1
begin

lemma of_int_of_bit_eq:
  "of_int (of_bit b) = of_bit b"
  by (cases b) simp_all

end

hide_const (open) set

end


(*  Title       : HOL/Library/Zorn.thy
    ID          : $Id$
    Author      : Jacques D. Fleuriot, Tobias Nipkow
    Description : Zorn's Lemma (ported from Larry Paulson's Zorn.thy in ZF)
                  The well-ordering theorem
*)

header {* Zorn's Lemma *}

theory Zorn
imports ATP_Linkup Hilbert_Choice
begin

text{*
  The lemma and section numbers refer to an unpublished article
  \cite{Abrial-Laffitte}.
*}

definition
  chain     ::  "'a set set => 'a set set set" where
  "chain S  = {F. F \<subseteq> S & (\<forall>x \<in> F. \<forall>y \<in> F. x \<subseteq> y | y \<subseteq> x)}"

definition
  super     ::  "['a set set,'a set set] => 'a set set set" where
  "super S c = {d. d \<in> chain S & c \<subset> d}"

definition
  maxchain  ::  "'a set set => 'a set set set" where
  "maxchain S = {c. c \<in> chain S & super S c = {}}"

definition
  succ      ::  "['a set set,'a set set] => 'a set set" where
  "succ S c =
    (if c \<notin> chain S | c \<in> maxchain S
    then c else SOME c'. c' \<in> super S c)"

inductive_set
  TFin :: "'a set set => 'a set set set"
  for S :: "'a set set"
  where
    succI:        "x \<in> TFin S ==> succ S x \<in> TFin S"
  | Pow_UnionI:   "Y \<in> Pow(TFin S) ==> Union(Y) \<in> TFin S"
  monos          Pow_mono


subsection{*Mathematical Preamble*}

lemma Union_lemma0:
    "(\<forall>x \<in> C. x \<subseteq> A | B \<subseteq> x) ==> Union(C) \<subseteq> A | B \<subseteq> Union(C)"
  by blast


text{*This is theorem @{text increasingD2} of ZF/Zorn.thy*}

lemma Abrial_axiom1: "x \<subseteq> succ S x"
  apply (unfold succ_def)
  apply (rule split_if [THEN iffD2])
  apply (auto simp add: super_def maxchain_def psubset_def)
  apply (rule contrapos_np, assumption)
  apply (rule someI2, blast+)
  done

lemmas TFin_UnionI = TFin.Pow_UnionI [OF PowI]

lemma TFin_induct:
          "[| n \<in> TFin S;
             !!x. [| x \<in> TFin S; P(x) |] ==> P(succ S x);
             !!Y. [| Y \<subseteq> TFin S; Ball Y P |] ==> P(Union Y) |]
          ==> P(n)"
  apply (induct set: TFin)
   apply blast+
  done

lemma succ_trans: "x \<subseteq> y ==> x \<subseteq> succ S y"
  apply (erule subset_trans)
  apply (rule Abrial_axiom1)
  done

text{*Lemma 1 of section 3.1*}
lemma TFin_linear_lemma1:
     "[| n \<in> TFin S;  m \<in> TFin S;
         \<forall>x \<in> TFin S. x \<subseteq> m --> x = m | succ S x \<subseteq> m
      |] ==> n \<subseteq> m | succ S m \<subseteq> n"
  apply (erule TFin_induct)
   apply (erule_tac [2] Union_lemma0)
  apply (blast del: subsetI intro: succ_trans)
  done

text{* Lemma 2 of section 3.2 *}
lemma TFin_linear_lemma2:
     "m \<in> TFin S ==> \<forall>n \<in> TFin S. n \<subseteq> m --> n=m | succ S n \<subseteq> m"
  apply (erule TFin_induct)
   apply (rule impI [THEN ballI])
   txt{*case split using @{text TFin_linear_lemma1}*}
   apply (rule_tac n1 = n and m1 = x in TFin_linear_lemma1 [THEN disjE],
     assumption+)
    apply (drule_tac x = n in bspec, assumption)
    apply (blast del: subsetI intro: succ_trans, blast)
  txt{*second induction step*}
  apply (rule impI [THEN ballI])
  apply (rule Union_lemma0 [THEN disjE])
    apply (rule_tac [3] disjI2)
    prefer 2 apply blast
   apply (rule ballI)
   apply (rule_tac n1 = n and m1 = x in TFin_linear_lemma1 [THEN disjE],
     assumption+, auto)
  apply (blast intro!: Abrial_axiom1 [THEN subsetD])
  done

text{*Re-ordering the premises of Lemma 2*}
lemma TFin_subsetD:
     "[| n \<subseteq> m;  m \<in> TFin S;  n \<in> TFin S |] ==> n=m | succ S n \<subseteq> m"
  by (rule TFin_linear_lemma2 [rule_format])

text{*Consequences from section 3.3 -- Property 3.2, the ordering is total*}
lemma TFin_subset_linear: "[| m \<in> TFin S;  n \<in> TFin S|] ==> n \<subseteq> m | m \<subseteq> n"
  apply (rule disjE)
    apply (rule TFin_linear_lemma1 [OF _ _TFin_linear_lemma2])
      apply (assumption+, erule disjI2)
  apply (blast del: subsetI
    intro: subsetI Abrial_axiom1 [THEN subset_trans])
  done

text{*Lemma 3 of section 3.3*}
lemma eq_succ_upper: "[| n \<in> TFin S;  m \<in> TFin S;  m = succ S m |] ==> n \<subseteq> m"
  apply (erule TFin_induct)
   apply (drule TFin_subsetD)
     apply (assumption+, force, blast)
  done

text{*Property 3.3 of section 3.3*}
lemma equal_succ_Union: "m \<in> TFin S ==> (m = succ S m) = (m = Union(TFin S))"
  apply (rule iffI)
   apply (rule Union_upper [THEN equalityI])
    apply assumption
   apply (rule eq_succ_upper [THEN Union_least], assumption+)
  apply (erule ssubst)
  apply (rule Abrial_axiom1 [THEN equalityI])
  apply (blast del: subsetI intro: subsetI TFin_UnionI TFin.succI)
  done

subsection{*Hausdorff's Theorem: Every Set Contains a Maximal Chain.*}

text{*NB: We assume the partial ordering is @{text "\<subseteq>"},
 the subset relation!*}

lemma empty_set_mem_chain: "({} :: 'a set set) \<in> chain S"
  by (unfold chain_def) auto

lemma super_subset_chain: "super S c \<subseteq> chain S"
  by (unfold super_def) blast

lemma maxchain_subset_chain: "maxchain S \<subseteq> chain S"
  by (unfold maxchain_def) blast

lemma mem_super_Ex: "c \<in> chain S - maxchain S ==> EX d. d \<in> super S c"
  by (unfold super_def maxchain_def) auto

lemma select_super:
     "c \<in> chain S - maxchain S ==> (\<some>c'. c': super S c): super S c"
  apply (erule mem_super_Ex [THEN exE])
  apply (rule someI2, auto)
  done

lemma select_not_equals:
     "c \<in> chain S - maxchain S ==> (\<some>c'. c': super S c) \<noteq> c"
  apply (rule notI)
  apply (drule select_super)
  apply (simp add: super_def psubset_def)
  done

lemma succI3: "c \<in> chain S - maxchain S ==> succ S c = (\<some>c'. c': super S c)"
  by (unfold succ_def) (blast intro!: if_not_P)

lemma succ_not_equals: "c \<in> chain S - maxchain S ==> succ S c \<noteq> c"
  apply (frule succI3)
  apply (simp (no_asm_simp))
  apply (rule select_not_equals, assumption)
  done

lemma TFin_chain_lemma4: "c \<in> TFin S ==> (c :: 'a set set): chain S"
  apply (erule TFin_induct)
   apply (simp add: succ_def select_super [THEN super_subset_chain[THEN subsetD]])
  apply (unfold chain_def)
  apply (rule CollectI, safe)
   apply (drule bspec, assumption)
   apply (rule_tac [2] m1 = Xa and n1 = X in TFin_subset_linear [THEN disjE],
     blast+)
  done

theorem Hausdorff: "\<exists>c. (c :: 'a set set): maxchain S"
  apply (rule_tac x = "Union (TFin S)" in exI)
  apply (rule classical)
  apply (subgoal_tac "succ S (Union (TFin S)) = Union (TFin S) ")
   prefer 2
   apply (blast intro!: TFin_UnionI equal_succ_Union [THEN iffD2, symmetric])
  apply (cut_tac subset_refl [THEN TFin_UnionI, THEN TFin_chain_lemma4])
  apply (drule DiffI [THEN succ_not_equals], blast+)
  done


subsection{*Zorn's Lemma: If All Chains Have Upper Bounds Then
                               There Is  a Maximal Element*}

lemma chain_extend:
    "[| c \<in> chain S; z \<in> S;
        \<forall>x \<in> c. x \<subseteq> (z:: 'a set) |] ==> {z} Un c \<in> chain S"
  by (unfold chain_def) blast

lemma chain_Union_upper: "[| c \<in> chain S; x \<in> c |] ==> x \<subseteq> Union(c)"
  by (unfold chain_def) auto

lemma chain_ball_Union_upper: "c \<in> chain S ==> \<forall>x \<in> c. x \<subseteq> Union(c)"
  by (unfold chain_def) auto

lemma maxchain_Zorn:
     "[| c \<in> maxchain S; u \<in> S; Union(c) \<subseteq> u |] ==> Union(c) = u"
  apply (rule ccontr)
  apply (simp add: maxchain_def)
  apply (erule conjE)
  apply (subgoal_tac "({u} Un c) \<in> super S c")
   apply simp
  apply (unfold super_def psubset_def)
  apply (blast intro: chain_extend dest: chain_Union_upper)
  done

theorem Zorn_Lemma:
    "\<forall>c \<in> chain S. Union(c): S ==> \<exists>y \<in> S. \<forall>z \<in> S. y \<subseteq> z --> y = z"
  apply (cut_tac Hausdorff maxchain_subset_chain)
  apply (erule exE)
  apply (drule subsetD, assumption)
  apply (drule bspec, assumption)
  apply (rule_tac x = "Union(c)" in bexI)
   apply (rule ballI, rule impI)
   apply (blast dest!: maxchain_Zorn, assumption)
  done

subsection{*Alternative version of Zorn's Lemma*}

lemma Zorn_Lemma2:
  "\<forall>c \<in> chain S. \<exists>y \<in> S. \<forall>x \<in> c. x \<subseteq> y
    ==> \<exists>y \<in> S. \<forall>x \<in> S. (y :: 'a set) \<subseteq> x --> y = x"
  apply (cut_tac Hausdorff maxchain_subset_chain)
  apply (erule exE)
  apply (drule subsetD, assumption)
  apply (drule bspec, assumption, erule bexE)
  apply (rule_tac x = y in bexI)
   prefer 2 apply assumption
  apply clarify
  apply (rule ccontr)
  apply (frule_tac z = x in chain_extend)
    apply (assumption, blast)
  apply (unfold maxchain_def super_def psubset_def)
  apply (blast elim!: equalityCE)
  done

text{*Various other lemmas*}

lemma chainD: "[| c \<in> chain S; x \<in> c; y \<in> c |] ==> x \<subseteq> y | y \<subseteq> x"
  by (unfold chain_def) blast

lemma chainD2: "!!(c :: 'a set set). c \<in> chain S ==> c \<subseteq> S"
  by (unfold chain_def) blast


(* FIXME into Relation.thy *)

lemma mono_Field: "r \<subseteq> s \<Longrightarrow> Field r \<subseteq> Field s"
by(auto simp:Field_def Domain_def Range_def)

lemma Field_empty[simp]: "Field {} = {}"
by(auto simp:Field_def)

lemma Field_insert[simp]: "Field (insert (a,b) r) = {a,b} \<union> Field r"
by(auto simp:Field_def)

lemma Field_Un[simp]: "Field (r \<union> s) = Field r \<union> Field s"
by(auto simp:Field_def)

lemma Field_Union[simp]: "Field (\<Union>R) = \<Union>(Field ` R)"
by(auto simp:Field_def)

lemma Domain_converse[simp]: "Domain(r^-1) = Range r"
by blast

lemma Range_converse[simp]: "Range(r^-1) = Domain r"
by blast

lemma Field_converse[simp]: "Field(r^-1) = Field r"
by(auto simp:Field_def)

lemma reflexive_reflcl[simp]: "reflexive(r^=)"
by(simp add:refl_def)

lemma antisym_reflcl[simp]: "antisym(r^=) = antisym r"
by(simp add:antisym_def)

lemma trans_reflclI[simp]: "trans r \<Longrightarrow> trans(r^=)"
unfolding trans_def by blast

(*********************************************************)

(* Define globally? In Set.thy?
   Use in def of chain at the beginning *)
definition "subset_chain C \<equiv> \<forall>A\<in>C.\<forall>B\<in>C. A \<subseteq> B \<or> B \<subseteq> A"

(* Define globally? In Relation.thy? *)
definition Chain :: "('a*'a)set \<Rightarrow> 'a set set" where
"Chain r \<equiv> {A. \<forall>a\<in>A.\<forall>b\<in>A. (a,b) : r \<or> (b,a) \<in> r}"

lemma mono_Chain: "r \<subseteq> s \<Longrightarrow> Chain r \<subseteq> Chain s"
unfolding Chain_def by blast

(* Are the following definitions the "right" ones?

Key point: should the set appear as an explicit argument,
(as currently in "refl A r") or should it remain implicitly the Field
(as in Refl below)? I use refl/Refl merely to illusrate the point.

The notation "refl A r" is closer to the usual (A,<=) in the literature
whereas "Refl r" is shorter and avoids naming the set.
Note that "refl A r \<Longrightarrow> A = Field r & Refl r" and "Refl r \<Longrightarrow> refl (Field r) r"
This makes the A look redundant.

A slight advantage of having the A around is that one can write "a:A"
rather than "a:Field r". A disavantage is the multiple occurrences of
"refl (Field r) r" (etc) in the proof of the well-ordering thm.

I propose to move the definitions into Main, either as they are or
with an additional A argument.

Naming: The capital letters were chosen to distinguish them from
versions on the whole type we have (eg reflexive) or may want to have
(eg preorder). In case of an additional A argument one could append
"_on" to distinguish the relativized versions.
*)

definition "Refl r \<equiv> \<forall>x \<in> Field r. (x,x) \<in> r"
definition "Preorder r \<equiv> Refl r \<and> trans r"
definition "Partial_order r \<equiv> Preorder r \<and> antisym r"
definition "Total r \<equiv> \<forall>x\<in>Field r.\<forall>y\<in>Field r. x\<noteq>y \<longrightarrow> (x,y)\<in>r \<or> (y,x)\<in>r"
definition "Linear_order r \<equiv> Partial_order r \<and> Total r"
definition "Well_order r \<equiv> Linear_order r \<and> wf(r - Id)"

lemmas Order_defs =
  Preorder_def Partial_order_def Linear_order_def Well_order_def

lemma Refl_empty[simp]: "Refl {}"
by(simp add:Refl_def)
lemma Preorder_empty[simp]: "Preorder {}"
by(simp add:Preorder_def trans_def)
lemma Partial_order_empty[simp]: "Partial_order {}"
by(simp add:Partial_order_def)
lemma Total_empty[simp]: "Total {}"
by(simp add:Total_def)
lemma Linear_order_empty[simp]: "Linear_order {}"
by(simp add:Linear_order_def)
lemma Well_order_empty[simp]: "Well_order {}"
by(simp add:Well_order_def)

lemma Refl_converse[simp]: "Refl(r^-1) = Refl r"
by(simp add:Refl_def)

lemma Preorder_converse[simp]: "Preorder (r^-1) = Preorder r"
by (simp add:Preorder_def)

lemma Partial_order_converse[simp]:
  "Partial_order (r^-1) = Partial_order r"
by (simp add: Partial_order_def)

lemma subset_Image_Image_iff:
  "\<lbrakk> Preorder r; A \<subseteq> Field r; B \<subseteq> Field r\<rbrakk> \<Longrightarrow>
   r `` A \<subseteq> r `` B \<longleftrightarrow> (\<forall>a\<in>A.\<exists>b\<in>B. (b,a):r)"
apply(auto simp add:subset_def Preorder_def Refl_def Image_def)
apply metis
by(metis trans_def)

lemma subset_Image1_Image1_iff:
  "\<lbrakk> Preorder r; a : Field r; b : Field r\<rbrakk> \<Longrightarrow> r `` {a} \<subseteq> r `` {b} \<longleftrightarrow> (b,a):r"
by(simp add:subset_Image_Image_iff)

lemma Refl_antisym_eq_Image1_Image1_iff:
  "\<lbrakk>Refl r; antisym r; a:Field r; b:Field r\<rbrakk> \<Longrightarrow> r `` {a} = r `` {b} \<longleftrightarrow> a=b"
by(simp add:Preorder_def expand_set_eq Partial_order_def antisym_def Refl_def)
  metis

lemma Partial_order_eq_Image1_Image1_iff:
  "\<lbrakk>Partial_order r; a:Field r; b:Field r\<rbrakk> \<Longrightarrow> r `` {a} = r `` {b} \<longleftrightarrow> a=b"
by(auto simp:Preorder_def Partial_order_def Refl_antisym_eq_Image1_Image1_iff)

text{* Zorn's lemma for partial orders: *}

lemma Zorns_po_lemma:
assumes po: "Partial_order r" and u: "\<forall>C\<in>Chain r. \<exists>u\<in>Field r. \<forall>a\<in>C. (a,u):r"
shows "\<exists>m\<in>Field r. \<forall>a\<in>Field r. (m,a):r \<longrightarrow> a=m"
proof-
  have "Preorder r" using po by(simp add:Partial_order_def)
--{* Mirror r in the set of subsets below (wrt r) elements of A*}
  let ?B = "%x. r^-1 `` {x}" let ?S = "?B ` Field r"
  have "\<forall>C \<in> chain ?S. EX U:?S. ALL A:C. A\<subseteq>U"
  proof (auto simp:chain_def)
    fix C assume 1: "C \<subseteq> ?S" and 2: "\<forall>A\<in>C.\<forall>B\<in>C. A\<subseteq>B | B\<subseteq>A"
    let ?A = "{x\<in>Field r. \<exists>M\<in>C. M = ?B x}"
    have "C = ?B ` ?A" using 1 by(auto simp: image_def)
    have "?A\<in>Chain r"
    proof (simp add:Chain_def, intro allI impI, elim conjE)
      fix a b
      assume "a \<in> Field r" "?B a \<in> C" "b \<in> Field r" "?B b \<in> C"
      hence "?B a \<subseteq> ?B b \<or> ?B b \<subseteq> ?B a" using 2 by auto
      thus "(a, b) \<in> r \<or> (b, a) \<in> r" using `Preorder r` `a:Field r` `b:Field r`
	by(simp add:subset_Image1_Image1_iff)
    qed
    then obtain u where uA: "u:Field r" "\<forall>a\<in>?A. (a,u) : r" using u by auto
    have "\<forall>A\<in>C. A \<subseteq> r^-1 `` {u}" (is "?P u")
    proof auto
      fix a B assume aB: "B:C" "a:B"
      with 1 obtain x where "x:Field r" "B = r^-1 `` {x}" by auto
      thus "(a,u) : r" using uA aB `Preorder r`
	by (auto simp add: Preorder_def Refl_def) (metis transD)
    qed
    thus "EX u:Field r. ?P u" using `u:Field r` by blast
  qed
  from Zorn_Lemma2[OF this]
  obtain m B where "m:Field r" "B = r^-1 `` {m}"
    "\<forall>x\<in>Field r. B \<subseteq> r^-1 `` {x} \<longrightarrow> B = r^-1 `` {x}"
    by(auto simp:image_def) blast
  hence "\<forall>a\<in>Field r. (m, a) \<in> r \<longrightarrow> a = m" using po `Preorder r` `m:Field r`
    by(auto simp:subset_Image1_Image1_iff Partial_order_eq_Image1_Image1_iff)
  thus ?thesis using `m:Field r` by blast
qed

(* The initial segment of a relation appears generally useful.
   Move to Relation.thy?
   Definition correct/most general?
   Naming?
*)
definition init_seg_of :: "(('a*'a)set * ('a*'a)set)set" where
"init_seg_of == {(r,s). r \<subseteq> s \<and> (\<forall>a b c. (a,b):s \<and> (b,c):r \<longrightarrow> (a,b):r)}"

abbreviation initialSegmentOf :: "('a*'a)set \<Rightarrow> ('a*'a)set \<Rightarrow> bool"
             (infix "initial'_segment'_of" 55) where
"r initial_segment_of s == (r,s):init_seg_of"

lemma refl_init_seg_of[simp]: "r initial_segment_of r"
by(simp add:init_seg_of_def)

lemma trans_init_seg_of:
  "r initial_segment_of s \<Longrightarrow> s initial_segment_of t \<Longrightarrow> r initial_segment_of t"
by(simp (no_asm_use) add: init_seg_of_def)
  (metis Domain_iff UnCI Un_absorb2 subset_trans)

lemma antisym_init_seg_of:
  "r initial_segment_of s \<Longrightarrow> s initial_segment_of r \<Longrightarrow> r=s"
by(auto simp:init_seg_of_def)

lemma Chain_init_seg_of_Union:
  "R \<in> Chain init_seg_of \<Longrightarrow> r\<in>R \<Longrightarrow> r initial_segment_of \<Union>R"
by(auto simp add:init_seg_of_def Chain_def Ball_def) blast

lemma subset_chain_trans_Union:
  "subset_chain R \<Longrightarrow> \<forall>r\<in>R. trans r \<Longrightarrow> trans(\<Union>R)"
apply(auto simp add:subset_chain_def)
apply(simp (no_asm_use) add:trans_def)
apply (metis subsetD)
done

lemma subset_chain_antisym_Union:
  "subset_chain R \<Longrightarrow> \<forall>r\<in>R. antisym r \<Longrightarrow> antisym(\<Union>R)"
apply(auto simp add:subset_chain_def antisym_def)
apply (metis subsetD)
done

lemma subset_chain_Total_Union:
assumes "subset_chain R" "\<forall>r\<in>R. Total r"
shows "Total (\<Union>R)"
proof (simp add: Total_def Ball_def, auto del:disjCI)
  fix r s a b assume A: "r:R" "s:R" "a:Field r" "b:Field s" "a\<noteq>b"
  from `subset_chain R` `r:R` `s:R` have "r\<subseteq>s \<or> s\<subseteq>r"
    by(simp add:subset_chain_def)
  thus "(\<exists>r\<in>R. (a,b) \<in> r) \<or> (\<exists>r\<in>R. (b,a) \<in> r)"
  proof
    assume "r\<subseteq>s" hence "(a,b):s \<or> (b,a):s" using assms(2) A
      by(simp add:Total_def)(metis mono_Field subsetD)
    thus ?thesis using `s:R` by blast
  next
    assume "s\<subseteq>r" hence "(a,b):r \<or> (b,a):r" using assms(2) A
      by(simp add:Total_def)(metis mono_Field subsetD)
    thus ?thesis using `r:R` by blast
  qed
qed

lemma wf_Union_wf_init_segs:
assumes "R \<in> Chain init_seg_of" and "\<forall>r\<in>R. wf r" shows "wf(\<Union>R)"
proof(simp add:wf_iff_no_infinite_down_chain, rule ccontr, auto)
  fix f assume 1: "\<forall>i. \<exists>r\<in>R. (f(Suc i), f i) \<in> r"
  then obtain r where "r:R" and "(f(Suc 0), f 0) : r" by auto
  { fix i have "(f(Suc i), f i) \<in> r"
    proof(induct i)
      case 0 show ?case by fact
    next
      case (Suc i)
      moreover obtain s where "s\<in>R" and "(f(Suc(Suc i)), f(Suc i)) \<in> s"
	using 1 by auto
      moreover hence "s initial_segment_of r \<or> r initial_segment_of s"
	using assms(1) `r:R` by(simp add: Chain_def)
      ultimately show ?case by(simp add:init_seg_of_def) blast
    qed
  }
  thus False using assms(2) `r:R`
    by(simp add:wf_iff_no_infinite_down_chain) blast
qed

lemma Chain_inits_DiffI:
  "R \<in> Chain init_seg_of \<Longrightarrow> {r - s |r. r \<in> R} \<in> Chain init_seg_of"
apply(auto simp:Chain_def init_seg_of_def)
apply (metis subsetD)
apply (metis subsetD)
done

theorem well_ordering: "\<exists>r::('a*'a)set. Well_order r"
proof-
-- {*The initial segment relation on well-orders: *}
  let ?WO = "{r::('a*'a)set. Well_order r}"
  def I \<equiv> "init_seg_of \<inter> ?WO \<times> ?WO"
  have I_init: "I \<subseteq> init_seg_of" by(auto simp:I_def)
  hence subch: "!!R. R : Chain I \<Longrightarrow> subset_chain R"
    by(auto simp:init_seg_of_def subset_chain_def Chain_def)
  have Chain_wo: "!!R r. R \<in> Chain I \<Longrightarrow> r \<in> R \<Longrightarrow> Well_order r"
    by(simp add:Chain_def I_def) blast
  have FI: "Field I = ?WO" by(auto simp add:I_def init_seg_of_def Field_def)
  hence 0: "Partial_order I"
    by(auto simp add: Partial_order_def Preorder_def antisym_def antisym_init_seg_of Refl_def trans_def I_def)(metis trans_init_seg_of)
-- {*I-chains have upper bounds in ?WO wrt I: their Union*}
  { fix R assume "R \<in> Chain I"
    hence Ris: "R \<in> Chain init_seg_of" using mono_Chain[OF I_init] by blast
    have subch: "subset_chain R" using `R : Chain I` I_init
      by(auto simp:init_seg_of_def subset_chain_def Chain_def)
    have "\<forall>r\<in>R. Refl r" "\<forall>r\<in>R. trans r" "\<forall>r\<in>R. antisym r" "\<forall>r\<in>R. Total r"
         "\<forall>r\<in>R. wf(r-Id)"
      using Chain_wo[OF `R \<in> Chain I`] by(simp_all add:Order_defs)
    have "Refl (\<Union>R)" using `\<forall>r\<in>R. Refl r` by(auto simp:Refl_def)
    moreover have "trans (\<Union>R)"
      by(rule subset_chain_trans_Union[OF subch `\<forall>r\<in>R. trans r`])
    moreover have "antisym(\<Union>R)"
      by(rule subset_chain_antisym_Union[OF subch `\<forall>r\<in>R. antisym r`])
    moreover have "Total (\<Union>R)"
      by(rule subset_chain_Total_Union[OF subch `\<forall>r\<in>R. Total r`])
    moreover have "wf((\<Union>R)-Id)"
    proof-
      have "(\<Union>R)-Id = \<Union>{r-Id|r. r \<in> R}" by blast
      with `\<forall>r\<in>R. wf(r-Id)` wf_Union_wf_init_segs[OF Chain_inits_DiffI[OF Ris]]
      show ?thesis by (simp (no_asm_simp)) blast
    qed
    ultimately have "Well_order (\<Union>R)" by(simp add:Order_defs)
    moreover have "\<forall>r \<in> R. r initial_segment_of \<Union>R" using Ris
      by(simp add: Chain_init_seg_of_Union)
    ultimately have "\<Union>R : ?WO \<and> (\<forall>r\<in>R. (r,\<Union>R) : I)"
      using mono_Chain[OF I_init] `R \<in> Chain I`
      by(simp (no_asm) add:I_def del:Field_Union)(metis Chain_wo subsetD)
  }
  hence 1: "\<forall>R \<in> Chain I. \<exists>u\<in>Field I. \<forall>r\<in>R. (r,u) : I" by (subst FI) blast
--{*Zorn's Lemma yields a maximal well-order m:*}
  then obtain m::"('a*'a)set" where "Well_order m" and
    max: "\<forall>r. Well_order r \<and> (m,r):I \<longrightarrow> r=m"
    using Zorns_po_lemma[OF 0 1] by (auto simp:FI)
--{*Now show by contradiction that m covers the whole type:*}
  { fix x::'a assume "x \<notin> Field m"
--{*We assume that x is not covered and extend m at the top with x*}
    have "m \<noteq> {}"
    proof
      assume "m={}"
      moreover have "Well_order {(x,x)}"
	by(simp add:Order_defs Refl_def trans_def antisym_def Total_def Field_def Domain_def Range_def)
      ultimately show False using max
	by (auto simp:I_def init_seg_of_def simp del:Field_insert)
    qed
    hence "Field m \<noteq> {}" by(auto simp:Field_def)
    moreover have "wf(m-Id)" using `Well_order m` by(simp add:Well_order_def)
--{*The extension of m by x:*}
    let ?s = "{(a,x)|a. a : Field m}" let ?m = "insert (x,x) m Un ?s"
    have Fm: "Field ?m = insert x (Field m)"
      apply(simp add:Field_insert Field_Un)
      unfolding Field_def by auto
    have "Refl m" "trans m" "antisym m" "Total m" "wf(m-Id)"
      using `Well_order m` by(simp_all add:Order_defs)
--{*We show that the extension is a well-order*}
    have "Refl ?m" using `Refl m` Fm by(auto simp:Refl_def)
    moreover have "trans ?m" using `trans m` `x \<notin> Field m`
      unfolding trans_def Field_def Domain_def Range_def by blast
    moreover have "antisym ?m" using `antisym m` `x \<notin> Field m`
      unfolding antisym_def Field_def Domain_def Range_def by blast
    moreover have "Total ?m" using `Total m` Fm by(auto simp: Total_def)
    moreover have "wf(?m-Id)"
    proof-
      have "wf ?s" using `x \<notin> Field m`
	by(auto simp add:wf_eq_minimal Field_def Domain_def Range_def) metis
      thus ?thesis using `wf(m-Id)` `x \<notin> Field m`
	wf_subset[OF `wf ?s` Diff_subset]
	by (fastsimp intro!: wf_Un simp add: Un_Diff Field_def)
    qed
    ultimately have "Well_order ?m" by(simp add:Order_defs)
--{*We show that the extension is above m*}
    moreover hence "(m,?m) : I" using `Well_order m` `x \<notin> Field m`
      by(fastsimp simp:I_def init_seg_of_def Field_def Domain_def Range_def)
    ultimately
--{*This contradicts maximality of m:*}
    have False using max `x \<notin> Field m` unfolding Field_def by blast
  }
  hence "Field m = UNIV" by auto
  with `Well_order m` have "Well_order m" by simp
  thus ?thesis ..
qed

end

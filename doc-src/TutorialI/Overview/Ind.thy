theory Ind = Main:

section{*Inductive Definitions*}


subsection{*Even Numbers*}

subsubsection{*The Definition*}

consts even :: "nat set"
inductive even
intros
zero[intro!]: "0 \<in> even"
step[intro!]: "n \<in> even \<Longrightarrow> Suc(Suc n) \<in> even"

lemma [simp,intro!]: "2 dvd n \<Longrightarrow> 2 dvd Suc(Suc n)"
apply (unfold dvd_def)
apply clarify
apply (rule_tac x = "Suc k" in exI, simp)
done

subsubsection{*Rule Induction*}

thm even.induct

lemma even_imp_dvd: "n \<in> even \<Longrightarrow> 2 dvd n"
apply (erule even.induct)
apply simp_all
done

subsubsection{*Rule Inversion*}

inductive_cases Suc_Suc_case [elim!]: "Suc(Suc n) \<in> even"
thm Suc_Suc_case

lemma "Suc(Suc n) \<in> even \<Longrightarrow> n \<in> even"
by blast


subsection{*Mutually Inductive Definitions*}

consts evn :: "nat set"
       odd :: "nat set"

inductive evn odd
intros
zero: "0 \<in> evn"
evnI: "n \<in> odd \<Longrightarrow> Suc n \<in> evn"
oddI: "n \<in> evn \<Longrightarrow> Suc n \<in> odd"

lemma "(m \<in> evn \<longrightarrow> 2 dvd m) \<and> (n \<in> odd \<longrightarrow> 2 dvd (Suc n))"
apply(rule evn_odd.induct)
by simp_all


subsection{*The Reflexive Transitive Closure*}

consts rtc :: "('a \<times> 'a)set \<Rightarrow> ('a \<times> 'a)set"   ("_*" [1000] 999)
inductive "r*"
intros
rtc_refl[iff]:  "(x,x) \<in> r*"
rtc_step:       "\<lbrakk> (x,y) \<in> r; (y,z) \<in> r* \<rbrakk> \<Longrightarrow> (x,z) \<in> r*"

lemma [intro]: "(x,y) : r \<Longrightarrow> (x,y) \<in> r*"
by(blast intro: rtc_step);

lemma rtc_trans: "\<lbrakk> (x,y) \<in> r*; (y,z) \<in> r* \<rbrakk> \<Longrightarrow> (x,z) \<in> r*"
apply(erule rtc.induct)
oops

lemma rtc_trans[rule_format]:
  "(x,y) \<in> r* \<Longrightarrow> (y,z) \<in> r* \<longrightarrow> (x,z) \<in> r*"
apply(erule rtc.induct)
 apply(blast);
apply(blast intro: rtc_step);
done

text{*
\begin{exercise}
Show that the converse of @{thm[source]rtc_step} also holds:
@{prop[display]"[| (x,y) : r*; (y,z) : r |] ==> (x,z) : r*"}
\end{exercise}
*}

subsection{*The accessible part of a relation*}

consts
  acc :: "('a \<times> 'a) set \<Rightarrow> 'a set"
inductive "acc r"
intros
  "(\<forall>y. (x,y) \<in> r \<longrightarrow> y \<in> acc r) \<Longrightarrow> x \<in> acc r"


consts
  accs :: "('a \<times> 'a) set \<Rightarrow> 'a set"
inductive "accs r"
intros
 "r``{x} \<in> Pow(accs r) \<Longrightarrow> x \<in> accs r"
monos Pow_mono

end

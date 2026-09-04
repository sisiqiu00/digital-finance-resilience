/***********************************************
Project: Digital Financial Resilience
Purpose: Estimate the main instrumental-variable specifications, including the
         baseline model and the crisis-specific interaction model.
Author: Xinchen "Sisi" Qiu
Update date: August 2026
Inputs: data/proc/combined_clean.dta
Outputs: table/baseline_regs.tex; table/crisis_regs.tex
Language/version: Stata do-file; Tested with Stata 19.5.
Run order: Step 4 of 5. Run after code/1_clean_main_data.do.
***********************************************/

/***********************************************
Main Analysis
***********************************************/

* Load data set
use "$datacall/proc/combined_clean.dta", clear

* Construct baseline (2017) instrument, held fixed across both waves
bysort country_id (year): assert year[1] == 2017
bysort country_id (year): gen iv_baseline = secure_internet_pm[1]
label variable iv_baseline "Secure servers (per 1 million people)"

/***********************************************
Results:
	- Main IV:
		- Baseline regs
		- Crisis-specific regs
***********************************************/

****** Main IV ******
eststo clear

* Standardize IV
summarize iv_baseline
gen iv_std = (iv_baseline - r(mean)) / r(sd)
label variable iv_std "Secure servers"

* Label vars for table presentation
label variable fin_penetration_index "DFP index"
label variable covid "Post-pandemic"

*** Baseline: first stage ***

* Extract first-stage F-statistic from ivreg2
ivreg2 econ_resilience_index (fin_penetration_index = iv_std) ///
	covid log_pop i.income_group, cluster(country_id) first

* Save Kleibergen-Paap Weak IV F-statistic
scalar fstat = e(widstat)

* Run first-stage regression
eststo base_1st: reg fin_penetration_index iv_std ///
	covid log_pop i.income_group, vce(cluster country_id)

* Add the F-statistic to the stored estimation
estadd scalar widstat = fstat, replace

*** Baseline: second stage ***

* Run baseline IV regression
eststo base_2nd: ivreg2 econ_resilience_index ///
	(fin_penetration_index = iv_std) ///
	covid log_pop i.income_group, cluster(country_id)

* Omit second-stage R-squared
estadd local r2 "", replace

* Baseline: weak-IV-robust (Anderson--Rubin) inference
// Tested and excluded gridmin < 0; restricted the reported AR confidence-set 
// grid to the theoretically relevant nonnegative range for interpretation
weakiv, gridmin(0) gridmax(4.9) gridpoints(2000)

* Store scalars
local ar_stat = e(ar_chi2)
local ar_p = e(ar_p)
local ar_cset = "`e(ar_cset)'"

* Reformat a bounded AR interval to 3 decimals
if regexm("`ar_cset'", "\[ *(-?[0-9.]+) *, *(-?[0-9.]+) *\]") {
    local lo = round(real(regexs(1)), 0.001)
    local hi = round(real(regexs(2)), 0.001)
    local lo : di %9.3f `lo'
    local hi : di %9.3f `hi'
    local ar_cset = "[`=strtrim("`lo'")', `=strtrim("`hi'")']"
}

* Add scalars for presentation
estadd scalar ar_stat = `ar_stat', replace : base_2nd
estadd scalar ar_p = `ar_p', replace : base_2nd
estadd local  ar_cset "`ar_cset'", : base_2nd

* Export baseline results to LaTeX
esttab base_* using "$texout/baseline_regs.tex", replace ///
    b(3) se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(iv_std fin_penetration_index covid) ///
	order(iv_std fin_penetration_index covid) ///
    nodepvars booktabs nomtitles noobs ///
	nonote unstack nonumbers ///
	nobaselevels label compress ///
	s(N r2 widstat ar_stat ar_p ar_cset, ///
	fmt(%9.0fc %9.2f %9.2f %9.2f %9.3f %s) ///
	label("Observations" "R\(^2\)" "KP F-stat" ///
	"AR \(\chi^2(1)\)" "AR \(p\)-value" "AR 95\% CI")) ///
	substitute("\midrule" "" ///
	"Observations" "\midrule Observations") ///
	prehead("") ///
	postfoot("\bottomrule")

*** Crisis-specific: first stage ***

eststo clear

* Interaction term for DFP-by-post
gen fin_covid = fin_penetration_index * covid
label variable fin_covid "DFP * Post"

* Instrument-by-post interaction
gen instr_covid = iv_std * covid
label variable instr_covid "Servers * Post"

* Run the actual joint model first: `ffirst` computes the Sanderson--Windmeijer
* conditional F-stat for each endogenous regressor (the correct per-regressor
* weak-ID diagnostic when there are 2+ endogenous variables)
ivreg2 econ_resilience_index ///
    (fin_penetration_index fin_covid = iv_std instr_covid) ///
    covid log_pop i.income_group, cluster(country_id) first ffirst
scalar fstat_joint = e(widstat) // Extract scalar

* Pull SW conditional F-stats from e(first): Column names match the endogenous
* regressors; the "SWF" row holds the conditional F
matrix swf = e(first)
scalar swf_dfp = swf["SWF","fin_penetration_index"]
scalar swf_covid = swf["SWF","fin_covid"]

* First-stage reg for DFP
eststo crisis_1st_1: reg fin_penetration_index iv_std instr_covid ///
    covid log_pop i.income_group, vce(cluster country_id)

* Store joint system F-stat and SW-stat
estadd scalar widstat = fstat_joint, replace
estadd scalar swf = swf_dfp, replace

* First-stage reg for DFP * COVID
eststo crisis_1st_2: reg fin_covid iv_std instr_covid ///
    covid log_pop i.income_group, vce(cluster country_id)

* Store same joint system F-stat and conditional SW-stat
estadd scalar widstat = fstat_joint, replace
estadd scalar swf = swf_covid, replace

*** Crisis-specific: second stage ***

* Run IV reg (already estimated above for widstat, but re-run to store as eststo)
eststo crisis_2nd: ivreg2 econ_resilience_index ///
    (fin_penetration_index fin_covid = iv_std instr_covid) ///
    covid log_pop i.income_group, cluster(country_id)
	
* Omit second-stage R-squared
estadd local r2 "", replace

* Crisis: weak-IV-robust (Anderson--Rubin) inference
weakiv, grid level(95)

* Store scalars
local ar_stat = e(ar_chi2)
local ar_p    = e(ar_p)

* Add scalars for presentation
estadd scalar ar_stat = `ar_stat', replace : crisis_2nd
estadd scalar ar_p    = `ar_p',    replace : crisis_2nd

* Export crisis-specific results to LaTeX
esttab crisis_* using "$texout/crisis_regs.tex", ///
	replace ///
    b(3) se star(* 0.10 ** 0.05 *** 0.01) ///
	keep(iv_std instr_covid fin_penetration_index covid fin_covid) ///
	order(iv_std instr_covid fin_penetration_index covid fin_covid) ///
    nodepvars booktabs nomtitles noobs ///
	nonote unstack nonumbers ///
	nobaselevels label compress ///
	s(N r2 widstat swf ar_stat ar_p, ///
	fmt(%9.0fc %9.2f %9.2f %9.2f %9.2f %9.3f) ///
	label("Observations" "R\(^2\)" "Joint KP F" "SW conditional F" ///
	"AR \(\chi^2(2)\)" "AR \(p\)-value")) ///
	substitute("\midrule" "" " * " " $\times$ " ///
	"Observations" "\midrule Observations") ///
	prehead("") ///
	postfoot("\bottomrule")
	
/***********************************************
Project: Digital Financial Resilience
Purpose: Run robustness specifications, including OLS associations between DFP
         factors and resilience outcomes, plus weak-IV diagnostics for candidate
         instruments.
Author: Xinchen "Sisi" Qiu
Update date: July 2026
Inputs: data/proc/combined_clean.dta
Outputs: table/econ_resilience_on_dfp_ols.tex; table/instrument_search.tex
Language/version: Stata do-file; Tested with Stata 19.5.
Run order: Step 5 of 5. Run after code/1_clean_main_data.do.
***********************************************/

/***********************************************
Main Analysis
***********************************************/

* Load data set
use "$datacall/proc/combined_clean.dta", clear

/***********************************************
Robustness:
	- OLS: economic resilience components on DFP factors
	- Candidates IV F-Statistics Table
***********************************************/

****** OLS: econ resilience on DFP factors ******
eststo clear

local econ_resi_vars econ_resi_consumption_pc_growth econ_resi_gdp_pc_growth ///
	econ_resi_gross_savings econ_resi_unemp_rev econ_resi_curr_acct_balance

* Run OLS for each resilience component on all DFP components (all standardized)
local i = 1
foreach var of local econ_resi_vars {
	eststo ols1_`i': reg `var' fin_pen_* ///
		log_pop covid i.income_group, ///
		vce(cluster country_id)
	local i = `i' + 1
}

* Run OLS for the resilience index on the DFP index
eststo ols2: reg econ_resilience_index fin_penetration_index ///
	log_pop covid i.income_group, vce(cluster country_id)

* Export regressions to LaTeX
esttab ols* using "$texout/econ_resilience_on_dfp_ols.tex", ///
	replace ///
    b(3) se star(* 0.10 ** 0.05 *** 0.01) ///
	drop(log_pop covid *income_group _cons) ///
	rename(fin_pen_digital_payment "Digital payments" ///
	fin_pen_use_mobl_intnt_balance "Digital account balance" ///
	fin_pen_use_mobile_wage "Mobile wages" ///
	fin_penetration_index "\textbf{DFP index}") ///
    nodepvars booktabs nomtitles noobs ///
	nonote unstack nonumbers compress ///
	nobaselevels ///
	s(N r2, fmt(%9.0fc %9.2fc) label("Observations" "R\(^2\)")) ///
	substitute("\midrule" "" ///
	"Observations" "\midrule Observations") ///
	prehead("") ///
	postfoot("\bottomrule")

****** Candidates IV F-Statistics Table ******

local weak_iv_list secure_internet_pm mobile_subs_ph broadband_subs ///
    internet_usage telephone_subs_ph

* Store KP F-statistic and pre-pandemic N
local n_iv : word count `weak_iv_list'
matrix weakF = J(`n_iv', 2, .)
matrix colnames weakF = "KP F" "N 2017"

local r = 1
foreach var of local weak_iv_list {

    capture drop `var'_b `var'_s

    * Construct baseline (2017) instrument, held fixed across both waves
    bysort country_id (year): assert year[1] == 2017
    bysort country_id (year): gen `var'_b = `var'[1]

    * Standardize IV exactly as in the working specification
    quietly summarize `var'_b
    gen `var'_s = (`var'_b - r(mean)) / r(sd)

    quietly ivreg2 econ_resilience_index ///
        (fin_penetration_index = `var'_s) ///
        log_pop covid i.income_group, ///
        cluster(country_id) first

    * Store KP weak-IV F-statistic
    matrix weakF[`r', 1] = e(widstat)

    * Store 2017 observations retained in this regression
    quietly count if e(sample) & year == 2017
    matrix weakF[`r', 2] = r(N)

    local ++r
}

* Label instrument rows
label variable secure_internet_pm_s "Secure internet servers"
label variable mobile_subs_ph_s "Mobile cellular subscriptions"
label variable broadband_subs_s "Fixed broadband subscriptions"
label variable internet_usage_s "Internet usage"
label variable telephone_subs_ph_s "Fixed telephone subscriptions"

* Apply row names
matrix rownames weakF = ///
    secure_internet_pm_s ///
    mobile_subs_ph_s ///
    broadband_subs_s ///
    internet_usage_s ///
    telephone_subs_ph_s

* Display matrix in log
matrix list weakF

* Export LaTeX table
esttab matrix(weakF, fmt(2 0)) ///
    using "$texout/instrument_search.tex", replace ///
    fragment ///
    nodepvars booktabs nomtitles noobs ///
    nonote unstack nonumbers ///
    nobaselevels label compress ///
    alignment(D{.}{.}{-1}) ///
    collabels(none) ///
    prehead("") posthead("") ///
    prefoot("") postfoot("\bottomrule")
	
/***********************************************
Project: Digital Financial Resilience
Purpose: Produce descriptive statistics, validation checks, and exploratory
         figures for the cleaned analysis dataset.
Author: Xinchen "Sisi" Qiu
Update date: August 2026
Inputs: data/proc/combined_clean.dta
Outputs: table/resilience_index_validation.tex; table/resi_var_stats.tex;
         table/dfp_var_stats.tex; table/ctrl_var_stats.tex;
         table/index_by_inc_pre.tex; table/index_by_inc_post.tex;
         graph/dfp_distribution_across_country.pdf;
         graph/resilience_distribution_across_country.pdf;
         graph/resilience_on_dfp_by_pandemic.pdf;
         graph/resilience_on_dfp_by_income.pdf
Language/version: Stata do-file; Tested with Stata 19.5.
Run order: Step 3 of 5. Run after code/1_clean_main_data.do.
***********************************************/

/***********************************************
Descriptive Statistics and Figures
***********************************************/

* Load data set
use "$datacall/proc/combined_clean.dta", clear

/***********************************************
Data and Measurement Construction:
	- Table: validate resilience index against GDP per capita
***********************************************/

* Standardize GDP per capita
summarize gdp_pc_ppp
gen gdp_pc_ppp_std = (gdp_pc_ppp - r(mean)) / r(sd)
label variable gdp_pc_ppp_std "GDP per capita"

* Run OLS estimate (raw)
eststo valid_raw: reg econ_resilience_index gdp_pc_ppp_std, ///
	vce(cluster country_id)

* Run OLS estimate (control)
eststo valid_control: reg econ_resilience_index gdp_pc_ppp_std ///
	log_pop covid i.income_group, vce(cluster country_id)

* Export results to LaTeX
esttab valid_* using "$texout/resilience_index_validation.tex", replace ///
    b(3) se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(gdp_pc_ppp_std) ///
    nodepvars booktabs nomtitles noobs ///
	nonote unstack nonumbers ///
	nobaselevels label compress ///
	s(N r2, fmt(%9.0fc %9.2fc) ///
	label("Observations" "R\(^2\)")) ///
	substitute("\midrule" "" ///
	"Observations" "\midrule Observations") ///
	prehead("") ///
	postfoot("\bottomrule")

/***********************************************
Summary Statistics:
	- Tables:
		- Key vars by pandemic period
		- Indices by income group and pandemic period
	- Graphs:
		- Histograms: DFP and resilience distributions by pandemic period
		- Binscatter: resilience on DFP by pandemic
		- Binscatter: resilience on DFP by income
***********************************************/

eststo clear

********** Tables **********

*** Key vars by pandemic period ***

* Define resilience components
local econ_resi_vars consumption_pc_growth gdp_pc_growth gross_savings ///
	unemp curr_acct_balance
	
* Summarize economic-resilience component statistics
eststo resi_stats_pre: estpost summarize `econ_resi_vars' if covid == 0, detail
eststo resi_stats_post: estpost summarize `econ_resi_vars' if covid == 1, detail

* Export to LaTeX
esttab resi_stats_* using "$texout/resi_var_stats.tex", replace ///
    cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc))") ///
		rename(consumption_pc_growth "Consumption per capita growth" ///
		gdp_pc_growth "GDP per capita growth" ///
		gross_savings "Gross savings" ///
		unemp "Unemployment rate" ///
		curr_acct_balance "Current account balance") ///
    nodepvars booktabs nomtitles noobs ///
	nonote unstack nonumbers compress ///
	nobaselevels ///
	substitute("\midrule" "" "&     mean&       sd&     mean&       sd\\" "") ///
	prehead("") ///
	postfoot("\bottomrule")

eststo clear

* Scale DFP component variables by 100 for presentation
local fin_pen_vars digital_payment use_mobl_intnt_balance use_mobile_wage
foreach var in `fin_pen_vars' {
	gen `var'_p_stats = `var' * 100
}

* Summarize DFP statistics
eststo dfp_stats_pre: estpost summarize *_p_stats if covid == 0, detail
eststo dfp_stats_post: estpost summarize *_p_stats if covid == 1, detail

* Export to LaTeX
esttab dfp_stats_* using "$texout/dfp_var_stats.tex", replace ///
    cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc))") ///
		rename(digital_payment_p_stats "Digital payments" ///
		use_mobl_intnt_balance_p_stats "Digital account balance" ///
		use_mobile_wage_p_stats "Mobile wages") ///
    nodepvars booktabs nomtitles noobs ///
	nonote unstack nonumbers compress alignment(D{.}{.}{-1}) ///
	nobaselevels ///
	substitute("\midrule" "" "&     mean&       sd&     mean&       sd\\" "") ///
	prehead("") ///
	postfoot("\bottomrule")
	
eststo clear

* Downsize population for visual clarity
gen pop_mill = pop / 1000000

* Summarize control vars statistics
local control_vars pop_mill secure_internet_pm
eststo ctrl_stats_pre: estpost summarize `control_vars' if covid == 0, detail
eststo ctrl_stats_post: estpost summarize `control_vars' if covid == 1, detail

* Dynamically capture the N for both groups
quietly est restore ctrl_stats_pre
local N_pre = e(N)
quietly est restore ctrl_stats_post
local N_post = e(N)

* Export to LaTeX
esttab ctrl_stats_* using "$texout/ctrl_var_stats.tex", replace ///
    cells("mean(fmt(%9.2fc)) sd(fmt(%9.2fc))") ///
    rename(pop_mill "Population" ///
           secure_internet_pm "Secure servers") ///
    nodepvars booktabs nomtitles ///
    nonote unstack nonumbers compress ///
    nobaselevels noobs ///
    substitute("\midrule" "" ///
	"          &     mean&       sd&     mean&       sd\\" "" ///
	"Countries" "\midrule Countries") ///
    prehead("") ///
    postfoot("Countries & \multicolumn{2}{c}{`N_pre'} & \multicolumn{2}{c}{`N_post'} \\" ///
	"\bottomrule")

*** Indices by income group and pandemic period ***

eststo clear

local indices econ_resilience_index fin_penetration_index

preserve

* Pre-pandemic
keep if covid == 0

* Summarize indices by income group
foreach i in 1 2 3 {
	eststo inc_pre`i': estpost summarize `indices' if income_group == `i', detail
}

restore

* Export to LaTeX
esttab inc_pre* using "$texout/index_by_inc_pre.tex", replace ///
    cells("mean(fmt(%9.2f)) sd(fmt(%9.2f))") ///
	rename(fin_penetration_index "DFP index" ///
	econ_resilience_index "Economic resilience index") ///
    nodepvars booktabs nomtitles noobs ///
	nonote unstack nonumbers compress ///
	nobaselevels ///
	substitute("\midrule" "" "&     mean&       sd&     mean&       sd&     mean&       sd\\" "") ///
	prehead("") ///
	postfoot("\bottomrule")
	
eststo clear

preserve

* Post-pandemic
keep if covid == 1

* Summarize indices by income group
foreach i in 1 2 3 {
	eststo inc_post`i': estpost summarize `indices' if income_group == `i', detail
}

restore

* Export to LaTeX
esttab inc_post* using "$texout/index_by_inc_post.tex", replace ///
    cells("mean(fmt(%9.2f)) sd(fmt(%9.2f))") ///
	rename(fin_penetration_index "DFP index" ///
	econ_resilience_index "Economic resilience index") ///
    nodepvars booktabs nomtitles noobs ///
	nonote unstack nonumbers compress ///
	nobaselevels ///
	substitute("\midrule" "" "&     mean&       sd&     mean&       sd&     mean&       sd\\" "") ///
	prehead("") ///
	postfoot("\bottomrule")

********** Graphs **********

*** Histogram: DFP by pandemic period ***

* Sanity check the lowest value
assert fin_penetration_index >= -6.5

* Two-way histogram for pre- and post-pandemic observations
twoway ///
    (hist fin_penetration_index if covid==0, percent ///
        start(-6.5) width(0.5) ///
        fcolor(navy%80) lcolor(none)) ///
    (hist fin_penetration_index if covid==1, percent ///
        start(-6.5) width(0.5) ///
        fcolor(maroon%80) lcolor(none)), ///
    legend(order(1 "Pre-pandemic" 2 "Post-pandemic") $titlesize) ///
    xtitle("Digital financial penetration index", $titlesize) ///
    ytitle("Percentage of countries", $titlesize) ///
    xlabel(-6(2)6, grid $labsize) ///
    ylabel(0(5)30, grid $labsize) ///
    xscale(range(-6.5 6)) ///
    yscale(range(0 30))
	
* Export graph
graph export "$graphs/dfp_distribution_across_country.pdf", replace

*** Histogram: resilience by pandemic period ***

* Sanity check the lowest value
assert econ_resilience_index >= -6.5

* Two-way histogram for pre- and post-pandemic observations
twoway ///
    (hist econ_resilience_index if covid==0, percent ///
        start(-6.5) width(0.5) ///
        fcolor(navy%80) lcolor(none)) ///
    (hist econ_resilience_index if covid==1, percent ///
        start(-6.5) width(0.5) ///
        fcolor(maroon%80) lcolor(none)), ///
    legend(order(1 "Pre-pandemic" 2 "Post-pandemic") $titlesize) ///
    xtitle("Economic resilience index", $titlesize) ///
    ytitle("Percentage of countries", $titlesize) ///
    xlabel(-6(2)6, grid $labsize) ///
    ylabel(0(5)30, grid $labsize) ///
    xscale(range(-6.5 6)) ///
    yscale(range(0 30))
	
* Export graph
graph export "$graphs/resilience_distribution_across_country.pdf", replace

*** Binscatter: resilience on DFP by pandemic ***

* Binscatter for pre- and post-pandemic observations
binscatter econ_resilience_index fin_penetration_index, line(lfit) ///
	controls(log_pop i.income_group) by(covid) ///
	ytitle("Economic resilience index", $titlesize) ///
	xtitle("Digital financial penetration index", $titlesize) ///
	ylab(-2(1)2, format(%3.0f) $labsize) ///
	xlab(-2(1)3, format(%3.0f) $labsize) ///
	legend(order(1 "Pre-pandemic" 2 "Post-pandemic") ///
		col(2) $titlesize) ///
	msymbols(circle triangle) mcolors(navy maroon) ///
	lcolors(navy maroon)
	
* Export graph
graph export "$graphs/resilience_on_dfp_by_pandemic.pdf", replace

*** Binscatter: resilience on DFP by income ***

* Binscatter for high-, middle-, and low-income observations
binscatter econ_resilience_index fin_penetration_index, line(lfit) ///
	controls(log_pop covid) by(income_group) ///
	ytitle("Economic resilience index", $titlesize) ///
	xtitle("Digital financial penetration index", $titlesize) ///
	ylab(-2(1)2, format(%3.0f) $labsize) ///
	xlab(-2(1)3, format(%3.0f) $labsize) ///
	legend(order(1 "High income" 2 "Middle income" 3 "Low income") ///
		col(3) $titlesize) ///
	msymbols(circle triangle diamond) mcolors(navy maroon orangebrown) ///
	lcolors(navy maroon orangebrown)
		  
* Export graph
graph export "$graphs/resilience_on_dfp_by_income.pdf", replace

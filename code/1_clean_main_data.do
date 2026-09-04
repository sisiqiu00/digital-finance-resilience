/***********************************************
Project: Digital Financial Resilience
Purpose: Clean the raw/provided Findex and WDI extracts, merge country-year
         observations, construct the economic-resilience and digital financial
         penetration indices, and save the final analysis dataset.
Author: Xinchen "Sisi" Qiu
Update date: August 2026
Inputs: data/raw/DatabankWide.dta; data/raw/world_development.csv
Outputs: data/proc/DatabankWide_clean.dta; data/proc/world_development.dta;
         data/proc/combined.dta; data/proc/combined_clean.dta
Language/version: Stata do-file; Tested with Stata 19.5.
Run order: Step 2 of 5. Run after _config.do.
***********************************************/

/***********************************************
Data Cleaning and Preparation (Individual): Findex
***********************************************/

*** Clean financial penetration dataset ***
use "$datacall/raw/DatabankWide.dta", clear

* Rename to prepare for merging
rename countrynewwb country

* Keep years used in the analysis comparison
keep if year == 2017 | year == 2021 | year == 2022

* Drop World Bank regional and income aggregates before country-level merging
drop if inlist(codewb, "ARB", "EAS", "EAP", "EMU", "ECS", "ECA", "NAC")
drop if inlist(codewb, "HIC", "OED", "LCN", "LAC", "UMC", "WLD", "LMY")
drop if inlist(codewb, "LIC", "LMC", "MEA", "MNA", "MIC", "SAS", "SSF", "SSA")

* Drop empty variables
foreach var of varlist _all {
    quietly count if missing(`var')
    if r(N) == _N {
        drop `var'
    }
}

* Rename relevant Findex variables
rename fin6_t use_mobl_intnt_balance
rename fin34b_t use_mobile_wage
rename g20_t_d digital_payment

* Label variables
label variable digital_payment "Made or received a digital payment (% age 15+)"
label variable use_mobl_intnt_balance "Used a mobile phone or the internet to check account balance (% age 15+)"
label variable use_mobile_wage "Received wages: through a mobile phone (% age 15+)"

* Rename income group
rename incomegroupwb21 income_group
drop if missing(income_group)
label variable income_group "Income Group (World Bank 2021)"

* Verify uniqueness
isid codewb year 

* Sort and order
sort codewb year
keep country codewb year income_group ///
	 digital_payment use_mobl_intnt_balance use_mobile_wage
order country codewb year income_group ///
	  digital_payment use_mobl_intnt_balance use_mobile_wage

* Save cleaned Findex subset
save "$datacall/proc/DatabankWide_clean.dta", replace

/***********************************************
Data Cleaning and Preparation (Individual): WDI
***********************************************/

*** Clean World Development Indicators dataset ***
import delimited "$datacall/raw/world_development.csv", clear

* Rename imported columns by position
local i = 1
foreach var of varlist * {
    rename `var' v`i'
    local i = `i' + 1
}

* Rename to prepare for merging
rename v1 country
rename v2 codewb
rename v3 year

* Drop extra rows and duplicate year field
drop if missing(codewb)
drop v4

* Convert imported numeric columns
capture confirm string variable year
if !_rc {
	destring year, replace force
}
destring v*, replace force

* Rename relevant WDI variables
// Column numbers correspond to the archived WDI extract in data/raw/world_development.csv
rename v289 curr_acct_balance
rename v454 broadband_subs
rename v456 telephone_subs_ph
rename v483 gdp_pc_growth
rename v485 gdp_pc_ppp
rename v560 gross_savings
rename v578 consumption_pc_growth
rename v625 internet_usage
rename v798 mobile_subs_ph
rename v1092 pop
rename v1287 secure_internet_pm
rename v1453 unemp

* Label variables
label variable consumption_pc_growth "Household (and NPISH) final consumption expenditure per capita growth (annual %)"
label variable gdp_pc_growth "GDP per capita growth (annual %)"
label variable gross_savings "Gross savings (% of GDP)"
label variable unemp "Unemployment, total (% of total labor force) (modeled ILO estimate)"
label variable curr_acct_balance "Current account balance (% of GDP)"

* Verify uniqueness
isid codewb year

* Keep selected WDI variables in the same order as the rename block
sort codewb year
keep country codewb year ///
	 curr_acct_balance broadband_subs telephone_subs_ph ///
	 gdp_pc_growth gdp_pc_ppp gross_savings consumption_pc_growth ///
	 internet_usage mobile_subs_ph pop secure_internet_pm unemp

order country codewb year ///
	  curr_acct_balance broadband_subs telephone_subs_ph ///
	  gdp_pc_growth gdp_pc_ppp gross_savings consumption_pc_growth ///
	  internet_usage mobile_subs_ph pop secure_internet_pm unemp

* Save subset
save "$datacall/proc/world_development.dta", replace

/***********************************************
Data Cleaning and Preparation (Merge Individual Datasets)
***********************************************/

* Merge the two datasets
use "$datacall/proc/DatabankWide_clean.dta", clear
isid codewb year
merge 1:1 codewb year using "$datacall/proc/world_development.dta"
keep if _merge == 3
drop _merge

* Verify uniqueness
isid codewb year

* Keep selected merged variables: identifiers, WDI variables, then Findex variables
sort codewb year
keep country codewb year income_group ///
	 curr_acct_balance broadband_subs telephone_subs_ph ///
	 gdp_pc_growth gdp_pc_ppp gross_savings consumption_pc_growth ///
	 internet_usage mobile_subs_ph pop secure_internet_pm unemp ///
	 digital_payment use_mobl_intnt_balance use_mobile_wage

order country codewb year income_group ///
	  curr_acct_balance broadband_subs telephone_subs_ph ///
	  gdp_pc_growth gdp_pc_ppp gross_savings consumption_pc_growth ///
	  internet_usage mobile_subs_ph pop secure_internet_pm unemp ///
	  digital_payment use_mobl_intnt_balance use_mobile_wage
	  
save "$datacall/proc/combined.dta", replace

/***********************************************
Data Cleaning and Preparation (Merged Dataset)
***********************************************/

* Load data set
use "$datacall/proc/combined.dta", clear

* Drop empty variables
foreach var of varlist _all {
    quietly count if missing(`var')
    if r(N) == _N {
        drop `var'
    }
}

* Generate numeric clustering id
egen country_id = group(codewb)
label variable country_id "Numeric country id (from codewb)"

* Reverse variables where lower raw values imply stronger resilience
gen unemp_rev = 100 - unemp

* Drop observations missing more than half of the resilience components
local econ_resi_vars "consumption_pc_growth gdp_pc_growth gross_savings unemp_rev curr_acct_balance"
egen missing_count = rowmiss(`econ_resi_vars')
drop if missing_count > (wordcount("`econ_resi_vars'") / 2)
drop missing_count

* Drop observations missing more than half of the DFP components
local fin_pen_vars "digital_payment use_mobl_intnt_balance use_mobile_wage"
egen missing_count = rowmiss(`fin_pen_vars')
drop if missing_count > (wordcount("`fin_pen_vars'") / 2)
drop missing_count

* Drop country-year pairs if the base year instrument does not exist
// This also drops post-only singletons, leaving desired pre-only and pairs 
bysort country_id: egen secure_2017 = max(cond(year == 2017, secure_internet_pm, .))
drop if missing(secure_2017)
drop secure_2017

* Sanity checks after the drop
bysort country_id: gen n_country = _N
bysort country_id: egen has_2017 = max(year == 2017)

* Check panel length and baseline coverage
egen tag_country = tag(country_id)
count if tag_country & (n_country > 2 | has_2017 == 0)

* Assert expected panel structure
assert n_country <= 2
assert has_2017 == 1

* Generate dummy var for COVID-19 period
gen covid = 0 if year == 2017
replace covid = 1 if inlist(year, 2021, 2022)
label variable covid "Post-pandemic indicator"
assert !missing(covid)

* Combine low and lower-middle income groups to obtain larger sample size
assert inlist(income_group, "High income", "Upper middle income", ///
	"Lower middle income", "Low income")
gen income_group_new = .
replace income_group_new = 1 if income_group == "High income"
replace income_group_new = 2 if income_group == "Upper middle income"
// This includes lower-middle and low income groups
replace income_group_new = 3 if !missing(income_group) & missing(income_group_new)
assert !missing(income_group_new)

* Label income_group
label define income_la 1 "1: High income" ///
					   2 "2: Middle income" ///
                       3 "3: Low income"
label values income_group_new income_la

* Replace the original income-group string with the recoded numeric variable
drop income_group
rename income_group_new income_group

* Confirm income-group is stagnant within the same country across periods
bysort country_id (year): assert income_group == income_group[1]

* Prepared transformed population control
gen log_pop = ln(pop)
assert !missing(log_pop)

* Standardize economic resilience index components
foreach var of local econ_resi_vars {
	summarize `var'
	gen econ_resi_`var' = (`var' - r(mean)) / r(sd)
}

* Generate the economic resilience index as an unweighted rowmean
egen econ_resilience_index = rowmean(econ_resi_*)
label variable econ_resilience_index "Economic resilience index, unweighted"

* Standardize final economic resilience index over the pooled analysis sample
recast double econ_resilience_index
summarize econ_resilience_index
replace econ_resilience_index = (econ_resilience_index - r(mean)) / r(sd)
label variable econ_resilience_index "Economic resilience index"

* Standardize DFP index components
foreach var of local fin_pen_vars {
	summarize `var'
	gen fin_pen_`var' = (`var' - r(mean)) / r(sd)
	
}

* Generate the DFP index as an unweighted rowmean
egen fin_penetration_index = rowmean(fin_pen_*)
label variable fin_penetration_index "Digital finance penetration index, unweighted"

* Standardize final DFP index over the pooled analysis sample
recast double fin_penetration_index
summarize fin_penetration_index
replace fin_penetration_index = (fin_penetration_index - r(mean)) / r(sd)
label variable fin_penetration_index "Digital finance penetration index"

* Label remaining variables
label variable country "Country name"
label variable codewb "ISO-3 country code"
label variable year "Year surveyed"
label variable income_group "Income group: 1: High; 2: Middle; 3: Low"
label variable unemp_rev "100 minus unemployment percentage"
label variable econ_resi_consumption_pc_growth "Standardized resilience component: consumption pc growth"
label variable econ_resi_gdp_pc_growth "Standardized resilience component: GDP pc growth"
label variable econ_resi_gross_savings "Standardized resilience component: Gross savings"
label variable econ_resi_curr_acct_balance "Standardized resilience component: Current account balance"
label variable econ_resi_unemp_rev "Standardized resilience component: reversed unemployment"
label variable fin_pen_digital_payment "Standardized DFP component: Digital payment"
label variable fin_pen_use_mobl_intnt_balance "Standardized DFP component: Check account balance"
label variable fin_pen_use_mobile_wage "Standardized DFP component: Receive wage"
label variable log_pop "Log transformed total population"

* Verify uniqueness
isid codewb year

* Keep and order final dataset: identifiers, analysis variables, and candidate instruments
sort codewb year
keep country codewb country_id year income_group covid ///
	 consumption_pc_growth gdp_pc_growth gross_savings unemp unemp_rev ///
	 curr_acct_balance ///
	 econ_resi_* econ_resilience_index ///
	 fin_pen_* fin_penetration_index ///
	 digital_payment use_mobl_intnt_balance use_mobile_wage ///
	 gdp_pc_ppp pop log_pop secure_internet_pm mobile_subs_ph ///
	 broadband_subs internet_usage telephone_subs_ph

order country codewb country_id year income_group covid ///
	  consumption_pc_growth gdp_pc_growth gross_savings unemp unemp_rev ///
	  curr_acct_balance ///
	  econ_resi_* econ_resilience_index ///
	  fin_pen_* fin_penetration_index ///
	  digital_payment use_mobl_intnt_balance use_mobile_wage ///
	  gdp_pc_ppp pop log_pop secure_internet_pm mobile_subs_ph ///
	  broadband_subs internet_usage telephone_subs_ph

* Save final analysis dataset
save "$datacall/proc/combined_clean.dta", replace

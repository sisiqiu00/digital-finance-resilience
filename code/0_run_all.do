/***********************************************
Project: Digital Financial Resilience
Purpose: Master script that runs the replication workflow from raw/provided
         inputs through final tables and figures.
Author: Xinchen "Sisi" Qiu
Update date: July 2026
Inputs: _config.do; code/1_clean_main_data.do; code/2_desc_stats.do;
        code/3_main_IV.do; code/4_robust.do
Outputs: data/proc/combined_clean.dta; table/tab_name.tex; graph/fig_name.pdf
Language/version: Stata do-file; Tested with Stata 19.5.
Run order: Step 1 of 5. Run after _config.do, or run directly from the project
           root or code/ folder to configure paths automatically.
***********************************************/

if "$code" == "" {
	capture confirm file "_config.do"
	if !_rc {
		do "_config.do"
	}
	else {
		do "../_config.do"
	}
}

do "$code/1_clean_main_data.do"
do "$code/2_desc_stats.do"
do "$code/3_main_IV.do"
do "$code/4_robust.do"

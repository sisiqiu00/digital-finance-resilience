/***********************************************
Project: Digital Financial Resilience
Purpose: Configure project paths, Stata session settings, and output folders
         for the replication scripts.
Author: Xinchen "Sisi" Qiu
Update date: July 2026
Inputs: none
Outputs: code/, data/, data/raw/, data/proc/, graph/, table/
Language/version: Stata do-file; Tested with Stata 19.5.
Run order: Setup file; run before code/0_run_all.do or any individual script.
***********************************************/

/***********************************************
Environment Configuration
***********************************************/

clear all
set more off
set mem 1g
set maxvar 10000
set seed 07192026

* Resolve the project root from either the root folder or the code folder
global identity "`c(pwd)'"
capture confirm file "_config.do"
if _rc {
	capture confirm file "../_config.do"
	if !_rc {
		global identity "`c(pwd)'/.."
	}
}

* Set the working directory to the project root
cd "$identity"

* Define code directory
global code "$identity/code"

* Define data directory
global datacall "$identity/data"

/***********************************************
Create script-related folders if missing
***********************************************/

* Code folders
capture mkdir "$identity/code"

* Data folders
capture mkdir "$identity/data"
capture mkdir "$identity/data/raw"
capture mkdir "$identity/data/proc"

* Output folders
capture mkdir "$identity/graph"
capture mkdir "$identity/table"

/***********************************************
Graphs, Tables, & Exports
***********************************************/

* Define output paths
global texout "$identity/table"
global graphs "$identity/graph"

* Adjust default graph format
global titlesize "size(medlarge)"
global labsize "labsize(medium)"

* Use consistent font
local gfont "Palatino"
graph set window fontface "`gfont'"
graph set pdf fontface "`gfont'"

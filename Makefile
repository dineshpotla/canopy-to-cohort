.PHONY: all setup acquire regional-acquire inspect fia climate eda models longitudinal direction-audit recruitment recruitment-core paper-audit paper-word report-links survey-audit ri-audit length-plan maps report test publish clean-derived
# Pipeline stages read artifacts written by the preceding stage.
.NOTPARALLEL:

R := Rscript
PAPER_PYTHON ?= python3
QUARTO := $(if $(wildcard .tools/bin/quarto),.tools/bin/quarto,quarto)

all: inspect fia climate eda models longitudinal direction-audit recruitment maps test report

setup:
	Rscript --vanilla -e 'if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org"); renv::restore(prompt = FALSE)'
	$(R) scripts/00_setup.R

acquire:
	$(R) scripts/00_acquire_data.R

# Separate, explicitly requested regional acquisition; never part of make all.
regional-acquire:
	$(R) scripts/20_acquire_regional_fia.R

inspect:
	$(R) scripts/01_inspect_fia.R

fia:
	$(R) scripts/02_build_forest_dataset.R
	$(R) scripts/03_build_regeneration_metrics.R

climate:
	$(R) scripts/04_add_climate.R

eda:
	$(R) scripts/05_eda.R

models:
	$(R) scripts/06_models.R

longitudinal:
	$(R) scripts/09_build_longitudinal_dataset.R
	$(R) scripts/10_longitudinal_models.R

direction-audit:
	$(R) scripts/11_reassess_research_direction.R
	$(R) scripts/12_audit_recruitment_feasibility.R

# Completing the Michigan paper does not depend on new regional inventories.
recruitment: recruitment-core length-plan

recruitment-core:
	$(R) scripts/13_build_recruitment_dataset.R
	$(R) scripts/14_recruitment_models.R
	$(R) scripts/15_recruitment_figures.R
	$(R) scripts/16_recruitment_survey_audit.R
	$(R) scripts/17_audit_regeneration_indicator.R
	$(R) scripts/18_audit_ri_measurements.R
	$(R) scripts/21_audit_recruitment_paper.R

paper-audit:
	$(R) scripts/21_audit_recruitment_paper.R

.PHONY: submission-audit
submission-audit:
	$(R) scripts/26_verify_recruitment_submission.R

# Requires python-docx; select the environment with PAPER_PYTHON if necessary.
paper-word: paper-audit
	$(QUARTO) render report/recruitment.qmd --to docx --output recruitment-unformatted.docx
	$(PAPER_PYTHON) scripts/22_format_recruitment_docx.py _site/recruitment-unformatted.docx outputs/paper/michigan-recruitment-paper.docx --review-comments research/runs/recruitment-2026-09-08/manuscript-review-comments.json --manuscript-source report/recruitment.qmd

report-links:
	$(PAPER_PYTHON) scripts/23_check_report_links.py

survey-audit:
	$(R) scripts/16_recruitment_survey_audit.R
	$(R) scripts/17_audit_regeneration_indicator.R

ri-audit:
	$(R) scripts/18_audit_ri_measurements.R

length-plan:
	$(R) scripts/19_plan_length_study.R

maps:
	$(R) scripts/07_maps.R

test:
	$(R) -e 'testthat::test_dir("tests/testthat")'

report:
	$(QUARTO) render --to html

publish: report
	$(QUARTO) publish gh-pages --no-render --no-prompt --no-browser

clean-derived:
	$(R) scripts/99_clean_derived.R

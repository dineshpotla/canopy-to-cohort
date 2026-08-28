.PHONY: all setup acquire inspect fia climate eda models maps report test publish clean-derived

R := Rscript
QUARTO := $(if $(wildcard .tools/bin/quarto),.tools/bin/quarto,quarto)

all: inspect fia climate eda models maps test report

setup:
	Rscript --vanilla -e 'if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org"); renv::restore(prompt = FALSE)'
	$(R) scripts/00_setup.R

acquire:
	$(R) scripts/00_acquire_data.R

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

maps:
	$(R) scripts/07_maps.R

test:
	$(R) -e 'testthat::test_dir("tests/testthat")'

report:
	$(QUARTO) render

publish: report
	$(QUARTO) publish gh-pages --no-render --no-prompt --no-browser

clean-derived:
	$(R) scripts/99_clean_derived.R

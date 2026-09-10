# Recruitment manuscript reproducibility handoff

Prepared September 10, 2026. This records the local inputs and commands for the
revised Michigan manuscript. Code, aggregate evidence, and the HTML report are
publicly available on [GitHub](https://github.com/dineshpotla/canopy-to-cohort).
This is not a claim that an immutable archive exists or that a clean-machine
reproduction has been completed. Cite the exact Git commit for this public draft.

## Source and analysis identity

Use the Michigan FIADB archive recorded in `config/config.yml`, evaluation
262501. The archive is 1,180,933,421 bytes with SHA-256
`2c1eb908a47436d4edd0f3ba9e3d647b79a4f36cef972c5ba83277300817aee1`.
Keep the original archive or arrange approved access to that exact version;
the mutable DataMart URL may return a different database. The acquisition
script warns on snapshot mismatch. Such a warning must not be accepted as
reproduction of the reported results.

The core cohort has 922 intervals on 903 plots in 66 counties; 100 intervals
contain 169 recorded entrants. These are sample counts, not population totals.
Do not replace the recruitment endpoint with the earlier detection-loss pilot.

## Local verification without refitting the research models

From the project root, with the R dependencies available:

```bash
make paper-audit
make submission-audit
make test
```

`paper-audit` reconciles manuscript numbers with stored predictions and linked
records. `submission-audit` independently implements the declared objective
with a second optimizer, keeping its verification predictions in memory and
exporting aggregate checks only. Neither replaces the saved research model.
The complete test suite includes other project components; its passing result
is not a publication decision.

## Rebuild from the pinned source

Restore the R environment using `renv.lock` and inspect the package setup
requirements in `DESCRIPTION` and `scripts/00_setup.R`. This revision's checks
run on R 4.6.1. Do not silently update the source data, package versions, cohort,
or analysis contract while attempting an exact reproduction.

After placing and verifying the pinned archive/database at the configured
paths, the recruitment path starts with the shared longitudinal extraction:

```bash
Rscript scripts/09_build_longitudinal_dataset.R
make recruitment-core
make submission-audit
```

The common cohort is built directly from the database; no new climate download,
regional inventory, or pilot model fit is required for this path. The script
sequence and dependency requirements have been inspected, but a fresh-machine
run from an empty cache remains a release check rather than a completed claim.

To rebuild the Word manuscript, use Quarto and Python with `python-docx` 1.2.0
or compatible comment support:

```bash
make paper-word PAPER_PYTHON=/path/to/python
```

Replace the Python path with the installed runtime. The paper remains editable;
six review comments come from the versioned comment file in `research/runs/`.
The analytical-detail revision embeds sixteen tables in the main text and
appendix. `paper-audit` additionally reconciles the exposed coefficients,
fold diagnostics, interval-table point estimates, and joint strata with the
saved model bundle. These checks do not rerun the bootstrap intervals.
The full local HTML site uses `make report` and includes supporting pages with
additional prerequisites. Do not treat rendering every supporting page as a
necessary new ecological analysis.

## Public draft and archival follow-up

The public source includes the canonical manuscript, bibliography, configuration,
dependency lockfile, required R modules and scripts, tests, analysis contracts,
aggregate evidence, and the two scientific figures. The editable Word export
is built locally, not distributed on the website. A future archival deposit
should include a machine-readable checksum manifest and the exact code revision.
Keep cohort construction, model fitting, evidence auditing, and document
formatting distinguishable.

Choose and document access to the pinned source and record-level derived
analysis inputs. Public FIADB record identifiers are not confidential exact
plot coordinates. The existing local-only policy is a project choice and
cannot substitute for an approved reproducibility arrangement. A reviewer
needs enough permitted input and instructions to reproduce the calculations,
not just an aggregate table or a checksum of an unavailable file.

Exclude task-history files, credentials, caches, unrelated projects, and the
unjoined external-factor raw files. Do not redistribute archived third-party
PDFs without checking their terms. A release of the core analysis does not
require release of the optional deer-data exploration.

Any journal submission or archival deposit is a separate step. An immutable
archive identifier, journal acceptance, funding declaration, and author approval
must not be inferred from publication of the code and web report.

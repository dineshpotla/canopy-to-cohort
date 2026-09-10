# Regional acquisition: access review

Checked 2026-09-09. Wisconsin and Minnesota acquisition is now explicitly
authorized. **Neither archive was retrieved, and no regional feasibility
conclusion is available.** This is an access report, not a failed scientific
validation or evidence that either state's sample is too small.

## Evidence and access

| Check | Observed result |
|---|---|
| [Official FIA DataMart product page](https://research.fs.usda.gov/products/dataandtools/fia-datamart) | Reachable; continues to link the public DataMart as the SQLite distribution route. |
| DataMart landing page and expected Wisconsin/Minnesota SQLite archive URLs | Command-line HTTP requests return curl error 52, “Empty reply from server.” HEAD, GET, bounded retries, and a browser landing-page check fail. The browser reports `net::ERR_EMPTY_RESPONSE`. |
| Michigan archive URL, used successfully for the existing source | Same empty response now; the failure is not evidence specific to WI/MN inventory availability. Michigan's existing file is not replaced. |
| Smaller Wisconsin RI-table endpoint | Also returns an empty response. It does not establish zero RI coverage. |
| [Official Wisconsin update history](https://apps.fs.usda.gov/fiadb-api/fiadb_update_history?statecd=55) | Live HTTP response lists addition of 552025 on 2026-05-04 and 2022 soil-laboratory data on 2026-07-06. |
| [Official Minnesota update history](https://apps.fs.usda.gov/fiadb-api/fiadb_update_history?statecd=27) | Live HTTP response lists addition of 272025 on 2026-05-11 and 2022 soil-laboratory data on 2026-07-06. The web-search/open cache showed older information ending at 272024; the live response was checked explicitly. |
| [Federal data catalog](https://catalog.data.gov/dataset/forest-inventory-and-analysis-database) and its linked Forest Service ArcGIS record | Both lead back to the same DataMart. The ArcGIS item is a **Document Link**, not a second downloadable inventory. No working official mirror was identified. |

The two update-history pages returned application revision
`July 30, 2026 v2.1.7.26211`. These release notes establish listed inventory
availability, not which records are in a current ZIP, usable RI overlap,
recruitment events, or a completed download. The reason for the archive service's
empty response is unknown; it could be a service or network-path problem.
No VPN or network settings were changed, access controls bypassed, or agency
staff contacted.

## Reproducible acquisition attempt

`make regional-acquire` calls `scripts/20_acquire_regional_fia.R` separately
from `make all` and the Michigan pipeline. The run beginning at
2026-09-09 18:49:00 UTC tried each authorized archive three times and ended
nonzero, retaining the failure in
`outputs/audits/recruitment-regional-acquisition.csv`.

The audit deliberately uses missing sizes, dates, hashes, and integrity results,
not zero observations or fabricated checksums. Transfer logs remain under the
git-ignored regional raw-data directory. No archive, extracted database, or
regional source pin was finalized.

The acquisition helper limits a transfer to three GiB, checks free space before
download and extraction, and retains a four-GiB free-space reserve. Only the
expected state database member can be extracted; traversal paths and multiple
databases are rejected. An extraction warning, wrong state, missing required
table, or SQLite `quick_check` failure stops acquisition. Successful files are
hashed and pinned; cached hashes must match, and unpinned existing final files
are never overwritten. These are integrity guards, not measurement validation.

## Verification and limitations

The full test suite passes 434 expectations, with zero failures, warnings, or
skips. The 25 new acquisition-helper expectations check scope, date handling,
archive paths, disk reserve, state/table validation, and read-only checks on a
synthetic SQLite fixture. An invalid-date exception found on the first test run
was corrected. The successful large-archive path has **not** been exercised on
WI/MN files, and the scientific screening has **not** run on either state.
All nine report pages render; 1,803 local resource/fragment references pass.
The new acquisition-status section was visually checked in the rendered report.

## Next action

Retry the same authorized downloads when the public archive endpoint is
reachable, or inspect user-supplied official ZIP files with recorded provenance.
No additional geography approval is needed for WI/MN. After acquisition, execute
the [outcome-blinded feasibility contract](regional-feasibility-contract.md):
baseline RI and ordinary-count definitions, repeat visits, condition/frame
continuity, unique-plot support, and annual-manual qualifications. Only then
assess support for a separately frozen regional evaluation. No model fitting,
recruitment-outcome extraction, external validation, commit, or publication has
occurred in this continuation.

# Analysis decisions

This file records decisions that materially affect the scientific analysis.
It is updated from the actual FIA schema and cohort diagnostics; no FIA species,
forest-type, status, disturbance, or treatment code is accepted without a
reference-table or user-guide source.

## Pre-specified analysis decisions

1. The analytical key is a plot visit plus condition: `PLT_CN + CONDID`.
2. The primary response is whether sugar-maple seedlings were tallied on
   sampled microplots. The inverse is described as “no seedlings tallied,” not
   confirmed ecological absence.
3. The exploratory gap indicator is not a validated ecological index and is
   not used as the primary regression response.
4. Climate is aggregated to county and interpreted as a broad spatial gradient.
5. Maps summarize analyzed observations; they are not design-based county or
   statewide population estimates.
6. Longitudinal condition matching, formal FIA population estimation, Moran's
   I, and hurdle count models are documented future extensions.

## Decisions populated during schema audit

- **FIADB source.** Michigan's SQLite FIADB archive was retrieved from the FIA
  DataMart on 2026-08-27 UTC. The acquisition audit records the URL, byte size,
  and SHA-256 checksum.
- **Evaluation.** Releases v1.0.0 and v1.1.0 pin EVALID 262501,
  “MICHIGAN 2025: 2019-2025: CURRENT AREA, CURRENT VOLUME,” using
  post-stratification. The evaluation inventory window is 2019–2025; assigned
  measurement records span 2018–2025. The source archive is mutable, so exact
  source sizes and SHA-256 hashes are published with the release. A deliberate
  configuration change is required to analyze a different current evaluation.
- **Northern hardwoods.** Active field codes in FIA forest-type group 800 are
  resolved from `REF_FOREST_TYPE`: 801 sugar maple / beech / yellow birch, 802
  black cherry, 805 hard maple / basswood, and 809 red maple / upland.
- **Sugar maple.** `REF_SPECIES` resolves *Acer saccharum* to SPCD 318 (species
  symbol ACSA3).
- **Seedling sampling opportunity.** A condition is considered sampled only
  when `MICRPROP_UNADJ > 0`. A missing sugar-maple SEEDLING row becomes zero
  only for those conditions; otherwise the response remains missing.
- **Basal area.** Live-tree plot-basis contribution is
  `0.005454 * DIA^2 * TPA_UNADJ`; condition density divides by
  `CONDPROP_UNADJ`. The build compares derived total live basal area with
  `COND.BALIVE` and fails if their Pearson correlation is below 0.98.
- **Climate.** Each county receives a 1991–2020 normal from the Daymet cell at
  its Census Gazetteer internal point. This is explicitly a broad proxy, not a
  plot-level climate value or a county-wide spatial mean.
- **Model grouping.** FIA county GEOID and plot visit are candidate random
  intercepts. The plot-visit term accounts for the small number of visits that
  contribute more than one eligible condition. Mixed-model structures are
  retained only when group-support, convergence, and singularity checks pass;
  the pipeline simplifies the random-effects structure before falling back to
  ordinary logistic regression.
- **Gap thresholds.** The primary high-established threshold is the upper third
  of sugar-maple basal-area share among conditions with demonstrated seedling
  sampling. An upper-quartile alternative is reported as a sensitivity
  analysis.

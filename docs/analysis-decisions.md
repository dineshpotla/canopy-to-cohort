# Analysis decisions

This log records choices that materially affect the scientific interpretation.
It is updated from the actual FIA schema and cohort diagnostics; species,
forest-type, status, disturbance, and treatment fields are checked against FIA
reference tables or the FIADB user guide.

## Pre-specified boundaries

1. The analytical key is one plot visit and condition: `PLT_CN + CONDID`.
2. The response is whether sugar-maple seedlings were tallied on sampled
   microplots. Its inverse is “no seedlings tallied,” not confirmed absence.
3. The regeneration-gap flag is a descriptive screen, not a validated index or
   the regression response.
4. Climate is a county-scale proxy and cannot be interpreted as plot exposure.
5. Maps summarize the analyzed sample, not design-based county or statewide
   population estimates.
6. Exact FIA plot locations are neither used nor inferred.
7. Longitudinal transition analysis and formal FIA population estimation remain
   future extensions.

## Source and cohort

- **FIADB source.** Michigan's SQLite FIADB archive was retrieved from the FIA
  DataMart. The acquisition audit records the URL, byte size, retrieval time,
  and SHA-256 checksum.
- **Evaluation.** Release v1.3.0 pins EVALID 262501, “MICHIGAN 2025:
  2019-2025: CURRENT AREA, CURRENT VOLUME.” The evaluation inventory window is
  2019–2025; assigned measurement records span 2018–2025. A configuration
  change is required to analyze a different evaluation.
- **Operational northern-hardwood cohort.** FIA forest-type group 800 is the
  maple / beech / birch group. Active retained types resolve from
  `REF_FOREST_TYPE`: 801 sugar maple / beech / yellow birch, 802 black cherry,
  805 hard maple / basswood, and 809 red maple / upland.
- **Sugar maple.** `REF_SPECIES` resolves *Acer saccharum* to SPCD 318.
- **Seedling opportunity.** A condition is sampled only when
  `MICRPROP_UNADJ > 0`. An absent sugar-maple SEEDLING row becomes zero only
  under that demonstrated opportunity.

## Size-class correction

The v1.3.0 scientific model separates FIA TREE size classes instead of treating
all live sugar-maple basal area as established canopy structure.

- **Established-tree cohort.** The primary cohort requires at least one live
  sugar-maple TREE record with DBH ≥ 5 inches, FIA's subplot-tree threshold.
  This rule is inventory-defined, independent of the seedling outcome, and
  retains 1,072 sampled conditions in 66 counties.
- **Sapling stage.** Sugar-maple sapling presence means at least one live TREE
  record with DBH 1–4.9 inches. Presence is kept separate from established-tree
  basal area.
- **Competitor basal area.** The model uses live non-maple basal area. It does
  not subtract established sugar maple from total basal area because that would
  misclassify sugar-maple saplings as competitors.
- **Basal-area frames.** Each live-tree plot-basis contribution is
  `0.005454 * DIA^2 * TPA_UNADJ`. Condition density uses `MICRPROP_UNADJ` for
  microplot trees, `SUBPPROP_UNADJ` for subplot trees, and `MACRPROP_UNADJ` only
  above an applicable populated macroplot breakpoint. Derived total live basal
  area must pass strict agreement gates against `COND.BALIVE`.

The previous full-cohort model is retained as an explicitly labeled baseline.
Its nonlinear curve mixes 1–4.9-inch sugar-maple saplings into its basal-area
predictor and includes conditions without established sugar maple. It therefore
mixes species absence with regeneration continuity and is not the primary model.

## Primary model

- **Response.** `outcome_no_seedlings = 1 - maple_seedling_detected`.
- **Fixed effects.** Standardized `log1p` established sugar-maple basal area,
  sugar-maple sapling presence, standardized `log1p` non-maple basal area,
  microplot condition coverage, recorded treatment, stand age, disturbance,
  county temperature and precipitation proxies, and measurement year.
- **Functional form.** A linear standardized `log1p` established-tree term is
  selected. A two-degree-of-freedom spline did not improve fit. Binary sapling
  presence had lower AIC than no sapling term, continuous sapling basal area,
  or presence plus positive sapling amount.
- **Treatment.** The FIA treatment indicator is included because it is complete,
  scientifically relevant, and supported by 151 primary-cohort observations.
  It remains observational and is never described as a management effect.
- **Grouping.** County GEOID is the retained random intercept. Adding a plot
  visit intercept produced zero estimated variance, a singular fit, and no AIC
  improvement.
- **Inference.** Conventional fixed-effect summaries use model-based Wald 95%
  intervals. A fixed-effect logistic model with county-cluster CR1 covariance
  is reported as sensitivity evidence.
- **Validation.** Ten deterministic folds hold out whole counties. Every fold
  relearns transformations from training data and predicts held-out counties
  with fixed effects only. This is internal geographic validation, not external
  validation.
- **Forest type.** Indicators are evaluated through an omnibus sensitivity;
  the dominant type 801 is also refit alone. Sparse type cells are not
  interpreted individually.
- **Diagnostics.** DHARMa checks cover uniformity, dispersion, outliers, and
  residual quantiles. A county-plus-plot random-structure comparison and
  collinearity audit are published.

## Descriptive gap screen

The high-established threshold is the upper third of frame-corrected
established sugar-maple basal-area share among seedling-sampled conditions. The
share denominator includes only live trees with DBH ≥ 5 inches. An upper-quartile
alternative is reported. The sample-relative threshold is never reused to
construct the inferential cohort.

## Spatial decision

The Daymet normal uses the cell at each Census Gazetteer county internal point.
It is a county proxy, not a county-wide areal mean. Plot-level residual spatial
autocorrelation cannot be tested without plot coordinates. A naïve test on
county-aggregated residuals was rejected because it is unstable and does not
represent plot-scale dependence.

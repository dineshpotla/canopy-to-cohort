# RI protocol evidence and access record

Reviewed 2026-09-09. This note distinguishes documentary definitions from local
eligibility decisions. The audit is not certification of every historical
field protocol or independent validation of the underlying observations.

## Primary sources inspected

| Source | Exact access and locators | Supported use |
|---|---|---|
| USDA FIADB Database Description v9.4, August 2025, chapter 6 revised January 2024 | [Official PDF](https://research.fs.usda.gov/sites/default/files/2025-08/wo-v9-4_Aug2025_UG_FIADB_database_description_NFI.pdf); PDF pp. 413-416 and 419-420, printed pp. 6-7 to 6-10 and 6-13 to 6-14. Relevant full text read; status and length-code pages visually inspected. | Retired legacy field, all-year microplot status, RI keys, sources, lengths, and count grain. |
| USDA NRS P2+ supplement v7.0, revised April 2016 | [Official archived file](https://usfs-public.app.box.com/s/x7gdq3latjy1i5936ni46hm1u7g4v12v/file/1178034508947); PDF pp. 12-13 and 19-20, printed pp. 11-12 and 18-19. Relevant text and length table read. **The archived copy has a DRAFT watermark**, visible in the page rendering. | Contemporary support for sampling status, season, stump grouping, and length codes; not proof of the final deployed 2016 edition. |
| USDA NRS P2+ supplement v7.1, revised April 2017 | [Official archived file](https://usfs-public.app.box.com/s/x7gdq3latjy1i5936ni46hm1u7g4v12v/file/1178034501747); PDF pp. 15, 19-20, 22-23; length table visually inspected. | Sampling, season, qualifying counts, source/length codes. |
| USDA NRS P2+ supplement v7.2, revised April 2018 | [Official archived file](https://usfs-public.app.box.com/s/x7gdq3latjy1i5936ni46hm1u7g4v12v/file/1178034540147); PDF pp. 14-15 and 19-23; count/source/length pages visually inspected. | Sampling and count definitions; browse-impact circularity caution. |
| McWilliams et al., 2015, NRS-148 | [Official PDF](https://research.fs.usda.gov/download/treesearch/48367.pdf); relevant full text, printed pp. 18-23 and 72. | Earlier regional schema and design context, not each year's implementation. |

The [current official NRS page](https://research.fs.usda.gov/nrs/programs/fia)
links to the public historical archive. Generic web retrieval failed on the
Box redirect, but the public browser listing and anonymous downloads worked.
The annual folder and its second page were inspected. Individual 2012-2015
RI supplements were not recovered; the cited legacy 2014 URL also failed.
No login, subscription, agency contact, or independent final reviewer was used.

## Definition decisions

The dictionary explicitly retires `REGEN_SUBP_STATUS_CD` from 2015 and says
`REGEN_MICR_STATUS_CD` is populated for all years. Code 1 supports accessible
forest RI sampling; code 2 has no accessible forest, while 3-5 and 9 do not
verify the required sampled opportunity. The audit therefore requires 1 for
each positive forest-condition slice and rejects contradictory populated
legacy status or nonsampling reason fields.

The 2016 supplement still uses older subplot wording in several cross-references.
The 2017/2018 generic core-count paragraph associates "not sampled" with code 2,
which conflicts with its explicit microplot-status table. The audit follows
the explicit status table and the v9.4 dictionary, not that cross-reference.
No evidence of a changed sugar-maple length-class boundary was found in the
inspected 2016-2018 tables. That does not establish all earlier-year equivalence.

RI length is base-to-terminal-bud length. Qualifying established maple seedlings
begin at two inches; ordinary hardwood counts begin at one foot. Counts can be
estimated above five. Stump sprouts and common-origin suckers are grouped, not
independent genets. Source 3 is not a valid sugar-maple category. The at-least-five-
foot grouping uses classes 5-6 and was fixed in the contract before tabulation.

May-September is a conservative date-plausibility screen using `PLOT` dates.
RI rows have no separate field-observation date in this snapshot. A failed
follow-up date screen is not proof that RI was actually collected out of season.
The 2018 browse-impact definitions explicitly incorporate seedling vigor,
abundance, and length variability; treating that score as an independent cause
of those same measurements would be problematic.

## Local findings and interpretation

`scripts/18_audit_ri_measurements.R` retains 90 baseline intervals, 87 plots,
32 counties, and 14 event plots. All 311 contributing microplot-condition
intervals have matching ordinary and RI-at-least-one-foot counts (total 2,658).
All-size RI totals are 9,489. Exact agreement is consistent with shared or
derived tally information, but the database-generation code was not inspected;
it does not constitute independent field corroboration.

Verified baseline RI zeros number nine; another ten ordinary-zero conditions
have RI maple only below one foot. Four follow-up RI frame/date flags reduce
the both-visit subset to 86. These do not change baseline eligibility or the
existing TREE outcome. The 2016-2018 annual-guide-inspected subset has 37
intervals and four events, including the qualified 2016 draft source.

Thirteen events occur among 44 intervals with baseline maple at least five
feet long; one occurs among 46 without. This is an unadjusted, retrospective
association. The prospective-use question of added value beyond counts remains
unanswered. A later-year split provides only ten development and four test
events. No height model, independent survey target, utility assessment, or
external validation is supplied by this audit.

## Document hashes

SHA-256 values identify the exact inspected public files; sources remain
available through the original URLs rather than being bundled into the report.

| File | SHA-256 |
|---|---|
| FIADB v9.4 | `ec735ead3852ba6dbb65cb7257b4f8e0795d4c641be4d625ed81ce64eeba2833` |
| NRS-148 | `f889d62962b0ed5099e41ebe633b5b8987869287097fce742700fa7a2b7ad846` |
| NRS 2016 P2+ archived draft | `2d5e2abdc3a7bdb44e04d67e8ff6d3c8bca2dcaa4dc776208b88884da992bbf0` |
| NRS 2017 P2+ | `bde1d74b0780920554181f73e1cefb072338d31a38649c6e5cd263046c40c606` |
| NRS 2018 P2+ | `996719eb3807dccccd7bac4b749cb819dd5254ec9b3eb0e9dc777e7add35a2a3` |

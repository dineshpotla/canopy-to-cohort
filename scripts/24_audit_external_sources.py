#!/usr/bin/env python3
"""Inventory public external sources without joining FIA or fitting models.

Use the bundled Python (pypdf, pandas). The optional import copies the exact
browser-downloaded source files below; it never overwrites different raw bytes.
No network requests, model fitting, or manuscript changes occur in this script.
"""

import argparse
import csv
import hashlib
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import pdfplumber
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw/external"
AUDIT = ROOT / "outputs/audits"
INTERIM = ROOT / "data/interim/external"
DRYAD_DOI = "https://doi.org/10.5061/dryad.612jm647z"
ARCHIVE = "https://michigan.access.preservica.com"
# Year is the hunting season, NOT the publication year.
REPORTS = [
    (2008, "1246.pdf", 3499, "9047f2f1-14dd-48d1-a6a8-d9f9b0239474"),
    (2009, "1581.pdf", 3513, "39e48252-eafc-4eb1-9de2-a1f6b9728808"),
    (2010, "1917.pdf", 3526, "37e3dc5e-91d8-4a77-95d5-e5940deb3eaf"),
    (2011, "2484.pdf", 3548, "16e76823-e237-415d-aac4-e12bed43c4d2"),
    (2012, "3501.pdf", 3566, "482e72e6-cac9-4227-b160-233ddf20fb09"),
    (2013, "3728.pdf", 3585, "8979d49b-e1fa-4de0-adac-ee1e9ea1b33d"),
    (2014, "17843.pdf", 3609, "1ab0b273-a3f3-47a7-a7f4-acdff1d85f51"),
    (2015, "18015.pdf", 3621, "2edf5145-7b0b-4c5f-ae80-3f94bcb18f9e"),
    (2016, "18453.pdf", 3639, "31b52276-83ac-4f26-baec-2e43e986517b"),
    (2017, "2017_deer_harvest_survey_report.pdf", 3656, "c21455e8-93c1-4d07-9a73-4f80c4761ee5"),
    (2018, "2018_deer_harvest_survey_report.pdf", 3673, "a7d864d5-2a30-4cf9-8201-5e20c8b6b256"),
]
DRYAD_FILES = [
    ("NH_speciesdiversity_keyREADME_final.csv", 2316460, "2425a1637554f3400c76fa77141a19ee1f039ec12ac7d8ed1514267d94526f89"),
    ("NH_speciesdiversity.csv", 2316461, "114a7e6f37d468cfb59f448ad242a6b1d3c156b925de499a4c4f75bcb50807a3"),
    ("README.md", 2316462, "718ee9c1a37ec6daf519144ec7603a34803c081d183a3b90261f9578f8f99a40"),
]
CORE_FILES = ["report/recruitment.qmd", "outputs/models/recruitment-analysis.rds",
              "outputs/paper/michigan-recruitment-paper.docx"]
MEASURES = ["hunters_estimate", "hunters_cl95_halfwidth",
            "hunting_days_estimate", "hunting_days_cl95_halfwidth",
            "antlerless_estimate", "antlerless_cl95_halfwidth",
            "antlered_bucks_estimate", "antlered_bucks_cl95_halfwidth",
            "all_deer_estimate", "all_deer_cl95_halfwidth"]
# Visually transcribed from the complete rendered source page on 2026-09-10.
# This is a check, not a replacement for the extracted source observation.
VISUAL_NUMERIC_CHECKS = {
    (2012, 55, "069"): (
        "bde3977d2bec559665f102f5192f7f20d03e0967c8ac35fcd1bd182d9b2384ff",
        (7283, 856, 66939, 11981, 673, 266, 1901, 479, 2574, 578)),
}


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def preserve_copy(source, target):
    """Copy bytes only when target is absent; reject changed raw files."""
    source, target = Path(source), Path(target)
    if target.exists():
        if sha256(source) != sha256(target):
            raise ValueError(f"Raw file differs; refusing overwrite: {target}")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def write_csv(path, rows):
    if not rows:
        raise ValueError(f"No rows for {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def parse_dmu_line(line):
    """Only accept a DMU code followed by exactly ten published integers.

    CL means a 95% confidence half-width, not SE. Missing or malformed cells
    cause failure rather than being silently converted into zero or dropped.
    """
    tokens = line.split()
    if not tokens or not (code := re.fullmatch(r"(\d{3})([a-z]?)", tokens[0])):
        return None
    # Ignore standalone page numbers. Any code with data must parse completely.
    if len(tokens) == 1:
        return None
    footnote = code.group(2)
    if len(tokens) > 1 and re.fullmatch(r"[a-z]", tokens[1]):
        footnote += tokens.pop(1)
    if len(tokens) != 11 or not all(re.fullmatch(r"\d+|\d{1,3}(?:,\d{3})+", x) for x in tokens[1:]):
        raise ValueError(f"Unresolved DMU row: {line}")
    return {"dmu_code": code.group(1), "dmu_footnote": footnote,
            **dict(zip(MEASURES, (int(x.replace(",", "")) for x in tokens[1:])))}


def audit_dryad():
    path = RAW / "dryad-612jm647z-v2/NH_speciesdiversity.csv"
    x = pd.read_csv(path)
    if x.duplicated(["ID", "HtClass"]).any():
        raise ValueError("Duplicate Dryad site/height keys")
    by_site = x.groupby("ID", sort=True)
    predictors = ["deer.use", "avgBAtot", "avgBAtot.sd", "GC_HWL", "GC_BMS", "GC_CWD", "shrub", "ord", "Region"]
    if not by_site.HtClass.apply(lambda s: set(s) == {1, 2, 3}).all():
        raise ValueError("Incomplete Dryad height-class triplets")
    if (by_site[predictors].nunique(dropna=False) > 1).any().any():
        raise ValueError("Stand predictors vary across repeated size-class rows")
    stands = x.drop_duplicates("ID")
    return {
        "source": DRYAD_DOI, "dryad_version": 2, "inventory_year": 2017,
        "rows": len(x), "columns": len(x.columns), "stands": len(stands),
        "height_class_counts": {str(k): int(v) for k, v in x.HtClass.value_counts().sort_index().items()},
        "stands_by_region": {str(k): int(v) for k, v in stands.Region.value_counts().sort_index().items()},
        "missing_by_column": {k: int(v) for k, v in x.isna().sum().items()},
        "deer_use_stands_nonmissing": int(stands["deer.use"].notna().sum()),
        "deer_use_min_percent": float(stands["deer.use"].min()),
        "deer_use_max_percent": float(stands["deer.use"].max()),
        "site_quality_observed_values": sorted(int(v) for v in stands.ord.dropna().unique()),
        "predictors_constant_within_stand": True,
        "geography_fields": [c for c in x.columns if re.search(r"region|county|latitude|longitude|fips|geoid", c, re.I)],
        "has_direct_twig_browse_counts": False,
        "has_fia_crosswalk": False,
        "join_status": "No county, coordinates, or FIA identifier supplied; do not append to or join with FIA cohort",
        "deer_use_definition": "Modeled winter deer-use estimate, percent of transects occupied by pellets; not direct browsing",
        "dictionary_issue": "ord description says 1-4, units say 1-3; preserve original and confirm before using site quality",
    }


def harvest_appendix_page(text, year):
    # Older PDFs insert spaces within words and within the season year.
    compact = re.sub(r"\s+", "", text).lower()
    return ("estimatednumberofdeerhunters,huntingeffort,anddeerharvested" in compact
            and "summarizedbydeermanagementunit" in compact and f"during{year}" in compact)


def parse_crosscheck_line(line):
    # Some old PDFs lift the last numeric row into the first footnote line.
    # Accept only a complete code + ten-number suffix, never partial numbers.
    match = re.search(r"(?<!\S)(\d{3}[a-z]?(?:\s+[a-z])?(?:\s+\d[\d,]*){10})\s*$", line)
    return parse_dmu_line(match.group(1)) if match else None


def verify_numeric_rows(primary, secondary, year, page, source_sha):
    if any(primary.get(k) != v for k, v in secondary.items()):
        raise ValueError(f"Independent numeric extraction mismatch: {year} page {page}")
    missing = sorted(primary.keys() - secondary.keys())
    for code in missing:
        if VISUAL_NUMERIC_CHECKS.get((year, page, code)) != (source_sha, primary[code]):
            raise ValueError(f"Unverified numeric row requires visual review: {year} page {page} DMU {code}")
    return missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--import-downloads", type=Path, help="Directory containing the exact source filenames listed in this script")
    args = parser.parse_args()
    before = {p: sha256(ROOT / p) for p in CORE_FILES}
    now = datetime.now(timezone.utc).isoformat()
    manifest, report_audit, dmu_rows = [], [], []
    INTERIM.mkdir(parents=True, exist_ok=True)
    for filename, file_id, expected in DRYAD_FILES:
        target = RAW / "dryad-612jm647z-v2" / filename
        if args.import_downloads:
            if sha256(args.import_downloads / filename) != expected:
                raise ValueError(f"Dryad repository checksum mismatch: {filename}")
            preserve_copy(args.import_downloads / filename, target)
        if sha256(target) != expected:
            raise ValueError(f"Dryad repository checksum mismatch: {filename}")
        manifest.append(dict(source_id=f"dryad-{file_id}", kind="stand-data-or-documentation", season_year="",
            landing_url=DRYAD_DOI, download_url=f"https://datadryad.org/downloads/file_stream/{file_id}",
            local_path=str(target.relative_to(ROOT)), original_filename=filename,
            sha256=expected, bytes=target.stat().st_size, status="downloaded_checksum_verified",
            verification_utc=now, access_route="public browser download",
            rights_note="CC0; dataset version 2, API version ID 237141"))
    for year, filename, report_number, identifier in REPORTS:
        target = RAW / "michigan-deer-harvest" / f"mi-deer-harvest-{year}.pdf"
        if args.import_downloads:
            candidate = PdfReader(args.import_downloads / filename)
            cover = re.sub(r"\s+", " ", candidate.pages[0].extract_text())
            if str(report_number) not in cover or str(year) not in cover:
                raise ValueError(f"Source identity mismatch: {filename}")
            preserve_copy(args.import_downloads / filename, target)
        reader = PdfReader(target)
        source_sha = sha256(target)
        source_id = f"mi-deer-{year}"
        manifest.append(dict(source_id=source_id, kind="dnr-harvest-survey-pdf", season_year=year,
            landing_url=f"{ARCHIVE}/uncategorized/IO_{identifier}/",
            download_url=f"{ARCHIVE}/download/file/IO_{identifier}",
            local_path=str(target.relative_to(ROOT)), original_filename=filename,
            sha256=source_sha, bytes=target.stat().st_size, status="downloaded_identity_verified",
            verification_utc=now, access_route="Archives of Michigan public browser download",
            rights_note="Archive asks contact for permission to publish; retain raw source locally, do not redistribute PDF"))
        pages, maps, rows, texts, secondary_missing = [], [], [], [], []
        plumber = pdfplumber.open(target)
        for i, page in enumerate(reader.pages):
            text = page.extract_text()
            texts.append(f"\n--- PDF PAGE {i+1} ---\n{text}")
            if re.search(r"Figure\s+2[.]", text):
                maps.append(i + 1)
            if not harvest_appendix_page(text, year):
                continue
            pages.append(i + 1)
            page_rows, check_rows = [], []
            # pdfplumber associates the superscript f with DMU 273 correctly;
            # pypdf can lift it onto the preceding line (visually verified).
            page_text = plumber.pages[i].extract_text()
            for line in page_text.splitlines():
                row = parse_dmu_line(line)
                if row is not None:
                    page_rows.append(row)
            for line in page.extract_text(extraction_mode="layout").splitlines():
                row = parse_crosscheck_line(line)
                if row is not None:
                    check_rows.append(row)
            primary = {r["dmu_code"]: tuple(r[m] for m in MEASURES) for r in page_rows}
            secondary = {r["dmu_code"]: tuple(r[m] for m in MEASURES) for r in check_rows}
            missing = verify_numeric_rows(primary, secondary, year, i + 1, source_sha)
            secondary_missing.extend(f"{i+1}:{k}" for k in missing)
            for row in page_rows:
                combined = row["dmu_code"] == "273" and "Estimates for DMU 273 were combined with estimates for DMU 073" in page_text
                conflict = combined and any(row[m] > 0 for m in MEASURES)
                rows.append(dict(season_year=year, **row, source_id=source_id, pdf_page=i+1,
                        source_footnote_combined_into_dmu="073" if combined else "",
                        nonzero_row_conflicts_with_combination_note=conflict,
                        geography="DMU_as_published_not_county_FIPS", series="postseason_hunter_survey_estimates"))
        plumber.close()
        if len(pages) != 3 or not rows or "001" not in {r["dmu_code"] for r in rows}:
            raise ValueError(f"Incomplete three-page harvest appendix: {target}")
        if len({r["dmu_code"] for r in rows}) != len(rows):
            raise ValueError(f"Duplicate DMU codes: {year}")
        # Audit but never repair published totals. Differences can reflect
        # rounding at intermediate aggregation/adjustment stages, not just
        # rounding of the final two components. Keep unresolved cases visible.
        differences = [r["all_deer_estimate"] - r["antlerless_estimate"] - r["antlered_bucks_estimate"] for r in rows]
        for row, difference in zip(rows, differences):
            row["published_total_minus_components"] = difference
        (INTERIM / f"mi-deer-harvest-{year}.txt").write_text("\n".join(texts), encoding="utf-8")
        report_audit.append(dict(season_year=year, report_number=report_number, pdf_pages=len(reader.pages),
            appendix_pdf_pages=";".join(map(str, pages)), figure2_mention_pages=";".join(map(str, maps)),
            dmu_rows=len(rows), unique_dmu_codes=len({r["dmu_code"] for r in rows}),
            nonzero_component_differences=sum(v != 0 for v in differences),
            component_difference_max_abs=max(abs(v) for v in differences),
            component_differences_above_one=sum(abs(v) > 1 for v in differences),
            all_zero_rows=sum(all(r[m] == 0 for m in MEASURES) for r in rows),
            numeric_crosscheck_matched_rows=len(rows) - len(secondary_missing),
            secondary_reader_missing_page_dmu=";".join(secondary_missing),
            visually_checked_rows=len(secondary_missing),
            numeric_transcription_crosscheck="all_rows_match" if not secondary_missing else "secondary_reader_plus_hash_pinned_visual_check",
            combination_note_conflicts=sum(r["nonzero_row_conflicts_with_combination_note"] for r in rows),
            spatial_join_approved=False, status="parsed_not_spatially_harmonized"))
        dmu_rows.extend(rows)
    AUDIT.mkdir(parents=True, exist_ok=True)
    write_csv(AUDIT / "recruitment-external-sources.csv", manifest)
    write_csv(AUDIT / "recruitment-external-harvest-reports.csv", report_audit)
    code_sets = {year: {r["dmu_code"] for r in dmu_rows if r["season_year"] == year} for year, *_ in REPORTS}
    transitions = [dict(previous_season=previous, season_year=current,
        added_codes=";".join(sorted(code_sets[current] - code_sets[previous])),
        removed_codes=";".join(sorted(code_sets[previous] - code_sets[current])),
        limitation="Code-set changes only; unchanged codes do not guarantee unchanged boundaries")
        for previous, current in zip(sorted(code_sets)[:-1], sorted(code_sets)[1:])]
    write_csv(AUDIT / "recruitment-external-dmu-code-changes.csv", transitions)
    # Full numeric transcription is a local working table, not a model input.
    write_csv(INTERIM / "mi-deer-harvest-dmu-2008-2018.csv", dmu_rows)
    dryad = audit_dryad()
    (INTERIM / "dryad-data-audit.json").write_text(json.dumps(dryad, indent=2) + "\n", encoding="utf-8")
    preservation = [dict(path=p, sha256_before=h, sha256_after=sha256(ROOT / p), unchanged=h == sha256(ROOT / p)) for p, h in before.items()]
    if not all(x["unchanged"] for x in preservation):
        raise ValueError("Unexpected core-artifact modification")
    write_csv(AUDIT / "recruitment-external-core-preservation.csv", preservation)
    print(json.dumps({"source_files": len(manifest), "report_years": [x[0] for x in REPORTS],
                      "dmu_year_rows": len(dmu_rows), "dryad": dryad, "core_unchanged": True}, indent=2))


if __name__ == "__main__":
    main()

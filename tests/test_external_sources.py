"""Small, offline tests for the source audit; no raw data required."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("external_sources", Path(__file__).resolve().parents[1] / "scripts/24_audit_external_sources.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class SourceAuditTests(unittest.TestCase):
    def test_leading_zero_and_published_halfwidth(self):
        x = audit.parse_dmu_line("001 1,200 100 2,000 200 30 3 40 4 70 7")
        self.assertEqual(x["dmu_code"], "001")
        self.assertEqual(x["hunters_estimate"], 1200)
        self.assertEqual(x["antlered_bucks_cl95_halfwidth"], 4)

    def test_real_zero_is_not_dropped(self):
        x = audit.parse_dmu_line("245 " + "0 " * 10)
        self.assertEqual(x["all_deer_estimate"], 0)

    def test_dmu_footnotes_are_preserved(self):
        for label in ["255f", "255 f"]:
            x = audit.parse_dmu_line(label + " 1 2 3 4 5 6 7 8 12 9")
            self.assertEqual(x["dmu_code"], "255")
            self.assertEqual(x["dmu_footnote"], "f")

    def test_pdf_word_and_year_spacing_does_not_drop_pages(self):
        self.assertTrue(audit.harvest_appendix_page(
            "Appendix B. Estimated number of deer hunters, hunt ing effort, and deer harvested "
            "in Michigan during 2 009, summarized by Deer Management Unit.", 2009))
        self.assertFalse(audit.harvest_appendix_page(
            "Antlerless license quotas in Michigan during 2009, summarized by Deer Management Unit.", 2009))

    def test_malformed_or_missing_cell_fails(self):
        with self.assertRaises(ValueError):
            audit.parse_dmu_line("001 1 2 3 4 5 6 7 8 9")
        with self.assertRaises(ValueError):
            audit.parse_dmu_line("001 1 2 3 NA 5 6 7 8 9 10")

    def test_headers_and_page_numbers_are_not_data(self):
        self.assertIsNone(audit.parse_dmu_line("DMU Hunters Hunting effort"))
        self.assertIsNone(audit.parse_dmu_line("123"))

    def test_crosscheck_recovers_complete_row_after_footnote(self):
        row = audit.parse_crosscheck_line("aHarvest estimates exclude permits. 069 6,442 749 49,458 7,922 63 69 1,045 306 1,108 321")
        self.assertEqual(row["dmu_code"], "069")
        self.assertEqual(row["all_deer_estimate"], 1108)

    def test_missing_secondary_row_requires_hash_pinned_visual_values(self):
        source_sha, values = audit.VISUAL_NUMERIC_CHECKS[(2012, 55, "069")]
        self.assertEqual(audit.verify_numeric_rows({"069": values}, {}, 2012, 55, source_sha), ["069"])
        with self.assertRaises(ValueError):
            audit.verify_numeric_rows({"069": values}, {}, 2012, 55, "changed_source")
        with self.assertRaises(ValueError):
            audit.verify_numeric_rows({"069": values}, {"069": (1,)}, 2012, 55, source_sha)

    def test_raw_source_cannot_be_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, target = Path(tmp) / "source", Path(tmp) / "target"
            source.write_bytes(b"original")
            audit.preserve_copy(source, target)
            audit.preserve_copy(source, target)
            self.assertEqual(target.read_bytes(), b"original")
            source.write_bytes(b"different")
            with self.assertRaises(ValueError):
                audit.preserve_copy(source, target)
            self.assertEqual(target.read_bytes(), b"original")


if __name__ == "__main__":
    unittest.main()

"""Check local files and HTML fragments for the research site and its redirects."""
import json
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1] / "_site"
PAGES = ["index.html", "report/index.html", "report/recruitment.html",
         "report/spatial-context.html",
         "report/ri-audit.html", "report/length-study.html",
         "docs/research-direction.html", "docs/survey-validation-plan.html",
         "docs/analysis-decisions.html", "docs/data-dictionary.html"]


class Links(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.references, self.ids = [], set()
        self.feed(text)

    def handle_starttag(self, tag, attributes):
        for name, value in attributes:
            if value and name in ("href", "src"):
                self.references.append(value)
            if value and name == "id":
                self.ids.add(value)


def check_site():
    parsed, broken, checked = {}, [], 0
    for relative in PAGES:
        path = ROOT / relative
        if not path.is_file():
            broken.append({"page": relative, "missing_page": True})
            continue
        parsed[path.resolve()] = Links(path.read_text())
    for page in [ROOT / relative for relative in PAGES if (ROOT / relative).is_file()]:
        for reference in parsed[page.resolve()].references:
            url = urlsplit(reference)
            if url.scheme or url.netloc:
                continue
            checked += 1
            decoded = unquote(url.path)
            target = (ROOT / decoded.lstrip("/") if decoded.startswith("/") else page.parent / decoded) if decoded else page
            target = target.resolve()
            if target.is_dir():
                target /= "index.html"
            if not target.is_file():
                broken.append({"page": str(page.relative_to(ROOT)), "reference": reference, "reason": "file missing"})
            elif url.fragment and target.suffix == ".html":
                if target not in parsed:
                    parsed[target] = Links(target.read_text())
                if unquote(url.fragment) not in parsed[target].ids:
                    broken.append({"page": str(page.relative_to(ROOT)), "reference": reference, "reason": "fragment missing"})
    result = {"pages": len(PAGES), "local_references_checked": checked,
              "broken_references": len(broken), "failures": broken}
    print(json.dumps(result, indent=2))
    return bool(broken)


if __name__ == "__main__":
    raise SystemExit(check_site())

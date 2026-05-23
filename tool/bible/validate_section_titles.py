#!/usr/bin/env python3
"""
Valida subtítulos de sección contra los XML bíblicos del proyecto.
"""

from __future__ import annotations

import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "bible"
BASE_PATH = ASSETS / "section_titles.json"
OVERRIDES_PATH = ASSETS / "section_title_overrides.json"
XML_PATHS = {
    "RVR1960": ASSETS / "Reina Valera 1960.xml",
    "NVI": ASSETS / "NVI.xml",
    "NTV": ASSETS / "NTV.xml",
    "TLA": ASSETS / "TLA.xml",
}


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _sort_key(key: str) -> tuple[int, int, int]:
    book, chapter, verse = key.split(":")
    return int(book), int(chapter), int(verse)


def _chapter_verse_counts(xml_path: Path) -> dict[tuple[int, int], int]:
    root = ET.parse(xml_path).getroot()
    out: dict[tuple[int, int], int] = {}
    for book in root.findall(".//book"):
        book_number = int(book.attrib["number"])
        for chapter in book.findall("./chapter"):
            chapter_number = int(chapter.attrib["number"])
            max_verse = 0
            for verse in chapter.findall("./verse"):
                max_verse = max(max_verse, int(verse.attrib["number"]))
            out[(book_number, chapter_number)] = max_verse
    return out


def _validate_title_text(title: str) -> list[str]:
    issues: list[str] = []
    if not title.strip():
        issues.append("empty")
    if re.search(r"\s{2,}", title):
        issues.append("double-spaces")
    if len(title) < 3:
        issues.append("too-short")
    if len(title) > 100:
        issues.append("too-long")
    return issues


def main() -> None:
    base = _load_json(BASE_PATH)
    base_titles = {k: v for k, v in base.items() if not k.startswith("_")}
    overrides = _load_json(OVERRIDES_PATH)
    version_maps = {k: v for k, v in overrides.items() if not k.startswith("_")}

    errors: list[str] = []
    print(f"Base titles: {len(base_titles)}")

    for version_id, xml_path in XML_PATHS.items():
        counts = _chapter_verse_counts(xml_path)
        titles = version_maps.get(version_id)
        if titles is None:
            errors.append(f"{version_id}: missing version map")
            continue
        for key, title in sorted(titles.items(), key=lambda item: _sort_key(item[0])):
            book, chapter, verse = _sort_key(key)
            max_verse = counts.get((book, chapter))
            if max_verse is None:
                errors.append(f"{version_id}: missing chapter for key {key}")
                continue
            if verse < 1 or verse > max_verse:
                errors.append(
                    f"{version_id}: verse {verse} out of range for {book}:{chapter} "
                    f"(max {max_verse})"
                )
            for issue in _validate_title_text(title):
                errors.append(f"{version_id}: {key}: {issue}")
        missing_vs_base = len(base_titles) - len(titles)
        print(
            f"{version_id}: {len(titles)} titles, {len(counts)} chapters scanned, "
            f"{missing_vs_base} skipped vs base"
        )

    if errors:
        print("\nValidation errors:")
        for issue in errors[:100]:
            print(f"- {issue}")
        raise SystemExit(1)

    print("\nValidation OK")
    sample_keys = ("1:1:1", "19:23:1", "40:5:1", "43:3:1", "49:6:10", "66:21:1")
    for key in sample_keys:
        print(f"\n{key}")
        for version_id in XML_PATHS:
            print(f"  {version_id}: {version_maps[version_id][key]}")


if __name__ == "__main__":
    main()

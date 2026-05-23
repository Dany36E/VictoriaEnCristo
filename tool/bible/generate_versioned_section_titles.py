#!/usr/bin/env python3
"""
Genera subtítulos originales por versión para la app.

Estos subtítulos NO copian encabezados editoriales de traducciones protegidas.
Se derivan de una base descriptiva propia y luego se adaptan por estilo para
RVR1960, NVI, NTV y TLA.
"""

from __future__ import annotations

import json
import re
from datetime import date
from pathlib import Path
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
BASE_PATH = ROOT / "assets" / "bible" / "section_titles.json"
OVERRIDES_PATH = ROOT / "assets" / "bible" / "section_title_overrides.json"

SUPPORTED_VERSIONS = ("RVR1960", "NVI", "NTV", "TLA")
XML_PATHS = {
    "RVR1960": ROOT / "assets" / "bible" / "Reina Valera 1960.xml",
    "NVI": ROOT / "assets" / "bible" / "NVI.xml",
    "NTV": ROOT / "assets" / "bible" / "NTV.xml",
    "TLA": ROOT / "assets" / "bible" / "TLA.xml",
}


def _load_base_titles() -> dict[str, str]:
    data = json.loads(BASE_PATH.read_text(encoding="utf-8"))
    return {key: value for key, value in data.items() if not key.startswith("_")}


def _sort_key(key: str) -> tuple[int, int, int]:
    book, chapter, verse = key.split(":")
    return int(book), int(chapter), int(verse)


def _clean(title: str) -> str:
    title = re.sub(r"\s+", " ", title).strip()
    return title[:1].upper() + title[1:] if title else title


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


def _replace_case_insensitive(text: str, old: str, new: str) -> str:
    return re.sub(re.escape(old), new, text, flags=re.IGNORECASE)


def _apply_common_rules(title: str) -> str:
    replacements = (
        ("Bet-el", "Betel"),
        ("Padán-aram", "Padán Aram"),
    )
    for old, new in replacements:
        title = _replace_case_insensitive(title, old, new)
    return _clean(title)


def _to_rvr1960(title: str, _key: str) -> str:
    return _apply_common_rules(title)


def _to_nvi(title: str, key: str) -> str:
    title = _apply_common_rules(title)
    exact = {
        "19:23:1": "El Señor es mi pastor",
        "49:6:10": "La armadura de Dios",
        "49:6:21": "Saludos finales",
    }
    if key in exact:
        return exact[key]
    pattern_rules = (
        (r"^El llamamiento de (.+)$", r"El llamado de \1"),
        (r"^Llamamiento de (.+)$", r"Llamado de \1"),
        (r"^Visión y llamamiento de (.+)$", r"Visión y llamado de \1"),
    )
    for pattern, replacement in pattern_rules:
        title = re.sub(pattern, replacement, title)
    replacements = (
        ("Sepultura", "Entierro"),
        ("Salutaciones", "Saludos"),
        ("Ayes", "Advertencias"),
        ("Jehová", "el Señor"),
        ("Vara de Aarón florece", "La vara de Aarón florece"),
        ("La conversión y la misericordia de Dios", "La restauración y la misericordia de Dios"),
        ("El Shemá: ama a Dios", "Ama al Señor con todo tu ser"),
    )
    for old, new in replacements:
        title = _replace_case_insensitive(title, old, new)
    return _clean(title)


def _to_ntv(title: str, key: str) -> str:
    title = _apply_common_rules(title)
    exact = {
        "1:37:1": "José y sus sueños",
        "2:20:1": "Los diez mandamientos",
        "19:23:1": "El Señor es mi pastor",
        "40:5:1": "Las enseñanzas de Jesús sobre la vida del reino",
        "43:3:1": "Jesús y Nicodemo",
        "49:6:10": "Toda la armadura de Dios",
        "49:6:21": "Saludos finales",
    }
    if key in exact:
        return exact[key]
    pattern_rules = (
        (r"^Muerte de (.+)$", r"Muere \1"),
        (r"^Nacimiento de (.+)$", r"Nace \1"),
        (r"^Muerte y sepultura de (.+)$", r"Muerte y entierro de \1"),
        (r"^El llamamiento de (.+)$", r"El llamado de \1"),
        (r"^Llamamiento de (.+)$", r"Dios llama a \1"),
        (r"^Llamamiento a (.+)$", r"Dios llama a \1"),
        (r"^Visión y llamamiento de (.+)$", r"Visión y llamado de \1"),
        (r"^Salutaciones finales$", "Saludos finales"),
    )
    for pattern, replacement in pattern_rules:
        title = re.sub(pattern, replacement, title)
    replacements = (
        ("Sepultura", "Entierro"),
        ("Ayes", "Advertencias"),
        ("Jehová", "el Señor"),
    )
    for old, new in replacements:
        title = _replace_case_insensitive(title, old, new)
    return _clean(title)


def _to_tla(title: str, key: str) -> str:
    title = _apply_common_rules(title)
    exact = {
        "1:1:1": "Dios crea todo",
        "1:3:1": "La primera desobediencia",
        "1:23:1": "Muere Sara y la entierran",
        "1:50:1": "Muere Jacob y lo entierran",
        "2:20:1": "Los diez mandamientos",
        "19:23:1": "Dios cuida de mí",
        "20:8:1": "La sabiduría llama",
        "23:6:1": "Dios llama a Isaías",
        "40:5:1": "Jesús enseña a sus discípulos",
        "40:6:5": "Jesús enseña a orar",
        "43:3:1": "Jesús y Nicodemo",
        "49:6:10": "La armadura que Dios nos da",
        "49:6:21": "Saludos finales",
    }
    if key in exact:
        return exact[key]
    pattern_rules = (
        (r"^Muerte de (.+)$", r"Muere \1"),
        (r"^Nacimiento de (.+)$", r"Nace \1"),
        (r"^Muerte y sepultura de (.+)$", r"Muerte y entierro de \1"),
        (r"^El llamamiento de (.+)$", r"Dios llama a \1"),
        (r"^Llamamiento de (.+)$", r"Dios llama a \1"),
        (r"^Llamamiento a (.+)$", r"Dios llama a \1"),
        (r"^Visión y llamamiento de (.+)$", r"Visión y llamado de \1"),
        (r"^Bendición de (.+) a sus hijos$", r"\1 bendice a sus hijos"),
        (r"^Salutaciones finales$", "Saludos finales"),
    )
    for pattern, replacement in pattern_rules:
        title = re.sub(pattern, replacement, title)
    replacements = (
        ("Sepultura", "Entierro"),
        ("Ayes", "Advertencias"),
        ("Jehová", "Dios"),
        ("El llamamiento a la santidad", "Dios nos llama a vivir en santidad"),
        ("Las bienaventuranzas", "La verdadera felicidad"),
        ("No améis al mundo", "No vivan como el mundo"),
    )
    for old, new in replacements:
        title = _replace_case_insensitive(title, old, new)
    return _clean(title)


TRANSFORMERS = {
    "RVR1960": _to_rvr1960,
    "NVI": _to_nvi,
    "NTV": _to_ntv,
    "TLA": _to_tla,
}


def _build_versions(
    base_titles: dict[str, str],
) -> tuple[dict[str, dict[str, str]], dict[str, list[str]]]:
    versions: dict[str, dict[str, str]] = {}
    skipped: dict[str, list[str]] = {}
    for version_id, transform in TRANSFORMERS.items():
        counts = _chapter_verse_counts(XML_PATHS[version_id])
        version_titles: dict[str, str] = {}
        version_skipped: list[str] = []
        for key, title in sorted(base_titles.items(), key=lambda item: _sort_key(item[0])):
            book, chapter, verse = _sort_key(key)
            max_verse = counts.get((book, chapter), 0)
            if verse < 1 or verse > max_verse:
                version_skipped.append(key)
                continue
            version_titles[key] = transform(title, key)
        versions[version_id] = version_titles
        skipped[version_id] = version_skipped
    return versions, skipped


def main() -> None:
    base_titles = _load_base_titles()
    version_titles, skipped = _build_versions(base_titles)
    payload: dict[str, object] = {
        "_meta": {
            "description": (
                "Subtítulos originales de navegación para la app. "
                "No copian encabezados editoriales protegidos; se generan a partir "
                "de una base descriptiva propia y se adaptan por estilo para cada versión."
            ),
            "version": 2,
            "keyFormat": "bookNumber:chapter:startVerse",
            "generatedAt": date.today().isoformat(),
            "supportedVersions": list(SUPPORTED_VERSIONS),
            "counts": {version_id: len(titles) for version_id, titles in version_titles.items()},
            "skippedKeys": skipped,
        }
    }
    payload.update(version_titles)
    OVERRIDES_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Base titles: {len(base_titles)}")
    for version_id in SUPPORTED_VERSIONS:
        print(f"{version_id}: {len(version_titles[version_id])}")
    print(f"Wrote {OVERRIDES_PATH}")


if __name__ == "__main__":
    main()

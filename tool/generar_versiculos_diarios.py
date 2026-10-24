"""Genera lib/data/versiculos_diarios_lista.dart (versículo del día).

Entrada: tool/versiculos_diarios.tsv  (tema, libro, capítulo, verso_ini, verso_fin)
Texto de respaldo: assets/bible/Reina Valera 1960.xml

Intercala los temas por rondas (orden de temas barajado con semilla fija en
cada ronda) para que dos días seguidos nunca repitan tema, tampoco al dar la
vuelta a la lista. Uso (desde la raíz del repo):

    python tool/generar_versiculos_diarios.py
"""

import random
import xml.etree.ElementTree as ET
from collections import OrderedDict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
TSV = RAIZ / "tool" / "versiculos_diarios.tsv"
XML = RAIZ / "assets" / "bible" / "Reina Valera 1960.xml"
SALIDA = RAIZ / "lib" / "data" / "versiculos_diarios_lista.dart"
TEMAS = [
    "esperanza", "gracia", "pureza", "fortaleza", "oracion", "identidad",
    "tentacion", "perdon", "paz", "fe", "amor", "victoria", "palabra", "gozo",
]


def cargar_biblia():
    biblia = {}
    for libro in ET.parse(XML).getroot().iter("book"):
        n = int(libro.get("number"))
        for cap in libro.iter("chapter"):
            c = int(cap.get("number"))
            for v in cap.iter("verse"):
                biblia[(n, c, int(v.get("number")))] = "".join(v.itertext()).strip()
    return biblia


def dart_str(texto):
    t = texto.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return f"'{t}'"


def main():
    biblia = cargar_biblia()
    por_tema = OrderedDict((t, []) for t in TEMAS)
    for linea in TSV.read_text(encoding="utf-8").splitlines():
        if not linea.strip():
            continue
        tema, libro, cap, vi, vf = linea.split("\t")
        libro, cap, vi, vf = int(libro), int(cap), int(vi), int(vf)
        partes = [biblia[(libro, cap, v)] for v in range(vi, vf + 1)]
        texto = " ".join(partes)
        texto = texto[0].upper() + texto[1:]
        por_tema[tema].append((libro, cap, vi, vf, tema, texto))

    rondas = max(len(v) for v in por_tema.values())
    rnd = random.Random(2026)
    orden = []
    for r in range(rondas):
        temas = [t for t in TEMAS if r < len(por_tema[t])]
        while True:
            rnd.shuffle(temas)
            if not orden or orden[-1][4] != temas[0]:
                break
        orden.extend(por_tema[t][r] for t in temas)
    # Al dar la vuelta (último día → primero) tampoco se repite tema.
    assert orden[-1][4] != orden[0][4]
    for a, b in zip(orden, orden[1:]):
        assert a[4] != b[4]

    lineas = [
        "// GENERADO por tool/generar_versiculos_diarios.py — no editar a mano.",
        "// Texto de respaldo: Reina-Valera 1960 (assets/bible).",
        "// ignore_for_file: lines_longer_than_80_chars",
        "",
        "import 'versiculos_diarios.dart';",
        "",
        "/// Versículos del día, en el orden de rotación (un día por entrada).",
        "const List<VersiculoDiario> versiculosDiarios = <VersiculoDiario>[",
    ]
    for libro, cap, vi, vf, tema, texto in orden:
        lineas.append(
            f"  VersiculoDiario({libro}, {cap}, {vi}, {vf}, TemaVersiculo.{tema}, {dart_str(texto)}),"
        )
    lineas.append("];")
    SALIDA.write_text("\n".join(lineas) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(orden)} versiculos -> {SALIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()

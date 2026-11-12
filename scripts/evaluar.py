#!/usr/bin/python3
"""Vuelve a transcribir todas tus correcciones guardadas y dice cuántas saldrían bien hoy.

Sirve para saber si un cambio de vocabulario o de reglas mejoró o empeoró.
Uso: evaluar.py [--detalle]
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comun  # noqa: E402


def normal(texto):
    """Compara palabras y mayúsculas; ignora puntuación y espacios."""
    return re.findall(r"\w+", texto, flags=re.UNICODE)


def main():
    detalle = "--detalle" in sys.argv
    casos = sorted(glob.glob(os.path.join(comun.DIR_CORRECCIONES, "*.json")))
    total = bien = 0
    for ruta in casos:
        caso = comun.leer_json(ruta, {})
        audio = caso.get("audio")
        if not audio or not os.path.exists(audio):
            continue
        total += 1
        _crudo, texto = comun.transcribir(audio)
        acierto = normal(texto) == normal(caso.get("corregido", ""))
        bien += acierto
        if detalle or not acierto:
            print(("BIEN  " if acierto else "MAL   ") + os.path.basename(ruta))
            if not acierto:
                print("   esperado: " + caso.get("corregido", ""))
                print("   salió:    " + texto)
    if total == 0:
        print("Todavía no hay correcciones guardadas con audio.")
        return 0
    print(json.dumps({"total": total, "bien": bien, "porcentaje": round(100 * bien / total)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

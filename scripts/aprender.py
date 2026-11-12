#!/usr/bin/python3
"""Convierte una corrección tuya en reglas.

Lee JSON por la entrada estándar.

  aprender.py proponer   {"final": lo que se pegó, "corregido": como debía quedar}
      → {"reemplazos": [{"de", "a"}], "vocabulario": [palabras nuevas]}

  aprender.py aplicar    {"crudo", "final", "corregido", "audio": ruta o null,
                          "reemplazos": [...], "vocabulario": [...]}
      → guarda las reglas elegidas y archiva la corrección con su audio
"""
import difflib
import json
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comun  # noqa: E402

MAX_PALABRAS = 5


def palabras(texto):
    return re.findall(r"\w+(?:[-'’]\w+)*", texto, flags=re.UNICODE)


def proponer(final, corregido):
    a, b = palabras(final), palabras(corregido)
    cotejo = difflib.SequenceMatcher(a=[p.lower() for p in a], b=[p.lower() for p in b], autojunk=False)
    reemplazos, vistos = [], set()
    for tipo, i1, i2, j1, j2 in cotejo.get_opcodes():
        if tipo != "replace" or i2 - i1 > MAX_PALABRAS or j2 - j1 > MAX_PALABRAS:
            continue
        de, hacia = " ".join(a[i1:i2]), " ".join(b[j1:j2])
        if de.lower() in vistos:
            continue
        vistos.add(de.lower())
        reemplazos.append({"de": de, "a": hacia})

    # Cambios solo de mayúsculas ("supabase" → "Supabase"): el cotejo los ve iguales.
    for tipo, i1, i2, j1, j2 in cotejo.get_opcodes():
        if tipo != "equal":
            continue
        for x, y in zip(a[i1:i2], b[j1:j2]):
            # La app decide cuáles vienen marcadas: una palabra común ("hola" → "Hola") sale sin marcar.
            if x != y and x.lower() not in vistos and not x[0].isupper() and y[0].isupper():
                vistos.add(x.lower())
                reemplazos.append({"de": x, "a": y})

    conocido = {v.lower() for v in comun.cargar_reglas()["vocabulario"]}
    vocabulario = []
    for r in reemplazos:
        if r["a"].lower() not in conocido and r["a"] not in vocabulario:
            vocabulario.append(r["a"])
    return {"reemplazos": reemplazos, "vocabulario": vocabulario}


def aplicar(datos):
    reglas = comun.cargar_reglas()
    por_origen = {r["de"].lower(): r for r in reglas["reemplazos"]}
    for nueva in datos.get("reemplazos", []):
        de, a = nueva.get("de", "").strip(), nueva.get("a", "").strip()
        if not de or not a or de == a:
            continue
        if de.lower() in por_origen:
            por_origen[de.lower()]["a"] = a
        else:
            regla = {"de": de, "a": a}
            reglas["reemplazos"].append(regla)
            por_origen[de.lower()] = regla
    conocido = {v.lower() for v in reglas["vocabulario"]}
    for palabra in datos.get("vocabulario", []):
        palabra = palabra.strip()
        if palabra and palabra.lower() not in conocido:
            reglas["vocabulario"].append(palabra)
            conocido.add(palabra.lower())
    comun.escribir_json(comun.RUTA_REGLAS, reglas)

    # Cada corrección se archiva con su audio: es el examen para medir cambios futuros.
    os.makedirs(comun.DIR_CORRECCIONES, exist_ok=True)
    marca = time.strftime("%Y%m%d-%H%M%S")
    audio = datos.get("audio")
    guardado = None
    if audio and os.path.exists(audio):
        guardado = os.path.join(comun.DIR_CORRECCIONES, marca + ".wav")
        shutil.copyfile(audio, guardado)
    comun.escribir_json(
        os.path.join(comun.DIR_CORRECCIONES, marca + ".json"),
        {
            "cuando": time.strftime("%Y-%m-%d %H:%M:%S"),
            "crudo": datos.get("crudo", ""),
            "final": datos.get("final", ""),
            "corregido": datos.get("corregido", ""),
            "audio": guardado,
        },
    )
    return {"ok": True, "reemplazos": len(reglas["reemplazos"]), "vocabulario": len(reglas["vocabulario"])}


def main():
    modo = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        datos = json.load(sys.stdin)
        if modo == "proponer":
            salida = proponer(datos.get("final", ""), datos.get("corregido", ""))
        elif modo == "aplicar":
            salida = aplicar(datos)
        else:
            salida = {"error": "uso: aprender.py proponer|aplicar  (JSON por la entrada estándar)"}
    except Exception as e:
        salida = {"error": str(e)}
    print(json.dumps(salida, ensure_ascii=False))
    return 1 if "error" in salida else 0


if __name__ == "__main__":
    sys.exit(main())

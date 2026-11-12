#!/usr/bin/python3
"""Transcribe un audio con Whisper local, tu vocabulario y tus reglas.

Uso: transcribir.py <audio.wav>
Imprime JSON: {"crudo": lo que oyó Whisper, "texto": lo que se pega, "segundos": cuánto tardó}
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comun  # noqa: E402


def main():
    if len(sys.argv) != 2:
        print(json.dumps({"error": "uso: transcribir.py <audio.wav>"}))
        return 2
    inicio = time.time()
    try:
        crudo, texto = comun.transcribir(sys.argv[1])
    except Exception as e:  # el error viaja a la app, que lo muestra
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        return 1
    config = comun.cargar_config()
    if texto and config.get("espacio_final"):
        texto += " "
    resultado = {"crudo": crudo, "texto": texto, "segundos": round(time.time() - inicio, 2)}
    if texto.strip():
        try:
            os.makedirs(comun.DIR, exist_ok=True)
            with open(comun.RUTA_HISTORIAL, "a", encoding="utf-8") as f:
                f.write(json.dumps({"cuando": time.strftime("%Y-%m-%d %H:%M:%S"), **resultado}, ensure_ascii=False) + "\n")
        except OSError:
            pass
    print(json.dumps(resultado, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

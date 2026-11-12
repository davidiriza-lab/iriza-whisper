"""Piezas compartidas del dictado: rutas, configuración, reglas y limpieza de texto.

Solo biblioteca estándar; compatible con el Python 3.9 que trae macOS.
"""
import json
import os
import re
import shutil
import subprocess

# IRIZA_WHISPER_DIR permite probar con una carpeta de datos aparte, sin tocar la real.
DIR = os.environ.get("IRIZA_WHISPER_DIR") or os.path.expanduser("~/.config/iriza-whisper")
RUTA_CONFIG = os.path.join(DIR, "config.json")
RUTA_REGLAS = os.path.join(DIR, "reglas.json")
DIR_CORRECCIONES = os.path.join(DIR, "correcciones")

CONFIG_BASE = {
    "whisper": "/opt/homebrew/bin/whisper-cli",
    "modelo": os.path.expanduser("~/.cache/whisper-cpp/ggml-large-v3-turbo.bin"),
    "modelo_vad": os.path.expanduser("~/.cache/whisper-cpp/ggml-silero-v5.1.2.bin"),
    "idioma": "es",
    "hilos": 4,
    "espacio_final": True,
}

# Whisper recibe el vocabulario como "texto previo". Solo le caben unas 220 fichas,
# así que se corta por caracteres; lo primero de la lista es lo que nunca se pierde.
MAX_VOCABULARIO = 700

# Frases que Whisper inventa cuando solo hay silencio o ruido.
INVENTOS = [
    "subtítulos realizados por la comunidad de amara.org",
    "subtítulos por la comunidad de amara.org",
    "subtitulado por la comunidad de amara.org",
    "gracias por ver el video",
    "gracias por ver el vídeo",
    "¡gracias por ver el video!",
    "suscríbete al canal",
    "¡suscríbete!",
    "gracias.",
    "gracias",
]


def leer_json(ruta, base):
    try:
        with open(ruta, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return base


def escribir_json(ruta, datos):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    tmp = ruta + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, ruta)


def cargar_config():
    config = dict(CONFIG_BASE)
    config.update(leer_json(RUTA_CONFIG, {}))
    if not os.path.exists(config["whisper"]):
        # Homebrew vive en /opt/homebrew (chip Apple) o en /usr/local (Intel).
        for candidato in ("/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli", shutil.which("whisper-cli")):
            if candidato and os.path.exists(candidato):
                config["whisper"] = candidato
                break
    return config


def cargar_reglas():
    reglas = leer_json(RUTA_REGLAS, {})
    reglas.setdefault("vocabulario", [])
    reglas.setdefault("reemplazos", [])
    return reglas


def armar_prompt(vocabulario):
    """Frase de vocabulario para Whisper, recortada a lo que le cabe."""
    elegidas, largo = [], 0
    for palabra in vocabulario:
        palabra = palabra.strip()
        if not palabra:
            continue
        if largo + len(palabra) + 2 > MAX_VOCABULARIO:
            break
        elegidas.append(palabra)
        largo += len(palabra) + 2
    if not elegidas:
        return ""
    return "Vocabulario: " + ", ".join(elegidas) + "."


def aplicar_reemplazos(texto, reemplazos):
    """Cambia cada 'de' por su 'a': palabra o frase completa, sin importar mayúsculas."""
    # Las frases largas primero, para que "David Irisa" gane sobre "Irisa".
    for regla in sorted(reemplazos, key=lambda r: -len(r.get("de", ""))):
        de, a = regla.get("de", "").strip(), regla.get("a", "")
        if not de:
            continue
        patron = r"(?<!\w)" + re.escape(de).replace(r"\ ", r"\s+") + r"(?!\w)"
        texto = re.sub(patron, lambda _m, a=a: a, texto, flags=re.IGNORECASE)
    return texto


def limpiar_crudo(texto, prompt=""):
    """Quita marcas de no-voz, el eco del vocabulario y las frases inventadas."""
    texto = re.sub(r"\[[^\]]*\]|\([^)]*\)|\*[^*]*\*", " ", texto)  # [MÚSICA], (risas), *suspiro*
    texto = " ".join(texto.split())
    if prompt and texto.startswith(prompt):
        texto = texto[len(prompt):].strip()
    if texto.lower().startswith("vocabulario:"):
        return ""
    if texto.lower().strip(" .!¡") in {i.strip(" .!¡") for i in INVENTOS}:
        return ""
    return texto


def transcribir(ruta_audio, config=None, reglas=None):
    """Devuelve (crudo, texto): lo que oyó Whisper y lo que queda tras las reglas."""
    config = config or cargar_config()
    reglas = reglas or cargar_reglas()
    if not os.path.exists(config["whisper"]):
        raise RuntimeError("no encuentro whisper-cli: instálalo con 'brew install whisper.cpp'")
    if not os.path.exists(config["modelo"]):
        raise RuntimeError("falta el modelo de Whisper en " + config["modelo"] + ": corre ./instalar.sh")
    prompt = armar_prompt(reglas["vocabulario"])
    orden = [
        config["whisper"], "-m", config["modelo"], "-l", config["idioma"],
        "-t", str(config["hilos"]), "-nt", "-np", "-sns", "-f", ruta_audio,
    ]
    if prompt:
        orden += ["--prompt", prompt, "--carry-initial-prompt"]
    if config.get("modelo_vad") and os.path.exists(config["modelo_vad"]):
        orden += ["--vad", "-vm", config["modelo_vad"]]
    salida = subprocess.run(orden, capture_output=True, text=True, timeout=300)
    if salida.returncode != 0:
        raise RuntimeError("whisper-cli falló: " + salida.stderr.strip()[-400:])
    crudo = limpiar_crudo(salida.stdout, prompt)
    texto = aplicar_reemplazos(crudo, reglas["reemplazos"])
    return crudo, texto

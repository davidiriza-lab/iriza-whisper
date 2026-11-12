#!/bin/bash
# Instala o actualiza Iriza Whisper.
#
#   ./instalar.sh                 revisa requisitos, compila la app, la instala y la abre
#   ./instalar.sh --revisar       solo dice qué falta y cómo instalarlo; no toca nada
#   ./instalar.sh --solo-scripts  actualiza solo el motor (Python); no recompila la app
#   ./instalar.sh --solo-compilar compila en build/ sin instalar
#
# No instala nada por su cuenta: si falta algo, imprime el comando y se detiene.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${IRIZA_WHISPER_DIR:-$HOME/.config/iriza-whisper}"
APP="/Applications/Iriza Whisper.app"
AGENTE="$HOME/Library/LaunchAgents/com.davidiriza.irizawhisper.plist"
MODELOS="$HOME/.cache/whisper-cpp"
MODELO="$MODELOS/ggml-large-v3-turbo.bin"
MODELO_VAD="$MODELOS/ggml-silero-v5.1.2.bin"
MODO="${1:-}"

revisar() {
	local falta=0
	if [ "$(uname)" != "Darwin" ]; then
		echo "FALTA  Iriza Whisper solo funciona en macOS."
		return 1
	fi
	if xcrun --find swiftc >/dev/null 2>&1; then
		echo "OK     Compilador de Swift"
	else
		echo "FALTA  Compilador de Swift. Instálalo con:  xcode-select --install"
		falta=1
	fi
	if [ -x /opt/homebrew/bin/whisper-cli ] || [ -x /usr/local/bin/whisper-cli ] || command -v whisper-cli >/dev/null 2>&1; then
		echo "OK     whisper-cli"
	else
		echo "FALTA  whisper-cli. Instálalo con:  brew install whisper-cpp"
		falta=1
	fi
	if [ -f "$MODELO" ]; then
		echo "OK     Modelo de Whisper (large-v3-turbo)"
	else
		echo "FALTA  Modelo de Whisper (1.6 GB, se baja una vez). Descárgalo con:"
		echo "         mkdir -p \"$MODELOS\" && curl -L --fail -o \"$MODELO\" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
		falta=1
	fi
	if [ -f "$MODELO_VAD" ]; then
		echo "OK     Detector de voz (evita que invente texto en los silencios)"
	else
		echo "FALTA  Detector de voz (menos de 1 MB). Descárgalo con:"
		echo "         mkdir -p \"$MODELOS\" && curl -L --fail -o \"$MODELO_VAD\" https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin"
		falta=1
	fi
	return $falta
}

instalar_motor() {
	mkdir -p "$CONFIG/bin" "$CONFIG/correcciones"
	cp "$RAIZ"/scripts/*.py "$CONFIG/bin/"
	[ -f "$CONFIG/reglas.json" ] || cp "$RAIZ/reglas.inicial.json" "$CONFIG/reglas.json"
	echo "Motor actualizado en $CONFIG/bin"
}

if [ "$MODO" = "--revisar" ]; then
	revisar
	exit $?
fi
if [ "$MODO" = "--solo-scripts" ]; then
	instalar_motor
	exit 0
fi
if ! revisar; then
	echo
	echo "Instala lo que falta y vuelve a correr ./instalar.sh"
	exit 1
fi
instalar_motor

CONSTRUIDA="$RAIZ/build/Iriza Whisper.app"
rm -rf "$RAIZ/build"
mkdir -p "$CONSTRUIDA/Contents/MacOS" "$CONSTRUIDA/Contents/Resources"
cp "$RAIZ/app/Info.plist" "$CONSTRUIDA/Contents/Info.plist"
xcrun swiftc -O -swift-version 5 -o "$CONSTRUIDA/Contents/MacOS/IrizaWhisper" "$RAIZ/app/main.swift" \
	-framework Cocoa -framework AVFoundation

# Icono: la propia app lo dibuja y aquí se arma en los tamaños que pide macOS.
ICONOS="$RAIZ/build/Icono.iconset"
mkdir -p "$ICONOS"
"$CONSTRUIDA/Contents/MacOS/IrizaWhisper" --icono "$RAIZ/build/icono-1024.png"
for lado in 16 32 128 256 512; do
	sips -z $lado $lado "$RAIZ/build/icono-1024.png" --out "$ICONOS/icon_${lado}x${lado}.png" >/dev/null
	doble=$((lado * 2))
	sips -z $doble $doble "$RAIZ/build/icono-1024.png" --out "$ICONOS/icon_${lado}x${lado}@2x.png" >/dev/null
done
iconutil -c icns "$ICONOS" -o "$CONSTRUIDA/Contents/Resources/Icono.icns"

# Firma con un requisito fijo (solo el identificador) en lugar del predeterminado, que cambia
# con cada compilación. La idea es que macOS conserve los permisos entre versiones.
codesign --force --sign - --identifier com.davidiriza.irizawhisper \
	-r='designated => identifier "com.davidiriza.irizawhisper"' "$CONSTRUIDA" 2>/dev/null
echo "App compilada"

if [ "$MODO" = "--solo-compilar" ]; then
	exit 0
fi

# Cierra la que esté corriendo, reemplaza y abre.
pkill -x IrizaWhisper 2>/dev/null || true
rm -rf "$APP"
cp -R "$CONSTRUIDA" "$APP"

# Que se abra sola al iniciar sesión.
mkdir -p "$(dirname "$AGENTE")"
cat > "$AGENTE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.davidiriza.irizawhisper</string>
	<key>ProgramArguments</key>
	<array><string>/usr/bin/open</string><string>-g</string><string>$APP</string></array>
	<key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST

open -g "$APP"
echo "Instalada y abierta: $APP"
echo
echo "La primera vez macOS pide dos permisos: Micrófono y Accesibilidad."
echo "Accesibilidad se activa en Ajustes del Sistema → Privacidad y seguridad → Accesibilidad."

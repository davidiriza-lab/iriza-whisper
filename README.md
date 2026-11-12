# Iriza Whisper

Dictado para Mac que corre en tu computadora y aprende tus palabras. Mantienes **⌘ derecho**, hablas, sueltas, y el texto se pega donde está el cursor, en cualquier app.

- **Local:** usa Whisper (large-v3-turbo) en tu Mac. El audio no sale de ella y no hay cuenta ni suscripción.
- **Con tu vocabulario:** le das la lista de nombres, marcas y términos que usas, y deja de escribirlos mal.
- **Aprende de tus correcciones:** cuando algo sale mal lo arreglas una vez y se vuelve regla.

Guía completa: https://www.davidiriza.com/lab/dictado-propio-con-whisper

## Instalar

Necesitas una Mac con chip Apple, [Homebrew](https://brew.sh) y unos 2 GB libres.

**Opción 1, pídeselo a Claude Code:**

```
Lee https://raw.githubusercontent.com/davidiriza-lab/iriza-whisper/main/INSTALAR.md y sigue sus pasos.
```

**Opción 2, a mano:**

```bash
git clone https://github.com/davidiriza-lab/iriza-whisper.git
cd iriza-whisper
./instalar.sh --revisar   # dice qué falta y el comando exacto para instalarlo
./instalar.sh             # compila la app, la instala en /Applications y la abre
```

El instalador no instala nada por su cuenta: si falta el compilador, `whisper-cli` o el modelo (1.6 GB), imprime el comando y se detiene.

La primera vez macOS pide dos permisos: **Micrófono** (para grabar) y **Accesibilidad** (para escuchar la tecla ⌘ derecho y pegar el texto). Accesibilidad se activa en Ajustes del Sistema → Privacidad y seguridad → Accesibilidad.

## Uso

| Gesto | Qué pasa |
|---|---|
| Mantener ⌘ derecho | Graba. Al soltar, transcribe y pega donde esté el cursor |
| Doble toque de ⌘ derecho | Abre «Corregir lo último» |
| ⌘ derecho + otra tecla | Nada: se trata como un atajo normal y la grabación se descarta |

Mientras grabas aparece una cápsula con ondas que siguen tu voz y el tiempo transcurrido. El icono de micrófono en la barra de menús trae «Corregir lo último», «Copiar el último dictado», «Abrir vocabulario y reglas», «Pausar dictado» y «Salir».

### A dónde va el texto

| Lo que macOS dice del cursor | Qué hace |
|---|---|
| Está en una casilla de texto | Pega y te devuelve lo que tenías copiado |
| Está en otra cosa (una lista de Finder, un botón) | No pega: el dictado queda en el portapapeles y sale un aviso |
| No se puede saber (VS Code, Chrome, WhatsApp y otras apps que no lo informan) | Pega y además lo deja en el portapapeles, para que nunca se pierda |

## Cómo aprende

No se reentrena el modelo. Lo que mejora son dos listas en `~/.config/iriza-whisper/reglas.json`:

- **`vocabulario`**: palabras que Whisper recibe antes de cada dictado. Le caben unos 700 caracteres; lo que esté primero en la lista es lo que nunca se recorta. Empieza poniendo tu nombre, tu empresa y las herramientas que más nombras.
- **`reemplazos`**: «si sale *X*, escribir *Y*». Se aplican después de transcribir, a palabra o frase completa y sin importar mayúsculas.

Puedes editar el archivo a mano (surte efecto en el siguiente dictado) o dejar que la app lo llene:

1. Doble toque de ⌘ derecho después de un dictado que salió mal.
2. Deja el texto como debía quedar y guarda con ⌘↩.
3. La app compara y propone las reglas. Vienen marcadas las palabras que no existen en español («Berzel», «su pavase»); las palabras normales que solo esa vez salieron mal («casa» por «caza») vienen sin marcar, para que una regla no rompa otros dictados.

Cada corrección se guarda con su audio en `~/.config/iriza-whisper/correcciones/`. Con eso puedes medir si un cambio de reglas mejoró o empeoró:

```bash
python3 ~/.config/iriza-whisper/bin/evaluar.py
```

Vuelve a transcribir todas tus correcciones guardadas y dice cuántas saldrían bien hoy.

## Otro idioma u otro modelo

Crea `~/.config/iriza-whisper/config.json` con lo que quieras cambiar:

```json
{ "idioma": "en", "modelo": "/ruta/a/otro-modelo.bin" }
```

Las llaves disponibles están en `CONFIG_BASE`, en `scripts/comun.py`. La revisión de palabras «normales» al corregir está hecha para español.

## Piezas

| Pieza | Dónde | Qué hace |
|---|---|---|
| App (Swift, un archivo) | `app/main.swift` → `/Applications/Iriza Whisper.app` | Atajo global, grabación, cápsula, pegado y ventana de corrección |
| Motor (Python, sin dependencias) | `scripts/` → `~/.config/iriza-whisper/bin/` | Llama a Whisper, aplica vocabulario y reglas, aprende de las correcciones |
| Datos | `~/.config/iriza-whisper/` | `reglas.json`, `config.json` (opcional), `historial.jsonl`, `correcciones/`, `app.log` |

Para actualizar: `git pull && ./instalar.sh`. Si solo cambió el motor, `./instalar.sh --solo-scripts` no recompila. La app se firma con un requisito fijo para que macOS conserve los permisos entre versiones; si después de actualizar la tecla deja de responder, quita «Iriza Whisper» de la lista de Accesibilidad y vuelve a activarla.

## Pruebas

```bash
B="/Applications/Iriza Whisper.app/Contents/MacOS/IrizaWhisper"
"$B" --prueba audio.wav      # la app alcanza al motor y transcribe
"$B" --autoprueba            # graba 2 s del micrófono y transcribe, sin teclado ni pegado
"$B" --prueba-aviso          # recorre los estados de la cápsula y falla si el dibujo se desfasa
"$B" --destino               # dice cómo clasifica la app que tienes al frente
"$B" --fotos carpeta         # guarda una hoja con todos los estados de la cápsula
```

## Límites conocidos

- Probada en una Mac con chip Apple (M5) y macOS 26. En Intel debería compilar, pero la transcripción será lenta.
- Cada dictado tarda de 1.5 a 2 segundos en transcribirse, dure lo que dure, porque el modelo se carga cada vez.
- El primer cuarto de segundo tras oprimir ⌘ derecho puede no grabarse; empieza a hablar un instante después.
- En las apps que no informan dónde está el cursor (VS Code, Chrome) pierdes lo que tenías copiado antes de dictar.
- La tecla es ⌘ derecho y no se puede cambiar sin editar `app/main.swift`.
- `historial.jsonl` guarda el texto de todo lo dictado, solo en tu Mac. Se puede borrar cuando quieras.

## Desinstalar

```bash
pkill -x IrizaWhisper
rm -rf "/Applications/Iriza Whisper.app" ~/Library/LaunchAgents/com.davidiriza.irizawhisper.plist
rm -rf ~/.config/iriza-whisper   # borra también tu vocabulario, reglas e historial
```

## Licencia

MIT. Hecha por [David Iriza](https://www.davidiriza.com/lab). No está afiliada a OpenAI; Whisper es un modelo de OpenAI y aquí corre con [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

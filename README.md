# Iriza Whisper

Dictado para Mac que corre en tu computadora y aprende tus palabras. Mantienes **⌘ derecho**, hablas, sueltas, y el texto se pega donde está el cursor, en cualquier app.

- **Local:** usa Whisper (large-v3-turbo) en tu Mac. El audio no sale de ella y no hay cuenta ni suscripción.
- **Con tu vocabulario:** le das la lista de nombres, marcas y términos que usas, y deja de escribirlos mal.
- **Aprende de tus correcciones:** cuando algo sale mal lo arreglas una vez y se vuelve regla.

Es para quien dicta mucho (a Claude, en WhatsApp, en correos) y ya se cansó de que el dictado escriba mal su apellido, su empresa o las herramientas que nombra todos los días. No necesitas saber programar: Claude Code la instala por ti.

## Instalar: pega esto en Claude Code

```
Lee https://raw.githubusercontent.com/davidiriza-lab/iriza-whisper/main/INSTALAR.md y sigue sus pasos para instalar Iriza Whisper en mi Mac. Enséñame cada cosa que falte y pídeme permiso antes de instalarla. Al terminar, pregúntame mis palabras para dejarme listo el vocabulario.
```

Claude descarga el repo, revisa qué te falta, te pide permiso antes de instalar cada cosa, compila la app y al final te pregunta tus palabras. Lo más tardado es bajar el modelo (1.6 GB, una sola vez).

La primera vez macOS pide dos permisos, y solo tú puedes darlos:

1. **Micrófono**, para grabar. Sale como aviso: acepta.
2. **Accesibilidad**, para escuchar la tecla ⌘ derecho y pegar el texto. Este no sale como aviso: se activa en Ajustes del Sistema → Privacidad y seguridad → Accesibilidad.

En cuanto activas el segundo, abajo en la pantalla aparece «Listo: mantén ⌘ derecho para dictar».

### Sin Claude Code, a mano

```bash
git clone https://github.com/davidiriza-lab/iriza-whisper.git
cd iriza-whisper
./instalar.sh --revisar   # dice qué falta y el comando exacto para instalarlo
./instalar.sh             # compila la app, la instala en /Applications y la abre
```

El instalador no instala nada por su cuenta: si falta el compilador, `whisper-cli` o el modelo, imprime el comando y se detiene.

## Qué necesitas

- **Una Mac con chip Apple.** Está probada en una sola computadora: chip M5 y macOS 26. La app pide macOS 13 o más nuevo, pero en versiones anteriores a la 26 no está probada.
- **[Homebrew](https://brew.sh)**, para instalar whisper.cpp.
- **Las herramientas de línea de comandos de Apple** (`xcode-select --install`). Traen el compilador de Swift y el Python que usa el motor.
- **whisper.cpp** (`brew install whisper.cpp`), el programa que corre Whisper en tu Mac.
- **Unos 2 GB libres:** el modelo de Whisper pesa 1.6 GB y el detector de voz menos de 1 MB.

Opcional:

- **Claude Code**, para que la instale por ti. A mano son los cuatro comandos de arriba.
- **`config.json`**, solo si quieres otro idioma, otro modelo o cambiar un ajuste (ver «Ajustes»).

No hace falta cuenta ni llave de ningún servicio. Después de instalar funciona sin internet.

## Cómo se usa

| Gesto | Qué pasa |
|---|---|
| Mantener ⌘ derecho | Graba. Al soltar, transcribe y pega donde esté el cursor |
| Doble toque de ⌘ derecho | Abre «Corregir lo último». Cada toque dura menos de medio segundo y el segundo llega antes de un segundo |
| ⌘ derecho + otra tecla | Nada: se trata como un atajo normal y la grabación se descarta |

Mientras grabas aparece una cápsula con ondas que siguen tu voz y el tiempo transcurrido. Al soltar, la cápsula muestra una onda mientras transcribe. No hace falta esperarla: puedes empezar el siguiente dictado y los textos salen en orden.

El icono de micrófono en la barra de menús trae «Corregir lo último», «Copiar el último dictado», «Abrir vocabulario y reglas», «Pausar dictado» y «Salir».

### A dónde va el texto

| Lo que macOS dice del cursor | Qué hace |
|---|---|
| Está en una casilla de texto | Pega y te devuelve lo que tenías copiado |
| Está en otra cosa (una lista de Finder, un botón) | No pega: el dictado queda en el portapapeles y sale un aviso |
| No se puede saber (VS Code, Chrome, WhatsApp y otras apps que no lo informan) | Pega y además lo deja en el portapapeles, para que nunca se pierda |

### Cómo aprende

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

## Qué trae

| Pieza | Dónde | Qué hace |
|---|---|---|
| App (Swift, un archivo) | `app/main.swift` → `/Applications/Iriza Whisper.app` | Atajo global, grabación, cápsula, pegado y ventana de corrección |
| Motor (Python, sin dependencias) | `scripts/` → `~/.config/iriza-whisper/bin/` | Llama a Whisper, aplica vocabulario y reglas, aprende de las correcciones |
| Datos | `~/.config/iriza-whisper/` | `reglas.json`, `config.json` (opcional), `correcciones/`, `ultimo.wav`, `app.log` |
| Instalador | `instalar.sh` | Revisa requisitos, compila, instala y deja la app abriéndose sola al iniciar sesión |
| Instrucciones para un agente | `INSTALAR.md` | Lo que lee Claude Code cuando le pegas el encargo de arriba |
| Vocabulario de arranque | `reglas.inicial.json` | Una lista genérica que se copia la primera vez; la tuya nunca se sobrescribe |

### Qué ocupa y qué deja

- **En reposo:** unos 14 MB de memoria y 0 % de procesador. El modelo de Whisper (1.6 GB) solo se carga durante los uno o dos segundos que dura cada transcripción y se suelta al terminar. No queda ningún proceso de fondo aparte de la app.
- **Lo que dictas no se guarda.** No hay historial: el texto solo existe donde lo pegaste.
- **Audio:** se conserva únicamente el último dictado (`ultimo.wav`, se sobrescribe con el siguiente y se borra al cerrar la app), porque hace falta si decides corregirlo. Los dictados que esperan su turno viven unos segundos en la carpeta temporal del sistema; si alguno se queda ahí, se borra al cerrar la app y al volver a abrirla.
- **Lo que sí se acumula, porque tú lo pides:** cada corrección que guardas, con su audio, en `correcciones/`. Bórralas cuando quieras; solo pierdes el examen de `evaluar.py`.
- **Bitácora:** `app.log` anota qué pasó y cuándo: duraciones, volumen, el nombre del micrófono y el de la app donde se pegó. Nunca el texto. Se recorta sola a unas 200 líneas.

### Ajustes

Crea `~/.config/iriza-whisper/config.json` con lo que quieras cambiar. Surte efecto en el siguiente dictado:

```json
{ "idioma": "en", "modelo": "/ruta/a/otro-modelo.bin" }
```

| Llave | De fábrica | Qué hace |
|---|---|---|
| `idioma` | `es` | Idioma en que dictas |
| `modelo` | large-v3-turbo | Ruta a otro modelo de whisper.cpp |
| `vad_margen_ms` | `300` | Milisegundos que se dejan antes y después de la voz detectada. Súbelo si a los dictados de una o dos palabras les falta el principio o el final |
| `hilos` | `4` | Hilos de procesador que usa Whisper |

Todas las llaves están en `CONFIG_BASE`, en `scripts/comun.py`. La revisión de palabras «normales» al corregir está hecha para español.

### Actualizar

`git pull && ./instalar.sh`. Si solo cambió el motor, `./instalar.sh --solo-scripts` no recompila. La app se firma con un requisito fijo para que macOS conserve los permisos entre versiones.

### Pruebas

```bash
B="/Applications/Iriza Whisper.app/Contents/MacOS/IrizaWhisper"
"$B" --prueba audio.wav      # la app alcanza al motor y transcribe
"$B" --autoprueba            # graba 2 s del micrófono y transcribe, sin teclado ni pegado
"$B" --autoprueba-doble      # igual, pero empieza un segundo dictado mientras el primero se transcribe
"$B" --prueba-sello          # la app reconoce como propia la tecla que manda al pegar (ábrela con `open`)
"$B" --prueba-aviso          # recorre los estados de la cápsula y falla si el dibujo se desfasa
"$B" --destino               # dice cómo clasifica la app que tienes al frente
"$B" --fotos carpeta         # guarda una hoja con todos los estados de la cápsula
```

### Desinstalar

```bash
pkill -x IrizaWhisper
rm -rf "/Applications/Iriza Whisper.app" ~/Library/LaunchAgents/com.davidiriza.irizawhisper.plist
rm -rf ~/.config/iriza-whisper   # borra también tu vocabulario, tus reglas y tus correcciones
```

El modelo queda en `~/.cache/whisper-cpp/`; bórralo también si no lo usas en otra cosa.

## Si algo falla

Lo primero es ver el icono de la barra de menús y las últimas líneas de la bitácora (o pedirle a Claude Code que las lea):

```bash
tail -20 ~/.config/iriza-whisper/app.log
```

| Qué ves | Qué pasa y qué hacer |
|---|---|
| La tecla no hace nada y el micrófono del menú sale tachado | Falta el permiso de Accesibilidad. Abre el menú del icono → «Abrir Accesibilidad en Ajustes…» y activa «Iriza Whisper» |
| La tecla dejó de responder después de actualizar | macOS dejó de reconocer el permiso. En Accesibilidad quita «Iriza Whisper» de la lista (botón −) y vuelve a activarla |
| La tecla no hace nada y el icono es un círculo con pausa | El dictado está en pausa. Menú → «Reanudar dictado» |
| La tecla no responde después de que la Mac durmió | La app vuelve a poner el atajo sola cada vez que la Mac despierta. Si aun así no responde, menú → «Salir» y ábrela otra vez desde Aplicaciones |
| «No pude grabar: revisa el permiso de micrófono» | Ajustes del Sistema → Privacidad y seguridad → Micrófono, y activa «Iriza Whisper» |
| «No escuché nada» | El micrófono grabó silencio o muy bajo. Revisa cuál está elegido en Ajustes del Sistema → Sonido → Entrada (pasa al conectar o soltar unos audífonos). La bitácora anota en cada dictado el volumen máximo y el nombre del micrófono; el silencio ronda los −55 dB |
| «No escuché nada» en dictados de una o dos palabras | Es donde Whisper más falla. La app ya deja un margen alrededor de la voz y, si Whisper contesta con una frase de relleno, repite una vez sin el vocabulario. Si te sigue pasando, sube `vad_margen_ms` (ver «Ajustes») |
| Escribió una frase que no dijiste | Whisper inventa frases cuando casi no hay voz. Las más comunes («Gracias por ver el video») ya se descartan solas; si te sale otra, revisa que el detector de voz esté instalado con `./instalar.sh --revisar` |
| «El micrófono no alcanzó a grabar: inténtalo otra vez» | El micrófono tardó en arrancar y casi no grabó. Vuelve a dictar |
| «Mantén ⌘ derecho mientras hablas» | Fue un toque, no un dictado: la tecla sí responde. Mantenla oprimida todo el tiempo que hables |
| La grabación se cortó a media frase | Oprimiste otra tecla mientras mantenías ⌘ derecho y se trató como atajo. La bitácora dice «grabación descartada» y el motivo |
| «Copiado: pega con ⌘V donde lo necesites» | El cursor no estaba en una casilla de texto. El dictado está en tu portapapeles |
| «Falló la transcripción (ver app.log)» | La bitácora trae el error. Casi siempre falta `whisper-cli` o el modelo, o whisper.cpp es viejo: `./instalar.sh --revisar` y `brew upgrade whisper.cpp` |
| Escribe mal siempre la misma palabra | Doble toque de ⌘ derecho, corrígela y guarda la regla |

### Límites conocidos

- Probada en una Mac con chip Apple (M5) y macOS 26. En Intel debería compilar, pero la transcripción será lenta.
- Cada dictado tarda de 1.5 a 2 segundos en transcribirse, dure lo que dure, porque el modelo se carga cada vez. Cuando hace falta el segundo intento, el doble. No hace falta esperarlo: puedes empezar el siguiente y los textos salen en orden.
- El primer cuarto de segundo tras oprimir ⌘ derecho puede no grabarse; empieza a hablar un instante después.
- En las apps que no informan dónde está el cursor (VS Code, Chrome) pierdes lo que tenías copiado antes de dictar.
- Una grabación se cierra sola a los 10 minutos.
- La tecla es ⌘ derecho y no se puede cambiar sin editar `app/main.swift`.

## Guía completa

https://davidiriza.com/lab/dictado-propio-con-whisper

Por qué el dictado escribe mal tus palabras, cómo se instala y se usa paso a paso, y qué límites tiene.

## Licencia

MIT. Hecha por [David Iriza](https://www.davidiriza.com/lab). No está afiliada a OpenAI; Whisper es un modelo de OpenAI y aquí corre con [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

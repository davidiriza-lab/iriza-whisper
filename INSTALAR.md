# Instalar Iriza Whisper

Instrucciones para Claude Code (o cualquier agente con terminal) en una Mac. Síguelas en orden. No instales nada sin enseñarle antes el comando a la persona y esperar su permiso.

## 1. Clona el repo

```bash
git clone https://github.com/davidiriza-lab/iriza-whisper.git ~/iriza-whisper
cd ~/iriza-whisper
```

Si la persona tiene una carpeta de proyectos, clónalo ahí en lugar de en su carpeta de inicio.

Si la carpeta ya existe porque lo instaló antes, no la clones otra vez: entra a ella y corre `git pull`.

## 2. Revisa qué falta

```bash
./instalar.sh --revisar
```

Imprime una línea por requisito, con `OK` o `FALTA`, y debajo de cada `FALTA` el comando exacto para instalarlo. Los requisitos son:

- El compilador de Swift (`xcode-select --install`; abre una ventana del sistema que la persona debe aceptar).
- `whisper-cli` (`brew install whisper.cpp`). Si no hay Homebrew, dile que lo instale desde https://brew.sh.
- El modelo de Whisper, 1.6 GB. Avísale el tamaño antes de bajarlo.
- El detector de voz, menos de 1 MB.

Enséñale lo que falta, pide permiso y corre cada comando. Repite `./instalar.sh --revisar` hasta que todo diga `OK`.

## 3. Instala

```bash
./instalar.sh
```

Compila la app, la copia a `/Applications/Iriza Whisper.app`, la deja para abrirse al iniciar sesión y la abre. Tarda menos de un minuto.

## 4. Permisos

Dile esto a la persona, porque solo ella puede hacerlo:

> macOS te va a pedir dos permisos para «Iriza Whisper»:
> 1. **Micrófono:** acepta el aviso.
> 2. **Accesibilidad:** abre Ajustes del Sistema → Privacidad y seguridad → Accesibilidad y activa «Iriza Whisper». Lo necesita para escuchar la tecla ⌘ derecho y pegar el texto.
>
> Cuando lo actives, abajo en la pantalla sale «Listo: mantén ⌘ derecho para dictar».

Puedes confirmar que ya lo dio con:

```bash
tail -3 ~/.config/iriza-whisper/app.log
```

Debe aparecer `permiso de accesibilidad concedido`, o no aparecer `falta permiso de accesibilidad` después del último `arranque`.

## 5. Su vocabulario

Pregúntale su nombre completo, el nombre de su empresa o marca y de cinco a diez palabras que los dictados suelen escribirle mal (clientes, productos, herramientas). Ponlas al inicio de la lista `vocabulario` en `~/.config/iriza-whisper/reglas.json`, conservando el formato JSON.

## 6. Explícale cómo se usa

> - **Mantén ⌘ derecho**, habla y suelta: el texto se pega donde esté el cursor.
> - **Doble toque de ⌘ derecho** abre «Corregir lo último»: deja el texto como debía quedar y la app aprende la regla.
> - El icono de micrófono en la barra de menús tiene lo demás.

Pídele que dicte una frase con su nombre para probar.

## 7. Si algo no funciona

Lee las últimas líneas de la bitácora. Anota qué pasó en cada pulsación (nunca el texto dictado):

```bash
tail -20 ~/.config/iriza-whisper/app.log
```

| Línea en la bitácora | Qué significa |
|---|---|
| `falta permiso de accesibilidad` sin un `permiso de accesibilidad concedido` después | Falta activar «Iriza Whisper» en Accesibilidad. Si ya estaba activada, que la quite de la lista y la vuelva a activar |
| `micrófono permitido: false` o `no pude grabar` | Falta el permiso de Micrófono: Ajustes del Sistema → Privacidad y seguridad → Micrófono |
| `⌘ derecho sin efecto: el dictado está en pausa` | Menú del icono → «Reanudar dictado» |
| `sin texto: no se reconoció voz en la grabación` | Mira la línea `pulsación de…` de arriba: trae el volumen máximo y el nombre del micrófono. Si el volumen ronda −55 dB, el micrófono elegido en Ajustes → Sonido → Entrada no es el que la persona está usando |
| `error al transcribir: …` | Corre `./instalar.sh --revisar`. Si todo dice `OK`, propón `brew upgrade whisper.cpp` |
| No hay ninguna línea nueva al oprimir la tecla | La app no está abierta o no tiene Accesibilidad. Ábrela con `open -g "/Applications/Iriza Whisper.app"` |

El README trae la lista completa en «Si algo falla». No corras las pruebas `--autoprueba` sin avisarle a la persona: graban su micrófono.

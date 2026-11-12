# Instalar Iriza Whisper

Instrucciones para Claude Code (o cualquier agente con terminal) en una Mac. Síguelas en orden. No instales nada sin enseñarle antes el comando a la persona y esperar su permiso.

## 1. Clona el repo

```bash
git clone https://github.com/davidiriza-lab/iriza-whisper.git ~/iriza-whisper
cd ~/iriza-whisper
```

Si la persona tiene una carpeta de proyectos, clónalo ahí en lugar de en su carpeta de inicio.

## 2. Revisa qué falta

```bash
./instalar.sh --revisar
```

Imprime una línea por requisito, con `OK` o `FALTA`, y debajo de cada `FALTA` el comando exacto para instalarlo. Los requisitos son:

- El compilador de Swift (`xcode-select --install`; abre una ventana del sistema que la persona debe aceptar).
- `whisper-cli` (`brew install whisper-cpp`). Si no hay Homebrew, dile que lo instale desde https://brew.sh.
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

Pídele que dicte una frase con su nombre para probar. Si no pasa nada al mantener la tecla, revisa `~/.config/iriza-whisper/app.log`.

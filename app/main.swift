// Iriza Whisper: mantén ⌘ derecho, habla, suelta, y el texto se pega donde está el cursor.
//
// Esta app es solo el cascarón: atajo global, grabación, pegado y la ventana de corrección.
// La transcripción y las reglas viven en scripts de Python (~/.config/iriza-whisper/bin),
// para poder cambiarlas sin recompilar y sin volver a dar los permisos de macOS.

import AVFoundation
import ApplicationServices
import Cocoa

// IRIZA_WHISPER_DIR permite probar con una carpeta de datos aparte, sin tocar la real.
let dirConfig = ProcessInfo.processInfo.environment["IRIZA_WHISPER_DIR"] ?? (NSHomeDirectory() + "/.config/iriza-whisper")
let dirScripts = dirConfig + "/bin"
let rutaUltimoAudio = dirConfig + "/ultimo.wav"
let rutaReglas = dirConfig + "/reglas.json"
let rutaBitacora = dirConfig + "/app.log"
let rutaGrabacion = NSTemporaryDirectory() + "iriza-whisper-actual.wav"
let python = "/usr/bin/python3"

let teclaCmdDerecho: UInt16 = 54
let mascaraCmdDerecho: UInt = 0x10  // NX_DEVICERCMDKEYMASK
let mascaraCmdIzquierdo: UInt = 0x08  // NX_DEVICELCMDKEYMASK
// Un toque natural dura entre 0.1 y 0.4 s. Con 0.35 y 0.6 el doble toque exigía demasiada prisa.
let duracionMinima = 0.5  // menos que esto es un toque, no un dictado
let ventanaDobleToque = 1.0  // tiempo máximo entre soltar el primer toque y soltar el segundo

func anotar(_ texto: String) {
    let formato = DateFormatter()
    formato.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let linea = "\(formato.string(from: Date())) \(texto)\n"
    guard let datos = linea.data(using: .utf8) else { return }
    if let archivo = FileHandle(forWritingAtPath: rutaBitacora) {
        archivo.seekToEndOfFile()
        archivo.write(datos)
        archivo.closeFile()
    } else {
        try? FileManager.default.createDirectory(atPath: dirConfig, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: rutaBitacora, contents: datos)
    }
}

/// Corre un script del motor y devuelve su JSON.
func correrScript(_ nombre: String, _ argumentos: [String], entrada: [String: Any]? = nil) -> [String: Any] {
    let proceso = Process()
    proceso.executableURL = URL(fileURLWithPath: python)
    proceso.arguments = [dirScripts + "/" + nombre] + argumentos
    let salida = Pipe()
    proceso.standardOutput = salida
    proceso.standardError = FileHandle.nullDevice
    let tuboEntrada = Pipe()
    proceso.standardInput = tuboEntrada
    do { try proceso.run() } catch { return ["error": "No pude correr \(nombre): \(error.localizedDescription)"] }
    if let entrada = entrada, let datos = try? JSONSerialization.data(withJSONObject: entrada) {
        tuboEntrada.fileHandleForWriting.write(datos)
    }
    tuboEntrada.fileHandleForWriting.closeFile()
    let datos = salida.fileHandleForReading.readDataToEndOfFile()
    proceso.waitUntilExit()
    let objeto = (try? JSONSerialization.jsonObject(with: datos)) as? [String: Any]
    return objeto ?? ["error": "\(nombre) no respondió algo legible"]
}

/// ¿Todas las palabras de la frase existen en español? Sirve para no proponer como regla fija
/// una palabra normal que solo esta vez salió mal ("casa" → "caza").
func esEspanolComun(_ frase: String) -> Bool {
    let revisor = NSSpellChecker.shared
    guard revisor.availableLanguages.contains("es") else { return false }
    let palabras = frase.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    if palabras.isEmpty { return true }
    for palabra in palabras {
        let rango = revisor.checkSpelling(
            of: palabra, startingAt: 0, language: "es", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
        if rango.location != NSNotFound { return false }
    }
    return true
}

/// Guarda una vista como imagen PNG (para revisar el diseño en las pruebas).
func guardarImagen(de vista: NSView?, en ruta: String) {
    guard let vista = vista, let imagen = vista.bitmapImageRepForCachingDisplay(in: vista.bounds) else { return }
    vista.cacheDisplay(in: vista.bounds, to: imagen)
    try? imagen.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: ruta))
}

/// Dibuja el icono de la app: un cuadro oscuro con una onda de voz.
func guardarIcono(en ruta: String, lado: Int = 1024) {
    guard let lienzo = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: lado, pixelsHigh: lado, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let grafico = NSGraphicsContext(bitmapImageRep: lienzo) else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = grafico
    let contexto = grafico.cgContext
    let total = CGFloat(lado)
    // Proporciones de los iconos de macOS: el cuadro ocupa 824 de 1024, con esquinas redondeadas.
    let margen = total * 100 / 1024
    let cuadro = CGRect(x: margen, y: margen, width: total - 2 * margen, height: total - 2 * margen)
    let radio = cuadro.width * 0.2237
    contexto.addPath(CGPath(roundedRect: cuadro, cornerWidth: radio, cornerHeight: radio, transform: nil))
    contexto.clip()
    let colores = [
        CGColor(red: 0.21, green: 0.22, blue: 0.26, alpha: 1), CGColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1),
    ] as CFArray
    if let degradado = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colores, locations: [0, 1]) {
        contexto.drawLinearGradient(
            degradado, start: CGPoint(x: cuadro.midX, y: cuadro.maxY), end: CGPoint(x: cuadro.midX, y: cuadro.minY), options: [])
    }
    let alturas: [CGFloat] = [0.16, 0.30, 0.52, 0.80, 0.46, 1.0, 0.64, 0.86, 0.40, 0.24, 0.14]
    let ancho = cuadro.width * 0.046
    let paso = ancho * 1.85
    let altoMaximo = cuadro.height * 0.50
    let inicio = cuadro.midX - paso * CGFloat(alturas.count - 1) / 2
    contexto.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
    for (i, altura) in alturas.enumerated() {
        let alto = max(ancho, altura * altoMaximo)
        let barra = CGRect(x: inicio + CGFloat(i) * paso - ancho / 2, y: cuadro.midY - alto / 2, width: ancho, height: alto)
        contexto.addPath(CGPath(roundedRect: barra, cornerWidth: ancho / 2, cornerHeight: ancho / 2, transform: nil))
    }
    contexto.fillPath()
    NSGraphicsContext.restoreGraphicsState()
    try? lienzo.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: ruta))
}

// MARK: - ¿Hay una casilla de texto con el foco?

enum Destino: String {
    case campoDeTexto = "casilla de texto"
    case sinCampo = "sin casilla"
    case incierto = "no se puede saber"
}

/// Las apps hechas con Chromium o Electron (VS Code, Chrome, Slack…) no le dicen a macOS
/// qué elemento tiene el foco, salvo que haya un lector de pantalla activo.
func esChromium(_ app: NSRunningApplication?) -> Bool {
    guard let ruta = app?.bundleURL?.appendingPathComponent("Contents/Frameworks").path else { return false }
    let marcos = (try? FileManager.default.contentsOfDirectory(atPath: ruta)) ?? []
    let familias = ["Electron", "Chromium", "Chrome", "Edge", "Brave", "Vivaldi", "Opera", "Arc"]
    return marcos.contains { marco in
        marco.hasSuffix("Framework.framework") && familias.contains(where: { marco.contains($0) })
    }
}

/// Decide a dónde va el texto según el elemento que tiene el foco en la app dada.
func destinoDelTexto(en app: NSRunningApplication?) -> Destino {
    guard let app = app else { return .incierto }
    let opaca = esChromium(app)
    var referencia: CFTypeRef?
    let resultado = AXUIElementCopyAttributeValue(
        AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute as CFString, &referencia)
    guard resultado == .success, let valor = referencia, CFGetTypeID(valor) == AXUIElementGetTypeID() else {
        // "No hay nada con foco" no es de fiar: lo contestan igual las apps que no tienen casilla
        // activa y las que simplemente no lo informan (medido con WhatsApp, Chrome y VS Code).
        return .incierto
    }
    let elemento = valor as! AXUIElement
    var rolCrudo: CFTypeRef?
    AXUIElementCopyAttributeValue(elemento, kAXRoleAttribute as CFString, &rolCrudo)
    let rol = rolCrudo as? String ?? ""
    if ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(rol) { return .campoDeTexto }
    var nombres: CFArray?
    AXUIElementCopyAttributeNames(elemento, &nombres)
    if ((nombres as? [String]) ?? []).contains(kAXSelectedTextRangeAttribute as String) { return .campoDeTexto }
    return (opaca || rol.isEmpty) ? .incierto : .sinCampo
}

// MARK: - Aviso flotante

/// Dibuja el contenido de la cápsula: ondas que siguen tu voz, onda viajera al transcribir, o un mensaje.
final class VistaOnda: NSView {
    enum Modo { case grabando, transcribiendo, mensaje }
    var modo: Modo = .mensaje
    var texto = ""
    var colorTexto = NSColor.white
    var fuenteNivel: (() -> Float)?
    var inicio = Date()
    /// Historial del volumen, el más nuevo al final.
    var niveles = [CGFloat](repeating: 0, count: 48)
    private var reloj: Timer?
    private var ultimoMuestreo = Date()
    private let periodo = 0.05
    private let paso: CGFloat = 5
    private let ancho: CGFloat = 2.5

    func arrancar() {
        reloj?.invalidate()
        let nuevo = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tic() }
        RunLoop.main.add(nuevo, forMode: .common)
        reloj = nuevo
    }

    func parar() {
        reloj?.invalidate()
        reloj = nil
    }

    func reiniciar() {
        niveles = [CGFloat](repeating: 0, count: niveles.count)
        inicio = Date()
        ultimoMuestreo = Date()
    }

    private func tic() {
        if modo == .grabando, Date().timeIntervalSince(ultimoMuestreo) >= periodo {
            ultimoMuestreo = Date()
            // El volumen llega en decibeles: silencio ≈ -55, voz normal entre -35 y -10.
            let decibeles = CGFloat(fuenteNivel?() ?? -160)
            let crudo = max(0, min(1, (decibeles + 50) / 40))
            let suave = 0.65 * crudo + 0.35 * (niveles.last ?? 0)
            niveles.removeFirst()
            niveles.append(suave)
        }
        needsDisplay = true
    }

    private func barra(_ contexto: CGContext, x: CGFloat, alto: CGFloat, color: NSColor) {
        let rect = CGRect(x: x - ancho / 2, y: bounds.midY - alto / 2, width: ancho, height: alto)
        contexto.setFillColor(color.cgColor)
        contexto.addPath(CGPath(roundedRect: rect, cornerWidth: ancho / 2, cornerHeight: ancho / 2, transform: nil))
        contexto.fillPath()
    }

    /// Las barras se desvanecen hacia los bordes de su zona.
    private func desvanecer(_ x: CGFloat, en zona: CGRect) -> CGFloat {
        let margen: CGFloat = 22
        return max(0, min(1, min(x - zona.minX, zona.maxX - x) / margen))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let contexto = NSGraphicsContext.current?.cgContext else { return }
        let tiempo = Date().timeIntervalSince(inicio)
        switch modo {
        case .mensaje:
            let estilo = NSMutableParagraphStyle()
            estilo.alignment = .center
            estilo.lineBreakMode = .byTruncatingTail
            let atributos: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: colorTexto, .paragraphStyle: estilo,
            ]
            let alto = (texto as NSString).size(withAttributes: atributos).height
            (texto as NSString).draw(
                in: NSRect(x: 18, y: bounds.midY - alto / 2, width: bounds.width - 36, height: alto), withAttributes: atributos)

        case .grabando:
            // Punto rojo que late, con halo.
            let latido = CGFloat(0.5 + 0.5 * sin(tiempo * 4.2))
            let centro = CGPoint(x: 24, y: bounds.midY)
            contexto.setFillColor(NSColor.systemRed.withAlphaComponent(0.22 * latido).cgColor)
            contexto.fillEllipse(in: CGRect(x: centro.x - 9, y: centro.y - 9, width: 18, height: 18))
            contexto.setFillColor(NSColor.systemRed.withAlphaComponent(0.8 + 0.2 * latido).cgColor)
            contexto.fillEllipse(in: CGRect(x: centro.x - 4.5, y: centro.y - 4.5, width: 9, height: 9))

            // Tiempo transcurrido: se mide primero para que las ondas nunca lo toquen.
            let segundos = Int(tiempo)
            let reloj = String(format: "%d:%02d", segundos / 60, segundos % 60)
            let atributos: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.78),
            ]
            let medida = (reloj as NSString).size(withAttributes: atributos)
            let xReloj = bounds.width - 20 - ceil(medida.width)
            (reloj as NSString).draw(at: NSPoint(x: xReloj, y: bounds.midY - medida.height / 2), withAttributes: atributos)

            // Ondas: el historial del volumen corre de derecha a izquierda.
            let zona = CGRect(x: 42, y: 9, width: xReloj - 12 - 42, height: bounds.height - 18)
            let avance = CGFloat(min(1, Date().timeIntervalSince(ultimoMuestreo) / periodo))
            for k in 0..<niveles.count {
                let x = zona.maxX - CGFloat(k) * paso - avance * paso
                if x < zona.minX { break }
                let nivel = niveles[niveles.count - 1 - k]
                // Tope al 88 % del alto: una voz fuerte no debe verse como un bloque.
                let alto = max(ancho, pow(nivel, 0.85) * zona.height * 0.88)
                let opacidad = desvanecer(x, en: zona) * (0.45 + 0.55 * min(1, nivel * 1.6))
                barra(contexto, x: x, alto: alto, color: NSColor.white.withAlphaComponent(opacidad))
            }

        case .transcribiendo:
            // Onda que viaja mientras Whisper trabaja.
            let zona = CGRect(x: 22, y: 9, width: bounds.width - 44, height: bounds.height - 18)
            let cuantas = Int(zona.width / paso)
            let tinte = NSColor(calibratedRed: 0.62, green: 0.80, blue: 1.0, alpha: 1)
            for i in 0...cuantas {
                let x = zona.midX - CGFloat(cuantas) * paso / 2 + CGFloat(i) * paso
                let fase = tiempo * 7.0 - Double(i) * 0.42
                let ola = CGFloat(0.5 + 0.5 * sin(fase))
                let campana = CGFloat(sin(Double.pi * Double(i) / Double(max(1, cuantas))))
                let alto = max(ancho, zona.height * (0.14 + 0.62 * ola * campana))
                barra(contexto, x: x, alto: alto, color: tinte.withAlphaComponent(desvanecer(x, en: zona) * (0.35 + 0.65 * ola)))
            }
        }
    }
}

final class Aviso {
    private let panel: NSPanel
    private let fondo = NSVisualEffectView()
    private let vista = VistaOnda()
    private var turno = 0
    private let alto: CGFloat = 46

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: alto),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        fondo.material = .hudWindow
        fondo.state = .active
        fondo.blendingMode = .behindWindow
        fondo.appearance = NSAppearance(named: .vibrantDark)
        fondo.wantsLayer = true
        fondo.layer?.cornerRadius = alto / 2
        fondo.layer?.masksToBounds = true
        fondo.layer?.borderWidth = 1
        fondo.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        fondo.autoresizingMask = [.width, .height]
        vista.autoresizingMask = [.width, .height]
        panel.contentView = fondo
        // El dibujo se ancla una sola vez al tamaño de la cápsula y de ahí la sigue solo.
        // (Fijarle el tamaño a mano en cada cambio lo desfasaba: se sumaba al ajuste automático.)
        vista.frame = fondo.bounds
        fondo.addSubview(vista)
    }

    private func presentar(anchoCapsula: CGFloat, segundos: Double) {
        turno += 1
        let miTurno = turno
        let pantalla = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        let marco = pantalla?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let destino = NSRect(x: marco.midX - anchoCapsula / 2, y: marco.minY + 84, width: anchoCapsula, height: alto)
        vista.needsDisplay = true

        if panel.isVisible && panel.alphaValue > 0.05 {
            // Ya está a la vista: solo cambia de tamaño con suavidad.
            NSAnimationContext.runAnimationGroup { contexto in
                contexto.duration = 0.18
                contexto.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(destino, display: true)
                panel.animator().alphaValue = 1
            }
        } else {
            // Aparece subiendo unos puntos mientras se aclara.
            panel.alphaValue = 0
            panel.setFrame(destino.offsetBy(dx: 0, dy: -10), display: true)
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { contexto in
                contexto.duration = 0.22
                contexto.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(destino, display: true)
                panel.animator().alphaValue = 1
            }
        }
        if segundos > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + segundos) { [weak self] in
                if self?.turno == miTurno { self?.ocultar() }
            }
        }
    }

    /// Cápsula con ondas que siguen el volumen del micrófono (en decibeles).
    func mostrarGrabando(nivel: @escaping () -> Float) {
        vista.modo = .grabando
        vista.fuenteNivel = nivel
        vista.reiniciar()
        vista.arrancar()
        presentar(anchoCapsula: 250, segundos: 0)
    }

    func mostrarTranscribiendo() {
        vista.modo = .transcribiendo
        vista.fuenteNivel = nil
        vista.inicio = Date()
        vista.arrancar()
        presentar(anchoCapsula: 170, segundos: 0)
    }

    /// Mensaje corto; si `segundos` > 0 se esconde solo.
    func mostrar(_ texto: String, color: NSColor = .white, segundos: Double = 0) {
        vista.parar()
        vista.modo = .mensaje
        vista.texto = texto
        vista.colorTexto = color
        presentar(anchoCapsula: Aviso.anchoPara(texto), segundos: segundos)
    }

    func ocultar() {
        turno += 1
        let miTurno = turno
        NSAnimationContext.runAnimationGroup({ contexto in
            contexto.duration = 0.16
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self = self, self.turno == miTurno else { return }
            self.panel.orderOut(nil)
            self.vista.parar()
        })
    }

    /// Ancho de la cápsula y ancho del área donde se dibuja: deben ser iguales siempre.
    var medidas: String { "cápsula=\(Int(panel.frame.width)) dibujo=\(Int(vista.frame.width)) x=\(Int(vista.frame.minX))" }

    static func anchoPara(_ texto: String) -> CGFloat {
        let medida = (texto as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium)])
        return max(180, min(520, ceil(medida.width) + 52))
    }

    /// Guarda una hoja con todos los estados y sus casos extremos, para revisar el diseño sin abrir la app.
    static func fotografiar(en carpeta: String) {
        let alto: CGFloat = 46
        func onda(_ forma: (Double) -> Double) -> [CGFloat] {
            (0..<48).map { CGFloat(max(0.0, min(1.0, forma(Double($0))))) }
        }
        func habla(_ t: Double) -> Double {
            let lenta: Double = 0.4 * sin(t * 0.55) * cos(t * 0.17)
            let rapida: Double = 0.15 * sin(t * 1.9)
            return 0.45 + lenta + rapida
        }
        var filas: [(VistaOnda, CGFloat)] = []
        func grabando(_ niveles: [CGFloat], segundos: Double) {
            let v = VistaOnda()
            v.modo = .grabando
            v.niveles = niveles
            v.inicio = Date().addingTimeInterval(-segundos)
            filas.append((v, 250))
        }
        func mensaje(_ texto: String, _ color: NSColor = .white) {
            let v = VistaOnda()
            v.modo = .mensaje
            v.texto = texto
            v.colorTexto = color
            filas.append((v, anchoPara(texto)))
        }
        grabando(onda(habla), segundos: 7.3)
        grabando(onda { _ in 0.0 }, segundos: 0.4)
        grabando(onda { _ in 1.0 }, segundos: 754)
        let transcribe = VistaOnda()
        transcribe.modo = .transcribiendo
        transcribe.inicio = Date().addingTimeInterval(-0.4)
        filas.append((transcribe, 170))
        mensaje("No escuché nada")
        mensaje("Listo: mantén ⌘ derecho para dictar")
        mensaje("Copiado: pega con ⌘V donde lo necesites")
        mensaje("No pude grabar: revisa el permiso de micrófono", .systemOrange)
        mensaje("Un mensaje demasiado largo para caber en la cápsula debe cortarse con puntos suspensivos y nunca salirse")

        let anchoHoja: CGFloat = 600
        let paso: CGFloat = alto + 22
        let hoja = NSView(frame: NSRect(x: 0, y: 0, width: anchoHoja, height: CGFloat(filas.count) * paso + 22))
        hoja.wantsLayer = true
        hoja.layer?.backgroundColor = NSColor(calibratedWhite: 0.34, alpha: 1).cgColor
        for (indice, fila) in filas.enumerated() {
            let (vista, ancho) = fila
            let y = hoja.bounds.height - CGFloat(indice + 1) * paso
            let capsula = NSView(frame: NSRect(x: (anchoHoja - ancho) / 2, y: y, width: ancho, height: alto))
            capsula.wantsLayer = true
            capsula.layer?.backgroundColor = NSColor(calibratedWhite: 0.11, alpha: 0.96).cgColor
            capsula.layer?.cornerRadius = alto / 2
            capsula.layer?.masksToBounds = true
            capsula.layer?.borderWidth = 1
            capsula.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
            vista.frame = capsula.bounds
            capsula.addSubview(vista)
            hoja.addSubview(capsula)
        }
        guard let imagen = hoja.bitmapImageRepForCachingDisplay(in: hoja.bounds) else { return }
        hoja.cacheDisplay(in: hoja.bounds, to: imagen)
        try? imagen.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: carpeta + "/capsula.png"))
    }
}

// MARK: - App

final class Delegado: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var icono: NSStatusItem!
    private let aviso = Aviso()
    private var grabadora: AVAudioRecorder?
    private var grabando = false
    private var transcribiendo = false
    private var pausado = false
    private var ultimoToque = Date.distantPast
    private var inicioPulsacion = Date()
    private var nivelMaximo: Float = -160
    private var monitores: [Any] = []
    private var relojPermiso: Timer?
    private var ultimo: (crudo: String, texto: String)?
    private var ventana: NSWindow?
    private var editor: NSTextView?
    /// Autoprueba: graba 2 s sin tocar el teclado ni pegar nada, e imprime el resultado.
    var autoprueba = false
    /// En la prueba de corrección: carpeta donde se guardan las imágenes; no se espera a nadie.
    private var carpetaPrueba: String?

    /// Recorre la corrección completa sin intervención: abre la ventana con un dictado, escribe
    /// la versión corregida, acepta las reglas que vienen marcadas y guarda. Deja imágenes.
    func probarCorreccion(carpeta: String, dictado: String, corregido: String) {
        autoprueba = true
        carpetaPrueba = carpeta
        ultimo = (dictado, dictado)
        abrirCorreccion()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        guardarImagen(de: ventana?.contentView, en: carpeta + "/ventana.png")
        editor?.string = corregido
        guardarCorreccion()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    }

    /// La bitácora solo guarda horas y duraciones, y nunca pasa de unas 200 líneas.
    private func recortarBitacora() {
        guard let texto = try? String(contentsOfFile: rutaBitacora, encoding: .utf8) else { return }
        let lineas = texto.split(separator: "\n", omittingEmptySubsequences: true)
        guard lineas.count > 200 else { return }
        try? (lineas.suffix(100).joined(separator: "\n") + "\n").write(toFile: rutaBitacora, atomically: true, encoding: .utf8)
    }

    /// Al cerrar no queda audio: se borran la última grabación y el archivo temporal.
    func applicationWillTerminate(_ notification: Notification) {
        grabadora?.stop()
        try? FileManager.default.removeItem(atPath: rutaUltimoAudio)
        try? FileManager.default.removeItem(atPath: rutaGrabacion)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        recortarBitacora()
        anotar("arranque")
        if autoprueba {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.empezar() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { self.terminar() }
            return
        }
        armarMenuPrincipal()
        icono = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        pintarIcono()
        AVCaptureDevice.requestAccess(for: .audio) { permitido in anotar("micrófono permitido: \(permitido)") }

        let opciones = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opciones) {
            instalarMonitores()
        } else {
            anotar("falta permiso de accesibilidad")
            relojPermiso = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] reloj in
                guard AXIsProcessTrusted() else { return }
                reloj.invalidate()
                anotar("permiso de accesibilidad concedido")
                self?.instalarMonitores()
                self?.aviso.mostrar("Listo: mantén ⌘ derecho para dictar", segundos: 3)
            }
        }
    }

    // MARK: Menús

    /// Sin un menú Edición, ⌘C / ⌘V / ⌘A no funcionan en la ventana de corrección.
    private func armarMenuPrincipal() {
        let principal = NSMenu()
        let edicion = NSMenu(title: "Edición")
        edicion.addItem(withTitle: "Deshacer", action: Selector(("undo:")), keyEquivalent: "z")
        edicion.addItem(withTitle: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edicion.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edicion.addItem(withTitle: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edicion.addItem(withTitle: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let entrada = NSMenuItem()
        entrada.submenu = edicion
        principal.addItem(entrada)
        NSApp.mainMenu = principal
    }

    private func pintarIcono() {
        if autoprueba { return }
        let accesible = AXIsProcessTrusted()
        let simbolo: String
        if !accesible { simbolo = "mic.slash" }
        else if grabando { simbolo = "mic.fill" }
        else if transcribiendo { simbolo = "ellipsis.circle" }
        else if pausado { simbolo = "pause.circle" }
        else { simbolo = "mic" }
        let imagen = NSImage(systemSymbolName: simbolo, accessibilityDescription: "Iriza Whisper")
        imagen?.isTemplate = true
        icono.button?.image = imagen

        let menu = NSMenu()
        let estado = accesible ? "Mantén ⌘ derecho para dictar" : "Falta el permiso de Accesibilidad"
        menu.addItem(withTitle: estado, action: nil, keyEquivalent: "")
        if !accesible {
            menu.addItem(withTitle: "Abrir Accesibilidad en Ajustes…", action: #selector(abrirAccesibilidad), keyEquivalent: "")
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Corregir lo último… (doble toque de ⌘ derecho)", action: #selector(abrirCorreccion), keyEquivalent: "")
        menu.addItem(withTitle: "Copiar el último dictado", action: #selector(copiarUltimo), keyEquivalent: "")
        menu.addItem(withTitle: "Abrir vocabulario y reglas", action: #selector(abrirReglas), keyEquivalent: "")
        menu.addItem(withTitle: pausado ? "Reanudar dictado" : "Pausar dictado", action: #selector(alternarPausa), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Salir", action: #selector(salir), keyEquivalent: "q")
        for elemento in menu.items where elemento.action != nil { elemento.target = self }
        icono.menu = menu
    }

    @objc private func abrirAccesibilidad() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func abrirReglas() { NSWorkspace.shared.open(URL(fileURLWithPath: rutaReglas)) }

    @objc private func alternarPausa() {
        pausado.toggle()
        pintarIcono()
    }

    @objc private func salir() { NSApp.terminate(nil) }

    // MARK: Atajo

    private func instalarMonitores() {
        monitores.forEach { NSEvent.removeMonitor($0) }
        monitores = []
        let tipos: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: tipos, handler: { [weak self] in self?.alEvento($0) }) {
            monitores.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: tipos, handler: { [weak self] evento in
            self?.alEvento(evento)
            return evento
        }) {
            monitores.append(local)
        }
        pintarIcono()
    }

    private func alEvento(_ evento: NSEvent) {
        if evento.type == .keyDown {
            // ⌘ derecho + otra tecla es un atajo normal, no un dictado.
            if grabando { cancelar() }
            return
        }
        let banderas = evento.modifierFlags.rawValue
        let cmdDerecho = banderas & mascaraCmdDerecho != 0
        let otros = banderas & mascaraCmdIzquierdo != 0
            || !evento.modifierFlags.intersection([.shift, .control, .option]).isEmpty
        if evento.keyCode == teclaCmdDerecho {
            if cmdDerecho, !otros, !pausado, !transcribiendo {
                if grabando {
                    // Se perdió el aviso de que soltaste la tecla la vez anterior.
                    anotar("la grabación anterior quedó abierta: se reinicia")
                    cancelar()
                }
                empezar()
            } else if !cmdDerecho, grabando {
                terminar()
            }
        } else if grabando {
            cancelar()
        }
    }

    // MARK: Grabación

    private func prepararGrabadora() {
        let ajustes: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        do {
            grabadora = try AVAudioRecorder(url: URL(fileURLWithPath: rutaGrabacion), settings: ajustes)
            grabadora?.isMeteringEnabled = true
            grabadora?.prepareToRecord()
        } catch {
            grabadora = nil
            anotar("no pude preparar la grabadora: \(error.localizedDescription)")
        }
    }

    /// Volumen actual del micrófono en decibeles (0 es el máximo; el silencio ronda -55).
    private func nivelDelMicrofono() -> Float {
        guard grabando, let grabadora = grabadora else { return -160 }
        grabadora.updateMeters()
        let nivel = grabadora.averagePower(forChannel: 0)
        nivelMaximo = max(nivelMaximo, nivel)
        return nivel
    }

    private func empezar() {
        // La grabadora se crea al oprimir la tecla y se suelta al terminar. Una preparada de
        // antemano puede quedar inservible tras un rato sin uso, y así no se ocupa nada en reposo.
        inicioPulsacion = Date()
        nivelMaximo = -160
        prepararGrabadora()
        guard let grabadora = grabadora, grabadora.record() else {
            anotar("no pude grabar")
            if autoprueba { print("no pude grabar (¿permiso de micrófono?)"); exit(1) }
            self.grabadora = nil
            aviso.mostrar("No pude grabar: revisa el permiso de micrófono", color: .systemOrange, segundos: 3)
            return
        }
        grabando = true
        pintarIcono()
        // El aviso espera un instante para no parpadear con un toque o un atajo.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            if self?.grabando == true { self?.aviso.mostrarGrabando { [weak self] in self?.nivelDelMicrofono() ?? -160 } }
        }
        // Tope de seguridad: si nunca llega el aviso de que soltaste, no se queda grabando.
        let marca = inicioPulsacion
        DispatchQueue.main.asyncAfter(deadline: .now() + 600) { [weak self] in
            guard let self = self, self.grabando, self.inicioPulsacion == marca else { return }
            anotar("tope de 10 minutos: se cierra la grabación")
            self.terminar()
        }
    }

    private func soltarGrabadora() {
        grabadora?.stop()
        grabadora = nil
        try? FileManager.default.removeItem(atPath: rutaGrabacion)
    }

    private func cancelar() {
        anotar("grabación descartada: se oprimió otra tecla")
        grabando = false
        soltarGrabadora()
        aviso.ocultar()
        pintarIcono()
    }

    private func terminar() {
        // La duración se mide con el reloj, no con la grabadora: si el micrófono tarda en
        // arrancar, una pulsación larga no debe confundirse con un toque.
        let pulsacion = Date().timeIntervalSince(inicioPulsacion)
        _ = nivelDelMicrofono()
        let grabado = grabadora?.currentTime ?? 0
        grabando = false
        grabadora?.stop()
        grabadora = nil
        pintarIcono()

        if pulsacion < duracionMinima {
            aviso.ocultar()
            try? FileManager.default.removeItem(atPath: rutaGrabacion)
            let ahora = Date()
            if ahora.timeIntervalSince(ultimoToque) < ventanaDobleToque {
                ultimoToque = .distantPast
                anotar("doble toque: abrir corrección")
                abrirCorreccion()
            } else {
                anotar("toque de \(String(format: "%.2f", pulsacion)) s")
                ultimoToque = ahora
                // Si no llega un segundo toque, recuerda cómo se usa: así se ve que la tecla sí responde.
                DispatchQueue.main.asyncAfter(deadline: .now() + ventanaDobleToque) { [weak self] in
                    guard let self = self, self.ultimoToque == ahora, !self.grabando, !self.transcribiendo else { return }
                    self.aviso.mostrar("Mantén ⌘ derecho mientras hablas", segundos: 2.2)
                }
            }
            return
        }

        anotar(String(format: "pulsación de %.1f s, grabado %.1f s, volumen máximo %.0f dB", pulsacion, grabado, nivelMaximo))
        if autoprueba { print(String(format: "pulsación %.2f s · grabado %.2f s · arranque del micrófono %.2f s", pulsacion, grabado, pulsacion - grabado)) }
        try? FileManager.default.removeItem(atPath: rutaUltimoAudio)
        do {
            try FileManager.default.moveItem(atPath: rutaGrabacion, toPath: rutaUltimoAudio)
        } catch {
            anotar("no pude guardar el audio: \(error.localizedDescription)")
            aviso.mostrar("No pude guardar el audio", color: .systemOrange, segundos: 3)
            return
        }
        if grabado < 0.15 {
            anotar("el micrófono no alcanzó a grabar")
            aviso.mostrar("El micrófono no alcanzó a grabar: inténtalo otra vez", color: .systemOrange, segundos: 3)
            return
        }
        transcribir(duracion: grabado)
    }

    private func transcribir(duracion: Double) {
        transcribiendo = true
        pintarIcono()
        aviso.mostrarTranscribiendo()
        DispatchQueue.global(qos: .userInitiated).async {
            let respuesta = correrScript("transcribir.py", [rutaUltimoAudio])
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.transcribiendo = false
                if self.autoprueba {
                    let atributos = try? FileManager.default.attributesOfItem(atPath: rutaUltimoAudio)
                    print("grabación: \(String(format: "%.2f", duracion)) s, \(atributos?[.size] ?? 0) bytes")
                    print("respuesta: \(respuesta)")
                    exit(respuesta["error"] == nil ? 0 : 1)
                }
                self.pintarIcono()
                if let error = respuesta["error"] as? String {
                    anotar("error al transcribir: \(error)")
                    self.aviso.mostrar("Falló la transcripción (ver app.log)", color: .systemOrange, segundos: 4)
                    return
                }
                let texto = respuesta["texto"] as? String ?? ""
                let crudo = respuesta["crudo"] as? String ?? ""
                anotar("dictado de \(String(format: "%.1f", duracion)) s, transcrito en \(respuesta["segundos"] ?? "?") s")
                if texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    anotar("sin texto: no se reconoció voz en la grabación")
                    self.aviso.mostrar("No escuché nada", segundos: 1.5)
                    return
                }
                self.ultimo = (crudo, texto)
                self.pegar(texto)
            }
        }
    }

    // MARK: Pegado

    /// Tres casos:
    /// - macOS confirma una casilla de texto: pega y te devuelve lo que tenías copiado.
    /// - macOS confirma que el foco está en otra cosa (una lista, un botón): no pega;
    ///   el dictado se queda en el portapapeles y sale un aviso.
    /// - No se puede saber (VS Code, Chrome, WhatsApp…): pega y además lo deja en el
    ///   portapapeles. Si no había casilla, ahí lo encuentras; nunca se pierde.
    private func pegar(_ texto: String) {
        let alFrente = NSWorkspace.shared.frontmostApplication
        let destino = AXIsProcessTrusted() ? destinoDelTexto(en: alFrente) : .sinCampo
        anotar("destino: \(destino.rawValue) (\(alFrente?.localizedName ?? "?"))")

        let portapapeles = NSPasteboard.general
        var respaldo: [NSPasteboardItem] = []
        if destino == .campoDeTexto {
            respaldo = (portapapeles.pasteboardItems ?? []).map { original in
                let copia = NSPasteboardItem()
                for tipo in original.types {
                    if let datos = original.data(forType: tipo) { copia.setData(datos, forType: tipo) }
                }
                return copia
            }
        }
        portapapeles.clearContents()
        portapapeles.setString(texto.trimmingCharacters(in: .whitespacesAndNewlines) + (destino == .sinCampo ? "" : " "), forType: .string)

        if destino == .sinCampo {
            aviso.mostrar("Copiado: pega con ⌘V donde lo necesites", segundos: 2.5)
            return
        }
        let fuente = CGEventSource(stateID: .combinedSessionState)
        let teclaV: CGKeyCode = 9
        let abajo = CGEvent(keyboardEventSource: fuente, virtualKey: teclaV, keyDown: true)
        let arriba = CGEvent(keyboardEventSource: fuente, virtualKey: teclaV, keyDown: false)
        abajo?.flags = .maskCommand
        arriba?.flags = .maskCommand
        abajo?.post(tap: .cghidEventTap)
        arriba?.post(tap: .cghidEventTap)
        aviso.ocultar()

        guard destino == .campoDeTexto else { return }
        // Devuelve lo que tenías copiado, cuando la app de destino ya leyó el texto.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            portapapeles.clearContents()
            if !respaldo.isEmpty { portapapeles.writeObjects(respaldo) }
        }
    }

    @objc private func copiarUltimo() {
        guard let ultimo = ultimo else {
            aviso.mostrar("Todavía no has dictado nada", segundos: 2)
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ultimo.texto.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
        aviso.mostrar("Último dictado copiado", segundos: 1.8)
    }

    // MARK: Corrección

    @objc private func abrirCorreccion() {
        guard let ultimo = ultimo else {
            aviso.mostrar("Todavía no hay nada que corregir", segundos: 2)
            return
        }
        if ventana == nil {
            let nueva = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 300),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            nueva.title = "Corregir lo último"
            nueva.isReleasedWhenClosed = false
            nueva.delegate = self
            nueva.level = .floating
            let contenido = nueva.contentView!

            let rotulo = NSTextField(labelWithString: "Déjalo como debía quedar. Con lo que cambies se proponen reglas nuevas.")
            rotulo.textColor = .secondaryLabelColor
            rotulo.frame = NSRect(x: 20, y: 262, width: 580, height: 20)
            rotulo.autoresizingMask = [.width, .minYMargin]
            contenido.addSubview(rotulo)

            let desplazable = NSScrollView(frame: NSRect(x: 20, y: 62, width: 580, height: 192))
            desplazable.hasVerticalScroller = true
            desplazable.borderType = .bezelBorder
            desplazable.autoresizingMask = [.width, .height]
            let texto = NSTextView(frame: NSRect(x: 0, y: 0, width: 580, height: 192))
            texto.font = .systemFont(ofSize: 16)
            texto.isRichText = false
            texto.allowsUndo = true
            texto.autoresizingMask = [.width]
            texto.textContainerInset = NSSize(width: 6, height: 8)
            texto.isAutomaticQuoteSubstitutionEnabled = false
            texto.isAutomaticDashSubstitutionEnabled = false
            texto.isAutomaticSpellingCorrectionEnabled = false
            desplazable.documentView = texto
            contenido.addSubview(desplazable)
            editor = texto

            let guardar = NSButton(title: "Guardar  ⌘↩", target: self, action: #selector(guardarCorreccion))
            guardar.keyEquivalent = "\r"
            guardar.keyEquivalentModifierMask = .command
            guardar.bezelStyle = .rounded
            guardar.frame = NSRect(x: 470, y: 16, width: 130, height: 32)
            guardar.autoresizingMask = [.minXMargin, .maxYMargin]
            contenido.addSubview(guardar)

            let cancelar = NSButton(title: "Cancelar", target: self, action: #selector(cerrarCorreccion))
            cancelar.keyEquivalent = "\u{1b}"
            cancelar.bezelStyle = .rounded
            cancelar.frame = NSRect(x: 360, y: 16, width: 104, height: 32)
            cancelar.autoresizingMask = [.minXMargin, .maxYMargin]
            contenido.addSubview(cancelar)
            ventana = nueva
        }
        editor?.string = ultimo.texto.trimmingCharacters(in: .whitespacesAndNewlines)
        ventana?.center()
        NSApp.activate(ignoringOtherApps: true)
        ventana?.makeKeyAndOrderFront(nil)
        ventana?.makeFirstResponder(editor)
    }

    @objc private func cerrarCorreccion() { ventana?.orderOut(nil) }

    @objc private func guardarCorreccion() {
        guard let ultimo = ultimo, let editor = editor else { return }
        let final = ultimo.texto.trimmingCharacters(in: .whitespacesAndNewlines)
        let corregido = editor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if corregido.isEmpty || corregido == final {
            cerrarCorreccion()
            return
        }
        let propuesta = correrScript("aprender.py", ["proponer"], entrada: ["final": final, "corregido": corregido])
        if let error = propuesta["error"] as? String {
            anotar("error al proponer: \(error)")
            aviso.mostrar("No pude analizar la corrección (ver app.log)", color: .systemOrange, segundos: 4)
            return
        }
        let reemplazos = propuesta["reemplazos"] as? [[String: String]] ?? []
        let vocabulario = propuesta["vocabulario"] as? [String] ?? []
        var elegidos: [[String: String]] = []
        var palabras: [String] = []

        if !reemplazos.isEmpty || !vocabulario.isEmpty {
            let alerta = NSAlert()
            alerta.messageText = "¿Qué quieres que aprenda?"
            alerta.informativeText = "Marca lo que debe cambiarse siempre. Deja sin marcar las palabras normales que solo esta vez salieron mal."
            alerta.addButton(withTitle: "Guardar")
            alerta.addButton(withTitle: "Cancelar")
            let pila = NSStackView()
            pila.orientation = .vertical
            pila.alignment = .leading
            pila.spacing = 6
            var casillasReglas: [NSButton] = []
            var casillasPalabras: [NSButton] = []
            for regla in reemplazos {
                let de = regla["de"] ?? "", a = regla["a"] ?? ""
                let casilla = NSButton(checkboxWithTitle: "Si sale «\(de)», escribir «\(a)»", target: nil, action: nil)
                casilla.state = esEspanolComun(de) ? .off : .on
                casillasReglas.append(casilla)
                pila.addArrangedSubview(casilla)
            }
            for palabra in vocabulario {
                let casilla = NSButton(checkboxWithTitle: "Agregar «\(palabra)» al vocabulario", target: nil, action: nil)
                casilla.state = esEspanolComun(palabra) ? .off : .on
                casillasPalabras.append(casilla)
                pila.addArrangedSubview(casilla)
            }
            pila.setFrameSize(pila.fittingSize)
            alerta.accessoryView = pila
            alerta.window.level = .floating
            if let carpeta = carpetaPrueba {
                alerta.layout()
                guardarImagen(de: alerta.window.contentView, en: carpeta + "/alerta.png")
            } else if alerta.runModal() != .alertFirstButtonReturn {
                return
            }
            for (i, casilla) in casillasReglas.enumerated() where casilla.state == .on { elegidos.append(reemplazos[i]) }
            for (i, casilla) in casillasPalabras.enumerated() where casilla.state == .on { palabras.append(vocabulario[i]) }
        }

        let respuesta = correrScript("aprender.py", ["aplicar"], entrada: [
            "crudo": ultimo.crudo, "final": final, "corregido": corregido,
            "audio": rutaUltimoAudio, "reemplazos": elegidos, "vocabulario": palabras,
        ])
        if let error = respuesta["error"] as? String {
            anotar("error al aplicar: \(error)")
            aviso.mostrar("No pude guardar la corrección (ver app.log)", color: .systemOrange, segundos: 4)
            return
        }
        anotar("corrección guardada: \(elegidos.count) reglas, \(palabras.count) palabras")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(corregido, forType: .string)
        self.ultimo = (ultimo.crudo, corregido)
        cerrarCorreccion()
        let aprendido = elegidos.count + palabras.count
        aviso.mostrar(aprendido > 0 ? "Aprendido. El texto corregido quedó copiado" : "Guardado. El texto corregido quedó copiado", segundos: 3)
    }
}

// MARK: - Arranque

let argumentos = CommandLine.arguments
if argumentos.count >= 3, argumentos[1] == "--prueba" {
    // Comprueba, sin interfaz ni permisos, que la app alcanza el motor: IrizaWhisper --prueba audio.wav
    let respuesta = correrScript("transcribir.py", [argumentos[2]])
    let datos = try! JSONSerialization.data(withJSONObject: [
        "respuesta": respuesta,
        "ortografia_es": NSSpellChecker.shared.availableLanguages.contains("es"),
        "comun_casa": esEspanolComun("casa"),
        "comun_berzel": esEspanolComun("Berzel"),
        "comun_su_pavase": esEspanolComun("su pavase"),
        "accesibilidad": AXIsProcessTrusted(),
    ], options: [.prettyPrinted, .sortedKeys])
    print(String(data: datos, encoding: .utf8)!)
    exit(respuesta["error"] == nil ? 0 : 1)
}

if argumentos.count >= 2, argumentos[1] == "--destino" {
    // Dice a dónde iría el texto en la app del frente, o en la del identificador dado:
    //   IrizaWhisper --destino [com.apple.finder]
    let app = argumentos.count >= 3
        ? NSRunningApplication.runningApplications(withBundleIdentifier: argumentos[2]).first
        : NSWorkspace.shared.frontmostApplication
    print("\(app?.localizedName ?? "(no está abierta)"): \(destinoDelTexto(en: app).rawValue) · chromium=\(esChromium(app))")
    exit(0)
}

if argumentos.count >= 3, argumentos[1] == "--icono" {
    // Lo usa instalar.sh para generar el icono de la app: IrizaWhisper --icono icono.png
    guardarIcono(en: argumentos[2])
    exit(0)
}

if argumentos.count >= 5, argumentos[1] == "--prueba-correccion" {
    // IrizaWhisper --prueba-correccion <carpeta de imágenes> "<dictado>" "<corregido>"
    // Úsalo con IRIZA_WHISPER_DIR apuntando a una carpeta de datos de prueba.
    let appPrueba = NSApplication.shared
    appPrueba.setActivationPolicy(.accessory)
    let prueba = Delegado()
    prueba.probarCorreccion(carpeta: argumentos[2], dictado: argumentos[3], corregido: argumentos[4])
    exit(0)
}

if argumentos.count >= 2, argumentos[1] == "--prueba-aviso" {
    // Recorre los estados de la cápsula como en un dictado real y revisa que el dibujo nunca se salga.
    let appPrueba = NSApplication.shared
    appPrueba.setActivationPolicy(.accessory)
    let aviso = Aviso()
    var fallas = 0
    let pasos: [(String, () -> Void)] = [
        ("grabando", { aviso.mostrarGrabando { -30 } }),
        ("transcribiendo", { aviso.mostrarTranscribiendo() }),
        ("mensaje largo", { aviso.mostrar("Copiado: pega con ⌘V donde lo necesites") }),
        ("grabando otra vez", { aviso.mostrarGrabando { -30 } }),
        ("mensaje corto", { aviso.mostrar("No escuché nada") }),
        ("oculto y grabando", { aviso.ocultar(); RunLoop.main.run(until: Date().addingTimeInterval(0.4)); aviso.mostrarGrabando { -30 } }),
    ]
    for (nombre, accion) in pasos {
        accion()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let m = aviso.medidas
        let partes = m.split(separator: " ").map { $0.split(separator: "=").last.map(String.init) ?? "" }
        let bien = partes.count == 3 && partes[0] == partes[1] && partes[2] == "0"
        if !bien { fallas += 1 }
        print("\(bien ? "BIEN" : "MAL ") \(nombre): \(m)")
    }
    exit(fallas == 0 ? 0 : 1)
}

if argumentos.count >= 3, argumentos[1] == "--fotos" {
    // Guarda imágenes de la cápsula en la carpeta dada: IrizaWhisper --fotos carpeta
    _ = NSApplication.shared
    Aviso.fotografiar(en: argumentos[2])
    exit(0)
}

let yoMismo = NSRunningApplication.current
let gemelas = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.davidiriza.irizawhisper")
if !argumentos.contains("--autoprueba"), gemelas.contains(where: { $0.processIdentifier != yoMismo.processIdentifier }) {
    exit(0)  // ya hay una corriendo
}

let app = NSApplication.shared
let delegado = Delegado()
delegado.autoprueba = argumentos.contains("--autoprueba")
app.delegate = delegado
app.setActivationPolicy(.accessory)
app.run()

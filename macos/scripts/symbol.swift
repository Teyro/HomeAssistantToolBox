// App-Symbol zeichnen: Glühbirne auf blauem Verlauf im macOS-Stil (abgerundetes Quadrat).
// Aufruf: swift scripts/symbol.swift <Ordner.iconset>
import AppKit

let ordner = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: ordner, withIntermediateDirectories: true)

func bild(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let rand = s * 0.1
    let flaeche = NSRect(x: rand, y: rand, width: s - 2 * rand, height: s - 2 * rand)
    let form = NSBezierPath(roundedRect: flaeche, xRadius: flaeche.width * 0.225, yRadius: flaeche.width * 0.225)
    NSGraphicsContext.current?.saveGraphicsState()
    let schatten = NSShadow()
    schatten.shadowColor = NSColor.black.withAlphaComponent(0.3)
    schatten.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    schatten.shadowBlurRadius = s * 0.025
    schatten.set()
    NSGradient(colors: [NSColor(red: 0.16, green: 0.62, blue: 0.98, alpha: 1), NSColor(red: 0.07, green: 0.29, blue: 0.75, alpha: 1)])!
        .draw(in: form, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()
    // heller Schein oben (Glas)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSBezierPath(roundedRect: flaeche.insetBy(dx: s * 0.01, dy: s * 0.01), xRadius: flaeche.width * 0.215, yRadius: flaeche.width * 0.215), angle: -90)
    let konfig = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(red: 1, green: 0.85, blue: 0.35, alpha: 1)]))
    if let sym = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: nil)?.withSymbolConfiguration(konfig) {
        let g = sym.size
        let r = NSRect(x: (s - g.width) / 2, y: (s - g.height) / 2, width: g.width, height: g.height)
        NSGraphicsContext.current?.saveGraphicsState()
        let glanz = NSShadow()
        glanz.shadowColor = NSColor(red: 1, green: 0.8, blue: 0.2, alpha: 0.8)
        glanz.shadowBlurRadius = s * 0.06
        glanz.set()
        sym.draw(in: r)
        NSGraphicsContext.current?.restoreGraphicsState()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (groesse, faktor) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = faktor == 1 ? "icon_\(groesse)x\(groesse).png" : "icon_\(groesse)x\(groesse)@2x.png"
    try! bild(groesse * faktor).write(to: URL(fileURLWithPath: "\(ordner)/\(name)"))
}

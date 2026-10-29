// Desenha o ícone do Bloquinho (1024×1024) e salva como PNG.
// Uso: swift scripts/make-icon.swift saida.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments[1]

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    // Folha amarela com cantos arredondados (margem padrão dos ícones do macOS).
    let page = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: page, xRadius: 180, yRadius: 180)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 24
    shadow.set()
    NSColor(srgbRed: 1.0, green: 0.86, blue: 0.35, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    shape.addClip()
    // Faixa do topo, como a cola de um bloco.
    NSColor(srgbRed: 0.93, green: 0.55, blue: 0.20, alpha: 1).setFill()
    NSRect(x: page.minX, y: page.maxY - 170, width: page.width, height: 170).fill()

    // Linhas da folha.
    NSColor(srgbRed: 0.80, green: 0.62, blue: 0.20, alpha: 0.6).setFill()
    for i in 0..<5 {
        NSRect(x: page.minX + 120, y: page.minY + 140 + CGFloat(i) * 105, width: page.width - 240, height: 14).fill()
    }
    // Margem vermelha.
    NSColor(srgbRed: 0.85, green: 0.25, blue: 0.25, alpha: 0.7).setFill()
    NSRect(x: page.minX + 80, y: page.minY, width: 10, height: page.height - 170).fill()
    return true
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))

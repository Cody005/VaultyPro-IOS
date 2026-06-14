import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background gradient (deep navy)
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.08, green: 0.13, blue: 0.20, alpha: 1),
    NSColor(srgbRed: 0.05, green: 0.09, blue: 0.15, alpha: 1)
])!
gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

// Amber rounded square plate
let amber = NSColor(srgbRed: 0.957, green: 0.635, blue: 0.380, alpha: 1)
let inset = 250.0
let plate = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - inset*2, height: size - inset*2),
                         xRadius: 110, yRadius: 110)
amber.setFill()
plate.fill()

// Tray glyph
let config = NSImage.SymbolConfiguration(pointSize: 320, weight: .bold)
if let symbol = NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let navy = NSColor(srgbRed: 0.05, green: 0.09, blue: 0.15, alpha: 1)
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    navy.set()
    let rect = NSRect(origin: .zero, size: symbol.size)
    symbol.draw(in: rect)
    rect.fill(using: .sourceAtop)
    tinted.unlockFocus()
    let drawRect = NSRect(x: (size - symbol.size.width)/2,
                          y: (size - symbol.size.height)/2,
                          width: symbol.size.width, height: symbol.size.height)
    tinted.draw(in: drawRect)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render icon")
}
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
try! png.write(to: outURL)
print("Wrote \(outURL.path)")

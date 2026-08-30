// Renders Boo's app icon at every size macOS wants, then builds the .icns.
// Run via `swift scripts/make-icon.swift <out-dir>`.
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let sizes = [16, 32, 64, 128, 256, 512, 1024]

func booIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size / 64                       // the 64pt design grid

    // Rounded-square backdrop in Boo's dark, so the ghost reads on any
    // wallpaper. macOS expects app icons to have their own ground.
    let inset = size * 0.06
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let bg = CGPath(roundedRect: rect,
                    cornerWidth: size * 0.22, cornerHeight: size * 0.22, transform: nil)
    ctx.addPath(bg)
    ctx.setFillColor(CGColor(red: 0.055, green: 0.06, blue: 0.07, alpha: 1))
    ctx.fillPath()

    // Flip: AppKit's origin is bottom-left, the design grid is top-left.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let body = CGMutablePath()
    body.move(to: CGPoint(x: 32 * s, y: 5 * s))
    body.addCurve(to: CGPoint(x: 55 * s, y: 28.5 * s),
                  control1: CGPoint(x: 45.8 * s, y: 5 * s),
                  control2: CGPoint(x: 55 * s, y: 15 * s))
    body.addLine(to: CGPoint(x: 55 * s, y: 48.2 * s))
    let hem: [CGFloat] = [50, 43.5, 36.6, 30.1, 23.2, 16.7]
    body.addCurve(to: CGPoint(x: hem[0] * s, y: 50.6 * s),
                  control1: CGPoint(x: 55 * s, y: 51.4 * s),
                  control2: CGPoint(x: 52 * s, y: 52.6 * s))
    for i in 1..<hem.count {
        let midY: CGFloat = i.isMultiple(of: 2) ? 52.6 : 48.7
        body.addCurve(to: CGPoint(x: hem[i] * s, y: 50.6 * s),
                      control1: CGPoint(x: (hem[i-1] - 1.9) * s, y: midY * s),
                      control2: CGPoint(x: (hem[i] + 1.9) * s, y: midY * s))
    }
    body.addCurve(to: CGPoint(x: 12 * s, y: 48.2 * s),
                  control1: CGPoint(x: 14.7 * s, y: 52.6 * s),
                  control2: CGPoint(x: 12 * s, y: 51.4 * s))
    body.addLine(to: CGPoint(x: 12 * s, y: 28.5 * s))
    body.addCurve(to: CGPoint(x: 32 * s, y: 5 * s),
                  control1: CGPoint(x: 12 * s, y: 15 * s),
                  control2: CGPoint(x: 18.2 * s, y: 5 * s))
    body.closeSubpath()
    ctx.addPath(body)
    ctx.setFillColor(CGColor(red: 0.969, green: 0.957, blue: 0.925, alpha: 1))
    ctx.fillPath()

    // Eyes punched as real holes, same as the menu bar icon.
    ctx.setBlendMode(.clear)
    for cx in [CGFloat(23), 41] {
        ctx.addEllipse(in: CGRect(x: (cx - 4.3) * s, y: (31 - 4.6) * s,
                                  width: 8.6 * s, height: 9.2 * s))
    }
    ctx.fillPath()
    ctx.setBlendMode(.normal)

    // The amber heart.
    ctx.setFillColor(CGColor(red: 0.961, green: 0.651, blue: 0.137, alpha: 1))
    for (x, y, w, h) in [(28.0, 38.0, 3.0, 3.0), (33.0, 38.0, 3.0, 3.0),
                         (26.0, 41.0, 12.0, 3.0), (28.0, 44.0, 8.0, 3.0),
                         (30.0, 47.0, 4.0, 3.0)] {
        ctx.fill(CGRect(x: x * s, y: y * s, width: w * s, height: h * s))
    }

    image.unlockFocus()
    return image
}

for size in sizes {
    let image = booIcon(size: CGFloat(size))
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    let scale = size >= 32 ? size / 2 : size
    let suffix = size >= 32 ? "\(scale)x\(scale)@2x" : "\(size)x\(size)"
    try? png.write(to: URL(fileURLWithPath: "\(out)/icon_\(suffix).png"))
    if size <= 512 {
        try? png.write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size).png"))
    }
}
print("icons written to \(out)")

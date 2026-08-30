import SwiftUI
import AppKit

/// Renders Boo as a proper menu bar template image.
///
/// SwiftUI's `Color.primary` inside `MenuBarExtra`'s label resolves to
/// near-black regardless of the bar's appearance, which made the icon
/// invisible on a dark menu bar. A template NSImage sidesteps the whole
/// problem: macOS tints it to match the bar, inverting automatically when
/// you switch appearance or when the bar sits over a light wallpaper.
enum MenuBarIcon {
    /// Cache keyed on everything that changes the drawing. Rendering an
    /// NSImage every frame at 20fps would be wasteful; almost every tick
    /// reuses one of a handful of images.
    @MainActor private static var cache: [String: NSImage] = [:]

    @MainActor
    static func image(mood: Mood, blinking: Bool, gaze: CGFloat,
                      heartScale: CGFloat) -> NSImage {
        // Quantise the continuous inputs so the cache actually hits.
        let g = (gaze * 2).rounded() / 2
        let h = (heartScale * 10).rounded() / 10
        let key = "\(mood.rawValue)-\(blinking)-\(g)-\(h)"
        if let hit = cache[key] { return hit }

        let view = Face(mood: mood, tint: .idle,
                        blinking: blinking, gaze: g, heartScale: h,
                        bodyColor: .black,          // template: colour is ignored
                        punchThrough: true)
            .frame(width: 18, height: 18)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3                          // Retina
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 18, height: 18))
        image.size = NSSize(width: 18, height: 18)
        // The bit that actually fixes it: macOS recolours template images
        // to contrast with the menu bar, so the ghost is never black-on-black.
        image.isTemplate = true

        // Bound the cache — gaze and heartScale combinations are finite but
        // there is no reason to let it grow forever across a long session.
        if cache.count > 120 { cache.removeAll() }
        cache[key] = image
        return image
    }
}

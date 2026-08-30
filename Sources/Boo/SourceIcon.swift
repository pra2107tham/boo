import SwiftUI
import AppKit

/// The real app icon for whatever is making the sound.
///
/// Rather than drawing an approximation of the Spotify or Apple Music logo —
/// which would be someone else's trademark redrawn badly — this pulls the
/// actual icon macOS already has for the running app. It is always correct,
/// always current, and covers apps nobody thought to special-case.
enum SourceIcon {
    private static var cache: [String: NSImage] = [:]

    /// Icon for a named app, or nil when it can't be found.
    static func image(for appName: String) -> NSImage? {
        if let hit = cache[appName] { return hit }

        // Prefer a running instance: cheapest, and it is by definition the
        // app actually making the sound.
        var found: NSImage?
        for app in NSWorkspace.shared.runningApplications
        where app.localizedName == appName {
            found = app.icon
            break
        }

        // Fall back to looking the bundle up on disk.
        if found == nil {
            for dir in ["/Applications", "/System/Applications",
                        NSHomeDirectory() + "/Applications"] {
                let path = "\(dir)/\(appName).app"
                if FileManager.default.fileExists(atPath: path) {
                    found = NSWorkspace.shared.icon(forFile: path)
                    break
                }
            }
        }

        guard let icon = found else { return nil }
        if cache.count > 24 { cache.removeAll() }
        cache[appName] = icon
        return icon
    }
}

/// A little thought cloud with the source app's icon in it, floating beside
/// Boo while music plays.
struct ThoughtBubble: View {
    let appName: String?
    /// Drives a gentle bob so it feels attached to a living thing.
    let phase: Double

    var body: some View {
        HStack(spacing: 5) {
            if let name = appName, let icon = SourceIcon.image(for: name) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 15, height: 15)
                    .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            } else {
                // No identifiable source: a music note stands in.
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(HeartTint.audio.color)
            }
            NoteBars()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        // The two trailing dots that make a speech bubble read as a thought.
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 2) {
                Circle().fill(.regularMaterial).frame(width: 5, height: 5)
                Circle().fill(.regularMaterial).frame(width: 3, height: 3)
            }
            .offset(x: 6, y: 8)
        }
        .offset(y: sin(phase) * 2)
    }
}

/// Three bars bouncing inside the bubble.
private struct NoteBars: View {
    @State private var phase: Double = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(HeartTint.audio.color)
                    .frame(width: 2,
                           height: 3 + 7 * abs(sin(phase + Double(i) * 0.8)))
            }
        }
        .frame(height: 10, alignment: .bottom)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(95))
                phase += 0.45
            }
        }
    }
}

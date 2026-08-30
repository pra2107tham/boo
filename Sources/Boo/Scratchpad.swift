import SwiftUI

/// Three little bubbles under Boo that hold whatever you need to park.
///
/// Deliberately tiny: a scratchpad is for the thing you'd otherwise write on
/// your hand — a room number, a name, a command you'll paste in a minute.
/// Anything longer belongs in a real notes app, so there is no growing list
/// and no formatting.
@MainActor
final class Scratchpad: ObservableObject {
    /// Fixed at three. More would need scrolling, which defeats the point.
    @Published var notes: [String] {
        didSet { save() }
    }

    private static let key = "booScratchpadNotes"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        // Always exactly three slots, however the stored value looks.
        notes = (0..<3).map { i in i < saved.count ? saved[i] : "" }
    }

    private func save() {
        UserDefaults.standard.set(notes, forKey: Self.key)
    }

    func clear(_ index: Int) {
        guard notes.indices.contains(index) else { return }
        notes[index] = ""
    }

    var filledCount: Int { notes.filter { !$0.isEmpty }.count }
}

/// The bubble row that appears under Boo on hover.
struct ScratchBubbles: View {
    @ObservedObject var pad: Scratchpad
    /// Which bubble is open for editing, if any.
    @Binding var editing: Int?
    /// Staggers the entrance so they pop out one after another.
    let visible: Bool

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<3, id: \.self) { i in
                Bubble(index: i,
                       text: $pad.notes[i],
                       isEditing: editing == i,
                       onTap: { editing = (editing == i) ? nil : i },
                       onClear: { pad.clear(i) })
                    .scaleEffect(visible ? 1 : 0.2)
                    .opacity(visible ? 1 : 0)
                    .animation(
                        .spring(response: 0.32, dampingFraction: 0.62)
                            .delay(visible ? Double(i) * 0.05 : 0),
                        value: visible)
            }
        }
    }
}

private struct Bubble: View {
    let index: Int
    @Binding var text: String
    let isEditing: Bool
    let onTap: () -> Void
    let onClear: () -> Void

    @FocusState private var focused: Bool
    @State private var hovering = false

    private var isEmpty: Bool { text.isEmpty }

    var body: some View {
        Group {
            if isEditing {
                // Opens into a small field. Enter commits, Escape cancels.
                TextField("note", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white)
                    .focused($focused)
                    .frame(width: 116)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.78)))
                    .overlay(Capsule().strokeBorder(HeartTint.audio.color.opacity(0.55),
                                                    lineWidth: 1))
                    .onSubmit(onTap)
                    .onAppear { focused = true }
            } else {
                Button(action: onTap) {
                    ZStack {
                        Circle()
                            .fill(isEmpty ? Color.white.opacity(hovering ? 0.16 : 0.09)
                                          : HeartTint.audio.color.opacity(0.9))
                            .overlay(
                                Circle().strokeBorder(
                                    Color.white.opacity(isEmpty ? 0.22 : 0), lineWidth: 1)
                            )
                        if isEmpty {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        } else {
                            // First letter as the glyph, so a filled bubble
                            // is identifiable at a glance without opening it.
                            Text(String(text.prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.75))
                        }
                    }
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(isEmpty ? "Jot something down" : text)
                .onHover { hovering = $0 }
                // Right-click to empty a bubble without opening it.
                .contextMenu {
                    if !isEmpty {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }
                        Button("Clear", role: .destructive, action: onClear)
                    }
                }
            }
        }
    }
}

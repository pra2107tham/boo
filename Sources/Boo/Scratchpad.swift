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

    /// Each slot has its own identity, so muscle memory forms — you learn
    /// that the pin is where the room number lives.
    static let slots: [(icon: String, name: String)] = [
        ("pencil",       "Quick note"),
        ("pin.fill",     "Remember this"),
        ("link",         "Paste a link or command"),
    ]

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

    func copy(_ index: Int) {
        guard notes.indices.contains(index), !notes[index].isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(notes[index], forType: .string)
    }

    var filledCount: Int { notes.filter { !$0.isEmpty }.count }
}

/// The bubble row that appears under Boo on hover.
///
/// Modelled on the docked pill strips that menu-bar tools use: every control
/// is the SAME fixed-size circle, always. The previous version expanded the
/// tapped bubble into a 116pt text field, which shoved the other two off the
/// edge of the window — the editor is a separate floating card now, so the
/// row itself never moves.
struct ScratchBubbles: View {
    @ObservedObject var pad: Scratchpad
    @Binding var editing: Int?
    let visible: Bool

    /// Fixed forever. Nothing in this row is allowed to resize.
    private let diameter: CGFloat = 38

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Bubble(index: i,
                       text: pad.notes[i],
                       diameter: diameter,
                       isActive: editing == i,
                       onTap: { editing = (editing == i) ? nil : i },
                       onCopy: { pad.copy(i) },
                       onClear: { pad.clear(i) })
                    .scaleEffect(visible ? 1 : 0.3)
                    .opacity(visible ? 1 : 0)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.66)
                            .delay(visible ? Double(i) * 0.04 : 0),
                        value: visible)
            }
        }
    }
}

/// One pill. Always a circle, always `diameter` across, no exceptions.
private struct Bubble: View {
    let index: Int
    let text: String
    let diameter: CGFloat
    let isActive: Bool
    let onTap: () -> Void
    let onCopy: () -> Void
    let onClear: () -> Void

    @State private var hovering = false

    private var isEmpty: Bool { text.isEmpty }
    private var slot: (icon: String, name: String) { Scratchpad.slots[index] }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.07, green: 0.07, blue: 0.08))
                    .overlay(
                        Circle().strokeBorder(borderColor, lineWidth: isActive ? 1.5 : 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 5, y: 2)

                if isEmpty {
                    Image(systemName: slot.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(hovering ? 0.85 : 0.55))
                } else {
                    // A filled slot shows its first letter, so you can tell
                    // the three apart without opening any of them.
                    Text(String(text.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: diameter, height: diameter)
            // A filled slot gets a small dot, the way a live indicator works
            // on a docked strip — visible without reading anything.
            .overlay(alignment: .topTrailing) {
                if !isEmpty {
                    Circle()
                        .fill(HeartTint.idle.color)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(Color(red: 0.07, green: 0.07,
                                                             blue: 0.08), lineWidth: 1.5))
                        .offset(x: 1, y: -1)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isEmpty ? slot.name : text)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.12)) { hovering = h }
        }
        .contextMenu {
            if !isEmpty {
                Button("Copy", action: onCopy)
                Button("Clear", role: .destructive, action: onClear)
            }
        }
    }

    private var borderColor: Color {
        if isActive { return HeartTint.audio.color.opacity(0.9) }
        if !isEmpty { return .white.opacity(0.16) }
        return .white.opacity(hovering ? 0.24 : 0.12)
    }
}

/// The editor. A separate floating card, so the bubbles never resize.
struct ScratchEditor: View {
    @ObservedObject var pad: Scratchpad
    let index: Int
    let onClose: () -> Void

    @FocusState private var focused: Bool

    private var slot: (icon: String, name: String) { Scratchpad.slots[index] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: slot.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(slot.name.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.9)
                Spacer(minLength: 10)
                if !pad.notes[index].isEmpty {
                    Button { pad.copy(index) } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("Copy")
                    Button { pad.clear(index) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                }
            }
            .foregroundStyle(.white.opacity(0.45))

            TextField("", text: $pad.notes[index], axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1...4)
                .focused($focused)
                .onSubmit(onClose)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(width: 178)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
        .onAppear { focused = true }
        // Escape closes without needing the mouse.
        .onExitCommand(perform: onClose)
    }
}

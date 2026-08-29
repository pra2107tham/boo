import SwiftUI
import AppKit

/// The floating desktop Boo: a small borderless window you drag anywhere.
///
/// Deliberately NOT a real "widget" (WidgetKit) — those can't animate
/// continuously, can't be dragged freely, and only refresh on the system's
/// schedule. A borderless NSPanel does everything asked of it and needs
/// no extension target.
final class DesktopWindow: NSPanel {
    /// Position survives relaunch. Stored as the window's origin.
    private static let originKey = "desktopBooOrigin"

    init(content: NSView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
                   // .nonactivatingPanel keeps your current app focused when
                   // you drag Boo — grabbing the ghost shouldn't steal focus
                   // from whatever you're typing in.
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Above normal windows but below the menu bar, so it never covers
        // system UI or fights with a fullscreen video's controls.
        level = .floating
        // Follow you across Spaces, and stay visible over fullscreen apps.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        // Panels normally hide when the app deactivates; this is a pet, it stays.
        hidesOnDeactivate = false

        contentView = content
        restorePosition()

        // Save wherever it ends up, so it comes back there next launch.
        NotificationCenter.default.addObserver(
            self, selector: #selector(savePosition),
            name: NSWindow.didMoveNotification, object: self)
    }

    /// Borderless windows refuse key status by default, which would break
    /// the right-click menu.
    override var canBecomeKey: Bool { true }

    private func restorePosition() {
        guard let saved = UserDefaults.standard.string(forKey: Self.originKey) else {
            centerOnScreen()
            return
        }
        let point = NSPointFromString(saved)
        // A saved position can be off-screen now (display unplugged, or a
        // resolution change). Fall back to centre rather than stranding it.
        guard NSScreen.screens.contains(where: {
            $0.visibleFrame.intersects(NSRect(origin: point,
                                              size: CGSize(width: 120, height: 120)))
        }) else {
            centerOnScreen()
            return
        }
        setFrameOrigin(point)
    }

    private func centerOnScreen() {
        guard let visible = NSScreen.main?.visibleFrame else { return }
        setFrameOrigin(CGPoint(x: visible.maxX - 180, y: visible.minY + 120))
    }

    @objc private func savePosition() {
        UserDefaults.standard.set(NSStringFromPoint(frame.origin), forKey: Self.originKey)
    }
}

/// Owns the panel's lifetime and keeps its SwiftUI content fed with state.
@MainActor
final class DesktopBoo: ObservableObject {
    @Published var isVisible: Bool {
        didSet {
            UserDefaults.standard.set(isVisible, forKey: "desktopBooVisible")
            isVisible ? show() : hide()
        }
    }

    private var panel: DesktopWindow?
    private let state: BooState

    init(state: BooState) {
        self.state = state
        // Off by default — the menu bar is the primary surface. Opting in
        // is a deliberate act, not something sprung on a first-time user.
        self.isVisible = UserDefaults.standard.bool(forKey: "desktopBooVisible")
        if isVisible { show() }
    }

    private func show() {
        guard panel == nil else { panel?.orderFront(nil); return }
        let view = NSHostingView(rootView: DesktopFace(state: state, owner: self))
        view.frame = NSRect(x: 0, y: 0, width: 120, height: 120)
        let p = DesktopWindow(content: view)
        p.orderFront(nil)
        panel = p
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

/// What actually renders in the floating panel. Bigger than the menu bar
/// version, and it keeps its colours — no template-image tinting here.
struct DesktopFace: View {
    @ObservedObject var state: BooState
    @ObservedObject var animator: Animator
    let owner: DesktopBoo
    @State private var hovering = false

    init(state: BooState, owner: DesktopBoo) {
        self.state = state
        self.animator = state.animator
        self.owner = owner
    }

    var body: some View {
        ZStack {
            Face(mood: state.mood,
                 tint: state.tint,
                 blinking: animator.blinking,
                 gaze: animator.gaze,
                 heartScale: animator.heartScale,
                 voidColor: Color(red: 0.05, green: 0.05, blue: 0.06))
                .frame(width: 96, height: 96)
                .offset(y: animator.float * 3)   // more float than the menu bar
                .shadow(color: .black.opacity(0.28), radius: 10, y: 5)

            // A speech bubble on hover, so you can read the state without
            // going up to the menu bar.
            if hovering {
                Text(state.mood.headline)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -54)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: 120, height: 120)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .contextMenu {
            Text(state.mood.headline)
            Divider()
            Button("Hide desktop Boo") { owner.isVisible = false }
            Button("Quit Boo") { NSApplication.shared.terminate(nil) }
        }
        .help("Drag me anywhere")
    }
}

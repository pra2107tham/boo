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
        super.init(contentRect: NSRect(x: 0, y: 0, width: 220, height: 290),
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
        // NOT isMovableByWindowBackground: it moves the window itself while
        // the SwiftUI DragGesture is also handling the same events, and the
        // two fight. Dragging is driven explicitly in moveBy() instead.
        isMovableByWindowBackground = false
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
                                              size: CGSize(width: 220, height: 290)))
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
    let personality: Personality
    let scratchpad = Scratchpad()

    init(state: BooState, personality: Personality) {
        self.state = state
        self.personality = personality
        // Off by default — the menu bar is the primary surface. Opting in
        // is a deliberate act, not something sprung on a first-time user.
        self.isVisible = UserDefaults.standard.bool(forKey: "desktopBooVisible")
        if isVisible { show() }
    }

    private func show() {
        guard panel == nil else { panel?.orderFront(nil); return }
        personality.tracksCursor = true
        let view = NSHostingView(rootView: DesktopFace(state: state,
                                                       personality: personality,
                                                       owner: self))
        view.frame = NSRect(x: 0, y: 0, width: 220, height: 290)
        let p = DesktopWindow(content: view)
        p.orderFront(nil)
        panel = p
    }

    private func hide() {
        personality.tracksCursor = false
        panel?.orderOut(nil)
        panel = nil
    }

    /// Make sure the editor card has room below Boo before it opens.
    ///
    /// The card lives at the bottom of a 330pt window, so a Boo parked near
    /// the bottom of the screen would open it off the edge. Nudge the whole
    /// window up just enough, and only when needed.
    func ensureRoomForEditor() {
        guard let p = panel,
              let visible = NSScreen.screens.first(where: { $0.frame.intersects(p.frame) })?
                  .visibleFrame
        else { return }
        let overhang = visible.minY - p.frame.minY
        guard overhang > 0 else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().setFrameOrigin(CGPoint(x: p.frame.origin.x,
                                                y: p.frame.origin.y + overhang + 8))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.reportPosition()
        }
    }

    /// A borderless panel does not take key status by default, so the note
    /// field would silently swallow every keystroke. Only ask for it while
    /// the editor is open — grabbing focus permanently would steal typing
    /// from whatever you are actually working in.
    func setAcceptsKeyboard(_ accepts: Bool) {
        guard let p = panel else { return }
        if accepts {
            p.makeKeyAndOrderFront(nil)
        } else {
            p.resignKey()
        }
    }

    /// Move the window by a delta during a drag, so exactly one thing
    /// decides where the window is.
    func moveBy(dx: CGFloat, dy: CGFloat) {
        guard let p = panel else { return }
        // Screen y grows upward; gesture y grows downward.
        p.setFrameOrigin(CGPoint(x: p.frame.origin.x + dx,
                                 y: p.frame.origin.y - dy))
        personality.screenPosition = CGPoint(x: p.frame.midX, y: p.frame.midY)
    }

    /// Save where a drag landed, and keep it reachable on screen.
    func settleAfterDrag() {
        guard let p = panel else { return }
        if let visible = NSScreen.screens.first(where: { $0.frame.intersects(p.frame) })?
            .visibleFrame {
            var origin = p.frame.origin
            let margin: CGFloat = 40
            origin.x = min(max(origin.x, visible.minX - margin),
                           visible.maxX - p.frame.width + margin)
            origin.y = min(max(origin.y, visible.minY - margin),
                           visible.maxY - p.frame.height + margin)
            if origin != p.frame.origin {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.26
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    p.animator().setFrameOrigin(origin)
                }
            }
        }
        UserDefaults.standard.set(NSStringFromPoint(p.frame.origin),
                                  forKey: "desktopBooOrigin")
        reportPosition()
    }

    /// Keep Personality informed of where Boo sits, so cursor tracking
    /// can work out which way to look.
    func reportPosition() {
        guard let p = panel else { return }
        personality.screenPosition = CGPoint(x: p.frame.midX, y: p.frame.midY)
    }

    /// Fly the window to a point, or back to where the user parked it.
    /// The saved origin is untouched, so a swoop never loses their spot.
    /// Move the window toward a point.
    ///
    /// `animated: false` matters for the orbit, which updates the target 60
    /// times a second. Animating each step restarted an 0.85s animation on
    /// every frame, so each one was cancelled before it travelled anywhere
    /// and the window just shivered in place instead of lapping the cursor.
    func flyTo(_ target: CGPoint?, animated: Bool = true) {
        guard let p = panel else { return }
        let destination: CGPoint
        if let t = target {
            destination = CGPoint(x: t.x - p.frame.width / 2,
                                  y: t.y - p.frame.height / 2)
        } else {
            guard let saved = UserDefaults.standard.string(forKey: "desktopBooOrigin")
            else { return }
            destination = NSPointFromString(saved)
        }
        guard animated else {
            // Per-frame positioning: set it directly, no animation to cancel.
            p.setFrameOrigin(destination)
            personality.screenPosition = CGPoint(x: p.frame.midX, y: p.frame.midY)
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.85
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            p.animator().setFrameOrigin(destination)
        }
        // Report where it lands so gaze keeps working mid-flight.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.reportPosition()
        }
    }
}

/// The clickable parts of the panel. The frame is much wider than the ghost
/// so the editor card has somewhere to live, and the empty space must not
/// steal clicks from whatever is behind it.
private struct InteractiveRegion: Shape {
    let editing: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        // Ghost, centred on dy -46 to match where it renders.
        p.addEllipse(in: CGRect(x: cx - 54, y: cy - 100, width: 108, height: 108))
        // Bubble row, centred on dy +27 (106pt wide, 30pt tall + slop)
        p.addRoundedRect(in: CGRect(x: cx - 57, y: cy + 8, width: 114, height: 38),
                         cornerSize: CGSize(width: 19, height: 19))
        // Editor card, centred on dy +89, only while open
        if editing {
            p.addRoundedRect(in: CGRect(x: cx - 88, y: cy + 50, width: 176, height: 82),
                             cornerSize: CGSize(width: 14, height: 14))
        }
        return p
    }
}

/// What actually renders in the floating panel. Bigger than the menu bar
/// version, and it keeps its colours — no template-image tinting here.
struct DesktopFace: View {
    @ObservedObject var state: BooState
    @ObservedObject var animator: Animator
    @ObservedObject var personality: Personality
    let owner: DesktopBoo

    @State private var hovering = false
    @State private var hoverStart: Date?
    @State private var bubblePhase: Double = 0
    @State private var wobble: Double = 0
    @State private var hop: CGFloat = 0
    @State private var lastDrag: CGPoint = .zero
    @State private var editingNote: Int?

    init(state: BooState, personality: Personality, owner: DesktopBoo) {
        self.state = state
        self.animator = state.animator
        self.personality = personality
        self.owner = owner
    }

    private var effectiveMood: Mood {
        personality.act == .sleeping ? .sleepy : state.mood
    }

    private var bubblesShown: Bool { hovering || editingNote != nil }

    var body: some View {
        ZStack {
            ghost
            trail
            particles
            thoughtCloud
            speechBubble
            bubbleRow
            editorCard
        }
        .frame(width: 220, height: 290)
        .contentShape(InteractiveRegion(editing: editingNote != nil))
        .onTapGesture(count: 2) { personality.orbitCursor() }
        .onTapGesture { personality.showerHearts() }
        .gesture(dragGesture)
        .onHover(perform: handleHover)
        .onAppear { owner.reportPosition() }
        .onChange(of: editingNote) { _, value in
            // A borderless panel needs key status before it can receive typing.
            owner.setAcceptsKeyboard(value != nil)
            if value != nil { owner.ensureRoomForEditor() }
        }
        .onChange(of: personality.swoopTarget) { _, target in
            // The orbit drives position per frame; everything else animates.
            owner.flyTo(target, animated: personality.act != .orbiting)
        }
        .task { await animationClock() }
        .contextMenu {
            Text(state.mood.headline)
            Divider()
            Button("Do a lap around my cursor") { personality.orbitCursor() }
            Button("Come tell me to focus") { personality.swoop() }
            Button("Shower hearts") { personality.showerHearts() }
            Button("Give me a fright") { personality.scare() }
            Divider()
            Button("Hide desktop Boo") { owner.isVisible = false }
            Button("Quit Boo") { NSApplication.shared.terminate(nil) }
        }
    }

    // MARK: - Pieces

    private var ghost: some View {
        Face(mood: effectiveMood,
             tint: state.tint,
             blinking: animator.blinking,
             gaze: personality.lookX,
             gazeY: personality.lookY,
             act: personality.act,
             heartScale: animator.heartScale,
             voidColor: Color(red: 0.05, green: 0.05, blue: 0.06))
            .frame(width: 96, height: 96)
            .scaleEffect(x: (2 - personality.squash) / personality.stretch,
                         y: personality.squash * personality.stretch,
                         anchor: .bottom)
            .rotationEffect(.degrees(personality.danceAngle + wobble
                                     + personality.dragTilt), anchor: .bottom)
            .rotation3DEffect(.degrees(personality.spin), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(personality.scale)
            .offset(y: animator.float * 3 + hop - 46)
            .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
    }

    @ViewBuilder
    private var trail: some View {
        if personality.act == .orbiting {
            OrbitTrail(points: personality.trail)
                .frame(width: 120, height: 120)
                .offset(y: -46)
        }
    }

    private var particles: some View {
        ParticleLayer(particles: personality.particles)
            .frame(width: 120, height: 120)
            .offset(y: -46)
    }

    @ViewBuilder
    private var thoughtCloud: some View {
        if state.mood == .tunedIn {
            ThoughtBubble(appName: state.snapshot.audioSource, phase: bubblePhase)
                .offset(x: 44, y: -86)
        }
    }

    @ViewBuilder
    private var speechBubble: some View {
        if let line = personality.speech, editingNote == nil {
            Text(line)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.72), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .fixedSize()
                .offset(y: -102)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    private var bubbleRow: some View {
        ScratchBubbles(pad: owner.scratchpad,
                       editing: $editingNote,
                       visible: bubblesShown)
            .offset(y: 27)
    }

    @ViewBuilder
    private var editorCard: some View {
        if let i = editingNote {
            ScratchEditor(pad: owner.scratchpad, index: i) { editingNote = nil }
                .offset(y: 89)
                // Grows downward out of the row it belongs to, keeping
                // Boo's whole layout on one vertical axis.
                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
        }
    }

    // MARK: - Interaction

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                if personality.act != .squashed { personality.beginDrag() }
                let dx = value.location.x - lastDrag.x
                let dy = value.location.y - lastDrag.y
                if lastDrag != .zero { owner.moveBy(dx: dx, dy: dy) }
                lastDrag = value.location
                personality.dragging(velocity: value.velocity)
            }
            .onEnded { value in
                lastDrag = .zero
                personality.endDrag(velocity: value.velocity)
                owner.settleAfterDrag()
            }
    }

    private func handleHover(_ h: Bool) {
        withAnimation(.easeOut(duration: 0.16)) { hovering = h }
        guard h else { hoverStart = nil; return }
        hoverStart = Date()
        personality.noteActivity()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if hovering, let start = hoverStart,
               Date().timeIntervalSince(start) >= 1.9, editingNote == nil {
                personality.pet()
            }
        }
    }

    /// Local clock for the bubble bob and the jelly antics.
    private func animationClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(60))
            bubblePhase += 0.09
            switch personality.act {
            case .wobbling: wobble = sin(bubblePhase * 4) * 7
            case .bouncing: hop = -abs(sin(bubblePhase * 3)) * 10
            case .sneezing: hop = sin(bubblePhase * 9) * 3
            default:
                if wobble != 0 { wobble *= 0.8; if abs(wobble) < 0.1 { wobble = 0 } }
                if hop != 0 { hop *= 0.8; if abs(hop) < 0.1 { hop = 0 } }
            }
        }
    }
}


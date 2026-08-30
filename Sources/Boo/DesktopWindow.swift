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
        super.init(contentRect: NSRect(x: 0, y: 0, width: 168, height: 168),
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
        view.frame = NSRect(x: 0, y: 0, width: 168, height: 168)
        let p = DesktopWindow(content: view)
        p.orderFront(nil)
        panel = p
    }

    private func hide() {
        personality.tracksCursor = false
        panel?.orderOut(nil)
        panel = nil
    }

    /// Keep Personality informed of where Boo sits, so cursor tracking
    /// can work out which way to look.
    func reportPosition() {
        guard let p = panel else { return }
        personality.screenPosition = CGPoint(x: p.frame.midX, y: p.frame.midY)
    }

    /// Move the window by a delta during a drag. Driven from the gesture so
    /// there is exactly one thing deciding where the window is.
    func moveBy(dx: CGFloat, dy: CGFloat) {
        guard let p = panel else { return }
        // Screen y grows upward; gesture y grows downward.
        p.setFrameOrigin(CGPoint(x: p.frame.origin.x + dx,
                                 y: p.frame.origin.y - dy))
        personality.screenPosition = CGPoint(x: p.frame.midX, y: p.frame.midY)
    }

    /// Called when a drag ends: save where it landed, and keep it on screen.
    func settleAfterDrag() {
        guard let p = panel else { return }
        // A window dragged mostly off-screen is unrecoverable, so nudge it
        // back until at least most of it is visible.
        if let visible = NSScreen.screens.first(where: {
            $0.frame.intersects(p.frame)
        })?.visibleFrame {
            var origin = p.frame.origin
            let margin: CGFloat = 30
            origin.x = min(max(origin.x, visible.minX - margin),
                           visible.maxX - p.frame.width + margin)
            origin.y = min(max(origin.y, visible.minY - margin),
                           visible.maxY - p.frame.height + margin)
            if origin != p.frame.origin {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.28
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    p.animator().setFrameOrigin(origin)
                }
            }
        }
        UserDefaults.standard.set(NSStringFromPoint(p.frame.origin),
                                  forKey: "desktopBooOrigin")
        reportPosition()
    }

    /// Fly the window to a point, or back to where the user parked it.
    /// The saved origin is untouched, so a swoop never loses their spot.
    func flyTo(_ target: CGPoint?) {
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
    @State private var lastDrag: CGPoint = .zero
    @State private var editingNote: Int?
    @State private var wobble: Double = 0
    @State private var hop: CGFloat = 0

    init(state: BooState, personality: Personality, owner: DesktopBoo) {
        self.state = state
        self.animator = state.animator
        self.personality = personality
        self.owner = owner
    }

    /// Acts that should suppress the mood's own expression.
    private var effectiveMood: Mood {
        switch personality.act {
        case .sleeping: return .sleepy
        default: return state.mood
        }
    }

    var body: some View {
        ZStack {
            Face(mood: effectiveMood,
                 tint: state.tint,
                 blinking: animator.blinking,
                 gaze: personality.lookX,
                 gazeY: personality.lookY,
                 act: personality.act,
                 heartScale: animator.heartScale,
                 voidColor: Color(red: 0.05, green: 0.05, blue: 0.06))
                .frame(width: 96, height: 96)
                // Squash on drag, stretch on a yawn.
                .scaleEffect(x: (2 - personality.squash) / personality.stretch,
                             y: personality.squash * personality.stretch,
                             anchor: .bottom)
                .rotationEffect(.degrees(personality.danceAngle + wobble
                                         + personality.dragTilt), anchor: .bottom)
                .scaleEffect(personality.scale)
                .rotation3DEffect(.degrees(personality.spin), axis: (x: 0, y: 1, z: 0))
                .offset(y: animator.float * 3 + hop)
                .shadow(color: .black.opacity(0.28), radius: 10, y: 5)

            if personality.act == .orbiting {
                OrbitTrail(points: personality.trail)
                    .frame(width: 120, height: 120)
            }

            ParticleLayer(particles: personality.particles)
                .frame(width: 120, height: 120)

            // Thought cloud with the source app's icon while music plays.
            if state.mood == .tunedIn {
                ThoughtBubble(appName: state.snapshot.audioSource, phase: bubblePhase)
                    .offset(x: 42, y: -40)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            // What Boo says when it swoops over.
            if let line = personality.speech {
                Text(line)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.72), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                    .fixedSize()
                    .offset(y: -56)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // Scratchpad bubbles slide out below on hover.
            ScratchBubbles(pad: owner.scratchpad,
                           editing: $editingNote,
                           visible: hovering || editingNote != nil)
                .offset(y: 52)

            if hovering, personality.act != .sleeping, editingNote == nil {
                Text(bubbleText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -54)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: 168, height: 168)
        .contentShape(Rectangle())
        // Click for hearts — the first thing anyone tries.
        .onTapGesture(count: 2) { personality.orbitCursor() }
        .onTapGesture { personality.showerHearts() }
        // One gesture drives both the window position and the squash, so
        // nothing competes for the same events.
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { value in
                    if personality.act != .squashed { personality.beginDrag() }
                    // Move by the delta since the last frame, not from the
                    // start, so the window tracks the pointer exactly.
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
        )
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) { hovering = h }
            if h {
                hoverStart = Date()
                personality.noteActivity()
                // Linger and it counts as petting.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    if hovering, let start = hoverStart,
                       Date().timeIntervalSince(start) >= 1.9 {
                        personality.pet()
                    }
                }
            } else {
                hoverStart = nil
            }
        }
        .onAppear { owner.reportPosition() }
        // Fly to the pointer when a swoop starts, and home when it ends.
        .onChange(of: personality.swoopTarget) { _, target in
            owner.flyTo(target)
        }
        // Local animation clock for the bubble and the jelly antics.
        .task {
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
        .contextMenu {
            Text(state.mood.headline)
            Divider()
            Button("Give me a fright") { personality.scare() }
            Button("Shower hearts") { personality.showerHearts() }
            Button("Come tell me to focus") { personality.swoop() }
            Button("Do a lap around my cursor") { personality.orbitCursor() }
            Divider()
            Button("Hide desktop Boo") { owner.isVisible = false }
            Button("Quit Boo") { NSApplication.shared.terminate(nil) }
        }
        .help("Drag me anywhere · click for hearts")
    }

    private var bubbleText: String {
        switch personality.act {
        case .hearts, .petted: "hehe"
        case .scared:          "BOO!"
        case .giggling:        "got you"
        case .dancing:         "this one slaps"
        case .celebrating:     "we did it"
        case .squashed:        "wheee"
        case .yawning:         "hhhaaaah"
        case .sneezing:        "atchoo"
        case .stargazing:      "pretty"
        case .spinning:        "wheee"
        case .orbiting:        "zoom"
        default:               state.mood.headline
        }
    }
}

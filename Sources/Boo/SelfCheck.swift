import Foundation

/// Run with `swift run Boo --self-check`. Covers the parts that would
/// silently misbehave: threshold flapping, and the headphone name guess.
enum SelfCheck {
    static func run() -> Never {
        let base = Date()

        // Hysteresis: 80% must NOT trip strained on its own.
        var e = MoodEngine(dwell: 0)
        var s = Snapshot(cpu: 80)
        assert(e.update(s, now: base) != .strained, "80% should not enter strained")

        // 85% enters, and 80% keeps it — that's the whole point of the gap.
        s.cpu = 86
        assert(e.update(s, now: base) == .strained, "86% should enter strained")
        s.cpu = 80
        assert(e.update(s, now: base) == .strained, "80% should stay strained")
        s.cpu = 70
        assert(e.update(s, now: base) != .strained, "70% should leave strained")

        // Dwell: a spike shorter than the dwell must not change the face.
        e = MoodEngine(dwell: 5)
        assert(e.update(Snapshot(cpu: 5), now: base) == .calm)
        let spike = Snapshot(cpu: 95)
        assert(e.update(spike, now: base) == .calm, "spike should not apply instantly")
        assert(e.update(spike, now: base.addingTimeInterval(2)) == .calm, "2s < dwell")
        assert(e.update(spike, now: base.addingTimeInterval(6)) == .strained, "6s > dwell")

        // Charging is immediate and outranks everything.
        e = MoodEngine(dwell: 5)
        var charging = Snapshot(cpu: 99)
        charging.isCharging = true
        assert(e.update(charging, now: base) == .charged, "charging should apply at once")

        // Low battery beats a busy CPU, but not a charger.
        e = MoodEngine(dwell: 0)
        var low = Snapshot(cpu: 50)
        low.battery = 12
        assert(e.update(low, now: base) == .sleepy, "low battery should win over load")

        // Headphone detection: the negative case is the one that bites.
        assert(!SystemMetrics.looksLikeHeadphones("MacBook Pro Speakers", deviceID: 0),
               "built-in speakers are not headphones")
        assert(!SystemMetrics.looksLikeHeadphones("Studio Display", deviceID: 0),
               "a display is not headphones")
        assert(SystemMetrics.looksLikeHeadphones("Pratham's AirPods Pro", deviceID: 0),
               "AirPods are headphones")
        assert(SystemMetrics.looksLikeHeadphones("WH-1000XM5", deviceID: 0),
               "Sony cans are headphones")

        // Beat interval maps load onto the documented range.
        assert(abs(MoodEngine.beatInterval(cpu: 0) - 4.0) < 0.01)
        assert(abs(MoodEngine.beatInterval(cpu: 100) - 0.4) < 0.01)

        // Music on the built-in speakers must still read as tuned in —
        // the original bug was only ever checking the device type.
        e = MoodEngine(dwell: 0)
        var speakers = Snapshot(cpu: 10)
        speakers.outputDevice = "MacBook Air Speakers"
        speakers.isHeadphones = false
        speakers.isPlayingAudio = true
        assert(e.update(speakers, now: base) == .tunedIn,
               "music on speakers should count as tuned in")
        assert(MoodEngine.tint(for: speakers) == .audio,
               "playing audio should tint the heart teal")

        // Headphones plugged in but silent is NOT tuned in.
        e = MoodEngine(dwell: 0)
        var silent = Snapshot(cpu: 10)
        silent.isHeadphones = true
        silent.isPlayingAudio = false
        assert(e.update(silent, now: base) != .tunedIn,
               "silent headphones should not be tuned in")

        // Top process needs two samples: the first has no baseline, so it
        // must return nil rather than blaming whoever booted first.
        var top = TopProcess()
        assert(top.busiest(now: base) == nil, "first sample has no baseline")

        // Two samples too close together are meaningless — also nil.
        _ = top.busiest(now: base)
        assert(top.busiest(now: base.addingTimeInterval(0.1)) == nil,
               "sub-second gap is too short to rate")

        // Particles must die rather than accumulating forever — an
        // always-on pet leaking a growing array is how you get a 3am page.
        let personality = MainActor.assumeIsolated { Personality() }
        MainActor.assumeIsolated {
            personality.emit(.heart, count: 10)
            assert(personality.particles.count == 10, "emit should add particles")
            // Life drains at 0.022/frame, so ~46 frames clears them.
            for _ in 0..<60 { personality.stepParticlesForTesting() }
            assert(personality.particles.isEmpty,
                   "particles must expire, got \(personality.particles.count)")
        }

        print("self-check passed")
        exit(0)
    }
}

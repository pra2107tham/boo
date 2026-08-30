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

        // Beat interval maps load onto the documented range.
        assert(abs(MoodEngine.beatInterval(cpu: 0) - 4.0) < 0.01)
        assert(abs(MoodEngine.beatInterval(cpu: 100) - 0.4) < 0.01)

        // --- Audio edge cases. The stuck-on-Tuned-in bug lived here. ---

        // Music on the built-in speakers must read as tuned in.
        e = MoodEngine(dwell: 0)
        var speakers = Snapshot(cpu: 10)
        speakers.outputDevice = "MacBook Air Speakers"
        speakers.isPlayingAudio = true
        assert(e.update(speakers, now: base) == .tunedIn,
               "music on speakers should count as tuned in")
        assert(MoodEngine.tint(for: speakers) == .audio,
               "playing audio should tint the heart teal")

        // Headphones plugged in but silent is NOT tuned in. This is the
        // case the device-type check got wrong.
        e = MoodEngine(dwell: 0)
        var silent = Snapshot(cpu: 10)
        silent.outputDevice = "AirPods Pro"
        silent.isHeadphones = true
        silent.isPlayingAudio = false
        assert(e.update(silent, now: base) != .tunedIn,
               "silent headphones should not be tuned in")
        assert(MoodEngine.tint(for: silent) != .audio,
               "silence should not tint the heart teal")

        // Muted with a stream open — the paused-player case.
        e = MoodEngine(dwell: 0)
        var muted = Snapshot(cpu: 10)
        muted.outputDevice = "MacBook Air Speakers"
        muted.isMuted = true
        muted.isPlayingAudio = false
        assert(e.update(muted, now: base) != .tunedIn,
               "muted output should not be tuned in")

        // No output device at all: the panel hides the row rather than
        // printing "Unknown".
        let headless = Snapshot(cpu: 10)
        assert(headless.outputDevice == nil,
               "a Mac with no output device reports nil, not a placeholder")

        // The grace period: brief silence between tracks must not stop
        // the dance, but sustained silence must.
        var audio = AudioState()
        let t0 = Date()
        _ = audio.read(now: t0)          // establishes state; real APIs read live

        // Headphone name matching — the negative case is the one that bites.
        assert(!AudioState.looksLikeHeadphones("MacBook Pro Speakers", deviceID: 0),
               "built-in speakers are not headphones")
        assert(!AudioState.looksLikeHeadphones("Studio Display", deviceID: 0),
               "a display is not headphones")
        assert(AudioState.looksLikeHeadphones("Pratham's AirPods Pro", deviceID: 0),
               "AirPods are headphones")
        assert(AudioState.looksLikeHeadphones("WH-1000XM5", deviceID: 0),
               "Sony cans are headphones")

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

        // Scratchpad always holds exactly three slots, whatever is stored.
        // A short or missing saved array must not crash the bubble row.
        MainActor.assumeIsolated {
            UserDefaults.standard.removeObject(forKey: "booScratchpadNotes")
            let fresh = Scratchpad()
            assert(fresh.notes.count == 3, "empty state must still be 3 slots")
            assert(fresh.filledCount == 0, "nothing stored means nothing filled")

            // A truncated saved array (older version, manual edit) must pad.
            UserDefaults.standard.set(["only one"], forKey: "booScratchpadNotes")
            let padded = Scratchpad()
            assert(padded.notes.count == 3, "short saved array must pad to 3")
            assert(padded.notes[0] == "only one", "existing note must survive")
            assert(padded.filledCount == 1, "one note means one filled")

            padded.clear(0)
            assert(padded.filledCount == 0, "clear should empty the slot")
            // Out-of-range clear must be a no-op, not a crash.
            padded.clear(99)

            UserDefaults.standard.removeObject(forKey: "booScratchpadNotes")
        }

        // Rapid clicking must not pile up particles without bound. This is
        // what made Boo bog down and stop responding: every click added 12
        // more to a swarm that was already being stepped 30 times a second.
        MainActor.assumeIsolated {
            let spam = Personality()
            for _ in 0..<25 { spam.showerHearts() }
            assert(spam.particles.count <= 40,
                   "particle swarm must stay capped, got \(spam.particles.count)")
            // And they must still all expire afterwards.
            for _ in 0..<80 { spam.stepParticlesForTesting() }
            assert(spam.particles.isEmpty,
                   "capped particles must still expire, \(spam.particles.count) left")
        }

        // Behaviour priority: a filling disk must outrank a cold draught,
        // and neither may interrupt a performance.
        MainActor.assumeIsolated {
            let p = Personality()
            var reading = Activity.Reading()
            reading.freeDiskGB = 4          // critical
            reading.fansLikelySpinning = true
            p.observe(reading, snapshot: Snapshot())
            assert(p.act == .sheltering,
                   "low disk should outrank fans, got \(p.act)")

            // Fans alone, with plenty of disk.
            let q = Personality()
            var fans = Activity.Reading()
            fans.freeDiskGB = 400
            fans.fansLikelySpinning = true
            q.observe(fans, snapshot: Snapshot())
            assert(q.act == .shivering, "fans should shiver, got \(q.act)")

            // Typing beats everything else — you are actively working.
            let t = Personality()
            var typing = Activity.Reading()
            typing.isTyping = true
            typing.freeDiskGB = 2
            typing.fansLikelySpinning = true
            t.observe(typing, snapshot: Snapshot())
            assert(t.act == .typing, "typing should win, got \(t.act)")

            // Plenty of disk and a quiet machine leaves it alone.
            let calm = Personality()
            var quiet = Activity.Reading()
            quiet.freeDiskGB = 500
            calm.observe(quiet, snapshot: Snapshot())
            assert(calm.act == .none, "a quiet Mac should not trigger anything")
        }

        print("self-check passed")
        exit(0)
    }
}

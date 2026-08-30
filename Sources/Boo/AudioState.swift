import Foundation
import CoreAudio
import AppKit

/// Whether sound is actually coming out of the Mac right now.
///
/// The obvious flag — `kAudioDevicePropertyDeviceIsRunningSomewhere` — is a
/// trap. It means "a stream is open on this device", not "audio is playing".
/// Any app *holding* the device pins it to 1 forever: a muted browser tab,
/// an idle Zoom, a paused player. Measured on a real Mac it read 1 while
/// exactly one of sixty audio processes was genuinely outputting.
///
/// So this asks per process instead, and layers the cheap disqualifiers
/// (no device, muted, volume at zero) in front of it.
struct AudioState {
    /// Grace period before silence counts. The gap between tracks is
    /// shorter than this, so Boo doesn't stutter mid-playlist — the same
    /// hysteresis idea that stops the CPU face flickering during a build.
    private static let silenceGrace: TimeInterval = 3

    private var lastHeardSound: Date?

    /// Result of one poll.
    struct Reading {
        var deviceName: String?      // nil when there is no output device at all
        var isHeadphones = false
        var isPlaying = false
        var isMuted = false
        var volume: Float = 0
        /// App making the sound, when it can be named.
        var source: String?
    }

    mutating func read(now: Date = Date()) -> Reading {
        var r = Reading()

        guard let device = Self.defaultOutputDevice() else {
            // No output device — nothing to report, so report nothing.
            lastHeardSound = nil
            return r
        }

        r.deviceName = Self.name(of: device)
        r.isHeadphones = Self.looksLikeHeadphones(r.deviceName ?? "", deviceID: device)
        r.isMuted = Self.isMuted(device)
        r.volume = Self.volume(device)

        // Muted or silent volume means silent, whatever any process claims.
        guard !r.isMuted, r.volume > 0.001 else {
            lastHeardSound = nil
            return r
        }

        // Per-process flags are the signal. A process must report BOTH
        // IsRunning and IsRunningOutput: holding an output stream alone
        // (IsRunningOutput) is what Chrome does for minutes after a video
        // ends, which is what pinned Boo to "Tuned in" forever.
        //
        // Note the device-level DeviceIsRunning is NOT used as a gate.
        // It reads 0 on this hardware even mid-playback, so requiring it
        // suppressed detection entirely.
        let (playing, source) = Self.processesOutputting()
        if playing {
            lastHeardSound = now
            r.isPlaying = true
            r.source = source
        } else if let last = lastHeardSound,
                  now.timeIntervalSince(last) < Self.silenceGrace {
            // Briefly silent — probably between tracks. Hold the answer.
            r.isPlaying = true
        } else {
            lastHeardSound = nil
        }
        return r
    }

    // MARK: - Device

    static func defaultOutputDevice() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown
        else { return nil }
        return device
    }

    static func name(of device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        // CoreAudio hands back a +1 CFString; Unmanaged keeps ARC out of it.
        var unmanaged: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil,
                                         &size, &unmanaged) == noErr
        else { return nil }
        return unmanaged?.takeRetainedValue() as String?
    }

    static func isMuted(_ device: AudioDeviceID) -> Bool {
        var muted = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        // Not every device exposes mute; absence means "not muted".
        guard AudioObjectGetPropertyData(device, &address, 0, nil,
                                         &size, &muted) == noErr else { return false }
        return muted != 0
    }

    static func volume(_ device: AudioDeviceID) -> Float {
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(device, &address, 0, nil,
                                         &size, &volume) == noErr else {
            // Aggregate and some USB devices have no master volume. Assume
            // audible rather than silently never dancing.
            return 1
        }
        return volume
    }

    // MARK: - Per-process output

    /// True when any process is actively pushing audio, plus its app name
    /// when one can be resolved.
    static func processesOutputting() -> (Bool, String?) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                             &address, 0, nil, &size) == noErr,
              size > 0
        else {
            // macOS 14.0-14.3 has no process list. Fall back to the device
            // flag: wrong in the "app holds the device silently" case, but
            // better than never detecting audio at all.
            return (legacyDeviceRunning(), nil)
        }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var processes = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &size, &processes) == noErr
        else { return (legacyDeviceRunning(), nil) }

        // Several processes can hold output streams at once (a browser
        // with a stale stream, plus whatever is genuinely playing). Prefer
        // one that also reports IsRunning, and skip anything that isn't a
        // real foreground-ish app, so the name shown is the actual source.
        // Require both flags together. IsRunningOutput alone means "holds
        // a stream"; IsRunning alongside it means the stream is live.
        for process in processes
        where isRunningOutput(process) && isRunning(process) {
            return (true, appName(for: process))
        }
        return (false, nil)
    }

    /// The broader "this process has audio activity" flag. Used to break
    /// ties when more than one process holds an output stream.
    private static func isRunning(_ process: AudioObjectID) -> Bool {
        var running = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunning,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(process, &address, 0, nil,
                                         &size, &running) == noErr else { return false }
        return running != 0
    }

    private static func isRunningOutput(_ process: AudioObjectID) -> Bool {
        var running = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(process, &address, 0, nil,
                                         &size, &running) == noErr else { return false }
        return running != 0
    }

    /// Resolve an audio process to something a person recognises.
    private static func appName(for process: AudioObjectID) -> String? {
        var pid = pid_t(0)
        var size = UInt32(MemoryLayout<pid_t>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(process, &address, 0, nil,
                                         &size, &pid) == noErr else { return nil }

        if let app = NSRunningApplication(processIdentifier: pid)?.localizedName {
            return app
        }
        // Browsers play audio from helper processes that aren't registered
        // apps, so walk up to the owning bundle by name.
        return helperOwner(pid: pid)
    }

    /// "Google Chrome Helper" -> "Google Chrome".
    private static func helperOwner(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let path = String(cString: buffer)
        // Take the OUTERMOST .app in the path — the helper's own bundle is
        // nested inside the browser's, and the outer one is the real app.
        guard let range = path.range(of: ".app/") else { return nil }
        let outer = String(path[..<range.lowerBound])
        return (outer as NSString).lastPathComponent
    }

    /// Is the device's I/O engine actually moving audio right now?
    /// Distinct from DeviceIsRunningSomewhere, which only reports that a
    /// stream exists.
    static func deviceActuallyRunning(_ device: AudioDeviceID) -> Bool {
        var running = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunning,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(device, &address, 0, nil,
                                         &size, &running) == noErr else {
            // Device doesn't report it — fall back to trusting the process.
            return true
        }
        return running != 0
    }

    private static func legacyDeviceRunning() -> Bool {
        guard let device = defaultOutputDevice() else { return false }
        var running = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(device, &address, 0, nil,
                                         &size, &running) == noErr else { return false }
        return running != 0
    }

    // MARK: - Headphones

    /// CoreAudio has no "is this on someone's head" flag, so this reads the
    /// transport type and falls back to the name. The negative case is
    /// checked first: "MacBook Pro Speakers" must never match.
    static func looksLikeHeadphones(_ name: String, deviceID: AudioDeviceID) -> Bool {
        let lower = name.lowercased()
        if lower.contains("speaker") || lower.contains("display") { return false }

        var transport = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil,
                                      &size, &transport) == noErr {
            switch transport {
            case kAudioDeviceTransportTypeBluetooth,
                 kAudioDeviceTransportTypeBluetoothLE,
                 kAudioDeviceTransportTypeUSB:
                return true
            default:
                break
            }
        }
        return ["airpod", "headphone", "headset", "beats", "buds", "wh-", "wf-"]
            .contains { lower.contains($0) }
    }
}

import Foundation
import IOKit.ps
import CoreAudio

/// One snapshot of how the Mac is doing. Everything here comes from a public
/// API that needs no entitlement, no prompt and no sandbox exception.
struct Snapshot {
    var cpu: Double = 0            // 0…100, across all cores
    var memory: Double = 0         // 0…100, pressure-style (active+wired+compressed)
    var battery: Double? = nil     // 0…100, nil when there's no battery
    var isCharging = false
    var outputDevice = "Unknown"
    var isHeadphones = false
    /// True when any process is actually feeding audio to the output —
    /// music, video, a call. Distinct from isHeadphones, which only says
    /// what the sound would come out of.
    var isPlayingAudio = false
    /// Name of whatever is working hardest, when anything clearly is.
    var busiestProcess: String? = nil
}

/// Polls the system. Deliberately a plain class with a timer rather than
/// anything reactive — this runs every 2s forever, so cheap beats clever.
final class SystemMetrics {
    /// CPU load is a delta between two readings, so the previous one is state.
    private var lastTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var topProcess = TopProcess()

    func read() -> Snapshot {
        var s = Snapshot()
        s.cpu = readCPU()
        s.memory = readMemory()
        if let (level, charging) = readBattery() {
            s.battery = level
            s.isCharging = charging
        }
        let (name, headphones, playing) = readOutputDevice()
        s.outputDevice = name
        s.isHeadphones = headphones
        s.isPlayingAudio = playing
        // Only worth the scan when something is actually loaded.
        if s.cpu >= 30 { s.busiestProcess = topProcess.busiest() }
        return s
    }

    // MARK: - CPU

    private func readCPU() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size
                                          / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let cur = (user: info.cpu_ticks.0, system: info.cpu_ticks.1,
                   idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
        defer { lastTicks = cur }

        // First call has no baseline to diff against.
        guard let prev = lastTicks else { return 0 }

        // Tick counters are UInt32 and do wrap. Subtracting with overflow
        // wrap gives the right delta across the boundary.
        let dUser = cur.user &- prev.user
        let dSystem = cur.system &- prev.system
        let dIdle = cur.idle &- prev.idle
        let dNice = cur.nice &- prev.nice
        let busy = Double(dUser) + Double(dSystem) + Double(dNice)
        let total = busy + Double(dIdle)

        guard total > 0 else { return 0 }
        return min(100, max(0, busy / total * 100))
    }

    // MARK: - Memory

    private func readMemory() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size
                                          / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        // Match Activity Monitor's notion of "used": what can't be handed back
        // cheaply. Free and purgeable pages don't count against you.
        let used = Double(stats.active_count) + Double(stats.wire_count)
                 + Double(stats.compressor_page_count)
        let total = Double(ProcessInfo.processInfo.physicalMemory)
                  / Double(vm_kernel_page_size)
        guard total > 0 else { return 0 }
        return min(100, max(0, used / total * 100))
    }

    // MARK: - Battery

    private func readBattery() -> (Double, Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue()
                            as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(blob, source)?
                          .takeUnretainedValue() as? [String: Any],
                  let current = d[kIOPSCurrentCapacityKey] as? Int,
                  let max = d[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }

            let charging = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return (Double(current) / Double(max) * 100, charging)
        }
        return nil   // desktop Mac
    }

    // MARK: - Audio output

    private func readOutputDevice() -> (String, Bool, Bool) {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &size, &deviceID) == noErr
        else { return ("Unknown", false, false) }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        // CoreAudio hands back a +1 CFString. Take it through an unmanaged
        // pointer so ARC doesn't try to manage a value it never retained.
        var unmanaged: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil,
                                         &nameSize, &unmanaged) == noErr,
              let name = unmanaged?.takeRetainedValue() as String?
        else { return ("Unknown", false, false) }

        return (name,
                Self.looksLikeHeadphones(name, deviceID: deviceID),
                Self.isDeviceRunning(deviceID))
    }

    /// Whether anything is currently pushing audio through this device.
    /// This is what catches "music is playing" regardless of whether it
    /// comes out of speakers or headphones — the old code only knew what
    /// kind of device was selected, so speakers playing music read as silent.
    static func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        var running = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil,
                                         &size, &running) == noErr else { return false }
        return running != 0
    }

    /// CoreAudio has no "is this on someone's head" flag, so this reads the
    /// transport type (Bluetooth / USB / headphone jack) and falls back to
    /// the device name. Built-in speakers and displays are explicitly out.
    static func looksLikeHeadphones(_ name: String, deviceID: AudioDeviceID) -> Bool {
        var transport = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport) == noErr {
            switch transport {
            case kAudioDeviceTransportTypeBluetooth,
                 kAudioDeviceTransportTypeBluetoothLE,
                 kAudioDeviceTransportTypeUSB:
                return true
            case kAudioDeviceTransportTypeBuiltIn,
                 kAudioDeviceTransportTypeHDMI,
                 kAudioDeviceTransportTypeDisplayPort:
                // Built-in covers both the speakers and the headphone jack,
                // so fall through to the name check rather than deciding here.
                break
            default:
                break
            }
        }

        let lower = name.lowercased()
        // Guard the negative case first: "MacBook Pro Speakers" must not match.
        if lower.contains("speaker") || lower.contains("display") { return false }
        return ["airpod", "headphone", "headset", "beats", "buds", "wh-", "wf-"]
            .contains { lower.contains($0) }
    }
}

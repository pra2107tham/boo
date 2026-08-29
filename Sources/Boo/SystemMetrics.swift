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
    /// nil when the Mac has no output device at all.
    var outputDevice: String?
    var isHeadphones = false
    /// True when a process is genuinely pushing audio right now — not
    /// merely holding the device open. See AudioState for why that
    /// distinction is the whole ballgame.
    var isPlayingAudio = false
    var isMuted = false
    /// App making the sound, when it can be named.
    var audioSource: String?
    /// Name of whatever is working hardest, when anything clearly is.
    var busiestProcess: String? = nil
}

/// Polls the system. Deliberately a plain class with a timer rather than
/// anything reactive — this runs every 2s forever, so cheap beats clever.
final class SystemMetrics {
    /// CPU load is a delta between two readings, so the previous one is state.
    private var lastTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var topProcess = TopProcess()
    private var audio = AudioState()

    func read() -> Snapshot {
        var s = Snapshot()
        s.cpu = readCPU()
        s.memory = readMemory()
        if let (level, charging) = readBattery() {
            s.battery = level
            s.isCharging = charging
        }
        let a = audio.read()
        s.outputDevice = a.deviceName
        s.isHeadphones = a.isHeadphones
        s.isPlayingAudio = a.isPlaying
        s.isMuted = a.isMuted
        s.audioSource = a.source
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

}

import Foundation
import Darwin

/// Finds the process currently working hardest, so the panel can say
/// "Xcode is eating everything" instead of just "something is".
///
/// CPU time is cumulative since launch, so a single reading only tells you
/// who has burned the most since boot. Rates come from diffing two samples.
struct TopProcess {
    /// Cumulative CPU nanoseconds per pid, from the previous sample.
    private var previous: [pid_t: UInt64] = [:]
    private var lastSampled: Date?

    /// Name of the busiest process, or nil when nothing stands out.
    /// Returns nil on the first call — there's no baseline to diff yet.
    mutating func busiest(now: Date = Date()) -> String? {
        var counts = [pid_t: UInt64]()
        for pid in runningPIDs() {
            var info = rusage_info_v4()
            let ok = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: Optional<rusage_info_t>.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            guard ok == 0 else { continue }   // process died or we can't see it
            counts[pid] = info.ri_user_time + info.ri_system_time
        }

        defer { previous = counts; lastSampled = now }

        guard let last = lastSampled, !previous.isEmpty else { return nil }
        let elapsed = now.timeIntervalSince(last)
        guard elapsed > 0.5 else { return nil }   // too short to be meaningful

        // Diff against the previous sample to get an actual rate.
        var busiestPID: pid_t?
        var busiestShare = 0.0
        for (pid, total) in counts {
            guard let before = previous[pid], total > before else { continue }
            let seconds = Double(total - before) / 1_000_000_000
            let share = seconds / elapsed          // 1.0 == one core saturated
            if share > busiestShare {
                busiestShare = share
                busiestPID = pid
            }
        }

        // Below a third of a core isn't worth naming — that's just noise.
        guard busiestShare > 0.33, let pid = busiestPID else { return nil }
        return name(of: pid)
    }

    private func runningPIDs() -> [pid_t] {
        let capacity = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard capacity > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(capacity) / MemoryLayout<pid_t>.size)
        let written = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids,
                                    capacity)
        guard written > 0 else { return [] }
        let count = Int(written) / MemoryLayout<pid_t>.size
        return Array(pids.prefix(count)).filter { $0 > 0 }
    }

    private func name(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(2 * MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let path = String(cString: buffer)

        // Prefer the .app bundle name over the executable: users know
        // "Xcode", not "Xcode.app/Contents/MacOS/Xcode".
        if let range = path.range(of: ".app/") {
            let bundle = String(path[..<range.lowerBound])
            return (bundle as NSString).lastPathComponent
        }
        return (path as NSString).lastPathComponent
    }
}

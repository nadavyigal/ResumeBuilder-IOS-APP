import Foundation

// MARK: - DBGarminActivity → RecordedRun

extension DBGarminActivity {
    func toRecordedRun() -> RecordedRun? {
        guard let startStr = startTime,
              let startDate = parseISO8601(startStr),
              let durationS = durationS, durationS > 0 else { return nil }

        let distanceM = distanceM ?? 0
        let endDate = startDate.addingTimeInterval(durationS)
        let pace = distanceM > 0 ? durationS / (distanceM / 1000) : 0

        return RecordedRun(
            id: UUID(),
            providerActivityID: activityId,
            source: .garmin,
            startedAt: startDate,
            endedAt: endDate,
            distanceMeters: distanceM,
            movingTimeSeconds: durationS,
            averagePaceSecondsPerKm: pace,
            averageHeartRateBPM: avgHr,
            routePoints: [],
            syncedAt: Date()
        )
    }

    private func parseISO8601(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }
}

// MARK: - DBGarminDailyMetrics → readiness signals

struct GarminReadiness {
    let readiness: Int
    let readinessLabel: String
    let recoveryLabel: String
    let hrvLabel: String

    static func from(_ metrics: DBGarminDailyMetrics?) -> GarminReadiness {
        guard let m = metrics else {
            return GarminReadiness(readiness: 0, readinessLabel: "--", recoveryLabel: "--", hrvLabel: "--")
        }

        let bb = m.bodyBattery ?? 0
        let readiness = min(100, max(0, bb))
        let label: String
        switch bb {
        case 71...: label = "Ready to train"
        case 41...70: label = "Moderate energy"
        default: label = "Rest recommended"
        }

        let recovery: String
        if let sleepS = m.sleepDurationS, sleepS > 0 {
            let hrs = sleepS / 3600
            let mins = (sleepS % 3600) / 60
            recovery = String(format: "%dh %02dm", Int32(hrs), Int32(mins))
        } else {
            recovery = "--"
        }

        let hrv: String
        if let h = m.hrv {
            hrv = h > 50 ? "Stable" : h > 30 ? "Moderate" : "Low"
        } else {
            hrv = "--"
        }

        return GarminReadiness(readiness: readiness, readinessLabel: label, recoveryLabel: recovery, hrvLabel: hrv)
    }
}

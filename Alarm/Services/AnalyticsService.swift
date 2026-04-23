import Foundation
import os

/// Analytics stub. All events funnel through `track(_:props:)` which currently
/// just logs — swap the body for a real SDK (Amplitude, Mixpanel, PostHog, etc.)
/// without touching call sites.
enum AnalyticsEvent: String {
    // Rescue-loop lifecycle
    case rescueScheduled      = "rescue_scheduled"
    case rescueFired          = "rescue_fired"
    case rescueStuckCancelled = "rescue_stuck_cancelled"
    case rescueTick           = "rescue_tick"

    // Alarm lifecycle
    case alarmAlerting        = "alarm_alerting"
    case alarmSilenced        = "alarm_silenced"
    case missionAdopted       = "mission_adopted"
    case missionCompleted     = "mission_completed"
    case missedAlarmDetected  = "missed_alarm_detected"
}

enum AnalyticsService {
    private static let log = Logger(subsystem: "com.alarm", category: "analytics")

    /// Fire-and-forget. Never throws, never blocks.
    static func track(_ event: AnalyticsEvent, props: [String: Any] = [:]) {
        // TODO: replace with real analytics SDK.
        if props.isEmpty {
            log.info("📊 \(event.rawValue)")
        } else {
            let rendered = props
                .map { "\($0.key)=\(stringify($0.value))" }
                .sorted()
                .joined(separator: " ")
            log.info("📊 \(event.rawValue) \(rendered)")
        }
    }

    private static func stringify(_ v: Any) -> String {
        if let d = v as? Date { return ISO8601DateFormatter().string(from: d) }
        return "\(v)"
    }
}

import AppIntents

struct SolveMissionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Solve to Dismiss"
    static let isDiscoverable: Bool = false
    static let openAppWhenRun: Bool = true

    nonisolated func perform() async throws -> some IntentResult {
        .result()
    }
}

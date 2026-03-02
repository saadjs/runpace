import AppIntents

struct RunPaceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PaceToSpeedIntent(),
            phrases: [
                "Convert pace to speed with \(.applicationName)",
                "What speed is my pace in \(.applicationName)",
            ],
            shortTitle: "Convert Pace",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: SpeedToPaceIntent(),
            phrases: [
                "Convert speed to pace with \(.applicationName)",
                "What pace is my speed in \(.applicationName)",
            ],
            shortTitle: "Convert Speed",
            systemImageName: "speedometer"
        )
    }
}

import SwiftUI
import SwiftData

@main
struct pace_to_mphApp: App {
    @State private var healthKitService = HealthKitService()

    var body: some Scene {
        WindowGroup {
            AppRootView(healthKitService: healthKitService)
        }
        .modelContainer(for: [StoredRunWorkout.self, RunSyncState.self])
    }
}

private struct AppRootView: View {
    let healthKitService: HealthKitService

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-runHistoryPreview")
            || ProcessInfo.processInfo.arguments.contains("-runHistoryGroupingPrototypes") {
            RunHistoryDebugPreviewView(
                showTrends: ProcessInfo.processInfo.arguments.contains("-runHistoryTrendsPreview"),
                showYearGroupingPrototypes: ProcessInfo.processInfo.arguments.contains("-runHistoryGroupingPrototypes")
            )
        } else {
            ContentView(
                healthKitService: healthKitService,
                initialScreen: initialScreenOverride
            )
                .task {
                    guard !isUITesting else { return }
                    await bootstrapHealthKit()
                }
        }
        #else
        ContentView(healthKitService: healthKitService)
            .task {
                guard !isUITesting else { return }
                await bootstrapHealthKit()
            }
        #endif
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    #if DEBUG
    private var initialScreenOverride: DefaultScreen? {
        guard isUITesting else { return nil }

        let arguments = ProcessInfo.processInfo.arguments
        if let flagIndex = arguments.firstIndex(of: "-initialScreen"),
           arguments.indices.contains(flagIndex + 1),
           let screen = DefaultScreen(rawValue: arguments[flagIndex + 1]) {
            return screen
        }

        // Keep UI tests isolated from preferences left behind by local use or
        // another test, unless a test explicitly requests a launch screen.
        return .converter
    }
    #endif

    private func bootstrapHealthKit() async {
        healthKitService.configure(modelContext: modelContext)
        await healthKitService.bootstrap()
        if healthKitService.authorizationState == .authorized {
            await healthKitService.refresh()
            healthKitService.startObserving()
        }
    }
}

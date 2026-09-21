import SwiftUI

struct RunHistoryView: View {
    let service: HealthKitService

    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = UnitSettings.shared
    @State private var debugLastSyncedAt = Date()
    private var unit: SpeedUnit { settings.unit }

    init(service: HealthKitService) {
        self.service = service
    }

    private var usesDemoData: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(where: { $0.hasPrefix("-runHistoryDemo") }) { return true }
        #if targetEnvironment(simulator)
        // HealthKit has no useful workout library in a fresh simulator. Seed a
        // handful of runs by default while preserving an opt-in live-data path.
        return !arguments.contains("-runHistoryLiveData")
        #else
        return false
        #endif
        #else
        return false
        #endif
    }

    private var demoRuns: [RunWorkout] {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-runHistoryDemoDenseData") { return RunHistoryPreviewData.runs }
        if arguments.contains("-runHistoryDemoMixedDistanceData") { return RunHistoryPreviewData.mixedDistanceRuns }
        if arguments.contains("-runHistoryDemoSparseData") { return RunHistoryPreviewData.sparseRuns }
        if arguments.contains("-runHistoryDemoRecordsData") { return RunHistoryPreviewData.recordProgressionRuns }
        if arguments.contains("-runHistoryDemoEdgeData") { return RunHistoryPreviewData.edgeCaseRuns }
        if arguments.contains("-runHistoryDemoEmptyData") { return [] }
        if arguments.contains("-runHistoryDemoCompactData") { return RunHistoryPreviewData.compactRuns }
        return Array(RunHistoryPreviewData.compactRuns.prefix(4))
        #else
        return []
        #endif
    }

    private var demoStartsOnTrends: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-runHistoryDemoTrends")
        #else
        return false
        #endif
    }

    // Lets screenshot tests show record progression without scrolling through
    // the larger Trends page first. This path is only active with demo data.
    private var demoShowsRecordDetail: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-runHistoryDemoRecordDetail")
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            if usesDemoData {
                if demoShowsRecordDetail {
                    PersonalRecordDetailView(
                        target: .fiveKilometers,
                        milestones: RunHistoryStats.recordProgression(
                            for: .fiveKilometers,
                            from: demoRuns,
                            unit: unit
                        ),
                        unit: unit
                    )
                } else {
                    RunHistoryContent(
                        runs: demoRuns,
                        unit: unit,
                        initialMode: demoStartsOnTrends ? .trends : .runs,
                        initialPeriod: .year,
                        lastSyncedAt: debugLastSyncedAt,
                        onSync: { debugLastSyncedAt = Date() }
                    )
                }
            } else {
                switch service.authorizationState {
                case .unavailable:
                    unavailableView
                case .notDetermined:
                    permissionPromptView
                case .denied:
                    deniedView
                case .authorized:
                    runHistory
                }
            }
        }
        .navigationTitle("Run History")
        .navigationBarTitleDisplayMode(.inline)
        // Refresh on foreground so we pick up access grants/revokes the user
        // made in Settings while the app was backgrounded.
        .onChange(of: scenePhase) { _, newPhase in
            guard usesDemoData == false,
                  newPhase == .active,
                  service.authorizationState == .authorized else { return }
            Task { await service.refresh() }
        }
    }

    // MARK: - States

    private var permissionPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 56))
                .foregroundStyle(.pink)
            Text("Import runs from Apple Health")
                .font(.title3.bold())
            Text("We'll read your running workouts to show pace and speed in mph and kph. Data stays on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await service.requestAuthorization() }
            } label: {
                Text("Allow access to Health")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .tint(.green)
        }
        .padding(32)
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Health access denied")
                .font(.headline)
            Text("Enable RunPace under Settings -> Health -> Data Access & Devices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Health data isn't available on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }

    @ViewBuilder
    private var runHistory: some View {
        if service.isLoading && service.runs.isEmpty {
            ProgressView("Importing...")
        } else if service.runs.isEmpty {
            ScrollView {
                VStack(spacing: 16) {
                    emptyRunsView
                    RunHistorySyncFooter(
                        lastSyncedAt: service.lastSyncedAt,
                        isLoading: service.isLoading,
                        onSync: { Task { await service.refresh() } }
                    )
                }
            }
        } else {
            RunHistoryContent(
                runs: service.runs,
                unit: unit,
                lastSyncedAt: service.lastSyncedAt,
                isSyncing: service.isLoading,
                onSync: { Task { await service.refresh() } }
            )
            .refreshable { await service.refresh() }
        }
    }

    // HealthKit hides read-denial from apps, so we always offer a recovery
    // path when authorized-but-empty in case the user said no at the prompt.
    // Read-only apps don't appear in Health -> Sharing -> Apps, so we send
    // users to Settings -> Apps -> Health -> Data Access & Devices.
    private var emptyRunsView: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "No runs found",
                systemImage: "figure.run",
                description: Text("If you have runs in Apple Health, open Settings → Apps → Health → Data Access & Devices → RunPace and turn on read access.")
            )
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .tint(.green)
        }
        .padding(.bottom, 24)
    }
}

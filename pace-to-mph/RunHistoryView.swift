import SwiftUI

struct RunHistoryView: View {
    @State private var service = HealthKitService()
    @State private var unit: SpeedUnit = .mph

    var body: some View {
        Group {
            switch service.authorizationState {
            case .unavailable:
                unavailableView
            case .notDetermined:
                permissionPromptView
            case .denied:
                deniedView
            case .authorized:
                runList
            }
        }
        .navigationTitle("Run History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if service.authorizationState == .authorized {
                ToolbarItem(placement: .topBarTrailing) {
                    unitToggle
                }
            }
        }
        .task {
            await service.bootstrap()
            if service.authorizationState == .authorized {
                await service.refresh()
                service.startObserving()
            }
        }
    }

    private var unitToggle: some View {
        HStack(spacing: 6) {
            ForEach(SpeedUnit.allCases, id: \.self) { u in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { unit = u }
                } label: {
                    Text(u.label)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                }
                .buttonStyle(.glass)
                .tint(unit == u ? .green : nil)
                .accessibilityLabel(u.label)
                .accessibilityAddTraits(unit == u ? .isSelected : [])
            }
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
                    .font(.system(size: 15, weight: .semibold))
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
            Text("Enable RunPace under Settings → Health → Data Access & Devices.")
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

    private var runList: some View {
        Group {
            if service.isLoading && service.runs.isEmpty {
                ProgressView("Importing…")
            } else if service.runs.isEmpty {
                ContentUnavailableView(
                    "No runs found",
                    systemImage: "figure.run",
                    description: Text("Recorded runs from Apple Fitness or Health will appear here.")
                )
            } else {
                List(service.runs) { run in
                    RunRow(run: run, unit: unit)
                }
                .listStyle(.plain)
                .refreshable { await service.refresh() }
            }
        }
    }
}

private struct RunRow: View {
    let run: RunWorkout
    let unit: SpeedUnit

    private var speedText: String {
        let value = unit == .mph ? run.averageSpeedMph : run.averageSpeedKph
        return String(format: "%.2f %@", value, unit.speedLabel)
    }

    private var paceText: String {
        let pace = unit == .mph ? run.paceMinutesPerMile : run.paceMinutesPerKilometer
        guard let pace, let formatted = ConversionEngine.formatPace(pace) else { return "—" }
        return "\(formatted) \(unit.paceLabel)"
    }

    private var distanceText: String {
        let value = unit == .mph ? run.distanceMiles : run.distanceKilometers
        let label = unit == .mph ? "mi" : "km"
        return String(format: "%.2f %@", value, label)
    }

    private var durationText: String {
        let total = Int(run.duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(run.startDate, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(speedText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
            HStack(spacing: 16) {
                Label(distanceText, systemImage: "ruler")
                Label(durationText, systemImage: "clock")
                Label(paceText, systemImage: "speedometer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { RunHistoryView() }
}

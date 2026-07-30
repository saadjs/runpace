import Charts
import SwiftUI
import SwiftData

struct RunHistoryView: View {
    let service: HealthKitService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = UnitSettings.shared
    private var unit: SpeedUnit { settings.unit }

    init(service: HealthKitService) {
        self.service = service
    }

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
                runHistory
            }
        }
        .navigationTitle("Run History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            service.configure(modelContext: modelContext)
            await service.bootstrap()
            if service.authorizationState == .authorized {
                await service.refresh()
                service.startObserving()
            }
        }
        // Refresh on foreground so we pick up access grants/revokes the user
        // made in Settings while the app was backgrounded.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active,
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

    private var runHistory: some View {
        Group {
            if service.isLoading && service.runs.isEmpty {
                ProgressView("Importing...")
            } else if service.runs.isEmpty {
                emptyRunsView
            } else {
                RunHistoryContent(runs: service.runs, unit: unit)
                    .refreshable { await service.refresh() }
            }
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

private struct RunHistoryContent: View {
    let runs: [RunWorkout]
    let unit: SpeedUnit

    @State private var selectedTrendScope: RunTrendScope = .threeMonths
    @State private var selectedTrendDistance: RunRecordTarget?
    @State private var selectedChartPoint: RunChartPoint?
    @State private var expandedWeekIDs: Set<String> = []
    @State private var selectedMode: RunHistoryMode
    @State private var selectedPeriod: RunHistoryPeriod = .week
    @State private var selectedMonthStart = RunHistoryStats.monthStart(containing: Date())
    @State private var selectedYearFilter = RunHistoryYearFilter.current()

    init(runs: [RunWorkout], unit: SpeedUnit, initialMode: RunHistoryMode = .runs) {
        self.runs = runs
        self.unit = unit
        _selectedMode = State(initialValue: initialMode)
        _selectedPeriod = State(initialValue: .week)
    }

    private var records: [RunPersonalRecord] {
        RunHistoryStats.personalRecords(from: runs, unit: unit)
    }

    // Always derived from the full run set so every PR badge shows in the Runs
    // list regardless of the period filter or Trends tab selection.
    private var prBadgesByRunID: [UUID: [RunRecordTarget]] {
        RunHistoryStats.personalRecordTargets(from: runs, unit: unit)
    }

    private var distanceTrends: [RunDistanceTrend] {
        RunHistoryStats.speedTrendsByDistance(from: runs, scope: selectedTrendScope, unit: unit)
    }

    private var availableTrendTargets: [RunRecordTarget] {
        distanceTrends.map(\.target)
    }

    // Keep the picker honest as scope/unit change buckets in and out: hold the
    // user's pick while it still has runs, otherwise fall back to their main
    // event (the distance with the most runs in scope).
    private var resolvedTrendDistance: RunRecordTarget? {
        if let selectedTrendDistance, availableTrendTargets.contains(selectedTrendDistance) {
            return selectedTrendDistance
        }
        return distanceTrends.max { $0.trend.runCount < $1.trend.runCount }?.target
    }

    private var selectedDistanceTrend: RunSpeedTrend? {
        guard let resolvedTrendDistance else { return nil }
        return distanceTrends.first { $0.target == resolvedTrendDistance }?.trend
    }

    private var activitySummary: RunActivitySummary {
        RunHistoryStats.activitySummary(from: runs, scope: selectedTrendScope, unit: unit)
    }

    private var volumeBars: [RunVolumeBar] {
        RunHistoryStats.volumeBars(from: runs, scope: selectedTrendScope, unit: unit)
    }

    private var weeks: [RunHistoryWeek] {
        RunHistoryStats.weeks(from: filteredRuns, unit: unit)
    }

    private var summary: RunHistorySummary {
        RunHistoryStats.summary(from: filteredRuns, unit: unit)
    }

    private var cadence: RunCadence {
        RunHistoryStats.cadence(
            from: filteredRuns,
            in: selectedFilter.interval(calendar: RunHistoryStats.calendar)
        )
    }

    private var filteredRuns: [RunWorkout] {
        runs.filter { selectedFilter.includes($0.startDate, calendar: RunHistoryStats.calendar) }
    }

    private var selectedFilter: RunHistoryFilter {
        switch selectedPeriod {
        case .week:
            return .currentWeek
        case .month:
            return .month(selectedMonthStart)
        case .year:
            switch selectedYearFilter {
            case .allTime:
                return .allTime
            case .year(let year):
                return .year(year)
            }
        }
    }

    private var monthOptions: [Date] {
        let monthStarts = Set(runs.map { RunHistoryStats.monthStart(containing: $0.startDate) })
        return monthStarts.sorted(by: >)
    }

    private var yearOptions: [RunHistoryYearFilter] {
        let years = Set(runs.map { RunHistoryStats.calendar.component(.year, from: $0.startDate) })
        return years.sorted(by: >).map(RunHistoryYearFilter.year) + [.allTime]
    }

    var body: some View {
        GlassEffectContainer {
            ScrollView {
                LazyVStack(spacing: 16) {
                    header

                    switch selectedMode {
                    case .runs:
                        RunSummaryStrip(summary: summary, cadence: cadence, unit: unit)
                        if filteredRuns.isEmpty {
                            filteredEmptyView
                        } else {
                            weekList
                        }
                    case .trends:
                        trendsBody
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .sensoryFeedback(.selection, trigger: selectedChartPoint?.id)
        .onAppear {
            normalizePeriodSelections()
            expandedWeekIDs = Set(weeks.filter(\.isCurrentWeek).map(\.id))
        }
        .onChange(of: runs) { _, _ in
            normalizePeriodSelections()
            expandedWeekIDs.formUnion(weeks.filter(\.isCurrentWeek).map(\.id))
        }
        .onChange(of: selectedFilter) { _, _ in
            selectedChartPoint = nil
            expandedWeekIDs = Set(weeks.filter(\.isCurrentWeek).map(\.id))
        }
        .onChange(of: unit) { _, _ in
            selectedChartPoint = nil
        }
        .onChange(of: selectedTrendScope) { _, _ in
            selectedChartPoint = nil
        }
        .onChange(of: resolvedTrendDistance) { _, _ in
            selectedChartPoint = nil
        }
    }

    @ViewBuilder
    private var trendsBody: some View {
        if records.isEmpty && activitySummary.runCount == 0 {
            trendsEmptyView
        } else {
            Group {
                TrendScopeMenu(scope: $selectedTrendScope)
                if let resolved = resolvedTrendDistance, let trend = selectedDistanceTrend {
                    SpeedTrendCard(
                        trend: trend,
                        availableTargets: availableTrendTargets,
                        selectedDistance: Binding(
                            get: { resolved },
                            set: { selectedTrendDistance = $0 }
                        ),
                        selectedPoint: $selectedChartPoint,
                        scope: selectedTrendScope,
                        unit: unit
                    )
                } else {
                    SpeedTrendEmptyCard()
                }
                ActivitySummaryCard(summary: activitySummary, scope: selectedTrendScope)
                PersonalBestsGrid(records: records, unit: unit)
                WeeklyVolumeCard(
                    bars: volumeBars,
                    cadence: activitySummary.cadence,
                    scope: selectedTrendScope,
                    unit: unit
                )
            }
            .tint(.green)
        }
    }

    private var trendsEmptyView: some View {
        ContentUnavailableView(
            "Not enough data",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Run a few more times to start seeing your trends.")
        )
        .font(.caption)
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(headerTitleText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                Text(unit.speedLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            modePicker
            if selectedMode == .runs {
                filterPicker
            }
        }
        .tint(.green)
    }

    private var headerTitleText: String {
        switch selectedMode {
        case .runs:
            return summary.runCountText
        case .trends:
            return "\(runs.count) \(runs.count == 1 ? "run" : "runs") tracked"
        }
    }

    private var modePicker: some View {
        Picker("Run history mode", selection: $selectedMode) {
            ForEach(RunHistoryMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .tint(.green)
    }

    private var filterPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Run history period", selection: $selectedPeriod) {
                ForEach(RunHistoryPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)

            secondaryFilterPicker
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run history period")
    }

    @ViewBuilder
    private var secondaryFilterPicker: some View {
        switch selectedPeriod {
        case .week:
            EmptyView()
        case .month:
            Picker("Month", selection: $selectedMonthStart) {
                ForEach(monthOptions, id: \.self) { monthStart in
                    Text(RunHistoryFormatters.monthYear(monthStart)).tag(monthStart)
                }
            }
            .pickerStyle(.menu)
        case .year:
            Picker("Year", selection: $selectedYearFilter) {
                ForEach(yearOptions) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var filteredEmptyView: some View {
        ContentUnavailableView(
            "No runs",
            systemImage: "figure.run",
            description: Text("No runs match \(selectedFilter.descriptionText.lowercased()).")
        )
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private func normalizePeriodSelections() {
        let currentMonthStart = RunHistoryStats.monthStart(containing: Date())
        let months = monthOptions
        if months.contains(selectedMonthStart) == false {
            selectedMonthStart = months.first ?? currentMonthStart
        }

        let currentYearFilter = RunHistoryYearFilter.current()
        let years = yearOptions
        if years.contains(selectedYearFilter) == false {
            selectedYearFilter = years.first ?? currentYearFilter
        }
    }

    private var weekList: some View {
        LazyVStack(spacing: 12) {
            ForEach(weeks) { week in
                if week.isCurrentWeek {
                    ExpandedWeekSection(week: week, unit: unit, prBadgesByRunID: prBadgesByRunID)
                } else {
                    CollapsedWeekSection(
                        week: week,
                        unit: unit,
                        prBadgesByRunID: prBadgesByRunID,
                        isExpanded: Binding(
                            get: { expandedWeekIDs.contains(week.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedWeekIDs.insert(week.id)
                                } else {
                                    expandedWeekIDs.remove(week.id)
                                }
                            }
                        )
                    )
                }
            }
        }
    }
}

private struct RunSummaryStrip: View {
    let summary: RunHistorySummary
    let cadence: RunCadence
    let unit: SpeedUnit

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                RunSummaryMetric(value: summary.distanceText, label: unit == .mph ? "Total mi" : "Total km")

                Divider().frame(height: 44)

                RunSummaryMetric(value: summary.durationText, label: "Total time")

                Divider().frame(height: 44)

                RunSummaryMetric(value: summary.averageSpeedText, label: "Avg \(unit.speedLabel)", isAccent: true)
            }
            .padding(.vertical, 16)

            RunCadenceFooter(cadence: cadence)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}

/// Run frequency stated in plain words under the totals — the "how often",
/// which totals on their own never answer. Draws nothing when the window is
/// too short for an average to differ from the total.
private struct RunCadenceFooter: View {
    let cadence: RunCadence

    var body: some View {
        if let averageText = cadence.averageText {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                        .imageScale(.small)
                        .foregroundStyle(.green)
                    Text(averageText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cadence.accessibilityText ?? averageText)
        }
    }
}

private struct RunSummaryMetric: View {
    let value: String
    let label: String
    var isAccent = false

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(isAccent ? Color.green : .primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

private struct TrendScopeMenu: View {
    @Binding var scope: RunTrendScope

    var body: some View {
        HStack(spacing: 10) {
            Label("Showing", systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

            Spacer()

            Menu {
                Picker("Scope", selection: $scope) {
                    ForEach(RunTrendScope.allCases) { value in
                        Text(value.menuLabel).tag(value)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(scope.menuLabel)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.tint)
            }
            .accessibilityLabel("Trend scope")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}

private struct ActivitySummaryCard: View {
    let summary: RunActivitySummary
    let scope: RunTrendScope

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(.headline)
                Spacer()
                Text(scope.menuLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 0) {
                metric(
                    value: "\(summary.runCount)",
                    label: summary.runCount == 1 ? "Run" : "Runs",
                    delta: runCountDeltaText
                )

                Divider().frame(height: 56)

                metric(
                    value: summary.distanceText,
                    label: "Total \(summary.distanceUnitLabel)",
                    delta: distanceDeltaText,
                    isAccent: true
                )

                Divider().frame(height: 56)

                metric(
                    value: summary.durationText,
                    label: "Active time",
                    delta: nil
                )
            }

            // Negative insets let the divider run edge to edge inside the card.
            RunCadenceFooter(cadence: summary.cadence)
                .padding(.horizontal, -16)
                .padding(.bottom, -6)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var runCountDeltaText: DeltaText? {
        guard let delta = summary.runCountDelta else { return nil }
        if delta == 0 { return DeltaText(text: "No change", isPositive: true, isNeutral: true) }
        let sign = delta > 0 ? "+" : ""
        return DeltaText(text: "\(sign)\(delta) vs prev", isPositive: delta >= 0, isNeutral: false)
    }

    private var distanceDeltaText: DeltaText? {
        guard let pct = summary.distanceDeltaPercent else { return nil }
        if abs(pct) < 0.005 { return DeltaText(text: "No change", isPositive: true, isNeutral: true) }
        return DeltaText(text: "\(RunHistoryFormatters.percent(pct)) vs prev", isPositive: pct >= 0, isNeutral: false)
    }

    private struct DeltaText {
        let text: String
        let isPositive: Bool
        let isNeutral: Bool
    }

    private func deltaColor(for delta: DeltaText) -> Color {
        if delta.isNeutral { return .secondary }
        return delta.isPositive ? .green : .red
    }

    private func metric(value: String, label: String, delta: DeltaText?, isAccent: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(isAccent ? Color.green : .primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let delta {
                Text(delta.text)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(deltaColor(for: delta))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

private struct PersonalBestsGrid: View {
    let records: [RunPersonalRecord]
    let unit: SpeedUnit

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Personal Bests")
                    .font(.headline)
                Spacer()
                Text("All time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(records) { record in
                    PBCell(target: record.target, record: record, unit: unit)
                }
            }
        }
    }
}

private struct PBCell: View {
    let target: RunRecordTarget
    let record: RunPersonalRecord
    let unit: SpeedUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(target.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "rosette")
                    .imageScale(.small)
                    .foregroundStyle(.green)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(record.speedText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit.speedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(record.paceText) \(unit.paceLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(record.achievedDate, format: .dateTime.month(.abbreviated).day().year())
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(target.displayName) personal best, \(record.speedText) \(unit.speedLabel)")
    }
}

/// Hero of the Trends tab: plots every run's average speed as dots with a
/// best-fit trend line, plus a plain-language verdict, so "am I getting faster?"
/// reads at a glance. Scrub the chart to inspect any single run.
private struct SpeedTrendCard: View {
    let trend: RunSpeedTrend
    let availableTargets: [RunRecordTarget]
    @Binding var selectedDistance: RunRecordTarget
    @Binding var selectedPoint: RunChartPoint?
    let scope: RunTrendScope
    let unit: SpeedUnit

    private var speedDomain: ClosedRange<Double> {
        var values = trend.points.map(\.speed)
        if let start = trend.trendStart?.speed { values.append(start) }
        if let end = trend.trendEnd?.speed { values.append(end) }
        guard let minSpeed = values.min(), let maxSpeed = values.max() else {
            return 0...1
        }
        let spread = maxSpeed - minSpeed
        let padding = max(spread * 0.3, 0.1)
        let lowerBound = max(0, minSpeed - padding)
        return lowerBound...(maxSpeed + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            metricRow
                .frame(height: 52, alignment: .top)
                .animation(.easeOut(duration: 0.12), value: selectedPoint?.id)

            chart
                .frame(height: 168)

            if selectedPoint == nil, trend.hasData {
                legend
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .sensoryFeedback(trigger: selectedPoint?.id) { _, new in
            new != nil ? .selection : nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Speed Trend")
                    .font(.headline)
                Spacer()
                Text(scope.menuLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Average \(unit.speedLabel) per \(selectedDistance.displayName) run, with your overall direction.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if availableTargets.count > 1 {
                Picker("Distance", selection: $selectedDistance) {
                    ForEach(availableTargets) { target in
                        Text(target.shortLabel).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Distance")
            }
        }
    }

    @ViewBuilder
    private var metricRow: some View {
        if let point = selectedPoint {
            scrubRow(for: point)
        } else {
            idleRow
        }
    }

    private var idleRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if trend.hasData {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(trend.averageSpeedText)
                            .font(.title)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                        Text(unit.speedLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Average · \(trend.runCount) \(trend.runCount == 1 ? "run" : "runs")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if trend.hasData {
                TrendVerdictBadge(trend: trend, unit: unit)
            }
        }
    }

    private func scrubRow(for point: RunChartPoint) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", point.speed))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Text(unit.speedLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text("\(point.paceText) \(unit.paceLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if let heartRate = point.avgHeartRate {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.heart")
                                .imageScale(.small)
                                .foregroundStyle(.pink)
                            Text("\(heartRate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Average heart rate \(heartRate) beats per minute")
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(point.distanceValueText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Text(unit == .mph ? "mi" : "km")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(point.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text("Each run")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if trend.trendEnd != nil {
                HStack(spacing: 5) {
                    Capsule()
                        .fill(Color.green)
                        .frame(width: 16, height: 3)
                    Text("Trend")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(trend.points) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(unit.speedLabel, point.speed)
                )
                .foregroundStyle(Color.green.opacity(0.4))
                .symbolSize(30)
            }

            if let start = trend.trendStart, let end = trend.trendEnd {
                ForEach([start, end]) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(unit.speedLabel, point.speed)
                    )
                }
                .foregroundStyle(Color.green)
                .lineStyle(.init(lineWidth: 2.5, lineCap: .round))
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected date", selectedPoint.date))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(.init(lineWidth: 1))

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value(unit.speedLabel, selectedPoint.speed)
                )
                .foregroundStyle(Color(.systemBackground))
                .symbolSize(70)

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value(unit.speedLabel, selectedPoint.speed)
                )
                .foregroundStyle(Color.green)
                .symbolSize(34)
            }
        }
        .chartYScale(domain: speedDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrameAnchor = proxy.plotFrame {
                    let plotFrame = geometry[plotFrameAnchor]
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - plotFrame.origin.x
                                    guard x >= 0, x <= plotFrame.width,
                                          let date: Date = proxy.value(atX: x) else {
                                        return
                                    }
                                    selectNearestPoint(to: date)
                                }
                                .onEnded { _ in
                                    selectedPoint = nil
                                }
                        )
                }
            }
        }
        .overlay {
            if trend.points.isEmpty {
                ContentUnavailableView(
                    "No runs in this range",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Try a longer time range to see your speed trend.")
                )
                .background(Color(.systemBackground))
            }
        }
    }

    private func selectNearestPoint(to date: Date) {
        guard let nearest = trend.points.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else { return }

        if selectedPoint?.id != nearest.id {
            selectedPoint = nearest
        }
    }
}

/// Shown when no single distance has enough runs in scope to chart a trend —
/// distinct from "no runs at all" so the runner knows what unlocks it.
private struct SpeedTrendEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speed Trend")
                .font(.headline)
            ContentUnavailableView(
                "Not enough runs at one distance",
                systemImage: "chart.xyaxis.line",
                description: Text("Log at least 2 runs at the same distance (5K, 10K, and so on) to see how your speed is trending.")
            )
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}

/// Plain-language read on the trend line's direction. Stays muted for "steady"
/// and "building" so the colored verdicts (faster/slower) carry the signal.
private struct TrendVerdictBadge: View {
    let trend: RunSpeedTrend
    let unit: SpeedUnit

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .imageScale(.small)
                Text(word)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.15)))

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var icon: String {
        switch trend.direction {
        case .faster: return "arrow.up.right"
        case .slower: return "arrow.down.right"
        case .steady: return "arrow.left.and.right"
        case .insufficient: return "chart.dots.scatter"
        }
    }

    private var word: String {
        switch trend.direction {
        case .faster: return "Faster"
        case .slower: return "Slower"
        case .steady: return "Steady"
        case .insufficient: return "Building"
        }
    }

    private var tint: Color {
        switch trend.direction {
        case .faster: return .green
        case .slower: return .orange
        case .steady, .insufficient: return Color(.secondaryLabel)
        }
    }

    private var detail: String? {
        switch trend.direction {
        case .faster: return "+\(trend.changeMagnitudeText) \(unit.speedLabel)"
        case .slower: return "−\(trend.changeMagnitudeText) \(unit.speedLabel)"
        case .steady: return "Little change"
        case .insufficient: return "Need 5+ runs"
        }
    }

    private var accessibilityText: String {
        switch trend.direction {
        case .faster: return "Trending faster, up \(trend.changeMagnitudeText) \(unit.speedLabel)"
        case .slower: return "Trending slower, down \(trend.changeMagnitudeText) \(unit.speedLabel)"
        case .steady: return "Holding steady"
        case .insufficient: return "Building, need at least 5 runs to show a trend"
        }
    }
}

private struct WeeklyVolumeCard: View {
    let bars: [RunVolumeBar]
    let cadence: RunCadence
    let scope: RunTrendScope
    let unit: SpeedUnit

    private var title: String {
        scope.bucketing == .weekly ? "Weekly Volume" : "Monthly Volume"
    }

    private var subtitle: String {
        let unitWord = unit == .mph ? "miles" : "kilometres"
        let interval = scope.bucketing == .weekly ? "week" : "month"
        return "Total \(unitWord) per \(interval)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(scope.menuLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if bars.isEmpty {
                Text("No runs in this period.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                chart
                    .frame(height: 120)
                statsRow
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var chart: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Period", bar.periodStart, unit: scope.bucketing == .weekly ? .weekOfYear : .month),
                    y: .value("Distance", bar.distance)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(4)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }

    /// Both averages divide by the scope's elapsed span — not by the number of
    /// bars — so a period the runner sat out still counts against the average,
    /// and the runs/wk here matches the one on the Activity card above.
    private var statsRow: some View {
        let total = bars.reduce(0.0) { $0 + $1.distance }
        let isWeekly = scope.bucketing == .weekly
        let periods = isWeekly ? cadence.weeks : cadence.months
        let averageDistance = periods > 0 ? total / periods : 0
        let averageRuns = isWeekly ? cadence.runsPerWeek : cadence.runsPerMonth
        let unitLabel = unit == .mph ? "mi" : "km"
        let intervalLabel = isWeekly ? "wk" : "mo"
        return HStack(alignment: .top, spacing: 0) {
            statBlock(value: String(format: "%.1f", total), label: "Total \(unitLabel)")
            Divider().frame(height: 32)
            statBlock(value: String(format: "%.1f", averageDistance), label: "\(unitLabel) / \(intervalLabel)")
            Divider().frame(height: 32)
            statBlock(value: String(format: "%.1f", averageRuns), label: "runs / \(intervalLabel)")
        }
        .frame(maxWidth: .infinity)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExpandedWeekSection: View {
    let week: RunHistoryWeek
    let unit: SpeedUnit
    let prBadgesByRunID: [UUID: [RunRecordTarget]]

    var body: some View {
        VStack(spacing: 0) {
            WeekHeader(week: week, isExpanded: true, showsChevron: false)
            ForEach(week.runs) { run in
                RunHistoryRow(
                    run: run,
                    unit: unit,
                    prBadges: prBadgesByRunID[run.id] ?? []
                )
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}

private struct CollapsedWeekSection: View {
    let week: RunHistoryWeek
    let unit: SpeedUnit
    let prBadgesByRunID: [UUID: [RunRecordTarget]]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                WeekHeader(week: week, isExpanded: isExpanded, showsChevron: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(week.title)
            .accessibilityHint(isExpanded ? "Collapse week" : "Expand week")

            if isExpanded {
                ForEach(week.runs) { run in
                    RunHistoryRow(
                        run: run,
                        unit: unit,
                        prBadges: prBadgesByRunID[run.id] ?? []
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}

private struct WeekHeader: View {
    let week: RunHistoryWeek
    let isExpanded: Bool
    let showsChevron: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Circle()
                        .fill(week.isCurrentWeek ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                        .frame(width: 12)
                }

                Text(week.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(week.runCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                Text(week.distanceText)
                Text("Avg \(week.averageSpeedText)")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.leading, 22)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
    }
}

private struct RunHistoryRow: View {
    let run: RunWorkout
    let unit: SpeedUnit
    let prBadges: [RunRecordTarget]

    private var speedText: String {
        let value = unit == .mph ? run.averageSpeedMph : run.averageSpeedKph
        return String(format: "%.2f", value)
    }

    private var paceText: String {
        let pace = unit == .mph ? run.paceMinutesPerMile : run.paceMinutesPerKilometer
        guard let pace, let formatted = ConversionEngine.formatPace(pace) else { return "--" }
        return formatted
    }

    private var distanceText: String {
        let value = unit == .mph ? run.distanceMiles : run.distanceKilometers
        let label = unit == .mph ? "mi" : "km"
        return String(format: "%.2f %@", value, label)
    }

    private var durationText: String {
        RunHistoryFormatters.duration(run.duration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(spacing: 8) {
                    Text(run.startDate, format: .dateTime.month(.abbreviated).day())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    ForEach(prBadges) { target in
                        Label("\(target.shortLabel) PR", systemImage: "rosette")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color.green.opacity(0.15))
                            )
                    }
                }

                Spacer(minLength: 12)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(speedText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    Text(unit.speedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(distanceText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text("\(paceText) \(unit.paceLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let heartRate = run.avgHeartRate {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.heart")
                            .imageScale(.small)
                            .foregroundStyle(.pink)
                        Text("\(heartRate)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Average heart rate \(heartRate) beats per minute")
                }

                Spacer(minLength: 8)

                Text(durationText)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .padding(.leading, 16)
        }
    }
}

struct RunHistoryStats {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    static func summary(from runs: [RunWorkout], unit: SpeedUnit) -> RunHistorySummary {
        let totalDistance = runs.reduce(0.0) { partial, run in
            partial + (unit == .mph ? run.distanceMiles : run.distanceKilometers)
        }
        let totalDuration = runs.reduce(0.0) { $0 + $1.duration }
        let averageSpeed = totalDuration > 0 ? totalDistance / (totalDuration / 3600.0) : 0

        return RunHistorySummary(
            runCount: runs.count,
            distanceText: RunHistoryFormatters.decimal(totalDistance, fractionDigits: 1),
            durationText: RunHistoryFormatters.duration(totalDuration),
            averageSpeedText: RunHistoryFormatters.decimal(averageSpeed, fractionDigits: 2)
        )
    }

    /// How often the runner actually runs, as an average per week and per month
    /// over an explicit window. Totals alone can't answer "am I running enough?" —
    /// 40 runs reads very differently over a month than over a year.
    ///
    /// The window is clipped to `referenceDate` (counting the unfinished
    /// remainder of this month would understate cadence) and floored at one
    /// week / one month, so a three-day-old window can't claim 7 runs a week.
    /// Pass `nil` for all time, which measures from the first run.
    static func cadence(
        from runs: [RunWorkout],
        in interval: DateInterval?,
        referenceDate: Date = Date()
    ) -> RunCadence {
        let windowStart = interval?.start ?? runs.map(\.startDate).min()
        let windowEnd = min(interval?.end ?? referenceDate, referenceDate)

        guard let windowStart, windowEnd > windowStart else {
            return RunCadence(runCount: runs.count, weeks: 1, months: 1)
        }

        let days = windowEnd.timeIntervalSince(windowStart) / 86_400
        return RunCadence(
            runCount: runs.count,
            weeks: max(days / 7, 1),
            months: max(days / 30.436_875, 1)
        )
    }

    static func personalRecords(from runs: [RunWorkout], unit: SpeedUnit, referenceDate: Date = Date()) -> [RunPersonalRecord] {
        RunRecordTarget.allCases.filter { $0.isVisible(in: unit) }.compactMap { target in
            let efforts = efforts(for: target, runs: runs, unit: unit)
            guard let best = efforts.max(by: { $0.speed < $1.speed }) else { return nil }
            let baselineCutoff = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
            let baseline = efforts
                .filter { $0.date < baselineCutoff }
                .max(by: { $0.speed < $1.speed })
            let pace = best.durationMinutes / target.distance(for: unit)

            return RunPersonalRecord(
                id: target.id,
                target: target,
                unit: unit,
                runID: best.runID,
                speed: best.speed,
                paceText: ConversionEngine.formatPace(pace) ?? "--",
                deltaSpeed: best.speed - (baseline?.speed ?? best.speed),
                achievedDate: best.date
            )
        }
    }

    /// Maps each run to every personal-record target it holds, so PR badges in
    /// the Runs list can render independently of the Trends tab selection. Built
    /// from `personalRecords`, so it inherits unit visibility and target order.
    static func personalRecordTargets(
        from runs: [RunWorkout],
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> [UUID: [RunRecordTarget]] {
        var map: [UUID: [RunRecordTarget]] = [:]
        for record in personalRecords(from: runs, unit: unit, referenceDate: referenceDate) {
            map[record.runID, default: []].append(record.target)
        }
        return map
    }

    /// Plots every run's average speed in scope and fits a least squares trend
    /// line. The line is drawn at >=2 runs, but a faster/slower *verdict* is only
    /// claimed at >=5 runs with a wide "steady" band, since run-to-run scatter is
    /// large and a confident-but-wrong direction is worse than none.
    static func speedTrend(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> RunSpeedTrend {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let scoped: [RunWorkout]
        if let lower {
            scoped = runs.filter { $0.startDate >= lower && $0.startDate <= referenceDate }
        } else {
            scoped = runs
        }
        return speedTrend(forRuns: scoped, unit: unit)
    }

    /// One Speed Trend chart per named distance (5K, 10K, …): runs are bucketed
    /// by distance (±10% band) so each chart compares like-for-like efforts and
    /// the trend line isn't confounded by whether you ran short or long lately.
    /// A distance only appears once it has at least 2 runs in scope, and only
    /// when it's relevant to the active unit (no "1 KM" chart for mph users).
    /// Returned ascending by distance for a stable picker order.
    static func speedTrendsByDistance(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> [RunDistanceTrend] {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let scoped: [RunWorkout]
        if let lower {
            scoped = runs.filter { $0.startDate >= lower && $0.startDate <= referenceDate }
        } else {
            scoped = runs
        }

        return RunRecordTarget.allCases
            .filter { $0.isVisible(in: unit) }
            .compactMap { target in
                let bucket = scoped.filter { target.containsDistance($0.distanceMeters) }
                // Count valid chart points, not raw runs: a zero-distance/zero-duration
                // run is dropped by speedTrend, so gating on bucket.count could surface
                // a "trend" with a single plotted point.
                let trend = speedTrend(forRuns: bucket, unit: unit)
                guard trend.runCount >= 2 else { return nil }
                return RunDistanceTrend(target: target, trend: trend)
            }
    }

    private static func speedTrend(forRuns runs: [RunWorkout], unit: SpeedUnit) -> RunSpeedTrend {
        let points = runs
            .filter { $0.duration > 0 && $0.distanceMeters > 0 }
            .sorted { $0.startDate < $1.startDate }
            .map { run -> RunChartPoint in
                let speed = unit == .mph ? run.averageSpeedMph : run.averageSpeedKph
                let pace = unit == .mph ? run.paceMinutesPerMile : run.paceMinutesPerKilometer
                let paceText = pace.flatMap { ConversionEngine.formatPace($0) } ?? "--"
                let distance = unit == .mph ? run.distanceMiles : run.distanceKilometers
                let distanceValueText = String(format: "%.2f", distance)
                return RunChartPoint(id: run.id.uuidString, date: run.startDate, speed: speed, paceText: paceText, distanceValueText: distanceValueText, avgHeartRate: run.avgHeartRate)
            }

        let speeds = points.map(\.speed)
        let average = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)

        var trendStart: RunChartPoint?
        var trendEnd: RunChartPoint?
        var change = 0.0

        if let first = points.first, let last = points.last, points.count >= 2 {
            let origin = first.date.timeIntervalSince1970
            let xs = points.map { ($0.date.timeIntervalSince1970 - origin) / 86_400.0 }
            let n = Double(points.count)
            let sumX = xs.reduce(0, +)
            let sumY = speeds.reduce(0, +)
            let sumXX = xs.reduce(0) { $0 + $1 * $1 }
            let sumXY = zip(xs, speeds).reduce(0) { $0 + $1.0 * $1.1 }
            let denominator = n * sumXX - sumX * sumX
            if denominator != 0 {
                let slope = (n * sumXY - sumX * sumY) / denominator
                let intercept = (sumY - slope * sumX) / n
                let lastX = xs.last ?? 0
                let fittedStart = intercept
                let fittedEnd = intercept + slope * lastX
                change = fittedEnd - fittedStart
                trendStart = RunChartPoint(id: "trend-start", date: first.date, speed: fittedStart, paceText: "", distanceValueText: "", avgHeartRate: nil)
                trendEnd = RunChartPoint(id: "trend-end", date: last.date, speed: fittedEnd, paceText: "", distanceValueText: "", avgHeartRate: nil)
            }
        }

        let direction: RunTrendDirection
        if points.count < 5 || trendEnd == nil {
            direction = .insufficient
        } else {
            // Steady band: ~4% of average speed, with an absolute floor so it stays
            // forgiving at low speeds. Anything inside reads as "holding steady".
            let band = max(average * 0.04, unit == .mph ? 0.1 : 0.16)
            if abs(change) < band {
                direction = .steady
            } else {
                direction = change > 0 ? .faster : .slower
            }
        }

        return RunSpeedTrend(
            points: points,
            trendStart: trendStart,
            trendEnd: trendEnd,
            averageSpeed: average,
            changeOverPeriod: change,
            direction: direction,
            unit: unit
        )
    }

    static func activitySummary(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> RunActivitySummary {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let previousLower = scope.previousLowerBound(from: referenceDate, calendar: calendar)

        let currentRuns: [RunWorkout]
        if let lower {
            currentRuns = runs.filter { $0.startDate >= lower && $0.startDate <= referenceDate }
        } else {
            currentRuns = runs
        }

        let previousRuns: [RunWorkout]
        if let lower, let previousLower {
            previousRuns = runs.filter { $0.startDate >= previousLower && $0.startDate < lower }
        } else {
            previousRuns = []
        }

        let distance = totalDistance(currentRuns, unit: unit)
        let duration = currentRuns.reduce(0.0) { $0 + $1.duration }
        let previousDistance = totalDistance(previousRuns, unit: unit)
        let previousDuration = previousRuns.reduce(0.0) { $0 + $1.duration }

        let window = lower.map { DateInterval(start: $0, end: referenceDate) }

        return RunActivitySummary(
            runCount: currentRuns.count,
            distance: distance,
            duration: duration,
            previousRunCount: previousRuns.count,
            previousDistance: previousDistance,
            previousDuration: previousDuration,
            cadence: cadence(from: currentRuns, in: window, referenceDate: referenceDate),
            unit: unit,
            hasPreviousPeriod: scope != .allTime
        )
    }

    static func volumeBars(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> [RunVolumeBar] {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let scoped: [RunWorkout]
        if let lower {
            scoped = runs.filter { $0.startDate >= lower && $0.startDate <= referenceDate }
        } else {
            scoped = runs
        }
        guard scoped.isEmpty == false else { return [] }

        switch scope.bucketing {
        case .weekly:
            let grouped = Dictionary(grouping: scoped) { weekStart(containing: $0.startDate) }
            return grouped.map { start, weekRuns in
                RunVolumeBar(
                    id: "w-\(Int(start.timeIntervalSince1970))",
                    periodStart: start,
                    distance: totalDistance(weekRuns, unit: unit),
                    label: RunHistoryFormatters.shortDay(start)
                )
            }
            .sorted { $0.periodStart < $1.periodStart }
        case .monthly:
            let grouped = Dictionary(grouping: scoped) { monthStart(containing: $0.startDate) }
            return grouped.map { start, monthRuns in
                RunVolumeBar(
                    id: "m-\(Int(start.timeIntervalSince1970))",
                    periodStart: start,
                    distance: totalDistance(monthRuns, unit: unit),
                    label: RunHistoryFormatters.monthShort(start)
                )
            }
            .sorted { $0.periodStart < $1.periodStart }
        }
    }

    private static func totalDistance(_ runs: [RunWorkout], unit: SpeedUnit) -> Double {
        runs.reduce(0.0) { partial, run in
            partial + (unit == .mph ? run.distanceMiles : run.distanceKilometers)
        }
    }

    static func weeks(from runs: [RunWorkout], unit: SpeedUnit, referenceDate: Date = Date()) -> [RunHistoryWeek] {
        let currentWeekStart = weekStart(containing: referenceDate)
        let grouped = Dictionary(grouping: runs) { weekStart(containing: $0.startDate) }

        return grouped.map { startDate, weekRuns in
            let endDate = calendar.date(byAdding: .day, value: 6, to: startDate) ?? startDate
            let sortedRuns = weekRuns.sorted { $0.startDate > $1.startDate }
            let totalDistance = sortedRuns.reduce(0.0) { partial, run in
                partial + (unit == .mph ? run.distanceMiles : run.distanceKilometers)
            }
            let totalDuration = sortedRuns.reduce(0.0) { $0 + $1.duration }
            let avgSpeed = totalDuration > 0 ? totalDistance / (totalDuration / 3600.0) : 0
            let unitDistanceLabel = unit == .mph ? "mi" : "km"
            let rangeTitle = RunHistoryFormatters.weekRange(startDate, endDate)
            let title = calendar.isDate(startDate, inSameDayAs: currentWeekStart) ? "This week · \(rangeTitle)" : rangeTitle

            return RunHistoryWeek(
                id: String(Int(startDate.timeIntervalSince1970)),
                title: title,
                runCount: sortedRuns.count,
                distanceText: "\(RunHistoryFormatters.decimal(totalDistance, fractionDigits: 1)) \(unitDistanceLabel)",
                averageSpeedText: "\(RunHistoryFormatters.decimal(avgSpeed, fractionDigits: 2)) \(unit.speedLabel)",
                startDate: startDate,
                endDate: endDate,
                runs: sortedRuns,
                isCurrentWeek: calendar.isDate(startDate, inSameDayAs: currentWeekStart)
            )
        }
        .sorted { $0.startDate > $1.startDate }
    }

    static func monthStart(containing date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func currentWeekInterval(containing date: Date = Date()) -> DateInterval {
        let start = weekStart(containing: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    private static func efforts(for target: RunRecordTarget, runs: [RunWorkout], unit: SpeedUnit) -> [RunRecordEffort] {
        runs.compactMap { run in
            guard run.distanceMeters >= target.meters, run.duration > 0 else { return nil }
            let distance = target.distance(for: unit)
            let estimatedDuration = run.duration * (target.meters / run.distanceMeters)
            let speed = distance / (estimatedDuration / 3600.0)
            return RunRecordEffort(
                runID: run.id,
                date: run.startDate,
                speed: speed,
                durationMinutes: estimatedDuration / 60.0
            )
        }
    }

    private static func weekStart(containing date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components).map(calendar.startOfDay(for:)) ?? calendar.startOfDay(for: date)
    }
}

struct RunPersonalRecord: Identifiable, Equatable {
    let id: String
    let target: RunRecordTarget
    let unit: SpeedUnit
    let runID: UUID
    let speed: Double
    let paceText: String
    let deltaSpeed: Double
    let achievedDate: Date

    var speedText: String {
        String(format: "%.2f", speed)
    }
}

struct RunActivitySummary: Equatable {
    let runCount: Int
    let distance: Double
    let duration: TimeInterval
    let previousRunCount: Int
    let previousDistance: Double
    let previousDuration: TimeInterval
    let cadence: RunCadence
    let unit: SpeedUnit
    let hasPreviousPeriod: Bool

    var distanceText: String {
        String(format: "%.1f", distance)
    }

    var durationText: String {
        RunHistoryFormatters.duration(duration)
    }

    var distanceUnitLabel: String {
        unit == .mph ? "mi" : "km"
    }

    var distanceDeltaPercent: Double? {
        guard hasPreviousPeriod, previousDistance > 0 else { return nil }
        return (distance - previousDistance) / previousDistance
    }

    var runCountDelta: Int? {
        guard hasPreviousPeriod else { return nil }
        return runCount - previousRunCount
    }
}

struct RunVolumeBar: Identifiable, Equatable {
    let id: String
    let periodStart: Date
    let distance: Double
    let label: String
}

/// Average run frequency over a window. An average is only offered once the
/// window is meaningfully longer than the unit it averages over: "3 runs/mo"
/// across a single month is just the total wearing a different label.
struct RunCadence: Equatable {
    let runCount: Int
    let weeks: Double
    let months: Double

    var runsPerWeek: Double { runCount == 0 ? 0 : Double(runCount) / weeks }
    var runsPerMonth: Double { runCount == 0 ? 0 : Double(runCount) / months }

    var runsPerWeekText: String { String(format: "%.1f", runsPerWeek) }
    var runsPerMonthText: String { String(format: "%.1f", runsPerMonth) }

    var hasWeeklyAverage: Bool { runCount > 0 && weeks >= 1.5 }
    var hasMonthlyAverage: Bool { runCount > 0 && months >= 1.5 }

    /// Compact one-liner for the summary cards, or nil when the window is too
    /// short for either average to say anything the total doesn't.
    var averageText: String? {
        var parts: [String] = []
        if hasWeeklyAverage { parts.append("\(runsPerWeekText) runs/wk") }
        if hasMonthlyAverage { parts.append("\(runsPerMonthText) runs/mo") }
        guard parts.isEmpty == false else { return nil }
        return "Averaging " + parts.joined(separator: " · ")
    }

    var accessibilityText: String? {
        var parts: [String] = []
        if hasWeeklyAverage { parts.append("\(runsPerWeekText) runs per week") }
        if hasMonthlyAverage { parts.append("\(runsPerMonthText) runs per month") }
        guard parts.isEmpty == false else { return nil }
        return "Averaging " + parts.joined(separator: ", ")
    }
}

struct RunChartPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let speed: Double
    let paceText: String
    let distanceValueText: String
    let avgHeartRate: Int?
}

enum RunTrendDirection: Equatable {
    case faster
    case steady
    case slower
    case insufficient
}

/// Overall speed trend: one point per run (its average speed) plus a least
/// squares best-fit line so the direction reads at a glance.
struct RunSpeedTrend: Equatable {
    let points: [RunChartPoint]
    let trendStart: RunChartPoint?
    let trendEnd: RunChartPoint?
    let averageSpeed: Double
    let changeOverPeriod: Double
    let direction: RunTrendDirection
    let unit: SpeedUnit

    var hasData: Bool { points.isEmpty == false }
    var runCount: Int { points.count }
    var averageSpeedText: String { String(format: "%.2f", averageSpeed) }
    var changeMagnitudeText: String { String(format: "%.2f", abs(changeOverPeriod)) }
}

/// A Speed Trend scoped to a single named distance, used to drive the Trends
/// tab's per-distance chart and its distance picker.
struct RunDistanceTrend: Identifiable, Equatable {
    let target: RunRecordTarget
    let trend: RunSpeedTrend

    var id: String { target.id }
}

struct RunHistorySummary: Equatable {
    let runCount: Int
    let distanceText: String
    let durationText: String
    let averageSpeedText: String

    var runCountText: String {
        "\(runCount) \(runCount == 1 ? "run" : "runs")"
    }
}

struct RunHistoryWeek: Identifiable, Equatable {
    let id: String
    let title: String
    let runCount: Int
    let distanceText: String
    let averageSpeedText: String
    let startDate: Date
    let endDate: Date
    let runs: [RunWorkout]
    let isCurrentWeek: Bool

    var runCountText: String {
        "\(runCount) \(runCount == 1 ? "run" : "runs")"
    }
}

private struct RunRecordEffort {
    let runID: UUID
    let date: Date
    let speed: Double
    let durationMinutes: Double
}

private enum RunHistoryMode: String, CaseIterable, Hashable, Identifiable {
    case runs
    case trends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runs: return "Runs"
        case .trends: return "Trends"
        }
    }

    var systemImage: String {
        switch self {
        case .runs: return "list.bullet"
        case .trends: return "chart.line.uptrend.xyaxis"
        }
    }
}

private enum RunHistoryPeriod: String, CaseIterable, Hashable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .week:
            return "W"
        case .month:
            return "M"
        case .year:
            return "Y"
        }
    }

    var title: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .year:
            return "Year"
        }
    }
}

private enum RunHistoryYearFilter: Hashable, Identifiable {
    case allTime
    case year(Int)

    var id: String {
        switch self {
        case .allTime:
            return "allTime"
        case .year(let year):
            return "year-\(year)"
        }
    }

    var title: String {
        switch self {
        case .allTime:
            return "All Time"
        case .year(let year):
            return String(year)
        }
    }

    static func current(referenceDate: Date = Date(), calendar: Calendar = RunHistoryStats.calendar) -> RunHistoryYearFilter {
        .year(calendar.component(.year, from: referenceDate))
    }
}

private enum RunHistoryFilter: Equatable {
    case currentWeek
    case month(Date)
    case year(Int)
    case allTime

    var descriptionText: String {
        switch self {
        case .currentWeek:
            return "Current Week"
        case .month(let monthStart):
            return RunHistoryFormatters.monthYear(monthStart)
        case .year(let year):
            return String(year)
        case .allTime:
            return "All Time"
        }
    }

    /// The span this filter covers, used as the denominator for run-frequency
    /// averages. `nil` for all time, which measures from the first run instead.
    func interval(calendar: Calendar, referenceDate: Date = Date()) -> DateInterval? {
        switch self {
        case .currentWeek:
            return RunHistoryStats.currentWeekInterval(containing: referenceDate)
        case .month(let monthStart):
            return calendar.dateInterval(of: .month, for: monthStart)
        case .year(let year):
            guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
                return nil
            }
            return calendar.dateInterval(of: .year, for: yearStart)
        case .allTime:
            return nil
        }
    }

    func includes(_ date: Date, calendar: Calendar, referenceDate: Date = Date()) -> Bool {
        switch self {
        case .currentWeek:
            return RunHistoryStats.currentWeekInterval(containing: referenceDate).contains(date)
        case .month(let monthStart):
            return calendar.dateInterval(of: .month, for: monthStart)?.contains(date) ?? false
        case .allTime:
            return true
        case .year(let year):
            return calendar.component(.year, from: date) == year
        }
    }
}

enum RunRecordTarget: String, CaseIterable, Identifiable {
    case oneMile
    case oneKilometer
    case fiveKilometers
    case tenKilometers
    case halfMarathon
    case marathon

    var id: String { rawValue }

    var meters: Double {
        switch self {
        case .oneMile:
            return 1609.34
        case .oneKilometer:
            return 1000
        case .fiveKilometers:
            return 5000
        case .tenKilometers:
            return 10000
        case .halfMarathon:
            return 21097.5
        case .marathon:
            return 42195
        }
    }

    var shortLabel: String {
        switch self {
        case .oneMile:
            return "1 MILE"
        case .oneKilometer:
            return "1 KM"
        case .fiveKilometers:
            return "5K"
        case .tenKilometers:
            return "10K"
        case .halfMarathon:
            return "HALF"
        case .marathon:
            return "MARA"
        }
    }

    var distanceCopy: String {
        switch self {
        case .oneMile:
            return "a mile"
        case .oneKilometer:
            return "a kilometer"
        case .fiveKilometers:
            return "5K"
        case .tenKilometers:
            return "10K"
        case .halfMarathon:
            return "a half marathon"
        case .marathon:
            return "a marathon"
        }
    }

    var displayName: String {
        switch self {
        case .oneMile:
            return "1 Mile"
        case .oneKilometer:
            return "1 KM"
        case .fiveKilometers:
            return "5K"
        case .tenKilometers:
            return "10K"
        case .halfMarathon:
            return "Half Marathon"
        case .marathon:
            return "Marathon"
        }
    }

    /// A run counts toward this distance when it's within ±10% of the nominal
    /// distance. At ±10% none of the named distances overlap, so a run lands in
    /// at most one bucket; runs in the gaps belong to none.
    func containsDistance(_ meters: Double) -> Bool {
        abs(meters - self.meters) <= self.meters * 0.10
    }

    func isVisible(in unit: SpeedUnit) -> Bool {
        switch (self, unit) {
        case (.oneMile, .kph), (.oneKilometer, .mph):
            return false
        default:
            return true
        }
    }

    func distance(for unit: SpeedUnit) -> Double {
        switch unit {
        case .mph:
            return meters / 1609.34
        case .kph:
            return meters / 1000.0
        }
    }
}

enum RunTrendScope: String, CaseIterable, Hashable, Identifiable {
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case allTime

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .oneMonth: return "Last month"
        case .threeMonths: return "Last 3 months"
        case .sixMonths: return "Last 6 months"
        case .oneYear: return "Last year"
        case .allTime: return "All time"
        }
    }

    var bucketing: RunVolumeBucketing {
        switch self {
        case .oneMonth, .threeMonths, .sixMonths: return .weekly
        case .oneYear, .allTime: return .monthly
        }
    }

    func lowerBound(from date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: date)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: date)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: date)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: date)
        case .allTime:
            return nil
        }
    }

    func previousLowerBound(from date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -2, to: date)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -6, to: date)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -12, to: date)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -2, to: date)
        case .allTime:
            return nil
        }
    }
}

enum RunVolumeBucketing {
    case weekly
    case monthly
}

private enum RunHistoryFormatters {
    static func decimal(_ value: Double, fractionDigits: Int) -> String {
        String(format: "%.\(fractionDigits)f", value)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    static func weekRange(_ startDate: Date, _ endDate: Date) -> String {
        let startMonth = monthFormatter.string(from: startDate)
        let endMonth = monthFormatter.string(from: endDate)
        let startDay = dayFormatter.string(from: startDate)
        let endDay = dayFormatter.string(from: endDate)

        if startMonth == endMonth {
            return "\(startMonth) \(startDay)–\(endDay)"
        }
        return "\(startMonth) \(startDay) – \(endMonth) \(endDay)"
    }

    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    static func monthShort(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    static func shortDay(_ date: Date) -> String {
        shortDayFormatter.string(from: date)
    }

    static func longDate(_ date: Date) -> String {
        longDateFormatter.string(from: date)
    }

    static func percent(_ value: Double) -> String {
        let percent = value * 100
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.0f", abs(percent)))%"
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter
    }()

    private static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return formatter
    }()
}

private enum RunHistoryPreviewData {
    static let runs: [RunWorkout] = {
        let calendar = RunHistoryStats.calendar
        let now = Date()

        func run(daysAgo: Int, miles: Double, minutes: Double, avgHeartRate: Int? = nil) -> RunWorkout {
            let start = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return RunWorkout(
                id: UUID(),
                startDate: start,
                endDate: start.addingTimeInterval(minutes * 60),
                distanceMeters: miles * 1609.34,
                duration: minutes * 60,
                source: "Preview",
                avgHeartRate: avgHeartRate
            )
        }

        // Roughly 18 months of training so every scope — and the per-week and
        // per-month averages that hang off them — has real spread to show:
        // three runs most weeks, an easy 5K / a mid-week 10K / a long run, with
        // the odd week skipped and a steady speed gain over time.
        var runs: [RunWorkout] = []
        let templates: [(offsetInWeek: Int, miles: Double, basePaceMinPerMile: Double, heartRate: Int?)] = [
            (0, 3.1, 8.6, 150),   // easy 5K
            (3, 6.2, 8.9, 159),   // mid-week 10K
            (5, 9.0, 9.6, 164)    // weekend long run
        ]

        for weeksAgo in 0..<78 {
            // Skip a week here and there so the weekly average isn't a flat 3.0.
            if weeksAgo % 7 == 4 { continue }
            let improvement = Double(weeksAgo) * 0.006  // older runs are slower
            let wobble = [0.0, 0.12, -0.08, 0.05, -0.14][weeksAgo % 5]

            for template in templates {
                // Drop the long run on lighter weeks.
                if template.offsetInWeek == 5 && weeksAgo % 3 == 2 { continue }
                let daysAgo = weeksAgo * 7 + (6 - template.offsetInWeek)
                guard daysAgo > 0 || weeksAgo == 0 else { continue }
                let pace = template.basePaceMinPerMile + improvement + wobble
                runs.append(
                    run(
                        daysAgo: daysAgo,
                        miles: template.miles,
                        minutes: template.miles * pace,
                        avgHeartRate: template.heartRate
                    )
                )
            }
        }

        // A couple of runs this week so the current-week section is populated.
        runs.append(run(daysAgo: 0, miles: 3.1, minutes: 25.0, avgHeartRate: 152))
        runs.append(run(daysAgo: 2, miles: 6.2, minutes: 53.0, avgHeartRate: 158))

        return runs.sorted { $0.startDate > $1.startDate }
    }()
}

#Preview {
    NavigationStack {
        RunHistoryContent(runs: RunHistoryPreviewData.runs, unit: .mph)
            .navigationTitle("Run History")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
struct RunHistoryDebugPreviewView: View {
    let showTrends: Bool

    init(showTrends: Bool = false) {
        self.showTrends = showTrends
    }

    var body: some View {
        NavigationStack {
            RunHistoryContent(
                runs: RunHistoryPreviewData.runs,
                unit: .mph,
                initialMode: showTrends ? .trends : .runs
            )
                .navigationTitle("Run History")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif

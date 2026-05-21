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
                    .font(.system(size: 15, weight: .semibold))
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

    @State private var selectedRecordID: String?
    @State private var selectedRange: RunChartRange = .sixMonths
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
        RunHistoryStats.personalRecords(from: filteredRuns, unit: unit)
    }

    private var selectedRecord: RunPersonalRecord? {
        records.first { $0.id == selectedRecordID } ?? records.first
    }

    private var chartPoints: [RunChartPoint] {
        RunHistoryStats.chartPoints(
            from: filteredRuns,
            target: selectedRecord?.target ?? .fiveKilometers,
            unit: unit,
            range: selectedRange
        )
    }

    private var weeks: [RunHistoryWeek] {
        RunHistoryStats.weeks(from: filteredRuns, unit: unit)
    }

    private var summary: RunHistorySummary {
        RunHistoryStats.summary(from: filteredRuns, unit: unit)
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
                        RunSummaryStrip(summary: summary, unit: unit)
                        if filteredRuns.isEmpty {
                            filteredEmptyView
                        } else {
                            weekList
                        }
                    case .trends:
                        if filteredRuns.isEmpty {
                            filteredEmptyView
                        } else if !records.isEmpty {
                            personalRecordsCarousel
                            performanceChart
                        } else {
                            filteredEmptyView
                        }
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
            selectedRecordID = selectedRecord?.id
            expandedWeekIDs = Set(weeks.filter(\.isCurrentWeek).map(\.id))
        }
        .onChange(of: runs) { _, _ in
            normalizePeriodSelections()
            if let selectedRecordID, records.contains(where: { $0.id == selectedRecordID }) == false {
                self.selectedRecordID = selectedRecord?.id
            }
            expandedWeekIDs.formUnion(weeks.filter(\.isCurrentWeek).map(\.id))
        }
        .onChange(of: selectedFilter) { _, _ in
            selectedChartPoint = nil
            if let selectedRecordID, records.contains(where: { $0.id == selectedRecordID }) == false {
                self.selectedRecordID = selectedRecord?.id
            }
            expandedWeekIDs = Set(weeks.filter(\.isCurrentWeek).map(\.id))
        }
        .onChange(of: selectedRange) { _, _ in
            selectedChartPoint = nil
        }
        .onChange(of: selectedRecordID) { _, _ in
            selectedChartPoint = nil
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.runCountText)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Text(unit.speedLabel.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
                    .tracking(1)
            }

            modePicker
            filterPicker
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
        VStack(alignment: .leading, spacing: 8) {
            Picker("Run history period", selection: $selectedPeriod) {
                ForEach(RunHistoryPeriod.allCases) { period in
                    Text(period.shortTitle).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .tint(.green)

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
            .tint(.green)
        case .year:
            Picker("Year", selection: $selectedYearFilter) {
                ForEach(yearOptions) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .tint(.green)
        }
    }

    private var filteredEmptyView: some View {
        ContentUnavailableView(
            "No runs",
            systemImage: "figure.run",
            description: Text("No runs match \(selectedFilter.descriptionText.lowercased()).")
        )
        .font(.caption)
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

    private var personalRecordsCarousel: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("PERSONAL RECORDS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(records.count)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(records) { record in
                        PRCard(
                            record: record,
                            isSelected: record.id == selectedRecord?.id
                        ) {
                            withAnimation(.snappy(duration: 0.2)) {
                                selectedRecordID = record.id
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)

            HStack(spacing: 4) {
                ForEach(records) { record in
                    Capsule()
                        .fill(record.id == selectedRecord?.id ? Color.green : Color.secondary.opacity(0.22))
                        .frame(width: record.id == selectedRecord?.id ? 16 : 4, height: 4)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var performanceChart: some View {
        RunPerformanceChart(
            points: chartPoints,
            selectedPoint: $selectedChartPoint,
            selectedRange: $selectedRange,
            record: selectedRecord,
            unit: unit
        )
    }

    private var weekList: some View {
        LazyVStack(spacing: 12) {
            ForEach(weeks) { week in
                if week.isCurrentWeek {
                    ExpandedWeekSection(week: week, unit: unit, selectedRecord: selectedRecord)
                } else {
                    CollapsedWeekSection(
                        week: week,
                        unit: unit,
                        selectedRecord: selectedRecord,
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
    let unit: SpeedUnit

    var body: some View {
        HStack(spacing: 0) {
            RunSummaryMetric(value: summary.distanceText, label: unit == .mph ? "Total mi" : "Total km")

            Divider()
                .padding(.vertical, 8)

            RunSummaryMetric(value: summary.durationText, label: "Total time")

            Divider()
                .padding(.vertical, 8)

            RunSummaryMetric(value: summary.averageSpeedText, label: "Avg \(unit.speedLabel)", isAccent: true)
        }
        .frame(minHeight: 66)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}

private struct RunSummaryMetric: View {
    let value: String
    let label: String
    var isAccent = false

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(isAccent ? .green : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .monospacedDigit()

            Text(label.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

private struct PRCard: View {
    let record: RunPersonalRecord
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Text(record.target.shortLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .tracking(0.5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(record.speedText)
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("\(record.unit.speedLabel)  /  \(record.paceText) \(record.unit.paceLabel)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                HStack(spacing: 3) {
                    Image(systemName: record.deltaSpeed >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .black))
                    Text("\(abs(record.deltaSpeed), specifier: "%.2f") vs last mo")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(record.deltaSpeed >= 0 ? .green : .red)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(width: 132, height: 84, alignment: .leading)
            .padding(12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.green : Color(.separator), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(record.target.shortLabel) personal record, \(record.speedText) \(record.unit.speedLabel)")
    }
}

private struct RunPerformanceChart: View {
    let points: [RunChartPoint]
    @Binding var selectedPoint: RunChartPoint?
    @Binding var selectedRange: RunChartRange
    let record: RunPersonalRecord?
    let unit: SpeedUnit

    private var displayPoint: RunChartPoint? {
        selectedPoint
    }

    private func deltaString(from start: RunChartPoint?, to end: RunChartPoint?) -> String? {
        guard let start, let end, start.id != end.id else { return nil }
        let delta = end.speed - start.speed
        return "\(delta >= 0 ? "+" : "-")\(String(format: "%.2f", abs(delta))) \(unit.speedLabel)"
    }

    private var speedDomain: ClosedRange<Double> {
        guard let minSpeed = points.map(\.speed).min(),
              let maxSpeed = points.map(\.speed).max() else {
            return 0...1
        }
        let spread = maxSpeed - minSpeed
        let padding = max(spread * 0.35, 0.08)
        let lowerBound = max(0, minSpeed - padding)
        return lowerBound...(maxSpeed + padding)
    }

    var body: some View {
        VStack(spacing: 10) {
            headerContent
                .frame(height: 44, alignment: .top)
                .animation(.easeOut(duration: 0.12), value: displayPoint?.id)

            chart
                .frame(height: 142)

            rangePicker
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .sensoryFeedback(trigger: selectedPoint?.id) { _, new in
            new != nil ? .selection : nil
        }
    }

    @ViewBuilder
    private var headerContent: some View {
        if let displayPoint {
            scrubHeader(for: displayPoint)
        } else {
            idleHeader
        }
    }

    private var idleHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(record?.target.shortLabel ?? "RUN") trend - \(selectedRange.shortTitle)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            if let delta = deltaString(from: points.first, to: points.last) {
                Text(delta)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(delta.hasPrefix("+") ? .green : .red)
                    .monospacedDigit()
            }
        }
    }

    private func scrubHeader(for point: RunChartPoint) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(String(format: "%.2f", point.speed)) \(unit.speedLabel)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text("\(point.paceText) \(unit.paceLabel)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(point.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let delta = deltaString(from: points.first, to: point) {
                    Text(delta)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(delta.hasPrefix("+") ? .green : .red)
                        .monospacedDigit()
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(unit.speedLabel, point.speed)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.green)
                .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Speed floor", speedDomain.lowerBound),
                    yEnd: .value(unit.speedLabel, point.speed)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green.opacity(0.24), Color.green.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            if let displayPoint {
                RuleMark(x: .value("Selected date", displayPoint.date))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(.init(lineWidth: 1))

                PointMark(
                    x: .value("Selected date", displayPoint.date),
                    y: .value(unit.speedLabel, displayPoint.speed)
                )
                .foregroundStyle(Color(.systemBackground))
                .symbolSize(58)

                PointMark(
                    x: .value("Selected date", displayPoint.date),
                    y: .value(unit.speedLabel, displayPoint.speed)
                )
                .foregroundStyle(Color.green)
                .symbolSize(26)
            }
        }
        .chartYScale(domain: speedDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(Color(.separator).opacity(0.35))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Color(.secondaryLabel))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.green.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
            if points.isEmpty {
                ContentUnavailableView(
                    "Not enough data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Runs at this distance will build the PR chart.")
                )
                .font(.caption)
                .background(Color(.systemBackground))
            }
        }
    }

    private var rangePicker: some View {
        HStack {
            Text("Range")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)

            Spacer()

            Picker("Chart range", selection: $selectedRange) {
                ForEach(RunChartRange.allCases) { range in
                    Text(range.shortTitle).tag(range)
                }
            }
            .pickerStyle(.menu)
            .tint(.green)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chart range")
    }

    private func selectNearestPoint(to date: Date) {
        guard let nearest = points.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else { return }

        if selectedPoint?.id != nearest.id {
            selectedPoint = nearest
        }
    }
}

private struct ExpandedWeekSection: View {
    let week: RunHistoryWeek
    let unit: SpeedUnit
    let selectedRecord: RunPersonalRecord?

    var body: some View {
        VStack(spacing: 0) {
            WeekHeader(week: week, isExpanded: true, showsChevron: false)
            ForEach(week.runs) { run in
                RunHistoryRow(
                    run: run,
                    unit: unit,
                    prBadge: run.id == selectedRecord?.runID ? "\(selectedRecord?.target.shortLabel ?? "") PR" : nil
                )
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}

private struct CollapsedWeekSection: View {
    let week: RunHistoryWeek
    let unit: SpeedUnit
    let selectedRecord: RunPersonalRecord?
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
                        prBadge: run.id == selectedRecord?.runID ? "\(selectedRecord?.target.shortLabel ?? "") PR" : nil
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
            HStack(spacing: 8) {
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .black))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                } else {
                    Circle()
                        .fill(week.isCurrentWeek ? Color.green : Color.secondary)
                        .frame(width: 4, height: 4)
                        .frame(width: 10)
                }

                Text(week.title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(week.runCountText)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                Text(week.distanceText)
                Text("Avg \(week.averageSpeedText)")
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.leading, 18)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
    let prBadge: String?

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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(spacing: 6) {
                    Text(run.startDate, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    if let prBadge {
                        Text(prBadge)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.16))
                            )
                    }
                }

                Spacer(minLength: 12)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(speedText)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                    Text(unit.speedLabel)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(distanceText)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text("\(paceText) \(unit.paceLabel)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Text(durationText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .padding(.leading, 14)
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

    static func personalRecords(from runs: [RunWorkout], unit: SpeedUnit, referenceDate: Date = Date()) -> [RunPersonalRecord] {
        RunRecordTarget.allCases.compactMap { target in
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
                deltaSpeed: best.speed - (baseline?.speed ?? best.speed)
            )
        }
    }

    static func chartPoints(
        from runs: [RunWorkout],
        target: RunRecordTarget,
        unit: SpeedUnit,
        range: RunChartRange,
        referenceDate: Date = Date()
    ) -> [RunChartPoint] {
        let lowerBound = range.lowerBound(from: referenceDate, calendar: calendar)
        let efforts = efforts(for: target, runs: runs, unit: unit)
            .filter { effort in
                guard let lowerBound else { return true }
                return effort.date >= lowerBound
            }

        let grouped = Dictionary(grouping: efforts) { calendar.startOfDay(for: $0.date) }
        return grouped.compactMap { day, efforts in
            guard let best = efforts.max(by: { $0.speed < $1.speed }) else { return nil }
            let pace = best.durationMinutes / target.distance(for: unit)
            return RunChartPoint(
                id: "\(target.id)-\(Int(day.timeIntervalSince1970))",
                date: day,
                speed: best.speed,
                paceText: ConversionEngine.formatPace(pace) ?? "--"
            )
        }
        .sorted { $0.date < $1.date }
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
            let title = calendar.isDate(startDate, inSameDayAs: currentWeekStart) ? "THIS WEEK - \(rangeTitle)" : rangeTitle

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

    var speedText: String {
        String(format: "%.2f", speed)
    }
}

struct RunChartPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let speed: Double
    let paceText: String
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

    func distance(for unit: SpeedUnit) -> Double {
        switch unit {
        case .mph:
            return meters / 1609.34
        case .kph:
            return meters / 1000.0
        }
    }
}

enum RunChartRange: String, CaseIterable, Hashable, Identifiable {
    case oneWeek
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneWeek: return "1W"
        case .oneMonth: return "1M"
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .oneYear: return "1Y"
        case .all: return "All"
        }
    }

    var shortTitle: String {
        switch self {
        case .oneWeek: return "1 wk"
        case .oneMonth: return "1 mo"
        case .threeMonths: return "3 mo"
        case .sixMonths: return "6 mo"
        case .oneYear: return "1 yr"
        case .all: return "all"
        }
    }

    func lowerBound(from date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: date)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: date)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: date)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: date)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: date)
        case .all:
            return nil
        }
    }
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
        let startMonth = monthFormatter.string(from: startDate).uppercased()
        let endMonth = monthFormatter.string(from: endDate).uppercased()
        let startDay = dayFormatter.string(from: startDate)
        let endDay = dayFormatter.string(from: endDate)

        if startMonth == endMonth {
            return "\(startMonth) \(startDay)-\(endDay)"
        }
        return "\(startMonth) \(startDay) - \(endMonth) \(endDay)"
    }

    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
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
}

private enum RunHistoryPreviewData {
    static let runs: [RunWorkout] = {
        let calendar = RunHistoryStats.calendar
        let now = Date()

        func run(daysAgo: Int, miles: Double, minutes: Double) -> RunWorkout {
            let start = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return RunWorkout(
                id: UUID(),
                startDate: start,
                endDate: start.addingTimeInterval(minutes * 60),
                distanceMeters: miles * 1609.34,
                duration: minutes * 60,
                source: "Preview"
            )
        }

        return [
            run(daysAgo: 0, miles: 2.0, minutes: 18),
            run(daysAgo: 1, miles: 3.1, minutes: 25),
            run(daysAgo: 3, miles: 4.0, minutes: 36),
            run(daysAgo: 4, miles: 5.0, minutes: 42),
            run(daysAgo: 8, miles: 6.2, minutes: 54),
            run(daysAgo: 10, miles: 3.4, minutes: 30),
            run(daysAgo: 16, miles: 5.1, minutes: 45),
            run(daysAgo: 30, miles: 3.1, minutes: 26),
            run(daysAgo: 65, miles: 7.5, minutes: 68),
            run(daysAgo: 110, miles: 3.1, minutes: 27),
            run(daysAgo: 390, miles: 4.2, minutes: 38),
            run(daysAgo: 420, miles: 3.1, minutes: 29)
        ]
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

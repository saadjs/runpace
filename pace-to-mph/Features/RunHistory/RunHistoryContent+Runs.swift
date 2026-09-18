import SwiftUI

extension RunHistoryContent {
    var header: some View {
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

    var headerTitleText: String {
        switch selectedMode {
        case .runs:
            return summary.runCountText
        case .trends:
            return "\(runs.count) \(runs.count == 1 ? "run" : "runs") tracked"
        }
    }

    var modePicker: some View {
        Picker("Run history mode", selection: $selectedMode) {
            ForEach(RunHistoryMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .tint(.green)
        .accessibilityIdentifier("run-history-mode-picker")
    }

    var filterPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Run history period", selection: $selectedPeriod) {
                ForEach(RunHistoryPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("run-history-period-picker")

            secondaryFilterPicker
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run history period")
    }

    @ViewBuilder
    var secondaryFilterPicker: some View {
        switch selectedPeriod {
        case .week:
            Label(
                RunHistoryStats.currentWeekRangeText(),
                systemImage: "calendar"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("run-history-week-range")
        case .month:
            Picker("Month", selection: $selectedMonthStart) {
                ForEach(monthOptions, id: \.self) { monthStart in
                    Text(RunHistoryFormatters.monthYear(monthStart)).tag(monthStart)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("run-history-month-filter")
        case .year:
            Picker("Year", selection: $selectedYearFilter) {
                ForEach(yearOptions) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("run-history-year-filter")

            if selectedYearFilter == .allTime,
               let firstRunDate = runs.map(\.startDate).min() {
                Label(
                    RunHistoryFormatters.dateRange(firstRunDate, Date()),
                    systemImage: "calendar"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("run-history-all-time-range")
            }
        }
    }

    var filteredEmptyView: some View {
        ContentUnavailableView(
            "No runs",
            systemImage: "figure.run",
            description: Text("No runs match \(selectedFilter.descriptionText.lowercased()).")
        )
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    func normalizePeriodSelections() {
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

    // Drops months that the new filter no longer shows, then guarantees at least
    // one open card. The current month is re-opened on every filter change on
    // purpose — matching the week list, a filter switch is a fresh look rather
    // than a return to the previous expand/collapse state.
    func normalizeMonthSelections() {
        let months = self.months
        expandedMonthIDs.formIntersection(Set(months.map(\.id)))
        expandedMonthIDs.formUnion(months.filter(\.isCurrentMonth).map(\.id))
        if expandedMonthIDs.isEmpty, let firstID = months.first?.id {
            expandedMonthIDs.insert(firstID)
        }
    }

    // The Month tab is a whole-month read, so every week opens and the runs sit
    // together; Week/Year keep the current week as the only open card.
    var defaultExpandedWeekIDs: Set<String> {
        if selectedPeriod == .month {
            return Set(weeks.map(\.id))
        }
        return Set(weeks.filter(\.isCurrentWeek).map(\.id))
    }

    func resetWeekExpansion() {
        expandedWeekIDs = defaultExpandedWeekIDs
    }

    var weekList: some View {
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

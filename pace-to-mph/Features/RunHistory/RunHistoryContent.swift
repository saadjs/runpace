import SwiftUI

struct RunHistoryContent: View {
    let runs: [RunWorkout]
    let unit: SpeedUnit
    let lastSyncedAt: Date?
    let isSyncing: Bool
    let onSync: (() -> Void)?

    @State var selectedTrendScope: RunTrendScope = .threeMonths
    @State var selectedTrendDistance: RunRecordTarget?
    @State var selectedChartPoint: RunChartPoint?
    @State var selectedTrendMetric: RunTrendMetric = .speed
    @State var showsMoreInsights = false
    @State var expandedWeekIDs: Set<String> = []
    @State var expandedMonthIDs: Set<String> = []
    @State var selectedMode: RunHistoryMode
    @State var selectedPeriod: RunHistoryPeriod = .week
    @State var selectedMonthStart = RunHistoryStats.monthStart(containing: Date())
    @State var selectedYearFilter = RunHistoryYearFilter.current()

    init(
        runs: [RunWorkout],
        unit: SpeedUnit,
        initialMode: RunHistoryMode = .runs,
        initialPeriod: RunHistoryPeriod = .week,
        lastSyncedAt: Date? = nil,
        isSyncing: Bool = false,
        onSync: (() -> Void)? = nil
    ) {
        self.runs = runs
        self.unit = unit
        self.lastSyncedAt = lastSyncedAt
        self.isSyncing = isSyncing
        self.onSync = onSync
        _selectedMode = State(initialValue: initialMode)
        _selectedPeriod = State(initialValue: initialPeriod)
    }

    // Deliberately not wrapped in a `GlassEffectContainer`. A container gives
    // every enclosed `.glassEffect` one shared sampling/blend scope, so any card
    // animating its height — an accordion expanding — invalidates the glass of
    // its neighbours too, which read as a flicker on the already-open card.
    // Containers are for small clusters of glass that should merge or morph
    // (a toolbar, a chip row), not for a long scroll of independent cards.
    var body: some View {
        ScrollView {
            // Not lazy: with a LazyVStack here, scrolling the Runs list while accessibility is active (VoiceOver, UI tests) hangs at 100% CPU.
            VStack(spacing: 16) {
                header

                switch selectedMode {
                case .runs:
                    RunSummaryStrip(summary: summary, cadence: cadence, unit: unit)
                    if filteredRuns.isEmpty {
                        filteredEmptyView
                    } else {
                        if selectedPeriod == .year {
                            MonthAccordionList(
                                months: months,
                                unit: unit,
                                prBadgesByRunID: prBadgesByRunID,
                                expandedMonthIDs: $expandedMonthIDs
                            )
                        } else {
                            weekList
                        }
                    }
                case .trends:
                    trendsBody
                }

                if let onSync {
                    RunHistorySyncFooter(
                        lastSyncedAt: lastSyncedAt,
                        isLoading: isSyncing,
                        onSync: onSync
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selectedChartPoint?.id)
        .onAppear {
            normalizePeriodSelections()
            resetWeekExpansion()
            normalizeMonthSelections()
        }
        .onChange(of: runs) { _, _ in
            normalizePeriodSelections()
            expandedWeekIDs.formUnion(defaultExpandedWeekIDs)
            normalizeMonthSelections()
        }
        .onChange(of: selectedPeriod) { _, _ in
            resetWeekExpansion()
        }
        .onChange(of: selectedFilter) { _, _ in
            selectedChartPoint = nil
            resetWeekExpansion()
            normalizeMonthSelections()
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
        .onChange(of: resolvedSpeedTrendDistance) { _, _ in
            selectedChartPoint = nil
        }
    }
}

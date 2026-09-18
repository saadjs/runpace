import SwiftUI

struct ContentView: View {
    let healthKitService: HealthKitService
    let defaultScreenSettings: DefaultScreenSettings

    @State var viewModel = ConverterViewModel()
    @State var favoritesStore = FavoritesStore()
    @State var unitSettings = UnitSettings.shared
    @State var currentScreen: DefaultScreen
    @FocusState var isInputFocused: Bool

    init(
        healthKitService: HealthKitService,
        defaultScreenSettings: DefaultScreenSettings = .shared,
        initialScreen: DefaultScreen? = nil
    ) {
        self.healthKitService = healthKitService
        self.defaultScreenSettings = defaultScreenSettings
        _currentScreen = State(
            initialValue: initialScreen ?? defaultScreenSettings.defaultScreen
        )
    }

    var body: some View {
        NavigationStack {
            topLevelScreen
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        toolsMenu
                    }
                }
        }
    }

    @ViewBuilder
    private var topLevelScreen: some View {
        switch currentScreen {
        case .converter:
            converterScreen
        case .raceCalculator:
            RaceTimeView()
        case .evenSplits:
            SplitCalculatorView()
        case .negativeSplits:
            NegativeSplitView()
        case .runHistory:
            RunHistoryView(service: healthKitService)
        case .favorites:
            FavoritesView(store: favoritesStore)
        case .referenceTable:
            ReferenceView()
        }
    }

    private var toolsMenu: some View {
        Menu {
            screenButton(.converter)

            Divider()

            screenButton(.raceCalculator)
            screenButton(.evenSplits)
            screenButton(.negativeSplits)

            Divider()

            screenButton(.runHistory)
            screenButton(.favorites)
            screenButton(.referenceTable)

            Divider()

            NavigationLink {
                SettingsView(defaultScreenSettings: defaultScreenSettings)
            } label: {
                Label("Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
        }
        .menuStyle(.button)
        .accessibilityLabel("Tools menu")
    }

    private func screenButton(_ screen: DefaultScreen) -> some View {
        Button {
            guard currentScreen != screen else { return }
            isInputFocused = false
            currentScreen = screen
        } label: {
            Label(screen.label, systemImage: screen.systemImage)
        }
    }

}

#Preview {
    ContentView(healthKitService: HealthKitService())
}

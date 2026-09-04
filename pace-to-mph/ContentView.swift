import SwiftUI

struct ContentView: View {
    let healthKitService: HealthKitService
    let defaultScreenSettings: DefaultScreenSettings

    @State private var viewModel = ConverterViewModel()
    @State private var favoritesStore = FavoritesStore()
    @State private var unitSettings = UnitSettings.shared
    @State private var currentScreen: DefaultScreen
    @FocusState private var isInputFocused: Bool

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

    private var converterScreen: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                conversionCard
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                Spacer()

                controlPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .autoFocus($isInputFocused, enabled: currentScreen == .converter)
            // Without a shape the tap target stops at the content, so the
            // empty space around the card never dismissed the keyboard.
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
            }
            .onChange(of: unitSettings.unit) { _, _ in
                viewModel.handleUnitChange()
            }
            .onChange(of: viewModel.direction) { _, _ in
                // Runs after SwiftUI has pushed the new keyboard type onto
                // the field, which is what UIKit reloads from.
                Task { @MainActor in reloadKeyboardForFocusedField() }
            }
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.directionLabel)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .strokeBorder(.quaternary, lineWidth: 1)
                )

            Text(viewModel.helperText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Conversion Card

    private var conversionCard: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField(viewModel.placeholder, text: Binding(
                        get: { viewModel.inputText },
                        set: { viewModel.handleInput($0) }
                    ))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .keyboardType(viewModel.direction == .paceToSpeed ? .numbersAndPunctuation : .decimalPad)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("Enter \(viewModel.direction == .paceToSpeed ? "pace" : "speed")")
                    .accessibilityHint(viewModel.helperText)

                    Text(viewModel.inputSuffix)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(height: 2)
                    .frame(maxWidth: 200)
                    .accessibilityHidden(true)
            }

            Divider()

            VStack(spacing: 6) {
                VStack(spacing: 6) {
                    Text(viewModel.result.isEmpty ? "–" : viewModel.result)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(viewModel.result.isEmpty ? .tertiary : .primary)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: viewModel.result)

                    Text(viewModel.resultSuffix)
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(viewModel.result.isEmpty ? "No result" : "\(viewModel.result) \(viewModel.resultSuffix)")

                if !viewModel.result.isEmpty {
                    let isFav = favoritesStore.isFavorited(
                        input: viewModel.inputText,
                        inputSuffix: viewModel.inputSuffix,
                        result: viewModel.result,
                        resultSuffix: viewModel.resultSuffix
                    )
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            favoritesStore.toggle(
                                input: viewModel.inputText,
                                inputSuffix: viewModel.inputSuffix,
                                result: viewModel.result,
                                resultSuffix: viewModel.resultSuffix
                            )
                        }
                    } label: {
                        Image(systemName: isFav ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundStyle(isFav ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.result)
        }
        .padding(24)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Conversion")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            directionPicker
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }

    private var directionPicker: some View {
        Picker("Conversion direction", selection: Binding(
            get: { viewModel.direction },
            set: { direction in
                withAnimation(.snappy(duration: 0.25)) {
                    viewModel.switchDirection(to: direction)
                }
                isInputFocused = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        )) {
            ForEach(ConversionDirection.allCases, id: \.self) { dir in
                Text(dir.label).tag(dir)
            }
        }
        .pickerStyle(.segmented)
        .tint(.green)
    }

}

#Preview {
    ContentView(healthKitService: HealthKitService())
}

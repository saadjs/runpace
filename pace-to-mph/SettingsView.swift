import SwiftUI

struct SettingsView: View {
    @State private var settings = UnitSettings.shared
    @State private var defaultScreenSettings: DefaultScreenSettings

    init(defaultScreenSettings: DefaultScreenSettings = .shared) {
        _defaultScreenSettings = State(initialValue: defaultScreenSettings)
    }

    var body: some View {
        GlassEffectContainer {
            ScrollView {
                VStack(spacing: 20) {
                    unitCard
                    defaultScreenCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var defaultScreenCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DEFAULT SCREEN")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)

            HStack {
                Text("Open app to")

                Spacer()

                Picker("Default screen", selection: Binding(
                    get: { defaultScreenSettings.defaultScreen },
                    set: { screen in
                        defaultScreenSettings.defaultScreen = screen
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                )) {
                    ForEach(DefaultScreen.allCases) { screen in
                        Label(screen.label, systemImage: screen.systemImage)
                            .tag(screen)
                    }
                }
                .pickerStyle(.menu)
                .tint(.green)
            }

            Text("Takes effect the next time you open the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }

    private var unitCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("UNITS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            unitPicker
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }

    private var unitPicker: some View {
        Picker("Speed unit", selection: Binding(
            get: { settings.unit },
            set: { unit in
                settings.unit = unit
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        )) {
            ForEach(SpeedUnit.allCases, id: \.self) { u in
                Text(u.label).tag(u)
            }
        }
        .pickerStyle(.segmented)
        .tint(.green)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

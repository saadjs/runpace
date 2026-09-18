import SwiftUI

// MARK: - Custom Selectors

struct UnitToggle: View {
    @Binding var selectedUnit: SpeedUnit

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SpeedUnit.allCases, id: \.self) { unit in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedUnit = unit }
                } label: {
                    Text(unit.speedLabel)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedUnit == unit ? .white : .secondary)
                .background(
                    selectedUnit == unit ? Color.green : Color.white.opacity(0.08),
                    in: Capsule()
                )
            }
        }
    }
}

struct DistanceSelector: View {
    @Binding var selected: RaceCalculator.Distance

    private let distances = RaceCalculator.Distance.standardCases

    var body: some View {
        HStack(spacing: 4) {
            ForEach(distances) { distance in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = distance }
                } label: {
                    Text(distance.shortLabel)
                        .font(.caption2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selected == distance ? .white : .secondary)
                .background(
                    selected == distance ? Color.green : Color.white.opacity(0.08),
                    in: Capsule()
                )
            }
        }
    }
}

extension View {
    @ViewBuilder
    func watchGlassCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(watchOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func watchGlassButton() -> some View {
        if #available(watchOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

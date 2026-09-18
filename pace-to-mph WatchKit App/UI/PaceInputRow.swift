import SwiftUI

// MARK: - Inline Pace Picker

struct PaceInputRow: View {
    @Binding var paceMinutes: Int
    @Binding var paceSeconds: Int
    let paceLabel: String

    @State private var editingSeconds = false
    @State private var crownValue: Double = 0

    private var crownMax: Double { editingSeconds ? 59 : 30 }
    private var crownMin: Double { editingSeconds ? 0 : 1 }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(paceMinutes)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(!editingSeconds ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
                )
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    editingSeconds = false
                    crownValue = Double(paceMinutes)
                }

            Text(":")
                .font(.title3.bold())

            Text(String(format: "%02d", paceSeconds))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(editingSeconds ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
                )
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    editingSeconds = true
                    crownValue = Double(paceSeconds)
                }

            Text(paceLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .focusable()
        .digitalCrownRotation(
            detent: $crownValue,
            from: crownMin, through: crownMax, by: 1,
            sensitivity: .low,
            isContinuous: false
        )
        .onChange(of: crownValue) { _, newValue in
            if editingSeconds {
                paceSeconds = Int(newValue)
            } else {
                paceMinutes = Int(newValue)
            }
        }
        .onAppear { crownValue = Double(paceMinutes) }
    }
}

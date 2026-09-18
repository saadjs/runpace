import SwiftUI

// MARK: - Shared Helpers

func makeUnitBinding(
    unit: Binding<SpeedUnit>,
    paceMinutes: Binding<Int>,
    paceSeconds: Binding<Int>
) -> Binding<SpeedUnit> {
    Binding(
        get: { unit.wrappedValue },
        set: { newUnit in
            let previousUnit = unit.wrappedValue
            guard previousUnit != newUnit else { return }

            if let converted = ConversionEngine.convertPaceComponents(
                minutes: paceMinutes.wrappedValue,
                seconds: paceSeconds.wrappedValue,
                from: previousUnit,
                to: newUnit
            ) {
                paceMinutes.wrappedValue = converted.minutes
                paceSeconds.wrappedValue = converted.seconds
            }

            unit.wrappedValue = newUnit
        }
    )
}

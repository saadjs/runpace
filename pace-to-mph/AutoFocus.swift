import SwiftUI
import UIKit

private enum FirstResponderStorage {
    static weak var current: UIResponder?
}

private extension UIResponder {
    @objc func captureFirstResponder(_ sender: Any?) {
        FirstResponderStorage.current = self
    }

    static var current: UIResponder? {
        FirstResponderStorage.current = nil
        UIApplication.shared.sendAction(
            #selector(captureFirstResponder(_:)),
            to: nil,
            from: nil,
            for: nil
        )
        return FirstResponderStorage.current
    }
}

/// UIKit keeps showing the old keyboard when a focused field's keyboard type
/// changes, so the input views have to be reloaded explicitly.
@MainActor
func reloadKeyboardForFocusedField() {
    (UIResponder.current as? UIView)?.reloadInputViews()
}

/// A field can hold focus while the keyboard stays down, so track whether the
/// keyboard actually came up rather than trusting focus state alone.
@MainActor
private enum KeyboardTracker {
    private(set) static var isVisible = false
    private static var started = false

    static func start() {
        guard !started else { return }
        started = true
        observe(UIResponder.keyboardDidShowNotification, visible: true)
        observe(UIResponder.keyboardDidHideNotification, visible: false)
    }

    private static func observe(_ name: Notification.Name, visible: Bool) {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { isVisible = visible }
        }
    }
}

/// Raises the keyboard as soon as a screen appears, so the user can start
/// typing without tapping into the field first.
private struct AutoFocusModifier: ViewModifier {
    @FocusState.Binding var isFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        // Keyed on scene phase so focus is only requested once the scene is
        // active, and is re-armed when the app returns to the foreground. UIKit
        // silently drops focus requests made while the scene is still inactive.
        content.task(id: scenePhase) {
            guard scenePhase == .active else { return }
            KeyboardTracker.start()
            await raiseKeyboard()
        }
    }

    @MainActor
    private func raiseKeyboard() async {
        for attempt in 0..<4 {
            // Re-setting true is a no-op for SwiftUI, so a failed attempt has to
            // resign first to make the next request a real state transition.
            if attempt > 0 {
                isFocused = false
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
            }

            isFocused = true

            // Give UIKit a full presentation window before judging the attempt.
            // The old 150ms check fired mid-presentation, so the next attempt
            // resigned a field that was about to raise the keyboard.
            try? await Task.sleep(for: .milliseconds(attempt == 0 ? 300 : 450))
            guard !Task.isCancelled else { return }

            // Either signal means the field is usable: an attached hardware
            // keyboard leaves the software keyboard hidden on purpose.
            if KeyboardTracker.isVisible || UIResponder.current is UITextInput {
                return
            }
        }
    }
}

extension View {
    func autoFocus(_ isFocused: FocusState<Bool>.Binding) -> some View {
        modifier(AutoFocusModifier(isFocused: isFocused))
    }
}

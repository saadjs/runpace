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

/// Raises the keyboard as soon as a screen appears, so the user can start
/// typing without tapping into the field first.
private struct AutoFocusModifier: ViewModifier {
    @FocusState.Binding var isFocused: Bool

    func body(content: Content) -> some View {
        content.task { @MainActor in
            // A FocusState may still be true after its field has resigned, so
            // force a real state transition for every appearance. Retry until
            // UIKit confirms that a text input is the first responder.
            for attempt in 0..<4 {
                isFocused = false
                await Task.yield()

                let delay: Duration = attempt == 0 ? .milliseconds(100) : .milliseconds(200)
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }

                isFocused = true
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }

                if UIResponder.current is UITextInput {
                    return
                }
            }
        }
    }
}

extension View {
    func autoFocus(_ isFocused: FocusState<Bool>.Binding) -> some View {
        modifier(AutoFocusModifier(isFocused: isFocused))
    }
}

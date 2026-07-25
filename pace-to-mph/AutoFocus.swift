import SwiftUI

/// Raises the keyboard as soon as a screen appears, so the user can start
/// typing without tapping into the field first.
private struct AutoFocusModifier: ViewModifier {
    @FocusState.Binding var isFocused: Bool
    let delay: Duration

    func body(content: Content) -> some View {
        content.onAppear {
            // A short delay lets the push/present transition settle; focusing
            // mid-transition is dropped by UIKit and the keyboard never shows.
            Task { @MainActor in
                try? await Task.sleep(for: delay)
                isFocused = true
            }
        }
    }
}

extension View {
    func autoFocus(_ isFocused: FocusState<Bool>.Binding, delay: Duration = .milliseconds(350)) -> some View {
        modifier(AutoFocusModifier(isFocused: isFocused, delay: delay))
    }
}

import SwiftUI
import UIKit

extension View {
    /// Resigns the first responder app-wide. Used for tap-outside-to-dismiss on
    /// screens with UIKit-backed `SelectAllTextField`s (SwiftUI's `@FocusState`
    /// doesn't drive them).
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}

/// A text field where a **double-tap selects the entire contents** (so one
/// delete clears everything) — the behavior expected across the app's input
/// boxes. SwiftUI's `TextField` only offers double-tap-selects-word, so this
/// wraps `UITextField` to add the select-all gesture while keeping the visual
/// styling to the SwiftUI caller (background, padding, clip shape).
struct SelectAllTextField: UIViewRepresentable {
    private let placeholder: String
    @Binding private var text: String
    private let keyboardType: UIKeyboardType
    private let onCommit: () -> Void

    init(
        _ placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        onCommit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.onCommit = onCommit
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.font = UIFont(name: "Kanit-Regular", size: 16) ?? .systemFont(ofSize: 16)
        field.textColor = .black
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        field.addGestureRecognizer(doubleTap)

        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let text: Binding<String>
        private let onCommit: () -> Void

        init(text: Binding<String>, onCommit: @escaping () -> Void) {
            self.text = text
            self.onCommit = onCommit
        }

        @objc func editingChanged(_ sender: UITextField) {
            text.wrappedValue = sender.text ?? ""
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let field = gesture.view as? UITextField else { return }
            if !field.isFirstResponder { field.becomeFirstResponder() }
            field.selectAll(nil)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            onCommit()
            return true
        }
    }
}

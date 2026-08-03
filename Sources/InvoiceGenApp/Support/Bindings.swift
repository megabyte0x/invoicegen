import Foundation
import SwiftUI
import AppKit
import InvoiceCore

struct NumericEditorResetID: Hashable {
    var entityID: UUID
    var generation: Int
}

enum MoneyTextFieldFormatter {
    static func text(
        draft: String?,
        minorUnits: Int64,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String {
        draft ?? string(from: minorUnits, locale: locale)
    }

    static func string(
        from minorUnits: Int64,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String {
        let magnitude = minorUnits == Int64.min
            ? UInt64(Int64.max) + 1
            : UInt64(abs(minorUnits))
        let sign = minorUnits < 0 ? "-" : ""
        let decimalSeparator = locale.decimalSeparator ?? "."
        let fractionalDigits = String(magnitude % 100).leftPadding(to: 2, with: "0")
        return "\(sign)\(magnitude / 100)\(decimalSeparator)\(fractionalDigits)"
    }

    static func minorUnits(
        from value: String,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> Int64? {
        guard case let .valid(parsed) = LocaleNumericParser.moneyMinorUnits(from: value, locale: locale) else {
            return nil
        }
        return parsed
    }
}

enum DecimalTextFieldFormatter {
    static func text(
        draft: String?,
        value: Double,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String {
        draft ?? string(from: value, locale: locale)
    }

    static func string(
        from value: Double,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String {
        guard value.isFinite else { return "" }
        if value.rounded() == value,
           value >= Double(Int64.min),
           value <= Double(Int64.max) {
            return String(Int64(value))
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func value(
        from rawValue: String,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> Double? {
        guard case let .valid(parsed) = LocaleNumericParser.decimal(from: rawValue, locale: locale) else {
            return nil
        }
        return parsed
    }
}

enum IntegerTextFieldFormatter {
    static func text(draft: String?, value: Int) -> String {
        draft ?? string(from: value)
    }

    static func string(from value: Int) -> String {
        String(value)
    }

    static func value(from rawValue: String) -> Int? {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.range(of: #"^-?[0-9]+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return Int(trimmed)
    }
}

struct RuneyMoneyTextField: View {
    @Binding var minorUnits: Int64
    var width: CGFloat? = nil
    var accessibilityLabel: String
    var validRange: ClosedRange<Int64>? = nil
    var outOfRangeMessage = "Enter an amount within the supported range."
    var resetID: AnyHashable? = nil
    var locale: Locale = .autoupdatingCurrent
    var onValidityChanged: (Bool) -> Void = { _ in }
    var onCommitDraft: () -> Void = {}
    @State private var draft: String?
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RuneyNumericDraftTextField(
                text: textBinding,
                isEditing: $isEditing,
                modelValueIsZero: minorUnits == 0,
                accessibilityLabel: accessibilityLabel,
                onCommit: onCommitDraft
            )
            .frame(width: width, height: 30)

            if !isEditing, case let .invalid(message) = draftState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.runeyDestructive)
            }
        }
            .onChange(of: resetID) { _, _ in
                resetDraft()
            }
            .onAppear {
                reportValidity()
            }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                MoneyTextFieldFormatter.text(
                    draft: draft,
                    minorUnits: minorUnits,
                    locale: locale
                )
            },
            set: { newValue in
                draft = newValue
                if case let .valid(parsed) = draftState {
                    minorUnits = parsed
                }
                reportValidity()
            }
        )
    }

    private func resetDraft() {
        draft = nil
        reportValidity()
    }

    private var draftState: NumericDraftState<Int64> {
        let state = draft.map { LocaleNumericParser.moneyMinorUnits(from: $0, locale: locale) }
            ?? .valid(minorUnits)
        if case let .valid(value) = state,
           let validRange,
           !validRange.contains(value) {
            return .invalid(outOfRangeMessage)
        }
        return state
    }

    private func reportValidity() {
        if case .valid = draftState {
            onValidityChanged(true)
        } else {
            onValidityChanged(false)
        }
    }
}

struct RuneyDecimalTextField: View {
    @Binding var value: Double
    var width: CGFloat? = nil
    var accessibilityLabel: String
    var validRange: ClosedRange<Double>? = nil
    var outOfRangeMessage = "Enter a number within the supported range."
    var resetID: AnyHashable? = nil
    var locale: Locale = .autoupdatingCurrent
    var onValidityChanged: (Bool) -> Void = { _ in }
    var onCommitDraft: () -> Void = {}
    @State private var draft: String?
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RuneyNumericDraftTextField(
                text: textBinding,
                isEditing: $isEditing,
                modelValueIsZero: value == 0,
                accessibilityLabel: accessibilityLabel,
                onCommit: onCommitDraft
            )
            .frame(width: width, height: 30)

            if !isEditing, case let .invalid(message) = draftState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.runeyDestructive)
            }
        }
            .onChange(of: resetID) { _, _ in
                resetDraft()
            }
            .onAppear {
                reportValidity()
            }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                DecimalTextFieldFormatter.text(
                    draft: draft,
                    value: value,
                    locale: locale
                )
            },
            set: { newValue in
                draft = newValue
                if case let .valid(parsed) = draftState {
                    value = parsed
                }
                reportValidity()
            }
        )
    }

    private func resetDraft() {
        draft = nil
        reportValidity()
    }

    private var draftState: NumericDraftState<Double> {
        let state = draft.map { LocaleNumericParser.decimal(from: $0, locale: locale) }
            ?? .valid(value)
        if case let .valid(value) = state,
           let validRange,
           !validRange.contains(value) {
            return .invalid(outOfRangeMessage)
        }
        return state
    }

    private func reportValidity() {
        if case .valid = draftState {
            onValidityChanged(true)
        } else {
            onValidityChanged(false)
        }
    }
}

private struct RuneyNumericDraftTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool
    var modelValueIsZero: Bool
    var accessibilityLabel: String
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.bezelStyle = .roundedBezel
        textField.delegate = context.coordinator
        textField.stringValue = text
        textField.setAccessibilityLabel(accessibilityLabel)
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        context.coordinator.parent = self
        textField.setAccessibilityLabel(accessibilityLabel)
        if !context.coordinator.isEditing, textField.stringValue != text {
            textField.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: RuneyNumericDraftTextField
        var isEditing = false

        init(parent: RuneyNumericDraftTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            isEditing = true
            parent.isEditing = true
            if parent.modelValueIsZero,
               let textField = notification.object as? NSTextField {
                textField.currentEditor()?.selectAll(nil)
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            isEditing = false
            parent.isEditing = false
            parent.onCommit()
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                // The first responder is the shared field editor, not this
                // NSTextField. Advance from the control explicitly so Tab
                // cannot select the same numeric field again.
                control.window?.selectKeyView(following: control)
                return true
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                control.window?.selectKeyView(preceding: control)
                return true
            }
            return false
        }
    }
}

private extension String {
    func leftPadding(to length: Int, with character: Character) -> String {
        String(repeating: String(character), count: max(0, length - count)) + self
    }
}

struct RuneyIntegerTextField: View {
    @Binding var value: Int
    @Binding var draft: String?
    var validRange: ClosedRange<Int>
    var width: CGFloat? = nil
    var resetID: AnyHashable? = nil
    var accessibilityLabel: String
    var onValidityChange: (Bool) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: textBinding)
            .accessibilityLabel(accessibilityLabel)
            .runeyFieldInput(width: width)
            .focused($isFocused)
            .onSubmit {
                clearDraftIfValid()
            }
            .onChange(of: isFocused) { _, newValue in
                if !newValue {
                    clearDraftIfValid()
                }
            }
            .onChange(of: resetID) { _, _ in
                draft = nil
            }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                IntegerTextFieldFormatter.text(
                    draft: draft,
                    value: value
                )
            },
            set: { newValue in
                draft = newValue
                guard let parsed = IntegerTextFieldFormatter.value(from: newValue),
                      validRange.contains(parsed) else {
                    onValidityChange(false)
                    return
                }
                value = parsed
                onValidityChange(true)
            }
        )
    }

    private func clearDraftIfValid() {
        guard let draft,
              let parsed = IntegerTextFieldFormatter.value(from: draft),
              validRange.contains(parsed) else {
            return
        }
        self.draft = nil
    }
}

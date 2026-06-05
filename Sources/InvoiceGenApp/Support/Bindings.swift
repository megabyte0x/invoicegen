import Foundation
import SwiftUI
import InvoiceCore

enum MoneyTextFieldFormatter {
    static func text(draft: String?, minorUnits: Int64) -> String {
        draft ?? string(from: minorUnits)
    }

    static func string(from minorUnits: Int64) -> String {
        let absolute = abs(minorUnits)
        let sign = minorUnits < 0 ? "-" : ""
        return "\(sign)\(absolute / 100).\(String(format: "%02d", absolute % 100))"
    }

    static func minorUnits(from value: String) -> Int64? {
        try? Money.parseMinorUnits(value)
    }
}

enum DecimalTextFieldFormatter {
    static func text(draft: String?, value: Double) -> String {
        draft ?? string(from: value)
    }

    static func string(from value: Double) -> String {
        guard value.isFinite else { return "" }
        if value.rounded() == value,
           value >= Double(Int64.min),
           value <= Double(Int64.max) {
            return String(Int64(value))
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func value(from rawValue: String) -> Double? {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard !trimmed.isEmpty,
              let value = Double(trimmed),
              value.isFinite
        else {
            return nil
        }
        return value
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
            .replacingOccurrences(of: ",", with: "")
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }
}

struct RuneyMoneyTextField: View {
    @Binding var minorUnits: Int64
    var width: CGFloat? = nil
    var resetID: AnyHashable? = nil
    @State private var draft: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: textBinding)
            .runeyFieldInput(width: width)
            .focused($isFocused)
            .onSubmit {
                resetDraft()
            }
            .onChange(of: isFocused) { _, newValue in
                if !newValue {
                    resetDraft()
                }
            }
            .onChange(of: resetID) { _, _ in
                resetDraft()
            }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                MoneyTextFieldFormatter.text(
                    draft: draft,
                    minorUnits: minorUnits
                )
            },
            set: { newValue in
                draft = newValue
                guard let parsed = MoneyTextFieldFormatter.minorUnits(from: newValue) else {
                    return
                }
                minorUnits = parsed
            }
        )
    }

    private func resetDraft() {
        draft = nil
    }
}

struct RuneyDecimalTextField: View {
    @Binding var value: Double
    var width: CGFloat? = nil
    var resetID: AnyHashable? = nil
    @State private var draft: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: textBinding)
            .runeyFieldInput(width: width)
            .focused($isFocused)
            .onSubmit {
                resetDraft()
            }
            .onChange(of: isFocused) { _, newValue in
                if !newValue {
                    resetDraft()
                }
            }
            .onChange(of: resetID) { _, _ in
                resetDraft()
            }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                DecimalTextFieldFormatter.text(
                    draft: draft,
                    value: value
                )
            },
            set: { newValue in
                draft = newValue
                guard let parsed = DecimalTextFieldFormatter.value(from: newValue) else {
                    return
                }
                value = parsed
            }
        )
    }

    private func resetDraft() {
        draft = nil
    }
}

struct RuneyIntegerTextField: View {
    @Binding var value: Int
    var width: CGFloat? = nil
    var resetID: AnyHashable? = nil
    @State private var draft: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: textBinding)
            .runeyFieldInput(width: width)
            .focused($isFocused)
            .onSubmit {
                resetDraft()
            }
            .onChange(of: isFocused) { _, newValue in
                if !newValue {
                    resetDraft()
                }
            }
            .onChange(of: resetID) { _, _ in
                resetDraft()
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
                guard let parsed = IntegerTextFieldFormatter.value(from: newValue) else {
                    return
                }
                value = parsed
            }
        )
    }

    private func resetDraft() {
        draft = nil
    }
}

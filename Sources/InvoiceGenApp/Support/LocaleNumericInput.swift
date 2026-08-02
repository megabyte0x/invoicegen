import Foundation

enum NumericDraftState<Value: Equatable>: Equatable {
    case empty
    case partial
    case valid(Value)
    case invalid(String)
}

enum LocaleNumericParser {
    static func moneyMinorUnits(
        from rawValue: String,
        locale: Locale = .autoupdatingCurrent
    ) -> NumericDraftState<Int64> {
        switch parsedComponents(from: rawValue, locale: locale) {
        case .empty:
            return .empty
        case .partial:
            return .partial
        case let .invalid(message):
            return .invalid(message)
        case let .number(sign, wholeDigits, fractionalDigits):
            guard fractionalDigits.count <= 2 else {
                return .invalid(moneyPrecisionMessage)
            }

            let paddedFraction = fractionalDigits + String(repeating: "0", count: 2 - fractionalDigits.count)
            guard let magnitude = unsignedInteger(from: wholeDigits + paddedFraction) else {
                return .invalid(invalidNumberMessage(locale: locale))
            }
            guard let value = signedInt64(magnitude, negative: sign) else {
                return .invalid(invalidNumberMessage(locale: locale))
            }
            return .valid(value)
        }
    }

    static func decimal(
        from rawValue: String,
        maximumFractionDigits: Int = 8,
        locale: Locale = .autoupdatingCurrent
    ) -> NumericDraftState<Double> {
        switch parsedComponents(from: rawValue, locale: locale) {
        case .empty:
            return .empty
        case .partial:
            return .partial
        case let .invalid(message):
            return .invalid(message)
        case let .number(negative, wholeDigits, fractionalDigits):
            guard maximumFractionDigits >= 0, fractionalDigits.count <= maximumFractionDigits else {
                return .invalid(decimalPrecisionMessage)
            }

            let normalized = (negative ? "-" : "") + wholeDigits +
                (fractionalDigits.isEmpty ? "" : "." + fractionalDigits)
            guard let value = Double(normalized), value.isFinite else {
                return .invalid(invalidNumberMessage(locale: locale))
            }
            return .valid(value)
        }
    }

    static func invalidNumberMessage(locale: Locale) -> String {
        let separator = locale.decimalSeparator ?? "."
        return "Enter a number using \(separator) as the decimal separator and no grouping separators."
    }

    static let moneyPrecisionMessage = "Enter no more than two decimal places."
    static let decimalPrecisionMessage = "Enter no more than eight decimal places."

    private enum ParsedComponents {
        case empty
        case partial
        case number(negative: Bool, wholeDigits: String, fractionalDigits: String)
        case invalid(String)
    }

    private static func parsedComponents(from rawValue: String, locale: Locale) -> ParsedComponents {
        let separator = locale.decimalSeparator ?? "."
        let invalidMessage = invalidNumberMessage(locale: locale)

        guard !rawValue.isEmpty else { return .empty }
        guard separator.count == 1 else { return .invalid(invalidMessage) }

        var value = rawValue
        let isNegative = value.removeFirstIfEqual(to: "-")
        if value.isEmpty { return .partial }

        let parts = value.components(separatedBy: separator)
        guard parts.count <= 2 else { return .invalid(invalidMessage) }

        let wholeDigits = parts[0]
        let fractionalDigits = parts.count == 2 ? parts[1] : ""
        if wholeDigits.isEmpty && parts.count == 1 {
            return .invalid(invalidMessage)
        }
        guard wholeDigits.allSatisfy({ Self.isASCIIDigit($0) }),
              fractionalDigits.allSatisfy({ Self.isASCIIDigit($0) })
        else {
            return .invalid(invalidMessage)
        }
        if parts.count == 2, fractionalDigits.isEmpty {
            return .partial
        }
        return .number(
            negative: isNegative,
            wholeDigits: wholeDigits.isEmpty ? "0" : wholeDigits,
            fractionalDigits: fractionalDigits
        )
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        character.unicodeScalars.count == 1 && character.unicodeScalars.allSatisfy { scalar in
            scalar.value >= UnicodeScalar("0").value && scalar.value <= UnicodeScalar("9").value
        }
    }

    private static func unsignedInteger(from digits: String) -> UInt64? {
        var value: UInt64 = 0
        for digit in digits.unicodeScalars {
            guard let nextDigit = UInt64(String(digit)) else { return nil }
            let product = value.multipliedReportingOverflow(by: 10)
            let sum = product.partialValue.addingReportingOverflow(nextDigit)
            guard !product.overflow, !sum.overflow else { return nil }
            value = sum.partialValue
        }
        return value
    }

    private static func signedInt64(_ magnitude: UInt64, negative: Bool) -> Int64? {
        if negative {
            let minimumMagnitude = UInt64(Int64.max) + 1
            guard magnitude <= minimumMagnitude else { return nil }
            return magnitude == minimumMagnitude ? Int64.min : -Int64(magnitude)
        }

        guard magnitude <= UInt64(Int64.max) else { return nil }
        return Int64(magnitude)
    }
}

private extension String {
    mutating func removeFirstIfEqual(to value: Character) -> Bool {
        guard first == value else { return false }
        removeFirst()
        return true
    }
}

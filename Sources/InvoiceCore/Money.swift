import Foundation

public enum MoneyError: Error, LocalizedError {
    case invalidAmount(String)

    public var errorDescription: String? {
        switch self {
        case .invalidAmount(let value):
            return "Invalid amount: \(value)"
        }
    }
}

public struct Money: Codable, Hashable, Sendable {
    public var minorUnits: Int64
    public var currencyCode: String

    public init(minorUnits: Int64, currencyCode: String = "USD") {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    public static func parse(_ value: String, currencyCode: String = "USD") throws -> Money {
        Money(minorUnits: try parseMinorUnits(value), currencyCode: currencyCode)
    }

    public var formatted: String {
        Money.format(minorUnits: minorUnits, currencyCode: currencyCode)
    }

    public static func parseMinorUnits(_ rawValue: String) throws -> Int64 {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard !trimmed.isEmpty else {
            throw MoneyError.invalidAmount(rawValue)
        }

        let isNegative = trimmed.hasPrefix("-")
        let unsigned = isNegative ? String(trimmed.dropFirst()) : trimmed
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count <= 2,
              !parts[0].isEmpty,
              parts[0].allSatisfy(Self.isASCIIDigit),
              let major = UInt64(parts[0])
        else {
            throw MoneyError.invalidAmount(rawValue)
        }

        var cents: UInt64 = 0
        if parts.count == 2 {
            let fraction = String(parts[1])
            guard fraction.count <= 2,
                  fraction.allSatisfy(Self.isASCIIDigit)
            else {
                throw MoneyError.invalidAmount(rawValue)
            }

            let padded = fraction.padding(toLength: 2, withPad: "0", startingAt: 0)
            cents = UInt64(padded) ?? 0
        }

        let product = major.multipliedReportingOverflow(by: 100)
        let sum = product.partialValue.addingReportingOverflow(cents)
        guard !product.overflow, !sum.overflow else {
            throw MoneyError.invalidAmount(rawValue)
        }

        let magnitude = sum.partialValue
        if isNegative {
            let minimumMagnitude = UInt64(Int64.max) + 1
            guard magnitude <= minimumMagnitude else { throw MoneyError.invalidAmount(rawValue) }
            return magnitude == minimumMagnitude ? .min : -Int64(magnitude)
        }
        guard magnitude <= UInt64(Int64.max) else { throw MoneyError.invalidAmount(rawValue) }
        return Int64(magnitude)
    }

    public static func format(minorUnits: Int64, currencyCode: String) -> String {
        let sign = minorUnits < 0 ? "-" : ""
        let absolute = minorUnits.magnitude
        let major = absolute / 100
        let cents = absolute % 100
        let centsText = cents < 10 ? "0\(cents)" : "\(cents)"
        return "\(currencyCode) \(sign)\(major).\(centsText)"
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        character.unicodeScalars.count == 1 && character.unicodeScalars.allSatisfy { scalar in
            scalar.value >= UnicodeScalar("0").value && scalar.value <= UnicodeScalar("9").value
        }
    }
}

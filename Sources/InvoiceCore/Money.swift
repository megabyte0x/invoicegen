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
              let major = Int64(parts[0]),
              major >= 0
        else {
            throw MoneyError.invalidAmount(rawValue)
        }

        var cents: Int64 = 0
        if parts.count == 2 {
            let fraction = String(parts[1])
            guard fraction.count <= 2,
                  fraction.allSatisfy({ $0.isNumber })
            else {
                throw MoneyError.invalidAmount(rawValue)
            }

            let padded = fraction.padding(toLength: 2, withPad: "0", startingAt: 0)
            cents = Int64(padded) ?? 0
        }

        let result = major * 100 + cents
        return isNegative ? -result : result
    }

    public static func format(minorUnits: Int64, currencyCode: String) -> String {
        let sign = minorUnits < 0 ? "-" : ""
        let absolute = abs(minorUnits)
        let major = absolute / 100
        let cents = absolute % 100
        return "\(currencyCode) \(sign)\(major).\(String(format: "%02d", cents))"
    }
}

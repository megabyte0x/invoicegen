import Foundation
import SwiftUI
import InvoiceCore

extension Binding where Value == Int64 {
    func moneyString(currencyCode: String) -> Binding<String> {
        Binding<String>(
            get: { MoneyTextFieldFormatter.string(from: wrappedValue) },
            set: { newValue in
                if let parsed = MoneyTextFieldFormatter.minorUnits(from: newValue) {
                    wrappedValue = parsed
                }
            }
        )
    }
}

enum MoneyTextFieldFormatter {
    static func string(from minorUnits: Int64) -> String {
        let absolute = abs(minorUnits)
        let sign = minorUnits < 0 ? "-" : ""
        return "\(sign)\(absolute / 100).\(String(format: "%02d", absolute % 100))"
    }

    static func minorUnits(from value: String) -> Int64? {
        try? Money.parseMinorUnits(value)
    }
}

import Foundation

public enum InvoiceAmountPolicy {
    public static let maximumQuantity: Double = 1_000_000
    public static let maximumMoneyMinorUnits: Int64 = 100_000_000_000

    public static func lineAmountsAreCalculable(_ item: InvoiceLineItem) -> Bool {
        item.quantity > 0
            && item.quantity <= maximumQuantity
            && item.quantity.isFinite
            && item.unitPriceMinorUnits >= 0
            && item.unitPriceMinorUnits <= maximumMoneyMinorUnits
            && item.taxRatePercent >= 0
            && item.taxRatePercent <= 100
            && item.taxRatePercent.isFinite
            && item.calculatedTotalMinorUnits != nil
    }
}

public enum MinorUnitArithmetic {
    public static func roundedProduct(_ minorUnits: Int64, by multiplier: Double) -> Int64? {
        let rounded = (Double(minorUnits) * multiplier).rounded()
        let int64Minimum = -9_223_372_036_854_775_808.0
        let int64MaximumPlusOne = 9_223_372_036_854_775_808.0
        guard rounded.isFinite,
              rounded >= int64Minimum,
              rounded < int64MaximumPlusOne else { return nil }
        return Int64(rounded)
    }

    public static func sum<S: Sequence>(_ values: S) -> Int64? where S.Element == Int64 {
        var total: Int64 = 0
        for value in values {
            let result = total.addingReportingOverflow(value)
            guard !result.overflow else { return nil }
            total = result.partialValue
        }
        return total
    }

    public static func adding(_ lhs: Int64, _ rhs: Int64) -> Int64? {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? nil : result.partialValue
    }

    public static func subtracting(_ rhs: Int64, from lhs: Int64) -> Int64? {
        let result = lhs.subtractingReportingOverflow(rhs)
        return result.overflow ? nil : result.partialValue
    }

}

import Foundation
import InvoiceCore

enum InvoiceAutoGenerationIntervalInput {
    static func intervalDays(from text: String) -> Int? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmedText), value > 0 else { return nil }
        return InvoiceAutoGenerationSettings.normalizedIntervalDays(value)
    }

    static func text(for intervalDays: Int) -> String {
        String(InvoiceAutoGenerationSettings.normalizedIntervalDays(intervalDays))
    }
}

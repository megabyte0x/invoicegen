import Foundation
import InvoiceCore

enum InvoiceAutoGenerationIntervalInput {
    static func intervalSeconds(from text: String) -> Int? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmedText), value > 0 else { return nil }
        return InvoiceAutoGenerationSettings.normalizedIntervalSeconds(value)
    }

    static func text(for intervalSeconds: Int) -> String {
        String(InvoiceAutoGenerationSettings.normalizedIntervalSeconds(intervalSeconds))
    }
}

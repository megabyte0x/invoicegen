import Foundation
import InvoiceCore

struct InvoiceMailDraft: Equatable {
    var recipients: [String]
    var subject: String
    var body: String

    var isMissingRecipient: Bool {
        recipients.isEmpty
    }

    init(invoice: Invoice, book: InvoiceBook) {
        let client = book.client(for: invoice)
        let businessName = Self.normalized(book.businessProfile.name, fallback: "Local Invoice")
        let clientName = Self.normalized(client?.name, fallback: "there")
        let clientEmail = client?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        self.recipients = clientEmail.isEmpty ? [] : [clientEmail]
        self.subject = "Invoice \(invoice.number) from \(businessName)"
        self.body = """
        Hi \(clientName),

        Please find invoice \(invoice.number) attached.

        Balance due: \(Money.format(minorUnits: invoice.balanceDueMinorUnits, currencyCode: invoice.currencyCode))
        Due date: \(DateFormatting.short.string(from: invoice.dueDate))

        Thanks,
        \(businessName)
        """
    }

    private static func normalized(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}

import Foundation

public enum InvoiceTextRenderer {
    public static func render(invoice: Invoice, book: InvoiceBook) -> String {
        let client = book.client(for: invoice)
        let project = book.project(for: invoice)
        let business = book.businessProfile

        var lines: [String] = []
        lines.append("INVOICE \(invoice.number)")
        lines.append(String(repeating: "=", count: 72))
        lines.append("")
        lines.append("From: \(business.name)")
        if !business.email.isEmpty { lines.append("Email: \(business.email)") }
        if !business.address.isEmpty { lines.append(business.address) }
        if !business.taxIdentifier.isEmpty { lines.append("Tax ID: \(business.taxIdentifier)") }
        lines.append("")

        lines.append("Bill To: \(client?.name ?? "Unassigned client")")
        if let company = client?.company, !company.isEmpty { lines.append(company) }
        if let email = client?.email, !email.isEmpty { lines.append(email) }
        if let address = client?.address, !address.isEmpty { lines.append(address) }
        if let project, !project.name.isEmpty { lines.append("Project: \(project.name)") }
        lines.append("")

        lines.append("Issue Date: \(DateFormatting.short.string(from: invoice.issueDate))")
        lines.append("Due Date:   \(DateFormatting.short.string(from: invoice.dueDate))")
        lines.append("Status:     \(invoice.status.label)")
        lines.append("")

        lines.append("Items")
        lines.append(String(repeating: "-", count: 72))
        for item in invoice.lineItems {
            let price = Money.format(minorUnits: item.unitPriceMinorUnits, currencyCode: invoice.currencyCode)
            let total = Money.format(minorUnits: item.totalMinorUnits, currencyCode: invoice.currencyCode)
            lines.append("\(item.title)")
            if !item.details.isEmpty {
                lines.append("  \(item.details)")
            }
            lines.append("  Qty \(trimmedQuantity(item.quantity)) x \(price)  Tax \(trimmedQuantity(item.taxRatePercent))%  \(total)")
        }

        lines.append(String(repeating: "-", count: 72))
        lines.append("Subtotal: \(Money.format(minorUnits: invoice.subtotalMinorUnits, currencyCode: invoice.currencyCode))")
        lines.append("Tax:      \(Money.format(minorUnits: invoice.taxMinorUnits, currencyCode: invoice.currencyCode))")
        lines.append("Paid:     \(Money.format(minorUnits: invoice.paidMinorUnits, currencyCode: invoice.currencyCode))")
        lines.append("Balance:  \(Money.format(minorUnits: invoice.balanceDueMinorUnits, currencyCode: invoice.currencyCode))")
        lines.append("")

        if !invoice.notes.isEmpty {
            lines.append("Notes")
            lines.append(invoice.notes)
            lines.append("")
        }

        if !invoice.terms.isEmpty {
            lines.append("Terms")
            lines.append(invoice.terms)
            lines.append("")
        }

        let paymentAcceptanceDetails = book.paymentAcceptanceDetails(for: invoice)
        if !paymentAcceptanceDetails.isEmpty {
            lines.append("Payment Acceptance")
            for detail in paymentAcceptanceDetails {
                lines.append("\(detail.kind.label): \(detail.label)")
                let detailLines = detail.details
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                for detailLine in detailLines {
                    lines.append("  \(detailLine)")
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func trimmedQuantity(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}

public enum DateFormatting {
    public static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

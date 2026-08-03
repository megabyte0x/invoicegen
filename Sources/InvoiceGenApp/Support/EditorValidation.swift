import Foundation
import InvoiceCore

enum EditorField: Hashable {
    case invoiceNumber
    case invoiceDueDate
    case invoiceCurrency
    case automaticGenerationInterval
    case lineItemTitle(UUID)
    case lineItemQuantity(UUID)
    case lineItemUnitPrice(UUID)
    case lineItemTaxRate(UUID)
    case clientName
    case projectName
    case projectHourlyRate
    case businessCurrency
    case paymentTermsDays
    case paymentDetailLabel(UUID)
}

struct EditorIssue: Identifiable, Equatable {
    var id: EditorField { field }
    var field: EditorField
    var message: String
}

struct EditorCommitError: LocalizedError, Equatable {
    var issues: [EditorIssue]

    var errorDescription: String? {
        issues.map(\.message).joined(separator: "\n")
    }
}

enum EditorValidator {
    static func invoiceIssues(for invoice: Invoice, in book: InvoiceBook) -> [EditorIssue] {
        var issues: [EditorIssue] = []
        let trimmedNumber = invoice.number.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedNumber.isEmpty {
            issues.append(EditorIssue(
                field: .invoiceNumber,
                message: "Invoice number is required."
            ))
        } else if book.invoices.contains(where: {
            $0.id != invoice.id &&
                $0.number.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(trimmedNumber) == .orderedSame
        }) {
            issues.append(EditorIssue(
                field: .invoiceNumber,
                message: "Invoice number must be unique."
            ))
        }

        if invoice.dueDate < invoice.issueDate {
            issues.append(EditorIssue(
                field: .invoiceDueDate,
                message: "Due date cannot be before the issue date."
            ))
        }

        if !isValidCurrencyCode(invoice.currencyCode) {
            issues.append(EditorIssue(
                field: .invoiceCurrency,
                message: "Invoice currency must be a three-letter uppercase code."
            ))
        }

        if invoice.autoGeneration.isEnabled,
           !(1...InvoiceAutoGenerationSettings.maximumIntervalDays).contains(invoice.autoGeneration.intervalDays) {
            issues.append(EditorIssue(
                field: .automaticGenerationInterval,
                message: "Automatic generation interval must be between 1 and 3650 days."
            ))
        }

        for item in invoice.lineItems {
            if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(EditorIssue(
                    field: .lineItemTitle(item.id),
                    message: "Line item title is required."
                ))
            }
            if item.quantity <= 0 || !item.quantity.isFinite || item.quantity > InvoiceAmountPolicy.maximumQuantity {
                issues.append(EditorIssue(
                    field: .lineItemQuantity(item.id),
                    message: "Line item quantity must be greater than zero and no more than 1,000,000."
                ))
            }
            if item.unitPriceMinorUnits < 0 || item.unitPriceMinorUnits > InvoiceAmountPolicy.maximumMoneyMinorUnits {
                issues.append(EditorIssue(
                    field: .lineItemUnitPrice(item.id),
                    message: "Line item unit price must be between 0.00 and 1,000,000,000.00."
                ))
            }
            if item.taxRatePercent < 0 || item.taxRatePercent > 100 || !item.taxRatePercent.isFinite {
                issues.append(EditorIssue(
                    field: .lineItemTaxRate(item.id),
                    message: "Line item tax rate must be between 0 and 100."
                ))
            }
            if item.quantity > 0,
               item.quantity <= InvoiceAmountPolicy.maximumQuantity,
               item.unitPriceMinorUnits >= 0,
               item.unitPriceMinorUnits <= InvoiceAmountPolicy.maximumMoneyMinorUnits,
               item.taxRatePercent >= 0,
               item.taxRatePercent <= 100,
               item.taxRatePercent.isFinite,
               item.calculatedTotalMinorUnits == nil {
                issues.append(EditorIssue(
                    field: .lineItemQuantity(item.id),
                    message: "Quantity and unit price produce a line amount that is too large to calculate."
                ))
            }
        }

        for payment in invoice.payments where payment.amountMinorUnits <= 0 {
            issues.append(EditorIssue(
                field: .invoiceNumber,
                message: "Payment amount must be greater than zero."
            ))
        }

        let hasInvalidLineAmount = invoice.lineItems.contains { item in
            item.quantity <= 0 ||
                item.quantity > InvoiceAmountPolicy.maximumQuantity ||
                !item.quantity.isFinite ||
                item.unitPriceMinorUnits < 0 ||
                item.unitPriceMinorUnits > InvoiceAmountPolicy.maximumMoneyMinorUnits ||
                item.taxRatePercent < 0 ||
                item.taxRatePercent > 100 ||
                !item.taxRatePercent.isFinite ||
                item.calculatedTotalMinorUnits == nil
        }

        if !hasInvalidLineAmount,
           (invoice.calculatedTotalMinorUnits == nil || invoice.calculatedPaidMinorUnits == nil) {
            issues.append(EditorIssue(
                field: .invoiceNumber,
                message: "Invoice totals are too large to calculate. Reduce one or more line-item amounts."
            ))
        } else if !hasInvalidLineAmount, invoice.paidMinorUnits > invoice.totalMinorUnits {
            issues.append(EditorIssue(
                field: .invoiceNumber,
                message: "Recorded payments cannot exceed the invoice total."
            ))
        }

        return issues
    }

    static func clientIssues(for client: Client) -> [EditorIssue] {
        guard !client.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [EditorIssue(field: .clientName, message: "Client name is required.")]
        }
        return []
    }

    static func projectIssues(for project: Project) -> [EditorIssue] {
        var issues: [EditorIssue] = []

        if project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(EditorIssue(field: .projectName, message: "Project name is required."))
        }
        if project.hourlyRateMinorUnits < 0 || project.hourlyRateMinorUnits > InvoiceAmountPolicy.maximumMoneyMinorUnits {
            issues.append(EditorIssue(
                field: .projectHourlyRate,
                message: "Project hourly rate must be between 0.00 and 1,000,000,000.00."
            ))
        }

        return issues
    }

    static func settingsIssues(for settings: WorkspaceSettingsDraft) -> [EditorIssue] {
        var issues: [EditorIssue] = []

        if !isValidCurrencyCode(settings.businessProfile.currencyCode) {
            issues.append(EditorIssue(
                field: .businessCurrency,
                message: "Business currency must be a three-letter uppercase code."
            ))
        }
        if !(0...120).contains(settings.businessProfile.paymentTermsDays) {
            issues.append(EditorIssue(
                field: .paymentTermsDays,
                message: "Payment terms must be between 0 and 120 days."
            ))
        }
        for detail in settings.paymentAcceptanceDetails where detail.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(EditorIssue(
                field: .paymentDetailLabel(detail.id),
                message: "Payment detail label is required."
            ))
        }

        return issues
    }

    private static func isValidCurrencyCode(_ value: String) -> Bool {
        let scalars = value.unicodeScalars
        return scalars.count == 3 && scalars.allSatisfy { scalar in
            scalar.value >= UnicodeScalar("A").value && scalar.value <= UnicodeScalar("Z").value
        }
    }
}

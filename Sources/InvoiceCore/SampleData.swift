import Foundation

public extension InvoiceBook {
    static func sample(now: Date = Date()) -> InvoiceBook {
        let clientA = Client(
            name: "Northstar Studio",
            company: "Northstar Studio LLC",
            email: "accounts@northstar.example",
            address: "12 Market Street\nSan Francisco, CA",
            notes: "Prefers monthly billing with itemized project notes."
        )

        let clientB = Client(
            name: "Avery Patel",
            company: "Patel Works",
            email: "avery@patel.example",
            address: "88 Lake Road\nAustin, TX",
            notes: "Pays by bank transfer."
        )

        let project = Project(
            clientId: clientA.id,
            name: "Brand refresh",
            summary: "Identity system, landing page direction, and launch assets.",
            hourlyRateMinorUnits: 12500,
            currencyCode: "USD"
        )

        let bankDetails = PaymentAcceptanceDetail(
            kind: .bankDetails,
            label: "Primary business account",
            details: "Bank: Example Federal Bank\nAccount: 123456789\nRouting: 987654321"
        )
        let cryptoDetails = PaymentAcceptanceDetail(
            kind: .cryptocurrency,
            label: "USDC wallet",
            details: "USDC on Base: 0x1234abcd5678ef901234abcd5678ef901234abcd"
        )

        let invoice1 = Invoice(
            number: "INV-\(Calendar(identifier: .gregorian).component(.year, from: now))-0001",
            clientId: clientA.id,
            projectId: project.id,
            issueDate: now,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now,
            status: .sent,
            currencyCode: "USD",
            lineItems: [
                InvoiceLineItem(title: "Discovery workshop", details: "Stakeholder interviews and synthesis", quantity: 1, unitPriceMinorUnits: 150000),
                InvoiceLineItem(title: "Design direction", details: "Visual territory and component starter kit", quantity: 1, unitPriceMinorUnits: 280000)
            ],
            notes: "Thank you for the continued partnership.",
            terms: "Net 14.",
            acceptedPaymentDetailIDs: [bankDetails.id, cryptoDetails.id]
        )

        let invoice2 = Invoice(
            number: "INV-\(Calendar(identifier: .gregorian).component(.year, from: now))-0002",
            clientId: clientB.id,
            issueDate: Calendar.current.date(byAdding: .day, value: -18, to: now) ?? now,
            dueDate: Calendar.current.date(byAdding: .day, value: -4, to: now) ?? now,
            status: .sent,
            currencyCode: "USD",
            lineItems: [
                InvoiceLineItem(title: "Retainer", details: "June advisory retainer", quantity: 1, unitPriceMinorUnits: 220000)
            ],
            terms: "Net 14.",
            acceptedPaymentDetailIDs: [bankDetails.id]
        )

        var book = InvoiceBook(
            businessProfile: BusinessProfile(
                name: "InvoiceGen Creative",
                email: "hello@invoicegen.local",
                address: "Local-only business profile",
                taxIdentifier: "TAX-LOCAL",
                currencyCode: "USD",
                paymentTermsDays: 14
            ),
            clients: [clientA, clientB],
            projects: [project],
            paymentAcceptanceDetails: [bankDetails, cryptoDetails],
            invoices: [invoice1, invoice2]
        )
        book.refreshInvoiceStatuses(now: now)
        return book
    }
}

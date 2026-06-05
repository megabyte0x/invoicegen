import XCTest
@testable import InvoiceGenApp
@testable import InvoiceCore

final class InvoiceMailDraftTests: XCTestCase {
    func testBuildsDraftWithClientRecipientSubjectAndBody() {
        let clientID = UUID()
        let dueDate = date(year: 2026, month: 6, day: 30)
        let invoice = Invoice(
            number: "INV-2026-0007",
            clientId: clientID,
            dueDate: dueDate,
            currencyCode: "USD",
            lineItems: [
                InvoiceLineItem(title: "Implementation", quantity: 2, unitPriceMinorUnits: 25_000)
            ]
        )
        let book = InvoiceBook(
            businessProfile: BusinessProfile(name: "Studio Atlas"),
            clients: [
                Client(id: clientID, name: "Avery Patel", email: "  billing@example.com  ")
            ],
            invoices: [invoice]
        )

        let draft = InvoiceMailDraft(invoice: invoice, book: book)

        XCTAssertEqual(draft.recipients, ["billing@example.com"])
        XCTAssertEqual(draft.subject, "Invoice INV-2026-0007 from Studio Atlas")
        XCTAssertTrue(draft.body.contains("Hi Avery Patel,"))
        XCTAssertTrue(draft.body.contains("Please find invoice INV-2026-0007 attached."))
        XCTAssertTrue(draft.body.contains("Balance due: USD 500.00"))
        XCTAssertTrue(draft.body.contains("Due date: \(DateFormatting.short.string(from: dueDate))"))
        XCTAssertTrue(draft.body.contains("Studio Atlas"))
        XCTAssertFalse(draft.isMissingRecipient)
    }

    func testBuildsDraftWithoutRecipientWhenClientEmailIsMissing() {
        let clientID = UUID()
        let invoice = Invoice(
            number: "INV-2026-0008",
            clientId: clientID,
            dueDate: date(year: 2026, month: 7, day: 15),
            lineItems: [
                InvoiceLineItem(title: "Consulting", quantity: 1, unitPriceMinorUnits: 10_000)
            ]
        )
        let book = InvoiceBook(
            businessProfile: BusinessProfile(name: "Studio Atlas"),
            clients: [
                Client(id: clientID, name: "No Email Client", email: " ")
            ],
            invoices: [invoice]
        )

        let draft = InvoiceMailDraft(invoice: invoice, book: book)

        XCTAssertEqual(draft.recipients, [])
        XCTAssertTrue(draft.isMissingRecipient)
        XCTAssertTrue(draft.body.contains("Hi No Email Client,"))
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        ).date!
    }
}

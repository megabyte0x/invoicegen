import XCTest
@testable import InvoiceGenApp
@testable import InvoiceCore

final class InvoiceMailtoURLTests: XCTestCase {
    func testBuildsMailtoURLWithRecipientSubjectAndBody() throws {
        let clientID = UUID()
        let invoice = Invoice(
            number: "INV-2026-0011",
            clientId: clientID,
            dueDate: Date(timeIntervalSince1970: 1_780_000_000),
            lineItems: [
                InvoiceLineItem(title: "Implementation", quantity: 1, unitPriceMinorUnits: 15_000)
            ]
        )
        let book = InvoiceBook(
            businessProfile: BusinessProfile(name: "Studio Atlas"),
            clients: [
                Client(id: clientID, name: "Avery", email: "billing@example.com")
            ],
            invoices: [invoice]
        )
        let draft = InvoiceMailDraft(invoice: invoice, book: book)

        let url = InvoiceMailtoURL.url(for: draft)
        let components = URLComponents(url: try XCTUnwrap(url), resolvingAgainstBaseURL: false)

        XCTAssertEqual(components?.scheme, "mailto")
        XCTAssertEqual(components?.path, "billing@example.com")
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "subject" })?.value, draft.subject)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "body" })?.value, draft.body)
    }

    func testBuildsMailtoURLWithoutRecipient() throws {
        let draft = InvoiceMailDraft(
            invoice: Invoice(
                number: "INV-2026-0012",
                dueDate: Date(timeIntervalSince1970: 1_780_000_000)
            ),
            book: InvoiceBook()
        )

        let url = try XCTUnwrap(InvoiceMailtoURL.url(for: draft))

        XCTAssertTrue(url.absoluteString.hasPrefix("mailto:?"))
        XCTAssertTrue(url.absoluteString.contains("subject="))
    }
}

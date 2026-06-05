import XCTest
@testable import InvoiceCore
@testable import InvoiceGenApp

final class InvoiceSummaryRowContentTests: XCTestCase {
    func testInvoiceSummaryRowContentSeparatesPrimaryAndMetadataText() {
        let invoice = Invoice(
            number: "INV-2026-0002",
            dueDate: Date(timeIntervalSince1970: 0),
            status: .draft,
            currencyCode: "USD",
            lineItems: [
                InvoiceLineItem(title: "Work", unitPriceMinorUnits: 200)
            ]
        )

        let content = InvoiceSummaryRowContent(invoice: invoice, clientName: "EigenCloud")

        XCTAssertEqual(content.invoiceNumber, "INV-2026-0002")
        XCTAssertEqual(content.statusLabel, "Draft")
        XCTAssertEqual(content.amountText, "2.00")
        XCTAssertEqual(content.clientName, "EigenCloud")
        XCTAssertGreaterThanOrEqual(content.minimumHeight, 58)
    }
}

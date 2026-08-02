import XCTest
import InvoiceCore
@testable import InvoiceGenApp

final class EditorValidationTests: XCTestCase {
    func testLineItemIssuesAreFieldLocalAndSuppressDerivativePaymentError() {
        let item = InvoiceLineItem(
            title: "",
            quantity: 0,
            unitPriceMinorUnits: -500,
            taxRatePercent: 0
        )
        let invoice = Invoice(
            number: "INV-VALIDATION",
            dueDate: Date(),
            lineItems: [item],
            payments: [Payment(amountMinorUnits: 100)]
        )

        let issues = EditorValidator.invoiceIssues(
            for: invoice,
            in: InvoiceBook(invoices: [invoice])
        )

        XCTAssertTrue(issues.contains { $0.field == .lineItemTitle(item.id) })
        XCTAssertTrue(issues.contains { $0.field == .lineItemQuantity(item.id) })
        XCTAssertTrue(issues.contains { $0.field == .lineItemUnitPrice(item.id) })
        XCTAssertFalse(issues.contains { $0.message.contains("payments") })
    }
}

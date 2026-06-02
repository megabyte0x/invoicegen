import XCTest
@testable import InvoiceCore

final class InvoiceCoreTests: XCTestCase {
    func testMoneyParsingAndFormatting() throws {
        XCTAssertEqual(try Money.parseMinorUnits("1,234.50"), 123450)
        XCTAssertEqual(Money.format(minorUnits: 123450, currencyCode: "USD"), "USD 1234.50")
        XCTAssertThrowsError(try Money.parseMinorUnits("12.345"))
    }

    func testInvoiceTotalsAndPaidStatus() {
        var invoice = Invoice(
            number: "INV-2026-0001",
            dueDate: Date(),
            lineItems: [
                InvoiceLineItem(title: "Work", quantity: 2, unitPriceMinorUnits: 10000, taxRatePercent: 10)
            ]
        )

        XCTAssertEqual(invoice.subtotalMinorUnits, 20000)
        XCTAssertEqual(invoice.taxMinorUnits, 2000)
        XCTAssertEqual(invoice.totalMinorUnits, 22000)

        invoice.payments.append(Payment(amountMinorUnits: 22000))
        invoice.refreshStatus()
        XCTAssertEqual(invoice.status, .paid)
        XCTAssertEqual(invoice.balanceDueMinorUnits, 0)
    }

    func testLocalStoreRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("store.json")
        let store = LocalInvoiceStore(url: url)
        let book = InvoiceBook.sample()

        try store.save(book)
        let loaded = try store.load()

        XCTAssertEqual(loaded.clients.count, 2)
        XCTAssertEqual(loaded.projects.count, 1)
        XCTAssertEqual(loaded.invoices.count, 2)
    }

    func testAppStoreOverrides() {
        let appURL = LocalInvoiceStore.defaultStoreURL(
            environment: ["INVOICEGEN_APP_STORE": "/tmp/invoicegen-app.json"]
        )

        XCTAssertEqual(appURL.path, "/tmp/invoicegen-app.json")
    }
}

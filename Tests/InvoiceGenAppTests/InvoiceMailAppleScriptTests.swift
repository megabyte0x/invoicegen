import XCTest
@testable import InvoiceGenApp
@testable import InvoiceCore

final class InvoiceMailAppleScriptTests: XCTestCase {
    func testBuildsMailScriptWithRecipientAndAttachment() {
        let clientID = UUID()
        let invoice = Invoice(
            number: "INV-2026-0009",
            clientId: clientID,
            dueDate: Date(timeIntervalSince1970: 1_780_000_000),
            lineItems: [
                InvoiceLineItem(title: "Consulting", quantity: 1, unitPriceMinorUnits: 10_000)
            ]
        )
        let book = InvoiceBook(
            businessProfile: BusinessProfile(name: "Studio \"Atlas\""),
            clients: [
                Client(id: clientID, name: "Avery", email: "billing@example.com")
            ],
            invoices: [invoice]
        )
        let draft = InvoiceMailDraft(invoice: invoice, book: book)
        let attachmentURL = URL(fileURLWithPath: "/private/tmp/InvoiceGen Mail/INV-2026-0009.pdf")

        let source = InvoiceMailAppleScript.source(draft: draft, attachmentURL: attachmentURL)

        XCTAssertTrue(source.contains("using terms from application \"/System/Applications/Mail.app\""))
        XCTAssertTrue(source.contains("tell application \"/System/Applications/Mail.app\""))
        XCTAssertTrue(source.contains("make new outgoing message"))
        XCTAssertTrue(source.contains("visible:true"))
        XCTAssertTrue(source.contains("make new to recipient at end of to recipients with properties {address:\"billing@example.com\"}"))
        XCTAssertTrue(source.contains("set attachmentFile to POSIX file \"/private/tmp/InvoiceGen Mail/INV-2026-0009.pdf\""))
        XCTAssertTrue(source.contains("make new attachment with properties {file name:attachmentFile} at after the last paragraph"))
        XCTAssertTrue(source.contains("Invoice INV-2026-0009 from Studio \\\"Atlas\\\""))
        XCTAssertNotNil(NSAppleScript(source: source))
    }

    func testBuildsMailScriptWithoutRecipientWhenEmailIsMissing() {
        let invoice = Invoice(
            number: "INV-2026-0010",
            dueDate: Date(timeIntervalSince1970: 1_780_000_000),
            lineItems: [
                InvoiceLineItem(title: "Consulting", quantity: 1, unitPriceMinorUnits: 10_000)
            ]
        )
        let draft = InvoiceMailDraft(invoice: invoice, book: InvoiceBook())
        let source = InvoiceMailAppleScript.source(
            draft: draft,
            attachmentURL: URL(fileURLWithPath: "/private/tmp/INV-2026-0010.pdf")
        )

        XCTAssertFalse(source.contains("make new to recipient"))
        XCTAssertTrue(source.contains("make new attachment"))
    }
}

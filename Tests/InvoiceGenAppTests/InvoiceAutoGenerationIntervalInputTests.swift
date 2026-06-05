import XCTest
@testable import InvoiceGenApp

final class InvoiceAutoGenerationIntervalInputTests: XCTestCase {
    func testIntervalInputIgnoresIncompleteTextWhileEditing() {
        XCTAssertNil(InvoiceAutoGenerationIntervalInput.intervalSeconds(from: ""))
        XCTAssertNil(InvoiceAutoGenerationIntervalInput.intervalSeconds(from: "   "))
        XCTAssertNil(InvoiceAutoGenerationIntervalInput.intervalSeconds(from: "0"))
    }

    func testIntervalInputParsesAndNormalizesCompletedText() {
        XCTAssertEqual(InvoiceAutoGenerationIntervalInput.intervalSeconds(from: "30"), 30)
        XCTAssertEqual(InvoiceAutoGenerationIntervalInput.intervalSeconds(from: "4000"), 4_000)
        XCTAssertEqual(InvoiceAutoGenerationIntervalInput.intervalSeconds(from: "400000000"), 315_360_000)
    }
}

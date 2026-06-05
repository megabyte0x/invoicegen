import XCTest
@testable import InvoiceGenApp

final class InvoiceAutoGenerationIntervalInputTests: XCTestCase {
    func testIntervalInputIgnoresIncompleteTextWhileEditing() {
        XCTAssertNil(InvoiceAutoGenerationIntervalInput.intervalDays(from: ""))
        XCTAssertNil(InvoiceAutoGenerationIntervalInput.intervalDays(from: "   "))
        XCTAssertNil(InvoiceAutoGenerationIntervalInput.intervalDays(from: "0"))
    }

    func testIntervalInputParsesAndNormalizesCompletedText() {
        XCTAssertEqual(InvoiceAutoGenerationIntervalInput.intervalDays(from: "30"), 30)
        XCTAssertEqual(InvoiceAutoGenerationIntervalInput.intervalDays(from: "4000"), 3_650)
        XCTAssertEqual(InvoiceAutoGenerationIntervalInput.intervalDays(from: "400000000"), 3_650)
    }
}

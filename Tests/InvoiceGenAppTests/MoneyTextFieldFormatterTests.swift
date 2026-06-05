import XCTest
@testable import InvoiceGenApp

final class MoneyTextFieldFormatterTests: XCTestCase {
    func testMoneyInputKeepsIncompleteDraftTextWhileEditing() {
        XCTAssertEqual(MoneyTextFieldFormatter.text(draft: "", minorUnits: 12_345), "")
        XCTAssertEqual(MoneyTextFieldFormatter.text(draft: "1", minorUnits: 12_345), "1")
    }

    func testMoneyInputFallsBackToFormattedModelValueWithoutDraft() {
        XCTAssertEqual(MoneyTextFieldFormatter.text(draft: nil, minorUnits: 12_345), "123.45")
    }

    func testMoneyInputParsesCompletedTextOnly() {
        XCTAssertNil(MoneyTextFieldFormatter.minorUnits(from: ""))
        XCTAssertEqual(MoneyTextFieldFormatter.minorUnits(from: "123.45"), 12_345)
    }

    func testMoneyInputParsesWholeDollarTextAsMajorUnits() {
        XCTAssertEqual(MoneyTextFieldFormatter.minorUnits(from: "30"), 3_000)
    }
}

final class DecimalTextFieldFormatterTests: XCTestCase {
    func testDecimalInputKeepsIncompleteDraftTextWhileEditing() {
        XCTAssertEqual(DecimalTextFieldFormatter.text(draft: "", value: 2.5), "")
        XCTAssertEqual(DecimalTextFieldFormatter.text(draft: "3.", value: 2.5), "3.")
        XCTAssertEqual(DecimalTextFieldFormatter.text(draft: ".", value: 2.5), ".")
    }

    func testDecimalInputFallsBackToFormattedModelValueWithoutDraft() {
        XCTAssertEqual(DecimalTextFieldFormatter.text(draft: nil, value: 2), "2")
        XCTAssertEqual(DecimalTextFieldFormatter.text(draft: nil, value: 2.5), "2.5")
    }

    func testDecimalInputParsesCompletedFiniteTextOnly() {
        XCTAssertNil(DecimalTextFieldFormatter.value(from: ""))
        XCTAssertNil(DecimalTextFieldFormatter.value(from: "."))
        XCTAssertEqual(DecimalTextFieldFormatter.value(from: "3"), 3)
        XCTAssertEqual(DecimalTextFieldFormatter.value(from: "3.25"), 3.25)
    }
}

final class IntegerTextFieldFormatterTests: XCTestCase {
    func testIntegerInputKeepsIncompleteDraftTextWhileEditing() {
        XCTAssertEqual(IntegerTextFieldFormatter.text(draft: "", value: 14), "")
        XCTAssertEqual(IntegerTextFieldFormatter.text(draft: "-", value: 14), "-")
    }

    func testIntegerInputFallsBackToFormattedModelValueWithoutDraft() {
        XCTAssertEqual(IntegerTextFieldFormatter.text(draft: nil, value: 14), "14")
    }

    func testIntegerInputParsesCompletedTextOnly() {
        XCTAssertNil(IntegerTextFieldFormatter.value(from: ""))
        XCTAssertNil(IntegerTextFieldFormatter.value(from: "-"))
        XCTAssertEqual(IntegerTextFieldFormatter.value(from: "30"), 30)
    }
}

import XCTest
@testable import InvoiceGenApp

final class LocaleNumericParserTests: XCTestCase {
    private let englishLocale = Locale(identifier: "en_US")

    func testCommaDecimalUsesLocaleInsteadOfChangingMagnitude() {
        XCTAssertEqual(
            LocaleNumericParser.moneyMinorUnits(
                from: "12,34",
                locale: Locale(identifier: "de_DE")
            ),
            .valid(1_234)
        )

        guard case .invalid(let message) = LocaleNumericParser.moneyMinorUnits(
            from: "12,34",
            locale: Locale(identifier: "en_IN")
        ) else {
            return XCTFail("Indian/English comma input must not change magnitude.")
        }
        XCTAssertEqual(
            message,
            "Enter a number using . as the decimal separator and no grouping separators."
        )
    }

    func testEmptyMoneyInputIsEmpty() {
        XCTAssertEqual(
            LocaleNumericParser.moneyMinorUnits(from: "", locale: englishLocale),
            .empty
        )
    }

    func testPartialDecimalMoneyInputIsPartial() {
        XCTAssertEqual(
            LocaleNumericParser.moneyMinorUnits(from: "12.", locale: englishLocale),
            .partial
        )
    }

    func testMalformedMoneyInputIsInvalid() {
        XCTAssertEqual(
            LocaleNumericParser.moneyMinorUnits(from: "12..3", locale: englishLocale),
            .invalid(LocaleNumericParser.invalidNumberMessage(locale: englishLocale))
        )
    }

    func testNegativeMoneyInputPreservesSign() {
        XCTAssertEqual(
            LocaleNumericParser.moneyMinorUnits(from: "-12.34", locale: englishLocale),
            .valid(-1_234)
        )
    }

    func testZeroMoneyInputIsValid() {
        XCTAssertEqual(
            LocaleNumericParser.moneyMinorUnits(from: "0", locale: englishLocale),
            .valid(0)
        )
    }

    func testTwoFractionalDigitsAreAccepted() {
        XCTAssertEqual(
            LocaleNumericParser.moneyMinorUnits(from: "12.34", locale: englishLocale),
            .valid(1_234)
        )
    }

    func testMoreThanTwoFractionalDigitsAreRejected() {
        XCTAssertEqual(
            LocaleNumericParser.moneyMinorUnits(from: "12.345", locale: englishLocale),
            .invalid(LocaleNumericParser.moneyPrecisionMessage)
        )
    }

    func testMoneyInputRejectsInt64Overflow() {
        XCTAssertEqual(
            LocaleNumericParser.moneyMinorUnits(
                from: "92233720368547758.08",
                locale: englishLocale
            ),
            .invalid(LocaleNumericParser.invalidNumberMessage(locale: englishLocale))
        )
    }
}

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

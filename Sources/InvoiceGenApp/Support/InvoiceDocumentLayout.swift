import AppKit
import SwiftUI
import InvoiceCore

struct InvoiceDocument: Equatable {
    static let pageSize = CGSize(width: 612, height: 792)
    static let pageInsets = EdgeInsets(top: 36, leading: 36, bottom: 36, trailing: 36)

    var pages: [InvoiceDocumentPage]
}

struct InvoiceDocumentPage: Identifiable, Equatable {
    var id: Int
    var blocks: [InvoiceDocumentBlock]
}

enum InvoiceDocumentBlock: Equatable {
    case identity(InvoiceIdentityFragment)
    case billing(InvoiceBillingFragment)
    case lineItemHeader
    case lineItem(InvoiceLineItemFragment)
    case titledText(InvoiceTitledTextFragment)
    case payment(InvoicePaymentFragment)
    case totals(InvoiceTotalsSnapshot)
    case pageNumber(current: Int, total: Int)

    var measuredHeight: CGFloat {
        switch self {
        case .identity(let fragment):
            max(fragment.businessLines.measuredHeight, fragment.invoiceLines.measuredHeight)
                + (fragment.isLast ? InvoiceDocumentMetrics.identityEndingHeight : InvoiceDocumentMetrics.fragmentSpacing)
        case .billing(let fragment):
            max(fragment.clientLines.measuredHeight, fragment.dateLines.measuredHeight)
                + (fragment.isLast ? InvoiceDocumentMetrics.billingEndingHeight : InvoiceDocumentMetrics.fragmentSpacing)
        case .lineItemHeader:
            InvoiceDocumentMetrics.lineItemHeaderHeight
        case .lineItem(let fragment):
            max(
                max(
                    fragment.descriptionLines.measuredHeight,
                    fragment.taxCodeLines.measuredHeight
                ),
                fragment.showsAmounts ? InvoiceDocumentMetrics.amountLineHeight : 0
            ) + InvoiceDocumentMetrics.lineItemVerticalPadding + InvoiceDocumentMetrics.dividerHeight
        case .titledText(let fragment):
            (fragment.showsTitle ? InvoiceDocumentMetrics.sectionTitleHeight : 0)
                + fragment.lines.measuredHeight
                + (fragment.isLast ? InvoiceDocumentMetrics.sectionEndingHeight : InvoiceDocumentMetrics.fragmentSpacing)
        case .payment(let fragment):
            (fragment.showsSectionTitle ? InvoiceDocumentMetrics.sectionTitleHeight : 0)
                + fragment.lines.measuredHeight
                + (fragment.isLast ? InvoiceDocumentMetrics.paymentEndingHeight : InvoiceDocumentMetrics.fragmentSpacing)
        case .totals(let snapshot):
            snapshot.amountPaid == nil
                ? InvoiceDocumentMetrics.totalsHeight
                : InvoiceDocumentMetrics.totalsWithPaidHeight
        case .pageNumber:
            InvoiceDocumentMetrics.pageNumberHeight
        }
    }
}

struct InvoiceIdentityFragment: Equatable {
    var businessLines: [InvoiceDocumentTextLine]
    var invoiceLines: [InvoiceDocumentTextLine]
    var isLast: Bool
}

struct InvoiceBillingFragment: Equatable {
    var clientLines: [InvoiceDocumentTextLine]
    var dateLines: [InvoiceDocumentTextLine]
    var isLast: Bool
}

struct InvoiceLineItemFragment: Equatable {
    var itemID: UUID
    var descriptionLines: [InvoiceDocumentTextLine]
    var taxCodeLines: [InvoiceDocumentTextLine]
    var quantity: String
    var unitPrice: String
    var tax: String
    var total: String
    var showsAmounts: Bool
}

struct InvoiceTitledTextFragment: Equatable {
    var title: String
    var lines: [InvoiceDocumentTextLine]
    var showsTitle: Bool
    var isLast: Bool
}

struct InvoicePaymentFragment: Equatable {
    var detailID: UUID
    var lines: [InvoiceDocumentTextLine]
    var showsSectionTitle: Bool
    var isLast: Bool
}

struct InvoiceTotalsSnapshot: Equatable {
    var subtotal: String
    var tax: String
    var amountPaid: String?
    var balanceDue: String
}

struct InvoiceDocumentTextLine: Equatable {
    var text: String
    var style: InvoiceDocumentTextStyle
    var spacingBefore: CGFloat = 0

    var measuredHeight: CGFloat {
        spacingBefore + style.lineHeight
    }
}

enum InvoiceDocumentTextStyle: Equatable {
    case businessName
    case invoiceTitle
    case invoiceNumber
    case label
    case bodyStrong
    case body
    case captionStrong
    case caption
    case itemTitle
    case itemDetail
    case itemCode

    var nsFont: NSFont {
        switch self {
        case .businessName:
            .systemFont(ofSize: 20, weight: .bold)
        case .invoiceTitle:
            .systemFont(ofSize: 28, weight: .black)
        case .invoiceNumber:
            .monospacedSystemFont(ofSize: 13, weight: .regular)
        case .label:
            .systemFont(ofSize: 11, weight: .bold)
        case .bodyStrong:
            .systemFont(ofSize: 13, weight: .bold)
        case .body:
            .systemFont(ofSize: 13, weight: .regular)
        case .captionStrong:
            .systemFont(ofSize: 11, weight: .semibold)
        case .caption:
            .systemFont(ofSize: 11, weight: .regular)
        case .itemTitle:
            .systemFont(ofSize: 13, weight: .medium)
        case .itemDetail:
            .systemFont(ofSize: 11, weight: .regular)
        case .itemCode:
            .monospacedSystemFont(ofSize: 11, weight: .regular)
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .businessName:
            24
        case .invoiceTitle:
            34
        case .invoiceNumber:
            17
        case .label, .captionStrong, .caption, .itemDetail, .itemCode:
            14
        case .bodyStrong, .body, .itemTitle:
            17
        }
    }
}

enum InvoiceDocumentMetrics {
    static let bodyWidth: CGFloat = 540
    static let bodyHeight: CGFloat = 720
    static let pageNumberHeight: CGFloat = 22
    static let flowHeight = bodyHeight - pageNumberHeight

    static let identityLeftWidth: CGFloat = 330
    static let identityRightWidth: CGFloat = 190
    static let billingLeftWidth: CGFloat = 320
    static let billingRightWidth: CGFloat = 200

    static let tableHorizontalPadding: CGFloat = 8
    static let tableColumnSpacing: CGFloat = 6
    static let taxCodeWidth: CGFloat = 60
    static let quantityWidth: CGFloat = 42
    static let unitPriceWidth: CGFloat = 82
    static let taxWidth: CGFloat = 42
    static let totalWidth: CGFloat = 90
    static let itemDescriptionWidth = bodyWidth
        - (tableHorizontalPadding * 2)
        - (tableColumnSpacing * 5)
        - taxCodeWidth
        - quantityWidth
        - unitPriceWidth
        - taxWidth
        - totalWidth

    static let dividerHeight: CGFloat = 1
    static let fragmentSpacing: CGFloat = 8
    static let identityEndingHeight: CGFloat = 61
    static let billingEndingHeight: CGFloat = 36
    static let lineItemHeaderHeight: CGFloat = 35
    static let lineItemVerticalPadding: CGFloat = 20
    static let amountLineHeight: CGFloat = 17
    static let sectionTitleHeight: CGFloat = 18
    static let sectionEndingHeight: CGFloat = 12
    static let paymentEndingHeight: CGFloat = 10
    static let totalsHeight: CGFloat = 109
    static let totalsWithPaidHeight: CGFloat = 134
}

@MainActor
enum InvoiceTextWrapper {
    static func lines(for text: String, font: NSFont, width: CGFloat) -> [String] {
        guard !text.isEmpty else { return [] }

        let textStorage = NSTextStorage(
            string: text,
            attributes: [.font: font]
        )
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: max(1, width),
                height: .greatestFiniteMagnitude
            )
        )
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        var result: [String] = []
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, glyphRange, _ in
            let characterRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )
            let line = (textStorage.string as NSString)
                .substring(with: characterRange)
                .trimmingCharacters(in: .newlines)
            result.append(line)
        }

        if text.hasSuffix("\n") {
            result.append("")
        }

        return result.isEmpty ? [text] : result
    }
}

@MainActor
enum InvoiceDocumentPaginator {
    static func paginate(invoice: Invoice, book: InvoiceBook) -> InvoiceDocument {
        var pages = [WorkingPage()]

        appendIdentity(invoice: invoice, book: book, to: &pages)
        appendBilling(invoice: invoice, book: book, to: &pages)

        if invoice.lineItems.isEmpty {
            appendFixed(.lineItemHeader, to: &pages)
        } else {
            for item in invoice.lineItems {
                appendLineItem(item, currencyCode: invoice.currencyCode, to: &pages)
            }
        }

        appendTitledText(title: "Notes", text: invoice.notes, to: &pages)
        appendTitledText(title: "Terms & Conditions", text: invoice.terms, to: &pages)
        appendPayments(book.paymentAcceptanceDetails(for: invoice), to: &pages)
        appendTotals(invoice: invoice, to: &pages)

        if pages.isEmpty {
            pages = [WorkingPage()]
        }

        let total = pages.count
        return InvoiceDocument(
            pages: pages.enumerated().map { index, page in
                var blocks = page.blocks
                blocks.append(.pageNumber(current: index + 1, total: total))
                return InvoiceDocumentPage(id: index + 1, blocks: blocks)
            }
        )
    }

    private static func appendIdentity(
        invoice: Invoice,
        book: InvoiceBook,
        to pages: inout [WorkingPage]
    ) {
        let left = joinedLineGroups([
            wrapped(book.businessProfile.name, style: .businessName, width: InvoiceDocumentMetrics.identityLeftWidth),
            wrapped(book.businessProfile.email, style: .caption, width: InvoiceDocumentMetrics.identityLeftWidth),
            wrapped(book.businessProfile.address, style: .caption, width: InvoiceDocumentMetrics.identityLeftWidth),
            wrapped(
                book.businessProfile.taxIdentifier.isEmpty ? "" : "Tax ID: \(book.businessProfile.taxIdentifier)",
                style: .caption,
                width: InvoiceDocumentMetrics.identityLeftWidth
            )
        ])
        let right = joinedLineGroups([
            wrapped("INVOICE", style: .invoiceTitle, width: InvoiceDocumentMetrics.identityRightWidth),
            wrapped(invoice.number, style: .invoiceNumber, width: InvoiceDocumentMetrics.identityRightWidth)
        ], spacing: 2)

        appendTwoColumnFragments(
            left: left,
            right: right,
            makeBlock: { left, right, isLast in
                .identity(
                    InvoiceIdentityFragment(
                        businessLines: left,
                        invoiceLines: right,
                        isLast: isLast
                    )
                )
            },
            to: &pages
        )
    }

    private static func appendBilling(
        invoice: Invoice,
        book: InvoiceBook,
        to pages: inout [WorkingPage]
    ) {
        let client = book.client(for: invoice)
        let left = joinedLineGroups([
            wrapped("BILL TO", style: .label, width: InvoiceDocumentMetrics.billingLeftWidth),
            wrapped(client?.name ?? "Unassigned Client", style: .bodyStrong, width: InvoiceDocumentMetrics.billingLeftWidth),
            wrapped(client?.company ?? "", style: .body, width: InvoiceDocumentMetrics.billingLeftWidth),
            wrapped(client?.address ?? "", style: .body, width: InvoiceDocumentMetrics.billingLeftWidth),
            wrapped(client?.email ?? "", style: .body, width: InvoiceDocumentMetrics.billingLeftWidth)
        ])
        let right = joinedLineGroups([
            wrapped(
                "Issue Date: \(DateFormatting.short.string(from: invoice.issueDate))",
                style: .body,
                width: InvoiceDocumentMetrics.billingRightWidth
            ),
            wrapped(
                "Due Date: \(DateFormatting.short.string(from: invoice.dueDate))",
                style: .bodyStrong,
                width: InvoiceDocumentMetrics.billingRightWidth
            )
        ], spacing: 6)

        appendTwoColumnFragments(
            left: left,
            right: right,
            makeBlock: { left, right, isLast in
                .billing(
                    InvoiceBillingFragment(
                        clientLines: left,
                        dateLines: right,
                        isLast: isLast
                    )
                )
            },
            to: &pages
        )
    }

    private static func appendTwoColumnFragments(
        left: [InvoiceDocumentTextLine],
        right: [InvoiceDocumentTextLine],
        makeBlock: ([InvoiceDocumentTextLine], [InvoiceDocumentTextLine], Bool) -> InvoiceDocumentBlock,
        to pages: inout [WorkingPage]
    ) {
        var leftIndex = 0
        var rightIndex = 0
        var mustEmit = true

        while leftIndex < left.count || rightIndex < right.count || mustEmit {
            mustEmit = false
            let remainingLeft = Array(left[leftIndex...])
            let remainingRight = Array(right[rightIndex...])
            let finalBlock = makeBlock(remainingLeft, remainingRight, true)

            if finalBlock.measuredHeight <= availableHeight(in: pages) {
                append(finalBlock, to: &pages)
                break
            }

            if finalBlock.measuredHeight <= InvoiceDocumentMetrics.flowHeight {
                startNewPage(in: &pages)
                continue
            }

            let endingHeight = makeBlock([], [], false).measuredHeight
            let lineCapacity = availableHeight(in: pages) - endingHeight
            var leftCount = prefixCount(fitting: remainingLeft, height: lineCapacity)
            var rightCount = prefixCount(fitting: remainingRight, height: lineCapacity)

            if leftCount == remainingLeft.count,
               rightCount == remainingRight.count {
                if leftCount > 0,
                   (rightCount == 0 || remainingLeft.measuredHeight >= remainingRight.measuredHeight) {
                    leftCount -= 1
                } else if rightCount > 0 {
                    rightCount -= 1
                }
            }

            guard leftCount > 0 || rightCount > 0 else {
                startNewPage(in: &pages)
                continue
            }

            let leftFragment = Array(remainingLeft.prefix(leftCount))
            let rightFragment = Array(remainingRight.prefix(rightCount))
            append(makeBlock(leftFragment, rightFragment, false), to: &pages)
            leftIndex += leftCount
            rightIndex += rightCount
        }
    }

    private static func appendLineItem(
        _ item: InvoiceLineItem,
        currencyCode: String,
        to pages: inout [WorkingPage]
    ) {
        var lines = wrapped(
            item.title,
            style: .itemTitle,
            width: InvoiceDocumentMetrics.itemDescriptionWidth
        )
        lines += wrapped(
            item.details,
            style: .itemDetail,
            width: InvoiceDocumentMetrics.itemDescriptionWidth,
            spacingBefore: lines.isEmpty ? 0 : 2
        )
        if lines.isEmpty {
            lines = [InvoiceDocumentTextLine(text: "", style: .itemTitle)]
        }

        let quantity = InvoiceDocumentFormatting.trimmedQuantity(item.quantity)
        let unitPrice = InvoiceDocumentFormatting.amountWithoutCurrency(
            item.unitPriceMinorUnits,
            currencyCode: currencyCode
        )
        let tax = "\(InvoiceDocumentFormatting.trimmedQuantity(item.taxRatePercent))%"
        let total = InvoiceDocumentFormatting.amountWithoutCurrency(
            item.totalMinorUnits,
            currencyCode: currencyCode
        )
        let taxCodeLines = wrapped(
            item.taxCode,
            style: .itemCode,
            width: InvoiceDocumentMetrics.taxCodeWidth
        )
        func fragment(
            descriptionLines: [InvoiceDocumentTextLine],
            taxCodeLines: [InvoiceDocumentTextLine],
            showsAmounts: Bool
        ) -> InvoiceLineItemFragment {
            InvoiceLineItemFragment(
                itemID: item.id,
                descriptionLines: descriptionLines,
                taxCodeLines: taxCodeLines,
                quantity: quantity,
                unitPrice: unitPrice,
                tax: tax,
                total: total,
                showsAmounts: showsAmounts
            )
        }

        var descriptionIndex = 0
        var taxCodeIndex = 0
        var didShowAmounts = false

        while descriptionIndex < lines.count
                || taxCodeIndex < taxCodeLines.count
                || !didShowAmounts {
            let remainingDescriptionLines = Array(lines[descriptionIndex...])
            let remainingTaxCodeLines = Array(taxCodeLines[taxCodeIndex...])
            let finalFragment = fragment(
                descriptionLines: remainingDescriptionLines,
                taxCodeLines: remainingTaxCodeLines,
                showsAmounts: true
            )
            let finalBlock = InvoiceDocumentBlock.lineItem(finalFragment)
            let headerAllowance = currentPage(in: pages).hasLineItemHeader
                ? 0
                : InvoiceDocumentMetrics.lineItemHeaderHeight

            if finalBlock.measuredHeight + headerAllowance <= InvoiceDocumentMetrics.flowHeight,
               finalBlock.measuredHeight + headerAllowance > availableHeight(in: pages) {
                startNewPage(in: &pages)
                continue
            }

            ensureLineItemHeader(to: &pages)

            if finalBlock.measuredHeight <= availableHeight(in: pages) {
                append(finalBlock, to: &pages)
                descriptionIndex = lines.count
                taxCodeIndex = taxCodeLines.count
                didShowAmounts = true
                continue
            }

            let lineCapacity = availableHeight(in: pages)
                - InvoiceDocumentMetrics.lineItemVerticalPadding
                - InvoiceDocumentMetrics.dividerHeight
            var descriptionCount = prefixCount(
                fitting: remainingDescriptionLines,
                height: lineCapacity
            )
            var taxCodeCount = prefixCount(
                fitting: remainingTaxCodeLines,
                height: lineCapacity
            )
            if descriptionCount == remainingDescriptionLines.count,
               taxCodeCount == remainingTaxCodeLines.count {
                if descriptionCount > 0,
                   (taxCodeCount == 0
                    || remainingDescriptionLines.measuredHeight >= remainingTaxCodeLines.measuredHeight) {
                    descriptionCount -= 1
                } else if taxCodeCount > 0 {
                    taxCodeCount -= 1
                }
            }

            guard descriptionCount > 0 || taxCodeCount > 0 else {
                startNewPage(in: &pages)
                continue
            }

            append(
                .lineItem(
                    fragment(
                        descriptionLines: Array(remainingDescriptionLines.prefix(descriptionCount)),
                        taxCodeLines: Array(remainingTaxCodeLines.prefix(taxCodeCount)),
                        showsAmounts: false
                    )
                ),
                to: &pages
            )
            descriptionIndex += descriptionCount
            taxCodeIndex += taxCodeCount
        }
    }

    private static func appendTitledText(
        title: String,
        text: String,
        to pages: inout [WorkingPage]
    ) {
        guard !text.isEmpty else { return }

        let lines = wrapped(
            text,
            style: .caption,
            width: InvoiceDocumentMetrics.bodyWidth
        )
        appendSingleColumnFragments(
            lines: lines,
            makeBlock: { lines, isFirst, isLast in
                .titledText(
                    InvoiceTitledTextFragment(
                        title: title,
                        lines: lines,
                        showsTitle: isFirst,
                        isLast: isLast
                    )
                )
            },
            to: &pages
        )
    }

    private static func appendPayments(
        _ details: [PaymentAcceptanceDetail],
        to pages: inout [WorkingPage]
    ) {
        var isFirstDetail = true
        for detail in details {
            let lines = joinedLineGroups([
                wrapped(
                    "\(detail.kind.label): \(detail.label)",
                    style: .captionStrong,
                    width: InvoiceDocumentMetrics.bodyWidth
                ),
                wrapped(
                    detail.details,
                    style: .caption,
                    width: InvoiceDocumentMetrics.bodyWidth
                )
            ], spacing: 2)

            appendSingleColumnFragments(
                lines: lines.isEmpty
                    ? [InvoiceDocumentTextLine(text: "", style: .caption)]
                    : lines,
                makeBlock: { lines, isFirstFragment, isLast in
                    .payment(
                        InvoicePaymentFragment(
                            detailID: detail.id,
                            lines: lines,
                            showsSectionTitle: isFirstDetail && isFirstFragment,
                            isLast: isLast
                        )
                    )
                },
                to: &pages
            )
            isFirstDetail = false
        }
    }

    private static func appendSingleColumnFragments(
        lines: [InvoiceDocumentTextLine],
        makeBlock: ([InvoiceDocumentTextLine], Bool, Bool) -> InvoiceDocumentBlock,
        to pages: inout [WorkingPage]
    ) {
        var index = 0
        var isFirst = true

        while index < lines.count {
            let remaining = Array(lines[index...])
            let finalBlock = makeBlock(remaining, isFirst, true)

            if finalBlock.measuredHeight <= availableHeight(in: pages) {
                append(finalBlock, to: &pages)
                break
            }

            if finalBlock.measuredHeight <= InvoiceDocumentMetrics.flowHeight {
                startNewPage(in: &pages)
                continue
            }

            let emptyBlock = makeBlock([], isFirst, false)
            let lineCapacity = availableHeight(in: pages) - emptyBlock.measuredHeight
            var count = prefixCount(fitting: remaining, height: lineCapacity)
            if count == remaining.count {
                count -= 1
            }

            guard count > 0 else {
                startNewPage(in: &pages)
                continue
            }

            append(makeBlock(Array(remaining.prefix(count)), isFirst, false), to: &pages)
            index += count
            isFirst = false
        }
    }

    private static func appendTotals(invoice: Invoice, to pages: inout [WorkingPage]) {
        appendFixed(
            .totals(
                InvoiceTotalsSnapshot(
                    subtotal: Money.format(
                        minorUnits: invoice.subtotalMinorUnits,
                        currencyCode: invoice.currencyCode
                    ),
                    tax: Money.format(
                        minorUnits: invoice.taxMinorUnits,
                        currencyCode: invoice.currencyCode
                    ),
                    amountPaid: invoice.paidMinorUnits > 0
                        ? Money.format(
                            minorUnits: invoice.paidMinorUnits,
                            currencyCode: invoice.currencyCode
                        )
                        : nil,
                    balanceDue: Money.format(
                        minorUnits: invoice.balanceDueMinorUnits,
                        currencyCode: invoice.currencyCode
                    )
                )
            ),
            to: &pages
        )
    }

    private static func appendFixed(
        _ block: InvoiceDocumentBlock,
        to pages: inout [WorkingPage]
    ) {
        if block.measuredHeight > availableHeight(in: pages) {
            startNewPage(in: &pages)
        }
        append(block, to: &pages)
    }

    private static func ensureLineItemHeader(to pages: inout [WorkingPage]) {
        guard !currentPage(in: pages).hasLineItemHeader else { return }

        let minimumItemHeight = InvoiceDocumentMetrics.lineItemVerticalPadding
            + InvoiceDocumentMetrics.dividerHeight
            + InvoiceDocumentTextStyle.itemTitle.lineHeight
        if InvoiceDocumentMetrics.lineItemHeaderHeight + minimumItemHeight > availableHeight(in: pages) {
            startNewPage(in: &pages)
        }

        append(.lineItemHeader, to: &pages)
        pages[pages.count - 1].hasLineItemHeader = true
    }

    private static func wrapped(
        _ text: String,
        style: InvoiceDocumentTextStyle,
        width: CGFloat,
        spacingBefore: CGFloat = 0
    ) -> [InvoiceDocumentTextLine] {
        guard !text.isEmpty else { return [] }

        return InvoiceTextWrapper.lines(for: text, font: style.nsFont, width: width)
            .enumerated()
            .map { index, line in
                InvoiceDocumentTextLine(
                    text: line,
                    style: style,
                    spacingBefore: index == 0 ? spacingBefore : 0
                )
            }
    }

    private static func joinedLineGroups(
        _ groups: [[InvoiceDocumentTextLine]],
        spacing: CGFloat = 4
    ) -> [InvoiceDocumentTextLine] {
        var result: [InvoiceDocumentTextLine] = []
        for var group in groups where !group.isEmpty {
            if !result.isEmpty {
                group[0].spacingBefore += spacing
            }
            result += group
        }
        return result
    }

    private static func prefixCount(
        fitting lines: [InvoiceDocumentTextLine],
        height: CGFloat
    ) -> Int {
        guard height > 0 else { return 0 }

        var used: CGFloat = 0
        var count = 0
        for line in lines {
            guard used + line.measuredHeight <= height else { break }
            used += line.measuredHeight
            count += 1
        }
        return count
    }

    private static func availableHeight(in pages: [WorkingPage]) -> CGFloat {
        max(0, InvoiceDocumentMetrics.flowHeight - currentPage(in: pages).usedHeight)
    }

    private static func currentPage(in pages: [WorkingPage]) -> WorkingPage {
        pages.last ?? WorkingPage()
    }

    private static func append(
        _ block: InvoiceDocumentBlock,
        to pages: inout [WorkingPage]
    ) {
        if pages.isEmpty {
            pages.append(WorkingPage())
        }
        pages[pages.count - 1].blocks.append(block)
        pages[pages.count - 1].usedHeight += block.measuredHeight
    }

    private static func startNewPage(in pages: inout [WorkingPage]) {
        if pages.isEmpty || !pages[pages.count - 1].blocks.isEmpty {
            pages.append(WorkingPage())
        }
    }

    private struct WorkingPage {
        var blocks: [InvoiceDocumentBlock] = []
        var usedHeight: CGFloat = 0
        var hasLineItemHeader = false
    }
}

enum InvoiceDocumentFormatting {
    static func trimmedQuantity(_ value: Double) -> String {
        if value.isFinite, value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    static func amountWithoutCurrency(_ minorUnits: Int64, currencyCode: String) -> String {
        Money.format(minorUnits: minorUnits, currencyCode: currencyCode)
            .replacingOccurrences(of: currencyCode + " ", with: "")
    }
}

private extension Array where Element == InvoiceDocumentTextLine {
    var measuredHeight: CGFloat {
        reduce(0) { $0 + $1.measuredHeight }
    }
}

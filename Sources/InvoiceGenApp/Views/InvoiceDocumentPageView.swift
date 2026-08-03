import SwiftUI

struct InvoiceDocumentPageView: View {
    var page: InvoiceDocumentPage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(page.blocks.enumerated()), id: \.offset) { _, block in
                if block.isPageNumber {
                    Spacer(minLength: 0)
                }
                blockView(block)
                    .frame(
                        width: InvoiceDocumentMetrics.bodyWidth,
                        height: block.measuredHeight,
                        alignment: .topLeading
                    )
            }
        }
        .frame(
            width: InvoiceDocumentMetrics.bodyWidth,
            height: InvoiceDocumentMetrics.bodyHeight,
            alignment: .topLeading
        )
        .padding(InvoiceDocument.pageInsets)
        .frame(
            width: InvoiceDocument.pageSize.width,
            height: InvoiceDocument.pageSize.height,
            alignment: .topLeading
        )
        .background(Color.white)
    }

    @ViewBuilder
    private func blockView(_ block: InvoiceDocumentBlock) -> some View {
        switch block {
        case .identity(let fragment):
            identity(fragment)
        case .billing(let fragment):
            billing(fragment)
        case .lineItemHeader:
            lineItemHeader
        case .lineItem(let fragment):
            lineItem(fragment)
        case .titledText(let fragment):
            titledText(fragment)
        case .payment(let fragment):
            payment(fragment)
        case .totals(let snapshot):
            totals(snapshot)
        case .pageNumber(let current, let total):
            pageNumber(current: current, total: total)
        }
    }

    private func identity(_ fragment: InvoiceIdentityFragment) -> some View {
        let contentHeight = max(
            fragment.businessLines.measuredHeight,
            fragment.invoiceLines.measuredHeight
        )

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                InvoiceDocumentTextLines(lines: fragment.businessLines)
                    .frame(
                        width: InvoiceDocumentMetrics.identityLeftWidth,
                        alignment: .topLeading
                    )

                InvoiceDocumentTextLines(lines: fragment.invoiceLines, isTrailing: true)
                    .frame(
                        width: InvoiceDocumentMetrics.identityRightWidth,
                        alignment: .topTrailing
                    )
            }
            .frame(height: contentHeight, alignment: .topLeading)

            if fragment.isLast {
                Spacer()
                    .frame(height: 36)
                Divider()
                    .overlay(Color(white: 0.85))
                    .frame(height: InvoiceDocumentMetrics.dividerHeight)
                Spacer()
                    .frame(height: 24)
            } else {
                Spacer()
                    .frame(height: InvoiceDocumentMetrics.fragmentSpacing)
            }
        }
    }

    private func billing(_ fragment: InvoiceBillingFragment) -> some View {
        let contentHeight = max(
            fragment.clientLines.measuredHeight,
            fragment.dateLines.measuredHeight
        )

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                InvoiceDocumentTextLines(lines: fragment.clientLines)
                    .frame(
                        width: InvoiceDocumentMetrics.billingLeftWidth,
                        alignment: .topLeading
                    )

                InvoiceDocumentTextLines(lines: fragment.dateLines, isTrailing: true)
                    .frame(
                        width: InvoiceDocumentMetrics.billingRightWidth,
                        alignment: .topTrailing
                    )
            }
            .frame(height: contentHeight, alignment: .topLeading)

            Spacer()
                .frame(
                    height: fragment.isLast
                        ? InvoiceDocumentMetrics.billingEndingHeight
                        : InvoiceDocumentMetrics.fragmentSpacing
                )
        }
    }

    private var lineItemHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: InvoiceDocumentMetrics.tableColumnSpacing) {
                Text("Description")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Qty")
                    .frame(width: InvoiceDocumentMetrics.quantityWidth, alignment: .center)
                Text("Unit Price")
                    .frame(width: InvoiceDocumentMetrics.unitPriceWidth, alignment: .trailing)
                Text("Tax")
                    .frame(width: InvoiceDocumentMetrics.taxWidth, alignment: .trailing)
                Text("Total")
                    .frame(width: InvoiceDocumentMetrics.totalWidth, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(white: 0.35))
            .padding(.horizontal, InvoiceDocumentMetrics.tableHorizontalPadding)
            .frame(height: InvoiceDocumentMetrics.lineItemHeaderHeight - InvoiceDocumentMetrics.dividerHeight)
            .background(Color(white: 0.94))

            Divider()
                .overlay(Color(white: 0.85))
                .frame(height: InvoiceDocumentMetrics.dividerHeight)
        }
    }

    private func lineItem(_ fragment: InvoiceLineItemFragment) -> some View {
        let contentHeight = max(
            fragment.descriptionLines.measuredHeight,
            fragment.showsAmounts ? InvoiceDocumentMetrics.amountLineHeight : 0
        )

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: InvoiceDocumentMetrics.tableColumnSpacing) {
                InvoiceDocumentTextLines(lines: fragment.descriptionLines)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                if fragment.showsAmounts {
                    amountText(fragment.quantity)
                        .frame(width: InvoiceDocumentMetrics.quantityWidth, alignment: .center)
                    amountText(fragment.unitPrice)
                        .frame(width: InvoiceDocumentMetrics.unitPriceWidth, alignment: .trailing)
                    amountText(fragment.tax)
                        .frame(width: InvoiceDocumentMetrics.taxWidth, alignment: .trailing)
                    amountText(fragment.total, isStrong: true)
                        .frame(width: InvoiceDocumentMetrics.totalWidth, alignment: .trailing)
                } else {
                    Color.clear
                        .frame(width: InvoiceDocumentMetrics.quantityWidth)
                    Color.clear
                        .frame(width: InvoiceDocumentMetrics.unitPriceWidth)
                    Color.clear
                        .frame(width: InvoiceDocumentMetrics.taxWidth)
                    Color.clear
                        .frame(width: InvoiceDocumentMetrics.totalWidth)
                }
            }
            .padding(.horizontal, InvoiceDocumentMetrics.tableHorizontalPadding)
            .padding(.vertical, InvoiceDocumentMetrics.lineItemVerticalPadding / 2)
            .frame(
                height: contentHeight + InvoiceDocumentMetrics.lineItemVerticalPadding,
                alignment: .topLeading
            )

            Divider()
                .overlay(Color(white: 0.88))
                .frame(height: InvoiceDocumentMetrics.dividerHeight)
        }
    }

    private func amountText(_ value: String, isStrong: Bool = false) -> some View {
        Text(value)
            .font(.system(size: 13, weight: isStrong ? .semibold : .regular, design: .monospaced))
            .foregroundStyle(Color.black)
            .frame(height: InvoiceDocumentMetrics.amountLineHeight, alignment: .top)
    }

    private func titledText(_ fragment: InvoiceTitledTextFragment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if fragment.showsTitle {
                Text(fragment.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(white: 0.45))
                    .frame(height: 14, alignment: .topLeading)
                Spacer()
                    .frame(height: 4)
            }

            InvoiceDocumentTextLines(lines: fragment.lines)

            Spacer()
                .frame(
                    height: fragment.isLast
                        ? InvoiceDocumentMetrics.sectionEndingHeight
                        : InvoiceDocumentMetrics.fragmentSpacing
                )
        }
    }

    private func payment(_ fragment: InvoicePaymentFragment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if fragment.showsSectionTitle {
                Text("Payment Acceptance")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(white: 0.45))
                    .frame(height: 14, alignment: .topLeading)
                Spacer()
                    .frame(height: 4)
            }

            InvoiceDocumentTextLines(lines: fragment.lines)

            Spacer()
                .frame(
                    height: fragment.isLast
                        ? InvoiceDocumentMetrics.paymentEndingHeight
                        : InvoiceDocumentMetrics.fragmentSpacing
                )
        }
    }

    private func totals(_ snapshot: InvoiceTotalsSnapshot) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 0) {
                totalRow(label: "Subtotal", value: snapshot.subtotal)
                Spacer().frame(height: 8)
                totalRow(label: "Tax", value: snapshot.tax)

                if let amountPaid = snapshot.amountPaid {
                    Spacer().frame(height: 8)
                    totalRow(label: "Amount Paid", value: amountPaid)
                }

                Spacer().frame(height: 12)
                Divider()
                    .overlay(Color(white: 0.8))
                    .frame(width: 220, height: 1)
                Spacer().frame(height: 16)

                HStack(spacing: 24) {
                    Text("Balance Due")
                        .font(.system(size: 13, weight: .bold))
                    Text(snapshot.balanceDue)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color.black)
                .frame(height: 20, alignment: .topTrailing)
            }
            .padding(.top, 18)
        }
    }

    private func totalRow(label: String, value: String) -> some View {
        HStack(spacing: 24) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.4))
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.black)
        }
        .frame(height: 17, alignment: .topTrailing)
    }

    private func pageNumber(current: Int, total: Int) -> some View {
        HStack {
            Spacer()
            Text("Page \(current) of \(total)")
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.45))
        }
        .padding(.top, 8)
        .frame(height: InvoiceDocumentMetrics.pageNumberHeight, alignment: .topTrailing)
    }
}

private struct InvoiceDocumentTextLines: View {
    var lines: [InvoiceDocumentTextLine]
    var isTrailing = false

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.spacingBefore > 0 {
                    Spacer()
                        .frame(height: line.spacingBefore)
                }

                Text(line.text)
                    .font(line.style.swiftUIFont)
                    .foregroundStyle(line.style.foregroundColor)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: line.style.lineHeight,
                        maxHeight: line.style.lineHeight,
                        alignment: isTrailing ? .trailing : .leading
                    )
                    .clipped()
            }
        }
    }

    private var horizontalAlignment: HorizontalAlignment {
        isTrailing ? .trailing : .leading
    }
}

private extension InvoiceDocumentTextStyle {
    var swiftUIFont: Font {
        switch self {
        case .businessName:
            .system(size: 20, weight: .bold)
        case .invoiceTitle:
            .system(size: 28, weight: .black)
        case .invoiceNumber:
            .system(size: 13, design: .monospaced)
        case .label:
            .system(size: 11, weight: .bold)
        case .bodyStrong:
            .system(size: 13, weight: .bold)
        case .body:
            .system(size: 13)
        case .captionStrong:
            .system(size: 11, weight: .semibold)
        case .caption:
            .system(size: 11)
        case .itemTitle:
            .system(size: 13, weight: .medium)
        case .itemDetail:
            .system(size: 11)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .businessName, .invoiceTitle, .bodyStrong, .itemTitle, .captionStrong:
            Color.black
        case .label:
            Color(white: 0.45)
        case .invoiceNumber, .body, .caption, .itemDetail:
            Color(white: 0.35)
        }
    }
}

private extension InvoiceDocumentBlock {
    var isPageNumber: Bool {
        if case .pageNumber = self {
            return true
        }
        return false
    }
}

private extension Array where Element == InvoiceDocumentTextLine {
    var measuredHeight: CGFloat {
        reduce(0) { $0 + $1.measuredHeight }
    }
}

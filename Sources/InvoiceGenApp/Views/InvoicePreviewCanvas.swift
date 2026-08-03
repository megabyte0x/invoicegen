import SwiftUI

enum PreviewScaleMode: String, CaseIterable, Identifiable {
    case fitWidth
    case actualSize

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fitWidth:
            "Fit Width"
        case .actualSize:
            "Actual Size"
        }
    }
}

enum PreviewScalePolicy {
    static let pageWidth = InvoiceDocument.pageSize.width
    static let horizontalMargin: CGFloat = 48

    static func fitScale(availableWidth: CGFloat) -> CGFloat {
        let clampedWidth = max(0, availableWidth)
        let usableWidth = max(0, clampedWidth - horizontalMargin)
        return min(1, usableWidth / pageWidth)
    }
}

struct InvoicePreviewCanvas: View {
    var document: InvoiceDocument
    @Binding var scaleMode: PreviewScaleMode

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = CGSize(
                width: max(0, geometry.size.width),
                height: max(0, geometry.size.height)
            )
            let scale = scale(for: viewportSize.width)
            let pageCount = document.pages.count
            let interPageHeight = CGFloat(max(0, pageCount - 1)) * 20
            let unscaledSize = CGSize(
                width: InvoiceDocument.pageSize.width,
                height: CGFloat(pageCount) * InvoiceDocument.pageSize.height + interPageHeight
            )
            let scaledSize = CGSize(
                width: max(0, unscaledSize.width * scale),
                height: max(0, unscaledSize.height * scale)
            )

            ScrollView([.horizontal, .vertical]) {
                scaledPageStack(scale: scale, unscaledSize: unscaledSize, scaledSize: scaledSize)
                    .padding(.horizontal, PreviewScalePolicy.horizontalMargin / 2)
                    .padding(.vertical, 16)
                    .frame(
                        minWidth: max(
                            0,
                            max(
                                viewportSize.width,
                                scaledSize.width + PreviewScalePolicy.horizontalMargin
                            )
                        ),
                        minHeight: max(0, max(viewportSize.height, scaledSize.height + 32)),
                        alignment: .topLeading
                    )
            }
            .scrollIndicators(.visible)
            .defaultScrollAnchor(.topLeading)
        }
    }

    private func scale(for availableWidth: CGFloat) -> CGFloat {
        switch scaleMode {
        case .fitWidth:
            PreviewScalePolicy.fitScale(availableWidth: max(0, availableWidth))
        case .actualSize:
            1
        }
    }

    private func scaledPageStack(
        scale: CGFloat,
        unscaledSize: CGSize,
        scaledSize: CGSize
    ) -> some View {
        VStack(spacing: 20) {
            ForEach(document.pages) { page in
                InvoiceDocumentPageView(page: page)
                    .frame(
                        width: InvoiceDocument.pageSize.width,
                        height: InvoiceDocument.pageSize.height
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.runeyBorder.opacity(0.75), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            }
        }
        .frame(
            width: max(0, unscaledSize.width),
            height: max(0, unscaledSize.height),
            alignment: .topLeading
        )
        .scaleEffect(scale, anchor: .topLeading)
        .frame(
            width: max(0, scaledSize.width),
            height: max(0, scaledSize.height),
            alignment: .topLeading
        )
    }
}

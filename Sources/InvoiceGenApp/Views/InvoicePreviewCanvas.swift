import SwiftUI
import InvoiceCore

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
    static let pageWidth: CGFloat = 612
    static let horizontalMargin: CGFloat = 48

    static func fitScale(availableWidth: CGFloat) -> CGFloat {
        min(1.0, max(0.35, (availableWidth - horizontalMargin) / pageWidth))
    }
}

struct InvoicePreviewCanvas: View {
    @Binding var invoice: Invoice
    var book: InvoiceBook
    @Binding var scaleMode: PreviewScaleMode

    @State private var sheetSize = CGSize(width: PreviewScalePolicy.pageWidth, height: 792)

    var body: some View {
        GeometryReader { geometry in
            let scale = scale(for: geometry.size.width)
            let scaledSheetSize = CGSize(
                width: sheetSize.width * scale,
                height: sheetSize.height * scale
            )

            ScrollView([.horizontal, .vertical]) {
                scaledSheet(scale: scale)
                    .padding(.horizontal, PreviewScalePolicy.horizontalMargin / 2)
                    .padding(.vertical, 16)
                    .frame(
                        minWidth: max(geometry.size.width, scaledSheetSize.width + PreviewScalePolicy.horizontalMargin),
                        minHeight: max(geometry.size.height, scaledSheetSize.height + 32),
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
            PreviewScalePolicy.fitScale(availableWidth: availableWidth)
        case .actualSize:
            1.0
        }
    }

    private func scaledSheet(scale: CGFloat) -> some View {
        InvoiceSheetView(invoice: invoice, book: book)
            .frame(width: PreviewScalePolicy.pageWidth, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.runeyBorder.opacity(0.75), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: InvoicePreviewSheetSizeKey.self,
                        value: proxy.size
                    )
                }
            }
            .scaleEffect(scale, anchor: .topLeading)
            .frame(
                width: sheetSize.width * scale,
                height: sheetSize.height * scale,
                alignment: .topLeading
            )
            .onPreferenceChange(InvoicePreviewSheetSizeKey.self) { size in
                guard size.width > 0, size.height > 0, size != sheetSize else { return }
                sheetSize = size
            }
    }
}

private struct InvoicePreviewSheetSizeKey: PreferenceKey {
    static var defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

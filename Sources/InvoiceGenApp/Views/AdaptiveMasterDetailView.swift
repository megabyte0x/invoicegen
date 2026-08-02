import SwiftUI

enum MasterDetailPresentation: Equatable {
    case list
    case detail
    case split
}

enum InvoiceEditorPresentation: Equatable, Hashable {
    case edit
    case preview
    case sideBySide
}

enum WorkspaceLayoutPolicy {
    static let masterDetailSplitWidth: CGFloat = 1_400
    static let editorSideBySideWidth: CGFloat = 1_120
    static let compactFormWidth: CGFloat = 700

    static func masterDetail(width: CGFloat, hasDetail: Bool) -> MasterDetailPresentation {
        if width >= masterDetailSplitWidth { return .split }
        return hasDetail ? .detail : .list
    }

    static func invoiceEditor(
        width: CGFloat,
        requested: InvoiceEditorPresentation
    ) -> InvoiceEditorPresentation {
        if width >= editorSideBySideWidth { return .sideBySide }
        return requested == .preview ? .preview : .edit
    }
}

struct AdaptiveMasterDetailView<ListContent: View, DetailContent: View>: View {
    var hasDetail: Bool
    var back: () -> Void

    private let list: ListContent
    private let detail: DetailContent

    init(
        hasDetail: Bool,
        back: @escaping () -> Void,
        @ViewBuilder list: () -> ListContent,
        @ViewBuilder detail: () -> DetailContent
    ) {
        self.hasDetail = hasDetail
        self.back = back
        self.list = list()
        self.detail = detail()
    }

    var body: some View {
        GeometryReader { proxy in
            let presentation = WorkspaceLayoutPolicy.masterDetail(
                width: proxy.size.width,
                hasDetail: hasDetail
            )

            if presentation == .split {
                HSplitView {
                    list
                        .frame(
                            minWidth: 240,
                            idealWidth: 300,
                            maxWidth: 340,
                            maxHeight: .infinity
                        )

                    detail
                        .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ZStack {
                    list
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(presentation == .list ? 1 : 0)
                        .allowsHitTesting(presentation == .list)
                        .accessibilityHidden(presentation != .list)

                    VStack(spacing: 0) {
                        HStack {
                            Button(action: back) {
                                Label("Back", systemImage: "chevron.left")
                            }
                            .buttonStyle(.borderless)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        Divider()

                        detail
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .opacity(presentation == .detail ? 1 : 0)
                    .allowsHitTesting(presentation == .detail)
                    .accessibilityHidden(presentation != .detail)
                }
            }
        }
    }
}

struct AdaptiveFieldRow<Content: View>: View {
    var availableWidth: CGFloat
    var spacing: CGFloat

    private let content: Content
    @State private var selectedAxis: AdaptiveFieldAxis

    init(
        availableWidth: CGFloat,
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.availableWidth = availableWidth
        self.spacing = spacing
        self.content = content()
        self._selectedAxis = State(
            initialValue: availableWidth < WorkspaceLayoutPolicy.compactFormWidth
                ? .vertical
                : .horizontal
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                AdaptiveFieldAxisProbe(axis: .horizontal, select: select)
                    .frame(
                        minWidth: availableWidth < WorkspaceLayoutPolicy.compactFormWidth
                            ? availableWidth + 1
                            : 0
                    )

                AdaptiveFieldAxisProbe(axis: .vertical, select: select)
            }
            .frame(height: 0)
            .clipped()
            .accessibilityHidden(true)

            layout {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var layout: AnyLayout {
        if selectedAxis == .vertical {
            AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
        } else {
            AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
        }
    }

    private func select(_ axis: AdaptiveFieldAxis) {
        selectedAxis = axis
    }
}

private enum AdaptiveFieldAxis {
    case horizontal
    case vertical
}

private struct AdaptiveFieldAxisProbe: View {
    var axis: AdaptiveFieldAxis
    var select: (AdaptiveFieldAxis) -> Void

    var body: some View {
        Color.clear
            .onAppear {
                select(axis)
            }
    }
}

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
            let safeWidth = max(0, proxy.size.width)
            let presentation = WorkspaceLayoutPolicy.masterDetail(
                width: safeWidth,
                hasDetail: hasDetail
            )

            content(for: presentation, width: safeWidth)
        }
    }

    @ViewBuilder
    private func content(
        for presentation: MasterDetailPresentation,
        width: CGFloat
    ) -> some View {
        switch presentation {
        case .split:
            HSplitView {
                list.frame(
                    minWidth: 240,
                    idealWidth: min(320, width * 0.28),
                    maxWidth: min(360, width * 0.34)
                )
                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .list:
            list.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .detail:
            VStack(spacing: 0) {
                compactBackBar
                Divider()
                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var compactBackBar: some View {
        HStack {
            Button(action: back) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct AdaptiveFieldRow<Content: View>: View {
    var availableWidth: CGFloat
    var spacing: CGFloat

    private let content: Content

    init(
        availableWidth: CGFloat,
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.availableWidth = availableWidth
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        let safeWidth = max(0, availableWidth)
        let axis: Axis = safeWidth < WorkspaceLayoutPolicy.compactFormWidth
            ? .vertical
            : .horizontal

        Group {
            if axis == .vertical {
                VStack(alignment: .leading, spacing: spacing) {
                    content
                }
            } else {
                HStack(alignment: .top, spacing: spacing) {
                    content
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

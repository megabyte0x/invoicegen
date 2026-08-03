import SwiftUI

enum WorkspaceContentMetrics {
    static let maximumEditorWidth: CGFloat = 1_180

    static func padding(for availableWidth: CGFloat) -> CGFloat {
        switch max(0, availableWidth) {
        case ..<520: return 12
        case ..<800: return 18
        default: return 24
        }
    }

    static func contentWidth(for availableWidth: CGFloat) -> CGFloat {
        let padding = padding(for: availableWidth)
        return min(max(0, availableWidth - (padding * 2)), maximumEditorWidth)
    }
}

extension View {
    func responsiveEditorFrame(availableWidth: CGFloat) -> some View {
        frame(
            width: WorkspaceContentMetrics.contentWidth(for: availableWidth),
            alignment: .topLeading
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

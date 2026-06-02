import SwiftUI
import AppKit

extension Color {
    static let runeyPrimary = Color(nsColor: NSColor(name: nil) { appearance in
        let best = appearance.bestMatch(from: [.aqua, .darkAqua])
        return best == .darkAqua ? NSColor(white: 0.88, alpha: 1.0) : NSColor(white: 0.14, alpha: 1.0)
    })
    
    static let runeySecondary = Color(nsColor: NSColor(name: nil) { appearance in
        let best = appearance.bestMatch(from: [.aqua, .darkAqua])
        return best == .darkAqua ? NSColor(white: 0.12, alpha: 1.0) : NSColor(white: 0.95, alpha: 1.0)
    })
    
    static let runeyBackground = Color(nsColor: NSColor(name: nil) { appearance in
        let best = appearance.bestMatch(from: [.aqua, .darkAqua])
        return best == .darkAqua ? NSColor(white: 0.05, alpha: 1.0) : NSColor(white: 0.98, alpha: 1.0)
    })
    
    static let runeyBorder = Color(nsColor: NSColor(name: nil) { appearance in
        let best = appearance.bestMatch(from: [.aqua, .darkAqua])
        return best == .darkAqua ? NSColor(white: 0.16, alpha: 1.0) : NSColor(white: 0.91, alpha: 1.0)
    })
    
    static let runeyMuted = Color(nsColor: NSColor(name: nil) { appearance in
        let best = appearance.bestMatch(from: [.aqua, .darkAqua])
        return best == .darkAqua ? NSColor(white: 0.50, alpha: 1.0) : NSColor(white: 0.46, alpha: 1.0)
    })
    
    static let runeySuccess = Color(red: 0.49, green: 0.78, blue: 0.28) // HSL 93 64% 52%
    static let runeyDestructive = Color(red: 1.0, green: 0.35, blue: 0.35) // HSL 0 100% 65%
    static let runeyWarning = Color(red: 1.0, green: 0.64, blue: 0.39) // HSL 39 100% 64%
    static let runeyOrange = Color(red: 1.0, green: 0.52, blue: 0.34) // HSL 16 100% 67%
    static let runeyInfo = Color(red: 0.2, green: 0.65, blue: 0.85) // HSL 200 70% 50%
}

struct RuneyCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var isHovered: Bool = false
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.runeySecondary.opacity(0.85))
                    .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.runeyBorder, lineWidth: 1)
            }
    }
}

extension View {
    func runeyCard(padding: CGFloat = 16, isHovered: Bool = false) -> some View {
        self.modifier(RuneyCardModifier(padding: padding, isHovered: isHovered))
    }
}

struct TahoeHeaderBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.runeySecondary)
            .overlay(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Color.runeyInfo.opacity(0.12),
                        Color.runeySuccess.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.runeyBorder, lineWidth: 1)
            }
    }
}

struct LocalBadge: View {
    var body: some View {
        Label("Local database only", systemImage: "lock.fill")
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.runeyMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.runeyBorder.opacity(0.5), in: Capsule())
    }
}

struct RuneyMultilineEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 72

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .padding(4)
            .background(Color.runeySecondary, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.runeyBorder, lineWidth: 1)
            }
    }
}

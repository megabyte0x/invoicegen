import SwiftUI
import AppKit

extension Color {
    static let runeyPrimary = Color(nsColor: .labelColor)
    
    static let runeySecondary = Color(nsColor: .controlBackgroundColor)
    
    static let runeyBackground = Color(nsColor: .windowBackgroundColor)
    
    static let runeyBorder = Color(nsColor: .separatorColor)
    
    static let runeyMuted = Color(nsColor: .secondaryLabelColor)
    static let runeyAccent = Color(nsColor: .controlAccentColor)
    
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)
                    .shadow(
                        color: Color.black.opacity(isHovered ? 0.10 : 0.035),
                        radius: isHovered ? 12 : 6,
                        x: 0,
                        y: isHovered ? 5 : 2
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.runeyBorder.opacity(0.7), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
    }
}

extension View {
    func runeyCard(padding: CGFloat = 16, isHovered: Bool = false) -> some View {
        self.modifier(RuneyCardModifier(padding: padding, isHovered: isHovered))
    }
}

struct RuneyFieldInputModifier: ViewModifier {
    var width: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        let styled = content
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.runeyBorder.opacity(0.75), lineWidth: 1)
            }

        if let width {
            styled.frame(width: width)
        } else {
            styled
        }
    }
}

struct RuneyButtonStyle: ButtonStyle {
    enum Variant {
        case secondary
        case prominent
        case success
        case destructive
        case icon
        case destructiveIcon
    }

    var variant: Variant = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: variant == .icon ? 28 : 30)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundStyle)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.86 : 1.0)
    }

    private var labelFont: Font {
        switch variant {
        case .icon, .destructiveIcon:
            return .body
        default:
            return .body.weight(.medium)
        }
    }

    private var horizontalPadding: CGFloat {
        switch variant {
        case .icon, .destructiveIcon:
            return 6
        default:
            return 12
        }
    }

    private var verticalPadding: CGFloat {
        switch variant {
        case .icon, .destructiveIcon:
            return 5
        default:
            return 7
        }
    }

    private var foregroundStyle: Color {
        switch variant {
        case .prominent, .success, .destructive:
            return .white
        case .destructiveIcon:
            return .runeyDestructive
        case .secondary, .icon:
            return .runeyPrimary
        }
    }

    private var backgroundStyle: Color {
        switch variant {
        case .prominent:
            return .runeyAccent
        case .success:
            return .runeySuccess
        case .destructive:
            return .runeyDestructive
        case .destructiveIcon:
            return .runeyDestructive.opacity(0.10)
        case .secondary, .icon:
            return .runeySecondary.opacity(0.7)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .prominent:
            return .runeyAccent.opacity(0.75)
        case .success:
            return .runeySuccess.opacity(0.75)
        case .destructive:
            return .runeyDestructive.opacity(0.75)
        case .destructiveIcon:
            return .runeyDestructive.opacity(0.18)
        case .secondary, .icon:
            return .runeyBorder.opacity(0.75)
        }
    }
}

struct RuneyFormLabel: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.runeyMuted)
    }
}

extension View {
    func runeyFieldInput(width: CGFloat? = nil) -> some View {
        modifier(RuneyFieldInputModifier(width: width))
    }
}

struct InvoiceGenLogoMark: View {
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let logo = Self.logoImage {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: size * 0.54, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .fill(Color.runeyPrimary)
                    )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
        .accessibilityHidden(true)
    }

    private static let logoImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "invoicegen-logo", withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: url)
    }()
}

struct TahoeHeaderBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.regularMaterial)
            .overlay(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Color.runeyAccent.opacity(0.18),
                        Color.runeyInfo.opacity(0.10),
                        Color.clear
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.runeyBorder.opacity(0.75), lineWidth: 1)
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
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.runeyBorder.opacity(0.55), lineWidth: 1)
            }
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.runeyBorder.opacity(0.75), lineWidth: 1)
            }
    }
}

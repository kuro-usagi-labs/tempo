import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Shared visual language for Tempo V2. Components deliberately use semantic
/// fonts and scaled measurements so they remain comfortable at larger text sizes.
enum TempoDesign {
    enum Palette {
        static let canvas = Color(red: 0.035, green: 0.039, blue: 0.051)
        static let surface = Color(red: 0.082, green: 0.094, blue: 0.125)
        static let surfaceElevated = Color(red: 0.106, green: 0.122, blue: 0.165)
        static let surfaceMuted = Color(red: 0.135, green: 0.148, blue: 0.192)

        static let textPrimary = Color(red: 0.96, green: 0.97, blue: 0.99)
        static let textSecondary = Color(red: 0.68, green: 0.71, blue: 0.77)
        static let textTertiary = Color(red: 0.48, green: 0.51, blue: 0.58)

        static let accent = Color(red: 0.47, green: 0.42, blue: 1.0)
        static let accentSoft = Color(red: 0.33, green: 0.78, blue: 0.91)
        static let positive = Color(red: 0.31, green: 0.83, blue: 0.60)
        static let caution = Color(red: 1.0, green: 0.67, blue: 0.27)
        static let critical = Color(red: 1.0, green: 0.25, blue: 0.36)
        static let hairline = Color.white.opacity(0.08)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 36
    }

    enum Radius {
        static let small: CGFloat = 14
        static let medium: CGFloat = 20
        static let large: CGFloat = 28
    }

    enum Typography {
        static let overline = Font.system(.caption, design: .rounded).weight(.bold)
        static let sectionTitle = Font.system(.title3, design: .rounded).weight(.semibold)
        static let cardTitle = Font.system(.headline, design: .rounded).weight(.semibold)
        static let pageTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let display = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let body = Font.body
        static let supporting = Font.subheadline
        static let caption = Font.caption
        static let numeric = Font.system(.title2, design: .rounded).weight(.bold).monospacedDigit()
    }

    static let readableContentWidth: CGFloat = 680
}

enum TempoBadgeTone: Sendable {
    case accent
    case positive
    case caution
    case critical
    case neutral

    var color: Color {
        switch self {
        case .accent: TempoDesign.Palette.accentSoft
        case .positive: TempoDesign.Palette.positive
        case .caution: TempoDesign.Palette.caution
        case .critical: TempoDesign.Palette.critical
        case .neutral: TempoDesign.Palette.textSecondary
        }
    }

    var defaultIcon: String {
        switch self {
        case .accent: "sparkles"
        case .positive: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.shield.fill"
        case .neutral: "circle.fill"
        }
    }
}

enum TempoCardEmphasis: Sendable {
    case standard
    case elevated
    case tinted
}

/// A dark, high-contrast surface used for activity summaries, plans, and insights.
struct TempoSurfaceCard<Content: View>: View {
    private let tint: Color
    private let emphasis: TempoCardEmphasis
    private let content: Content
    @ScaledMetric(relativeTo: .body) private var scaledPadding: CGFloat = TempoDesign.Spacing.lg

    init(
        tint: Color = .clear,
        emphasis: TempoCardEmphasis = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.emphasis = emphasis
        self.content = content()
    }

    var body: some View {
        content
            .padding(scaledPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
    }

    private var background: Color {
        switch emphasis {
        case .standard: TempoDesign.Palette.surface
        case .elevated: TempoDesign.Palette.surfaceElevated
        case .tinted: tint.opacity(0.13)
        }
    }

    private var borderColor: Color {
        emphasis == .tinted ? tint.opacity(0.30) : TempoDesign.Palette.hairline
    }
}

/// Compact status that carries both text and an icon, so its meaning is not color-only.
struct TempoStatusBadge: View {
    let title: String
    let tone: TempoBadgeTone
    let icon: String
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 12

    init(_ title: String, tone: TempoBadgeTone = .neutral, icon: String? = nil) {
        self.title = title
        self.tone = tone
        self.icon = icon ?? tone.defaultIcon
    }

    var body: some View {
        Label {
            Text(title)
                .font(TempoDesign.Typography.caption.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, TempoDesign.Spacing.sm)
        .padding(.vertical, TempoDesign.Spacing.xs)
        .background(tone.color.opacity(0.14), in: Capsule())
        .overlay { Capsule().stroke(tone.color.opacity(0.24), lineWidth: 1) }
        .accessibilityLabel(title)
    }
}

/// Section heading with an optional, clearly labelled text action.
struct TempoSectionHeader: View {
    let title: String
    let detail: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        _ title: String,
        detail: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TempoDesign.Spacing.sm) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xxs) {
                Text(title)
                    .font(TempoDesign.Typography.sectionTitle)
                    .foregroundStyle(TempoDesign.Palette.textPrimary)
                if let detail {
                    Text(detail)
                        .font(TempoDesign.Typography.supporting)
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                }
            }

            Spacer(minLength: TempoDesign.Spacing.sm)

            if let actionTitle, let action {
                Button(actionTitle) {
                    TempoFeedback.selection()
                    action()
                }
                .font(TempoDesign.Typography.supporting.weight(.semibold))
                .foregroundStyle(TempoDesign.Palette.accentSoft)
                .frame(minHeight: 44)
                .accessibilityHint("Buka \(actionTitle.lowercased())")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// The primary full-width call to action. It preserves a 44 pt touch target at every text size.
struct TempoPrimaryButton: View {
    let title: String
    let icon: String?
    let isEnabled: Bool
    let accessibilityHint: String?
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var minimumHeight: CGFloat = 52

    init(
        _ title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    var body: some View {
        Button {
            TempoFeedback.impact(.light)
            action()
        } label: {
            HStack(spacing: TempoDesign.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .font(TempoDesign.Typography.cardTitle)
            .frame(maxWidth: .infinity, minHeight: minimumHeight)
            .padding(.horizontal, TempoDesign.Spacing.md)
            .foregroundStyle(Color.white)
            .background(TempoDesign.Palette.accent, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(TempoTactileButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityHint(accessibilityHint ?? "")
    }
}

/// A secondary action whose outline stays visible in low-contrast environments.
struct TempoSecondaryButton: View {
    let title: String
    let icon: String?
    let tone: TempoBadgeTone
    let isEnabled: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var minimumHeight: CGFloat = 48

    init(
        _ title: String,
        icon: String? = nil,
        tone: TempoBadgeTone = .accent,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tone = tone
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            TempoFeedback.selection()
            action()
        } label: {
            HStack(spacing: TempoDesign.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .font(TempoDesign.Typography.cardTitle)
            .frame(maxWidth: .infinity, minHeight: minimumHeight)
            .padding(.horizontal, TempoDesign.Spacing.md)
            .foregroundStyle(tone.color)
            .background(tone.color.opacity(0.10), in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous)
                    .stroke(tone.color.opacity(0.36), lineWidth: 1)
            }
        }
        .buttonStyle(TempoTactileButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

/// A lightweight reusable row for clickable plans and settings.
struct TempoNavigationRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var iconLength: CGFloat = 42

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color = TempoDesign.Palette.accentSoft,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button {
            TempoFeedback.selection()
            action()
        } label: {
            HStack(spacing: TempoDesign.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: iconLength, height: iconLength)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TempoDesign.Spacing.xxs) {
                    Text(title)
                        .font(TempoDesign.Typography.cardTitle)
                        .foregroundStyle(TempoDesign.Palette.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(TempoDesign.Typography.supporting)
                            .foregroundStyle(TempoDesign.Palette.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: TempoDesign.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            .padding(TempoDesign.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous)
                    .stroke(TempoDesign.Palette.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(TempoTactileButtonStyle())
        .accessibilityHint("Buka \(title)")
    }
}

/// Shared press response that removes scaling when Reduce Motion is enabled.
struct TempoTactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.975)
            .opacity(configuration.isPressed ? 0.87 : 1)
            .animation(TempoMotion.pressAnimation(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

enum TempoMotion {
    static func pressAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78)
    }

    static func contentAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)
    }

    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .move(edge: .bottom))
    }
}

/// Optional entrance treatment for a page section. It becomes a no-motion fade for Reduce Motion.
private struct TempoEntranceMotion: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 10)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(TempoMotion.contentAnimation(reduceMotion: false)?.delay(delay)) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    /// Apply a restrained entrance animation suitable for non-critical content.
    func tempoEntrance(delay: Double = 0) -> some View {
        modifier(TempoEntranceMotion(delay: delay))
    }
}

enum TempoFeedback {
    @MainActor static func selection() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    @MainActor static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    @MainActor static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
        #endif
    }
}

import Foundation
import SwiftUI

// MARK: - Shared screen state

enum TempoScreenState<Value> {
    case loading
    case content(Value)
    case empty
    case failure(TempoUserFacingError)
}

struct TempoUserFacingError: Error, Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let recoveryTitle: String?

    init(id: String, title: String, message: String, recoveryTitle: String? = nil) {
        self.id = id
        self.title = title
        self.message = message
        self.recoveryTitle = recoveryTitle
    }
}

// MARK: - Design tokens

extension TempoDesign {
    enum Shadow {
        static let softRadius: CGFloat = 18
        static let softY: CGFloat = 8
        static let heroRadius: CGFloat = 28
        static let heroY: CGFloat = 14
    }

    enum Motion {
        static let quick: Double = 0.16
        static let standard: Double = 0.28
        static let deliberate: Double = 0.48
        static let warning: Double = 0.95
    }

    enum Layout {
        static let compactContentWidth: CGFloat = 560
        static let sessionControlHeight: CGFloat = 58
        static let stickyBarHorizontalPadding: CGFloat = 20
        static let stickyBarVerticalPadding: CGFloat = 12
    }
}

struct TempoMotionPolicy {
    let reduceMotion: Bool
    let hapticsEnabled: Bool
    let scenePhase: ScenePhase

    var permitsMotion: Bool { !reduceMotion && scenePhase == .active }
    var permitsHaptics: Bool { hapticsEnabled && scenePhase == .active }

    func animation(duration: Double = TempoDesign.Motion.standard) -> Animation? {
        permitsMotion ? .snappy(duration: duration) : nil
    }
}

// MARK: - Intensity zones

enum TempoIntensityZone: String, Codable, CaseIterable, Identifiable, Sendable {
    case calm
    case rising
    case medium
    case nearLimit
    case critical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Tenang"
        case .rising: "Mulai naik"
        case .medium: "Sedang"
        case .nearLimit: "Dekat batas"
        case .critical: "Kritis"
        }
    }

    var numericValue: Int {
        switch self {
        case .calm: 2
        case .rising: 4
        case .medium: 6
        case .nearLimit: 7
        case .critical: 9
        }
    }

    var tone: TempoBadgeTone {
        switch self {
        case .calm: .positive
        case .rising, .medium: .accent
        case .nearLimit: .caution
        case .critical: .critical
        }
    }

    var symbol: String {
        switch self {
        case .calm: "leaf.fill"
        case .rising: "waveform.path"
        case .medium: "circle.lefthalf.filled"
        case .nearLimit: "exclamationmark.circle.fill"
        case .critical: "hand.raised.fill"
        }
    }

    init(numericValue: Int) {
        switch min(10, max(1, numericValue)) {
        case ...3: self = .calm
        case 4...5: self = .rising
        case 6: self = .medium
        case 7...8: self = .nearLimit
        default: self = .critical
        }
    }
}

struct TempoIntensityZoneControl: View {
    @Binding var numericValue: Int
    var allowsDrag = true
    var accessibilityIdentifier = "intensity.zone"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @GestureState private var isDragging = false

    private var selectedZone: TempoIntensityZone {
        TempoIntensityZone(numericValue: numericValue)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            HStack(spacing: TempoDesign.Spacing.xs) {
                ForEach(TempoIntensityZone.allCases) { zone in
                    zoneButton(zone)
                }
            }
            .contentShape(Rectangle())
            .gesture(allowsDrag ? dragGesture(width: width) : nil)
            .animation(reduceMotion ? nil : .snappy(duration: TempoDesign.Motion.quick), value: selectedZone)
        }
        .frame(minHeight: 86)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Intensitas saat ini")
        .accessibilityValue("\(selectedZone.title), nilai \(selectedZone.numericValue) dari 10")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func zoneButton(_ zone: TempoIntensityZone) -> some View {
        let selected = selectedZone == zone
        return Button {
            select(zone)
        } label: {
            VStack(spacing: TempoDesign.Spacing.xs) {
                Image(systemName: zone.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.bounce, value: selected && !reduceMotion)
                Text(zone.title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(.horizontal, 4)
            .foregroundStyle(selected ? Color.white : zone.tone.color)
            .background(
                selected ? zone.tone.color : zone.tone.color.opacity(0.10),
                in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous)
                    .stroke(zone.tone.color.opacity(selected ? 0 : 0.28), lineWidth: 1)
            }
            .scaleEffect(selected && !reduceMotion ? 1.02 : 1)
        }
        .buttonStyle(TempoTactileButtonStyle())
        .accessibilityLabel(zone.title)
        .accessibilityValue("\(zone.numericValue) dari 10")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("\(accessibilityIdentifier).\(zone.rawValue)")
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                let normalized = min(0.999, max(0, value.location.x / width))
                let index = min(TempoIntensityZone.allCases.count - 1, Int(normalized * Double(TempoIntensityZone.allCases.count)))
                select(TempoIntensityZone.allCases[index], haptic: false)
            }
            .onEnded { _ in
                if hapticsEnabled { TempoFeedback.selection() }
            }
    }

    private func select(_ zone: TempoIntensityZone, haptic: Bool = true) {
        guard numericValue != zone.numericValue else { return }
        numericValue = zone.numericValue
        if haptic && hapticsEnabled { TempoFeedback.selection() }
    }
}

// MARK: - Reusable layout

struct TempoScreenContainer<Content: View>: View {
    let scrolls: Bool
    let content: Content

    init(scrolls: Bool = true, @ViewBuilder content: () -> Content) {
        self.scrolls = scrolls
        self.content = content()
    }

    var body: some View {
        Group {
            if scrolls {
                ScrollView(showsIndicators: false) { bodyContent }
            } else {
                bodyContent
            }
        }
        .background(TempoDesign.Palette.canvas.ignoresSafeArea())
    }

    private var bodyContent: some View {
        content
            .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
            .padding(.horizontal, TempoDesign.Spacing.lg)
            .padding(.top, TempoDesign.Spacing.lg)
            .padding(.bottom, 116)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct TempoStickyActionBar<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, TempoDesign.Layout.stickyBarHorizontalPadding)
            .padding(.vertical, TempoDesign.Layout.stickyBarVerticalPadding)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider().overlay(TempoDesign.Palette.hairline) }
            .safeAreaPadding(.bottom, TempoDesign.Spacing.xs)
    }
}

struct TempoHeroCard<Content: View>: View {
    let tint: Color
    let content: Content

    init(tint: Color = TempoDesign.Palette.accent, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(TempoDesign.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.26), TempoDesign.Palette.surfaceElevated],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: TempoDesign.Radius.large, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TempoDesign.Radius.large, style: .continuous)
                    .stroke(tint.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.12), radius: TempoDesign.Shadow.heroRadius, y: TempoDesign.Shadow.heroY)
    }
}

struct TempoCompactStatusRow: View {
    let title: String
    let detail: String?
    let icon: String
    let tone: TempoBadgeTone
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        detail: String? = nil,
        icon: String,
        tone: TempoBadgeTone = .neutral,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.icon = icon
        self.tone = tone
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: TempoDesign.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(tone.color)
                .frame(width: 34, height: 34)
                .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(TempoDesign.Typography.cardTitle)
                if let detail {
                    Text(detail).font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(TempoDesign.Typography.supporting.weight(.semibold))
                    .foregroundStyle(tone.color)
                    .frame(minHeight: 44)
            }
        }
        .padding(.vertical, TempoDesign.Spacing.xs)
        .accessibilityElement(children: .contain)
    }
}

struct TempoSessionHeader: View {
    let title: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryItems: [(String, String)]

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.sm) {
            Text(title)
                .font(TempoDesign.Typography.overline)
                .foregroundStyle(TempoDesign.Palette.accentSoft)
            Text(primaryValue)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(primaryLabel)
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            HStack(spacing: TempoDesign.Spacing.lg) {
                ForEach(Array(secondaryItems.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 2) {
                        Text(item.1).font(.caption.monospacedDigit()).foregroundStyle(TempoDesign.Palette.textPrimary)
                        Text(item.0).font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct TempoSessionControlBar: View {
    let pauseTitle: String
    let dangerTitle: String
    let finishTitle: String
    let pause: () -> Void
    let danger: () -> Void
    let finish: () -> Void

    var body: some View {
        HStack(spacing: TempoDesign.Spacing.xs) {
            control(pauseTitle, icon: "pause.fill", tone: .accent, action: pause)
            control(dangerTitle, icon: "hand.raised.fill", tone: .critical, action: danger)
            control(finishTitle, icon: "checkmark", tone: .positive, action: finish)
        }
    }

    private func control(_ title: String, icon: String, tone: TempoBadgeTone, action: @escaping () -> Void) -> some View {
        Button {
            TempoFeedback.impact(.medium)
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: TempoDesign.Layout.sessionControlHeight)
            .foregroundStyle(tone.color)
            .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
        }
        .buttonStyle(TempoTactileButtonStyle())
        .accessibilityLabel(title)
    }
}

struct TempoCompletionMetric: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let icon: String
}

struct TempoCompletionSummary: View {
    let title: String
    let message: String
    let metrics: [TempoCompletionMetric]
    let primaryTitle: String
    let secondaryTitle: String?
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.xl) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 66, weight: .semibold))
                .foregroundStyle(TempoDesign.Palette.positive)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.72)
                .symbolEffect(.bounce, value: appeared && !reduceMotion)
                .accessibilityHidden(true)
            VStack(spacing: TempoDesign.Spacing.xs) {
                Text(title).font(TempoDesign.Typography.pageTitle).multilineTextAlignment(.center)
                Text(message).foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: TempoDesign.Spacing.sm)], spacing: TempoDesign.Spacing.sm) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                        Image(systemName: metric.icon).foregroundStyle(TempoDesign.Palette.accentSoft)
                        Text(metric.value).font(TempoDesign.Typography.numeric)
                        Text(metric.title).font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
                    }
                    .padding(TempoDesign.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
                }
            }
            TempoPrimaryButton(primaryTitle, icon: "arrow.right", action: primaryAction)
            if let secondaryTitle, let secondaryAction {
                TempoSecondaryButton(secondaryTitle, icon: "calendar", tone: .accent, action: secondaryAction)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.72)) { appeared = true }
            UIAccessibility.post(notification: .announcement, argument: title)
        }
        .accessibilityElement(children: .contain)
    }
}

struct TempoEmptyState: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.md) {
            Image(systemName: icon).font(.system(size: 42)).foregroundStyle(TempoDesign.Palette.textTertiary)
            Text(title).font(TempoDesign.Typography.sectionTitle)
            Text(message).font(TempoDesign.Typography.supporting).foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(TempoDesign.Spacing.xl)
    }
}

struct TempoInlineError: View {
    let error: TempoUserFacingError
    let retry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            Label(error.title, systemImage: "exclamationmark.triangle.fill")
                .font(TempoDesign.Typography.cardTitle)
                .foregroundStyle(TempoDesign.Palette.critical)
            Text(error.message).font(TempoDesign.Typography.supporting).foregroundStyle(TempoDesign.Palette.textSecondary)
            if let retry, let title = error.recoveryTitle {
                Button(title, action: retry).foregroundStyle(TempoDesign.Palette.critical).frame(minHeight: 44)
            }
        }
        .padding(TempoDesign.Spacing.md)
        .background(TempoDesign.Palette.critical.opacity(0.10), in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
        .accessibilityElement(children: .contain)
    }
}

struct TempoSelectionCard: View {
    let title: String
    let subtitle: String?
    let icon: String
    let selected: Bool
    let tone: TempoBadgeTone
    let action: () -> Void

    var body: some View {
        Button {
            TempoFeedback.selection()
            action()
        } label: {
            HStack(spacing: TempoDesign.Spacing.md) {
                Image(systemName: icon)
                    .foregroundStyle(selected ? Color.white : tone.color)
                    .frame(width: 38, height: 38)
                    .background(selected ? tone.color : tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(TempoDesign.Typography.cardTitle)
                    if let subtitle { Text(subtitle).font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary) }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? tone.color : TempoDesign.Palette.textTertiary)
            }
            .padding(TempoDesign.Spacing.md)
            .foregroundStyle(TempoDesign.Palette.textPrimary)
            .background(selected ? tone.color.opacity(0.13) : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium))
            .overlay { RoundedRectangle(cornerRadius: TempoDesign.Radius.medium).stroke(selected ? tone.color.opacity(0.42) : TempoDesign.Palette.hairline) }
        }
        .buttonStyle(TempoTactileButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct TempoSegmentedChoice<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: TempoDesign.Spacing.xs) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    selection = option.0
                    TempoFeedback.selection()
                } label: {
                    Text(option.1)
                        .font(TempoDesign.Typography.supporting.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(selection == option.0 ? Color.white : TempoDesign.Palette.textSecondary)
                        .background(selection == option.0 ? TempoDesign.Palette.accent : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
                }
                .buttonStyle(TempoTactileButtonStyle())
                .accessibilityAddTraits(selection == option.0 ? .isSelected : [])
            }
        }
    }
}

struct TempoDisclosureSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let content: Content

    init(title: String, icon: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            Button {
                withAnimation(.snappy(duration: TempoDesign.Motion.quick)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label(title, systemImage: icon).font(TempoDesign.Typography.sectionTitle)
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(TempoDesign.Palette.textPrimary)
                .frame(minHeight: 50)
            }
            .buttonStyle(TempoTactileButtonStyle())
            if isExpanded {
                content.transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, TempoDesign.Spacing.xs)
        .overlay(alignment: .bottom) { Divider().overlay(TempoDesign.Palette.hairline) }
    }
}

// MARK: - Calendar visual state

enum TempoCalendarDayVisualState: String, Equatable, Sendable {
    case empty
    case upcoming
    case completed
    case adapted
    case skipped
    case recovery
    case replacement

    var symbol: String {
        switch self {
        case .empty: "circle"
        case .upcoming: "circle.fill"
        case .completed: "checkmark.circle.fill"
        case .adapted: "circle.lefthalf.filled"
        case .skipped: "minus"
        case .recovery: "leaf.fill"
        case .replacement: "arrow.triangle.swap"
        }
    }

    var tone: TempoBadgeTone {
        switch self {
        case .empty, .skipped: .neutral
        case .upcoming, .replacement: .accent
        case .completed: .positive
        case .adapted, .recovery: .caution
        }
    }
}

struct TempoCalendarVisualResolver {
    static func state(for items: [LocalPlanDay]) -> TempoCalendarDayVisualState {
        guard !items.isEmpty else { return .empty }
        if items.contains(where: { $0.rescheduledFromID != nil }) { return .replacement }
        if items.contains(where: { $0.status == .completed }) { return .completed }
        if items.contains(where: { $0.status == .recovery || $0.effectiveKind == .recovery }) { return .recovery }
        if items.contains(where: { $0.status == .adapted }) { return .adapted }
        if items.allSatisfy({ $0.status == .skipped }) { return .skipped }
        return .upcoming
    }
}

struct TempoCalendarDayCell: View {
    let date: Date
    let state: TempoCalendarDayVisualState
    let selected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(date.formatted(.dateTime.weekday(.narrow))).font(TempoDesign.Typography.caption)
                Text(date.formatted(.dateTime.day())).font(TempoDesign.Typography.cardTitle)
                Image(systemName: state.symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(selected ? Color.white : state.tone.color)
            }
            .foregroundStyle(selected ? Color.white : TempoDesign.Palette.textSecondary)
            .frame(width: 52, height: 72)
            .background(selected ? TempoDesign.Palette.accent : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
            .overlay {
                RoundedRectangle(cornerRadius: TempoDesign.Radius.small)
                    .stroke(isToday && !selected ? TempoDesign.Palette.accentSoft : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(TempoTactileButtonStyle())
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(state.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Trends

enum TempoTrendState: String, Codable, Sendable {
    case insufficient
    case stable
    case improving
    case attention

    var title: String {
        switch self {
        case .insufficient: "Belum cukup data"
        case .stable: "Stabil"
        case .improving: "Membaik"
        case .attention: "Perlu perhatian"
        }
    }

    var tone: TempoBadgeTone {
        switch self {
        case .insufficient, .stable: .neutral
        case .improving: .positive
        case .attention: .caution
        }
    }
}

enum TempoProgressTrendKind: String, CaseIterable, Sendable {
    case boundaryAwareness
    case recovery
    case emergencyPause
    case consistency
    case sessionAnxiety

    var title: String {
        switch self {
        case .boundaryAwareness: "Mengenali batas"
        case .recovery: "Pemulihan"
        case .emergencyPause: "Emergency pause"
        case .consistency: "Konsistensi"
        case .sessionAnxiety: "Kecemasan sesi"
        }
    }

    var icon: String {
        switch self {
        case .boundaryAwareness: "gauge.with.dots.needle.67percent"
        case .recovery: "leaf.fill"
        case .emergencyPause: "hand.raised.fill"
        case .consistency: "calendar.badge.checkmark"
        case .sessionAnxiety: "waveform.path.ecg"
        }
    }
}

struct TempoProgressTrend: Identifiable, Equatable {
    let kind: TempoProgressTrendKind
    let state: TempoTrendState
    let headline: String
    let detail: String
    let currentValue: Double?
    let previousValue: Double?
    let sampleCount: Int

    var id: String { kind.rawValue }
}

struct TempoTrendCard: View {
    let trend: TempoProgressTrend

    var body: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            HStack {
                Label(trend.kind.title, systemImage: trend.kind.icon).font(TempoDesign.Typography.cardTitle)
                Spacer()
                TempoStatusBadge(trend.state.title, tone: trend.state.tone)
            }
            Text(trend.headline).font(TempoDesign.Typography.sectionTitle)
            Text(trend.detail).font(TempoDesign.Typography.supporting).foregroundStyle(TempoDesign.Palette.textSecondary)
            Text("\(trend.sampleCount) sampel")
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(TempoDesign.Palette.textTertiary)
        }
        .padding(TempoDesign.Spacing.lg)
        .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium))
        .overlay { RoundedRectangle(cornerRadius: TempoDesign.Radius.medium).stroke(TempoDesign.Palette.hairline) }
        .accessibilityElement(children: .combine)
    }
}

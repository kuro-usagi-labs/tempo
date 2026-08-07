import SwiftUI

// MARK: - Shared screen state

enum TempoScreenState<Value> {
    case loading
    case content(Value)
    case empty
    case failure(TempoUserFacingError)
}

struct TempoUserFacingError: Error, Equatable, Identifiable {
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

// MARK: - Motion

struct TempoMotionPolicy {
    let reduceMotion: Bool
    let hapticsEnabled: Bool
    let sceneIsActive: Bool

    var selectionAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0.08)
    }

    var stateAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.32)
    }

    var warningAnimation: Animation? {
        guard !reduceMotion, sceneIsActive else { return nil }
        return .easeOut(duration: 0.72).repeatForever(autoreverses: false)
    }
}

// MARK: - Intensity zones

enum TempoIntensityZone: String, Codable, CaseIterable, Identifiable {
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

    var symbol: String {
        switch self {
        case .calm: "circle"
        case .rising: "waveform.path"
        case .medium: "waveform"
        case .nearLimit: "exclamationmark.circle"
        case .critical: "hand.raised.fill"
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

    static func from(numericValue: Int) -> TempoIntensityZone {
        switch min(10, max(1, numericValue)) {
        case 1...2: .calm
        case 3...4: .rising
        case 5...6: .medium
        case 7...8: .nearLimit
        default: .critical
        }
    }
}

// MARK: - Calendar presentation

enum TempoCalendarDayVisualState: String, CaseIterable {
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
        case .completed, .recovery: .positive
        case .adapted: .caution
        }
    }
}

// MARK: - Progress presentation

enum TempoTrendState: String, Codable {
    case insufficientData
    case stable
    case improving
    case needsAttention

    var title: String {
        switch self {
        case .insufficientData: "Belum cukup data"
        case .stable: "Stabil"
        case .improving: "Membaik"
        case .needsAttention: "Perlu perhatian"
        }
    }

    var tone: TempoBadgeTone {
        switch self {
        case .insufficientData: .neutral
        case .stable: .accent
        case .improving: .positive
        case .needsAttention: .caution
        }
    }
}

struct TempoProgressTrend: Identifiable, Equatable {
    let id: String
    let title: String
    let state: TempoTrendState
    let headline: String
    let detail: String
    let currentValue: Double?
    let previousValue: Double?
    let sampleCount: Int
}

// MARK: - Layout foundations

struct TempoScreenContainer<Content: View, BottomBar: View>: View {
    private let content: Content
    private let bottomBar: BottomBar

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottomBar: () -> BottomBar
    ) {
        self.content = content()
        self.bottomBar = bottomBar()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TempoDesign.Palette.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                content
                    .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
                    .padding(.horizontal, TempoDesign.Spacing.lg)
                    .padding(.top, TempoDesign.Spacing.lg)
                    .padding(.bottom, 132)
            }
            bottomBar
        }
    }
}

extension TempoScreenContainer where BottomBar == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, bottomBar: { EmptyView() })
    }
}

struct TempoStickyActionBar<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: TempoDesign.readableContentWidth)
            .padding(.horizontal, TempoDesign.Spacing.lg)
            .padding(.top, TempoDesign.Spacing.sm)
            .padding(.bottom, TempoDesign.Spacing.sm)
            .background {
                Rectangle()
                    .fill(reduceTransparency ? TempoDesign.Palette.canvas : TempoDesign.Palette.canvas.opacity(0.92))
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                Divider().overlay(TempoDesign.Palette.hairline)
            }
    }
}

struct TempoHeroCard<Actions: View>: View {
    let eyebrow: String?
    let title: String
    let detail: String
    let symbol: String
    let tone: TempoBadgeTone
    private let actions: Actions

    init(
        eyebrow: String? = nil,
        title: String,
        detail: String,
        symbol: String,
        tone: TempoBadgeTone = .accent,
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tone = tone
        self.actions = actions()
    }

    var body: some View {
        TempoSurfaceCard(tint: tone.color, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                HStack(alignment: .top, spacing: TempoDesign.Spacing.md) {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                        if let eyebrow {
                            Text(eyebrow)
                                .font(TempoDesign.Typography.overline)
                                .foregroundStyle(tone.color)
                        }
                        Text(title)
                            .font(TempoDesign.Typography.pageTitle)
                            .foregroundStyle(TempoDesign.Palette.textPrimary)
                        Text(detail)
                            .font(TempoDesign.Typography.supporting)
                            .foregroundStyle(TempoDesign.Palette.textSecondary)
                    }
                    Spacer(minLength: TempoDesign.Spacing.sm)
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(tone.color)
                        .accessibilityHidden(true)
                }
                actions
            }
        }
    }
}

struct TempoCompactStatusRow: View {
    let title: String
    let detail: String?
    let symbol: String
    let tone: TempoBadgeTone
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        detail: String? = nil,
        symbol: String,
        tone: TempoBadgeTone = .neutral,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tone = tone
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: TempoDesign.Spacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(tone.color)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(TempoDesign.Typography.cardTitle)
                if let detail {
                    Text(detail)
                        .font(TempoDesign.Typography.caption)
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(TempoDesign.Typography.supporting)
                    .foregroundStyle(tone.color)
                    .frame(minHeight: 44)
            }
        }
        .padding(.vertical, TempoDesign.Spacing.xs)
    }
}

struct TempoSessionHeader: View {
    let primaryLabel: String
    let primaryValue: String
    let secondaryItems: [(String, String)]

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.sm) {
            Text(primaryLabel)
                .font(TempoDesign.Typography.overline)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            Text(primaryValue)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            HStack(spacing: TempoDesign.Spacing.lg) {
                ForEach(Array(secondaryItems.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 2) {
                        Text(item.0).font(TempoDesign.Typography.caption)
                        Text(item.1).font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TempoSessionControlBar: View {
    let pauseTitle: String
    let onPause: () -> Void
    let onNearLimit: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: TempoDesign.Spacing.sm) {
            sessionButton(pauseTitle, symbol: "pause.fill", tone: .accent, action: onPause)
            sessionButton("Mendekati batas", symbol: "hand.raised.fill", tone: .caution, action: onNearLimit)
            sessionButton("Selesai", symbol: "checkmark", tone: .neutral, action: onFinish)
        }
        .accessibilityElement(children: .contain)
    }

    private func sessionButton(
        _ title: String,
        symbol: String,
        tone: TempoBadgeTone,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(TempoDesign.Typography.caption).lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundStyle(tone.color)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(TempoTactileButtonStyle())
    }
}

struct TempoCompletionMetric: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct TempoCompletionSummary<Actions: View>: View {
    let title: String
    let detail: String
    let metrics: [TempoCompletionMetric]
    private let actions: Actions

    init(
        title: String,
        detail: String,
        metrics: [TempoCompletionMetric],
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.detail = detail
        self.metrics = metrics
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(TempoDesign.Palette.positive)
                .symbolEffect(.bounce, value: metrics)
                .accessibilityHidden(true)
            VStack(spacing: TempoDesign.Spacing.xs) {
                Text(title).font(TempoDesign.Typography.pageTitle)
                Text(detail)
                    .font(TempoDesign.Typography.supporting)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TempoDesign.Spacing.sm) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(metric.title)
                            .font(TempoDesign.Typography.caption)
                            .foregroundStyle(TempoDesign.Palette.textSecondary)
                        Text(metric.value)
                            .font(TempoDesign.Typography.numeric)
                            .foregroundStyle(TempoDesign.Palette.textPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                    .padding(TempoDesign.Spacing.sm)
                    .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
                }
            }
            actions
        }
        .accessibilityElement(children: .contain)
    }
}

struct TempoEmptyState: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
            .foregroundStyle(TempoDesign.Palette.textSecondary)
    }
}

struct TempoInlineError: View {
    let error: TempoUserFacingError
    let retry: (() -> Void)?

    var body: some View {
        TempoSurfaceCard(tint: TempoDesign.Palette.critical, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                Label(error.title, systemImage: "exclamationmark.triangle.fill")
                    .font(TempoDesign.Typography.cardTitle)
                    .foregroundStyle(TempoDesign.Palette.critical)
                Text(error.message)
                    .font(TempoDesign.Typography.supporting)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                if let retry, let recoveryTitle = error.recoveryTitle {
                    Button(recoveryTitle, action: retry)
                        .font(TempoDesign.Typography.cardTitle)
                        .foregroundStyle(TempoDesign.Palette.critical)
                        .frame(minHeight: 44)
                }
            }
        }
    }
}

struct TempoSelectionCard: View {
    let title: String
    let detail: String?
    let symbol: String
    let selected: Bool
    let tone: TempoBadgeTone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TempoDesign.Spacing.md) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(selected ? tone.color : TempoDesign.Palette.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(TempoDesign.Typography.cardTitle)
                    if let detail {
                        Text(detail)
                            .font(TempoDesign.Typography.caption)
                            .foregroundStyle(TempoDesign.Palette.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? tone.color : TempoDesign.Palette.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(TempoDesign.Palette.textPrimary)
            .padding(TempoDesign.Spacing.md)
            .background(selected ? tone.color.opacity(0.14) : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
            .scaleEffect(selected ? 1 : 0.995)
        }
        .buttonStyle(TempoTactileButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct TempoSegmentedChoice<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: TempoDesign.Spacing.xs) {
            ForEach(values, id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    Text(title(value))
                        .font(TempoDesign.Typography.supporting)
                        .foregroundStyle(selection == value ? Color.white : TempoDesign.Palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selection == value ? TempoDesign.Palette.accent : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
                }
                .buttonStyle(TempoTactileButtonStyle())
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
    }
}

struct TempoIntensityZoneControl: View {
    @Binding var zone: TempoIntensityZone
    var allowedZones: [TempoIntensityZone] = TempoIntensityZone.allCases

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragStartZone: TempoIntensityZone?

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = proxy.size.width / CGFloat(max(1, allowedZones.count))
            HStack(spacing: 0) {
                ForEach(allowedZones) { option in
                    Button {
                        set(option)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: option.symbol)
                                .font(.title3)
                            Text(option.title)
                                .font(TempoDesign.Typography.caption)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(zone == option ? Color.white : option.tone.color)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(zone == option ? option.tone.color : option.tone.color.opacity(0.10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityValue("Nilai internal \(option.numericValue) dari 10")
                    .accessibilityAddTraits(zone == option ? .isSelected : [])
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous)
                    .stroke(TempoDesign.Palette.hairline, lineWidth: 1)
            }
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        if dragStartZone == nil { dragStartZone = zone }
                        let index = min(allowedZones.count - 1, max(0, Int(value.location.x / max(1, itemWidth))))
                        set(allowedZones[index])
                    }
                    .onEnded { _ in dragStartZone = nil }
            )
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: zone)
        }
        .frame(height: 64)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zona intensitas")
        .accessibilityValue("\(zone.title), nilai \(zone.numericValue) dari 10")
    }

    private func set(_ newZone: TempoIntensityZone) {
        guard zone != newZone else { return }
        zone = newZone
    }
}

struct TempoCalendarDayCell: View {
    let date: Date
    let selected: Bool
    let isToday: Bool
    let visualState: TempoCalendarDayVisualState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(TempoDesign.Typography.caption)
                Text(date.formatted(.dateTime.day()))
                    .font(TempoDesign.Typography.cardTitle)
                Image(systemName: visualState.symbol)
                    .font(.caption2)
                    .foregroundStyle(selected ? Color.white : visualState.tone.color)
            }
            .foregroundStyle(selected ? Color.white : TempoDesign.Palette.textSecondary)
            .frame(width: 52, height: 72)
            .background(selected ? TempoDesign.Palette.accent : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous)
                        .stroke(TempoDesign.Palette.accentSoft, lineWidth: 2)
                }
            }
        }
        .buttonStyle(TempoTactileButtonStyle())
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue("\(visualState.rawValue)\(isToday ? ", hari ini" : "")")
    }
}

struct TempoTrendCard: View {
    let trend: TempoProgressTrend

    var body: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            HStack {
                Text(trend.title).font(TempoDesign.Typography.cardTitle)
                Spacer()
                TempoStatusBadge(trend.state.title, tone: trend.state.tone)
            }
            Text(trend.headline)
                .font(TempoDesign.Typography.sectionTitle)
                .foregroundStyle(TempoDesign.Palette.textPrimary)
            Text(trend.detail)
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            Text("\(trend.sampleCount) contoh")
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(TempoDesign.Palette.textTertiary)
        }
        .padding(TempoDesign.Spacing.md)
        .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct TempoDisclosureSection<Content: View>: View {
    let title: String
    let detail: String?
    @Binding var isExpanded: Bool
    private let content: Content

    init(
        title: String,
        detail: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(TempoDesign.Typography.sectionTitle)
                        if let detail {
                            Text(detail)
                                .font(TempoDesign.Typography.caption)
                                .foregroundStyle(TempoDesign.Palette.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(TempoDesign.Palette.textTertiary)
                }
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Dibuka" : "Ditutup")
            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
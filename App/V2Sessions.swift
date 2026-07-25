import SwiftUI
import Combine
import AVFoundation

private func tempoDuration(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    return "\(safe / 60):\(String(format: "%02d", safe % 60))"
}

/// Shared V2 breathing cue. It deliberately lives with the active V2 session
/// flows so the retired V1 views are no longer compiled merely for this small
/// visual component.
struct BreathingOrbView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 150, height: 150)
            .shadow(color: .cyan.opacity(0.5), radius: 24)
            .scaleEffect(expanded || reduceMotion ? 1 : 0.72)
            .animation(reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: expanded)
            .onAppear { expanded = true }
            .accessibilityLabel("Panduan napas")
    }
}

private extension ImmediateActionChoice {
    var id: String { rawValue }
    var title: String {
        switch self {
        case .privateSession: "Sesi privat"
        case .reset: "Reset dulu"
        case .guided: "Sesi terpandu"
        }
    }
    var subtitle: String {
        switch self {
        case .privateSession: "Atur ritme secara pribadi, dengan timer dan jeda."
        case .reset: "Beri dorongan ruang lima menit sebelum memilih."
        case .guided: "Latihan terstruktur bila kondisi dan pemulihan memadai."
        }
    }
    var icon: String {
        switch self {
        case .privateSession: "hand.raised.fill"
        case .reset: "wind"
        case .guided: "timer"
        }
    }
}

/// The immediate flow has exactly three decisions: action, intensity, and a
/// compact symptom confirmation. It routes directly; no secondary sheet stack.
struct TempoImmediateActionScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @State private var step = 0
    @State private var choice: ImmediateActionChoice = .reset
    @State private var intensity: Int
    @State private var symptomReported = false
    @State private var saveFailed = false

    init(initialIntensity: Int = 5) {
        _intensity = State(initialValue: min(10, max(1, initialIntensity)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xl) {
            HStack {
                Text("Keputusan cepat").font(TempoDesign.Typography.pageTitle)
                Spacer()
                Text("\(step + 1) / 3").font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
            }
            SwiftUI.ProgressView(value: Double(step + 1), total: 3).tint(TempoDesign.Palette.accent)
            Group {
                if step == 0 { choiceStep }
                else if step == 1 { intensityStep }
                else { symptomStep }
            }
            Spacer(minLength: TempoDesign.Spacing.md)
            HStack(spacing: TempoDesign.Spacing.sm) {
                if step > 0 { TempoSecondaryButton("Kembali", icon: "chevron.left") { step -= 1 } }
                TempoPrimaryButton(step == 2 ? "Lanjutkan" : "Berikutnya", icon: "arrow.right") { advance() }
            }
        }
        .padding(TempoDesign.Spacing.lg)
        .frame(maxWidth: TempoDesign.readableContentWidth, maxHeight: .infinity, alignment: .topLeading)
        .background(TempoDesign.Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert("Catatan belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { route() } } message: { Text("TEMPO tidak meneruskan alur sebelum catatan lokal tersimpan dengan aman.") }
        .accessibilityIdentifier("immediate.action")
    }

    private var choiceStep: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            Text("Apa yang kamu butuhkan sekarang?").font(TempoDesign.Typography.sectionTitle)
            ForEach(ImmediateActionChoice.allCases, id: \.self) { option in
                Button { choice = option } label: {
                    HStack(spacing: TempoDesign.Spacing.md) {
                        Image(systemName: option.icon).foregroundStyle(choice == option ? TempoDesign.Palette.accentSoft : TempoDesign.Palette.textSecondary).frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title).font(TempoDesign.Typography.cardTitle)
                            Text(option.subtitle).font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: choice == option ? "checkmark.circle.fill" : "circle").foregroundStyle(TempoDesign.Palette.accentSoft)
                    }
                    .padding(TempoDesign.Spacing.md)
                    .background(choice == option ? TempoDesign.Palette.accent.opacity(0.16) : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
                }
                .buttonStyle(TempoTactileButtonStyle())
                .accessibilityLabel(option.title)
                .accessibilityHint(option.subtitle)
                .accessibilityIdentifier("immediate.choice.\(option.rawValue)")
            }
        }
    }

    private var intensityStep: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            Text("Seberapa kuat dorongannya?").font(TempoDesign.Typography.sectionTitle)
            Text("Pilih angka yang paling mendekati sekarang. Ini membantu memilih tempo, bukan menilai kamu.").foregroundStyle(TempoDesign.Palette.textSecondary)
            TempoIntensitySelector(value: $intensity, accent: intensity >= 8 ? TempoDesign.Palette.caution : TempoDesign.Palette.accentSoft)
        }
    }

    private var symptomStep: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            Text("Ada gejala yang perlu diperiksa sekarang?").font(TempoDesign.Typography.sectionTitle)
            Text("Nyeri, darah, demam, perih saat kencing, cairan tidak biasa, cedera, atau iritasi baru?").foregroundStyle(TempoDesign.Palette.textSecondary)
            HStack(spacing: TempoDesign.Spacing.sm) {
                choiceButton("Tidak", selected: !symptomReported) { symptomReported = false }
                choiceButton("Ya", selected: symptomReported, tone: .caution) { symptomReported = true }
            }
            if symptomReported {
                TempoStatusBadge("Kita hentikan latihan dan buka pemeriksaan singkat.", tone: .caution)
            }
        }
    }

    private func choiceButton(_ title: String, selected: Bool, tone: TempoBadgeTone = .accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(TempoDesign.Typography.cardTitle).frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(selected ? Color.white : tone.color)
                .background(selected ? tone.color : tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
        }.buttonStyle(TempoTactileButtonStyle())
    }

    private func advance() {
        guard step < 2 else { route(); return }
        step += 1
    }

    private func route() {
        let intent: UrgeIntent
        switch choice {
        case .privateSession: intent = .privateSession
        case .reset: intent = .calm
        case .guided: intent = .training
        }
        let activeHold = history.activeSafetyHold
        let activeHoldSeverity = activeHold.flatMap { RecommendationSeverity(rawValue: $0.severity) }
        let todayReadiness = history.todayReadiness
        // Recent sessions are a useful trend, but they must not become an
        // assertion about the user's state right now. Only today's check-in
        // can trigger current anxiety/sleep advisories in this quick route.
        let immediateAnxiety = todayReadiness?.anxietyToday ?? min(7, history.baseline?.anxiety ?? 5)
        let request = ImmediateActionRequest(
            choice: choice,
            intensity: intensity,
            anxiety: immediateAnxiety,
            sleepHours: todayReadiness?.sleepHoursLastNight,
            hoursSinceLastGuidedSession: history.hoursSinceLastSession,
            hoursSinceLastPrivateSession: history.hoursSinceLastPrivateSession,
            guidedSessionsLast7Days: history.guidedSessionsLast7Days,
            guidedEligibility: history.guidedEligibility,
            hasCurrentPhysicalSymptoms: symptomReported,
            hasActiveSafetyHold: history.hasSafetyBlock,
            activeSafetyHoldSeverity: activeHoldSeverity ?? (history.hasSafetyBlock ? .medical : nil),
            activeSafetyHoldReason: activeHold?.reasonCode ?? (history.hasSafetyBlock ? "safety.pending-write" : nil),
            activeSafetyHoldRecheckDate: activeHold?.recheckNotBefore
        )
        let result = ImmediateActionRouter().route(request)
        let recommendation: Recommendation
        switch result.destination {
        case .healthCheck:
            let currentSymptoms = request.hasCurrentPhysicalSymptoms
            recommendation = Recommendation(
                .healthCheck,
                result.activeSafetyHoldSeverity ?? .urgent,
                currentSymptoms ? "safety.immediate-symptoms" : "immediate.active-safety-hold",
                currentSymptoms ? "Gejala fisik perlu diperiksa sebelum melanjutkan." : "Safety hold aktif masih memerlukan pemeriksaan ulang.",
                blocked: true
            )
        case .recoveryBlocked:
            recommendation = Recommendation(.recovery, .caution, "immediate.active-irritation-hold", "Masa pemulihan iritasi masih aktif.", blocked: true)
        case .privateSession:
            recommendation = Recommendation(.privateSession, result.advisories.isEmpty ? .normal : .caution, "immediate.private", "Sesi privat dipilih secara langsung.")
        case .guided:
            recommendation = Recommendation(.guidedSession, .normal, "immediate.guided", "Sesi terpandu tersedia.")
        case .guidedUnavailable:
            recommendation = Recommendation(.recovery, .caution, "immediate.guided-unavailable", result.guidedEligibility?.message ?? "Sesi terpandu belum tersedia.")
        case .reset:
            recommendation = Recommendation(.urgeSurf, .normal, "immediate.reset", "Reset lima menit dipilih.")
        }
        guard history.add(intensity: intensity, trigger: .desire, intent: intent, recommendation: recommendation) else { saveFailed = true; return }
        switch result.destination {
        case .healthCheck: replaceWith(.healthCheck)
        case .recoveryBlocked:
            replaceWith(.safetyRecoveryBlock(result.activeSafetyHoldReason, result.activeSafetyHoldRecheckDate))
        case .privateSession: replaceWith(.privateSession(result.advisories))
        case .guided: replaceWith(.guided(nil))
        case .guidedUnavailable:
            let eligibility = result.guidedEligibility ?? history.guidedEligibility
            replaceWith(.guidedUnavailable(eligibility.reason, eligibility.message, history.guidedNextAvailableAt))
        case .reset: replaceWith(.breathing(nil, "Reset lima menit", 300))
        }
    }

    private func replaceWith(_ route: TempoRoute) {
        if let last = coordinator.path.last, case .immediateAction = last { coordinator.path.removeLast() }
        coordinator.open(route)
    }
}

struct TempoGuidedUnavailableScreen: View {
    let reason: GuidedEligibilityReason
    let message: String
    let nextAvailableAt: Date?
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Spacer()
            Image(systemName: reason == .safetyHold ? "cross.case.fill" : "clock.badge.exclamationmark")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(TempoDesign.Palette.caution)
            Text("Sesi terpandu belum tersedia").font(TempoDesign.Typography.pageTitle).multilineTextAlignment(.center)
            Text(message).foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            if let nextAvailableAt {
                TempoStatusBadge("Tersedia kembali sekitar \(nextAvailableAt.formatted(date: .abbreviated, time: .shortened))", tone: .neutral, icon: "calendar")
            }
            if reason == .safetyHold {
                TempoPrimaryButton("Buka pemeriksaan", icon: "cross.case.fill") { coordinator.open(.healthCheck) }
            } else {
                TempoPrimaryButton("Pilih sesi privat", icon: "hand.raised.fill") { coordinator.open(.privateSession([])) }
                TempoSecondaryButton("Reset lima menit", icon: "wind", tone: .caution) { coordinator.open(.breathing(nil, "Reset lima menit", 300)) }
            }
            TempoSecondaryButton("Kembali", icon: "chevron.left", tone: .neutral) { dismiss() }
            Spacer()
        }
        .padding(TempoDesign.Spacing.lg)
        .frame(maxWidth: TempoDesign.readableContentWidth, maxHeight: .infinity)
        .background(TempoDesign.Palette.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .accessibilityIdentifier("guided.unavailable")
    }
}

/// A mild irritation hold is a recovery window, not an invitation to start a
/// different kind of session. This route deliberately contains no reset or
/// private-session shortcut.
struct TempoSafetyRecoveryBlockScreen: View {
    let reason: String?
    let recheckDate: Date?
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Spacer()
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(TempoDesign.Palette.caution)
            Text("Masa pemulihan masih aktif")
                .font(TempoDesign.Typography.pageTitle)
                .multilineTextAlignment(.center)
            Text(reasonMessage)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let recheckDate {
                TempoStatusBadge(
                    recheckDate > .now
                        ? "Periksa ulang sekitar \(recheckDate.formatted(date: .abbreviated, time: .shortened))"
                        : "Waktu pemulihan telah tiba — lakukan pemeriksaan ulang sebelum melanjutkan.",
                    tone: .neutral,
                    icon: "calendar"
                )
            }
            TempoPrimaryButton("Buka pemeriksaan", icon: "cross.case.fill") { coordinator.open(.healthCheck) }
            TempoSecondaryButton("Kembali", icon: "chevron.left", tone: .neutral) { dismiss() }
            Spacer()
        }
        .padding(TempoDesign.Spacing.lg)
        .frame(maxWidth: TempoDesign.readableContentWidth, maxHeight: .infinity)
        .background(TempoDesign.Palette.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .accessibilityIdentifier("safety.recovery.blocked")
    }

    private var reasonMessage: String {
        guard let reason, reason.localizedCaseInsensitiveContains("irritation") else {
            return "Tubuh masih membutuhkan pemulihan sebelum sesi dapat dimulai."
        }
        return "Iritasi ringan sebelumnya masih dalam masa pemulihan. Hindari memulai sesi sampai pemeriksaan ulang aman."
    }
}

struct TempoIntensitySelector: View {
    @Binding var value: Int
    let accent: Color

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.md) {
            Text("\(value) / 10").font(.system(size: 48, weight: .bold, design: .rounded)).foregroundStyle(accent).monospacedDigit()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TempoDesign.Spacing.xs), count: 5), spacing: TempoDesign.Spacing.xs) {
                ForEach(1...10, id: \.self) { level in
                    Button { value = level } label: {
                        Text("\(level)").font(TempoDesign.Typography.cardTitle).frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(value == level ? Color.white : TempoDesign.Palette.textPrimary)
                            .background(value == level ? accent : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(TempoTactileButtonStyle())
                    .accessibilityIdentifier("intensity.level.\(level)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Intensitas saat ini")
        .accessibilityValue("\(value) dari 10")
    }
}

enum SessionIntensityZone: String, CaseIterable, Identifiable, Equatable {
    case calm
    case rising
    case limit

    var id: String { rawValue }

    func value(threshold: Int) -> Int {
        switch self {
        case .calm: 3
        case .rising: max(5, min(6, threshold - 1))
        case .limit: min(10, max(7, threshold))
        }
    }

    static func selected(for value: Int, threshold: Int) -> SessionIntensityZone {
        if value >= threshold { return .limit }
        if value >= 5 { return .rising }
        return .calm
    }
}

private enum SessionIntensityMode: Equatable {
    case active
    case recovery
}

private struct TempoSessionIntensityZones: View {
    @Binding var value: Int
    let threshold: Int
    let mode: SessionIntensityMode

    var body: some View {
        HStack(spacing: TempoDesign.Spacing.xs) {
            ForEach(SessionIntensityZone.allCases) { zone in
                let selected = SessionIntensityZone.selected(for: value, threshold: threshold) == zone
                Button {
                    value = zone.value(threshold: threshold)
                } label: {
                    VStack(spacing: 4) {
                        Text(title(for: zone))
                            .font(TempoDesign.Typography.cardTitle)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(detail(for: zone))
                            .font(TempoDesign.Typography.caption)
                            .foregroundStyle(selected ? Color.white.opacity(0.82) : TempoDesign.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .padding(.horizontal, 4)
                    .foregroundStyle(selected ? Color.white : TempoDesign.Palette.textPrimary)
                    .background(selected ? tint(for: zone) : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected ? tint(for: zone) : TempoDesign.Palette.hairline, lineWidth: selected ? 2 : 1)
                    }
                }
                .buttonStyle(TempoTactileButtonStyle())
                .accessibilityIdentifier("intensity.zone.\(zone.rawValue)")
                .accessibilityLabel(title(for: zone))
                .accessibilityValue(selected ? "Dipilih" : "Tidak dipilih")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(mode == .active ? "Zona intensitas saat ini" : "Kondisi tubuh saat pemulihan")
    }

    private func title(for zone: SessionIntensityZone) -> String {
        switch (mode, zone) {
        case (.active, .calm): "Masih tenang"
        case (.active, .rising): "Mulai naik"
        case (.active, .limit): "Dekat batas"
        case (.recovery, .calm): "Sudah tenang"
        case (.recovery, .rising): "Masih naik"
        case (.recovery, .limit): "Masih tinggi"
        }
    }

    private func detail(for zone: SessionIntensityZone) -> String {
        switch zone {
        case .calm: "1–4"
        case .rising: "5–6"
        case .limit: "\(max(7, threshold))+"
        }
    }

    private func tint(for zone: SessionIntensityZone) -> Color {
        switch zone {
        case .calm: TempoDesign.Palette.positive
        case .rising: TempoDesign.Palette.caution
        case .limit: TempoDesign.Palette.critical
        }
    }
}

private struct TempoSessionActiveControls: View {
    @Binding var intensity: Int
    let threshold: Int
    let onPause: () -> Void
    let onEmergency: () -> Void

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.sm) {
            TempoSessionIntensityZones(value: $intensity, threshold: threshold, mode: .active)
            Button(action: onPause) {
                Label("JEDA — LEPAS TANGAN", systemImage: "pause.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .foregroundStyle(Color.white)
                    .background(TempoDesign.Palette.caution, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(TempoTactileButtonStyle())
            .accessibilityIdentifier("session.pause.fixed")

            Button(action: onEmergency) {
                Label("Hampir keluar", systemImage: "hand.raised.fill")
                    .font(TempoDesign.Typography.cardTitle)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(TempoDesign.Palette.critical)
                    .background(TempoDesign.Palette.critical.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(TempoDesign.Palette.critical.opacity(0.48), lineWidth: 1)
                    }
            }
            .buttonStyle(TempoTactileButtonStyle())
            .accessibilityIdentifier("session.emergency.fixed")
        }
    }
}

private struct TempoSessionRecoveryControls: View {
    @Binding var intensity: Int
    let threshold: Int
    let elapsedSeconds: Int
    let minimumSeconds: Int
    let cycleCount: Int
    let continueTitle: String
    let onContinue: () -> Void
    let onFinish: () -> Void

    private var remainingSeconds: Int { max(0, minimumSeconds - elapsedSeconds) }
    private var isCalm: Bool { intensity <= 4 }
    private var isReady: Bool { remainingSeconds == 0 && isCalm }
    private var blockedReason: String {
        if remainingSeconds > 0 { return "Tunggu \(remainingSeconds) detik lagi" }
        if !isCalm { return "Pilih “Sudah tenang” saat tubuh benar-benar siap" }
        return "Tubuh sudah cukup tenang"
    }

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.sm) {
            BreathingOrbView()
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)
            Text("Lepas tangan dan bernapas")
                .font(TempoDesign.Typography.sectionTitle)
                .multilineTextAlignment(.center)
            Text(remainingSeconds > 0 ? "\(remainingSeconds)" : "Siap")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isReady ? TempoDesign.Palette.positive : TempoDesign.Palette.caution)
                .accessibilityLabel(remainingSeconds > 0 ? "\(remainingSeconds) detik tersisa" : "Waktu minimum selesai")
            TempoSessionIntensityZones(value: $intensity, threshold: threshold, mode: .recovery)
            Text(blockedReason)
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(isReady ? TempoDesign.Palette.positive : TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("session.recovery.reason")
            TempoPrimaryButton(
                isReady ? continueTitle : blockedReason,
                icon: isReady ? "play.fill" : "hourglass",
                isEnabled: isReady,
                action: onContinue
            )
            .accessibilityIdentifier("session.recovery.continue")
            TempoSecondaryButton("Cukup untuk hari ini", icon: "checkmark", tone: .positive, action: onFinish)
                .accessibilityIdentifier("session.recovery.finish")
            Text("\(cycleCount) putaran selesai")
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(TempoDesign.Palette.textTertiary)
        }
        .accessibilityIdentifier("session.recovery.shared")
    }
}

private enum PostSessionSymptom: String, CaseIterable, Identifiable, Hashable {
    case none
    case irritation
    case pain

    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Tidak ada"
        case .irritation: "Iritasi"
        case .pain: "Nyeri"
        }
    }
}

private struct TempoPostSessionSymptomPicker: View {
    @Binding var selection: PostSessionSymptom

    var body: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            Text("Ada nyeri atau iritasi?")
                .font(TempoDesign.Typography.cardTitle)
            Picker("Kondisi fisik setelah sesi", selection: $selection) {
                ForEach(PostSessionSymptom.allCases) { symptom in
                    Text(symptom.title).tag(symptom)
                }
            }
            .pickerStyle(.segmented)
            Text(selection == .none ? "Pilih sesuai kondisi tubuhmu sekarang." : "TEMPO akan menghentikan latihan dan membuka pemeriksaan.")
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(selection == .none ? TempoDesign.Palette.textSecondary : TempoDesign.Palette.caution)
        }
    }
}

struct TempoPrivateSessionTimerScreen: View {
    let advisories: [ImmediateActionAdvisory]
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var assistanceEnabled = true
    @State private var spokenPromptsEnabled = false
    @State private var speaker = AVSpeechSynthesizer()
    @State private var phase: PrivatePhase = .ready
    @State private var startedAt: Date?
    @State private var activeSeconds = 0
    @State private var totalRecoverySeconds = 0
    @State private var currentRecoverySeconds = 0
    @State private var totalSessionSeconds = 0
    @State private var manualPauseCount = 0
    @State private var thresholdPauseCount = 0
    @State private var emergencyPauseCount = 0
    @State private var interruptionPauseCount = 0
    @State private var cycleTracker = PrivateSessionCycleTracker()
    @State private var intensity = 3
    @State private var saveDetails = false
    @State private var outcome = "Lebih tenang"
    @State private var note = ""
    @State private var tooFast = false
    @State private var stoppedIntentionally = true
    @State private var symptomAfter: PostSessionSymptom = .none
    @State private var saveFailed = false
    @State private var warningReason: PrivatePauseReason?
    @State private var warningTask: Task<Void, Never>?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum PrivatePhase: String, Equatable { case ready, active, warning, recovery, paused, reflection, saved }
    private var prescription: SessionPrescription { history.sessionPrescription }
    private var canResume: Bool { currentRecoverySeconds >= prescription.recoverySeconds && intensity <= 4 }

    init(advisories: [ImmediateActionAdvisory] = []) { self.advisories = advisories }

    var body: some View {
        ZStack {
            (phase == .warning ? Color(red: 0.32, green: 0.02, blue: 0.03) : TempoDesign.Palette.canvas).ignoresSafeArea()
            if phase == .active {
                privateActiveScreen
            } else if phase == .warning {
                warningContent
                    .padding(TempoDesign.Spacing.lg)
            } else if phase == .recovery {
                privateRecoveryScreen
                    .padding(TempoDesign.Spacing.lg)
                    .frame(maxWidth: TempoDesign.readableContentWidth, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: TempoDesign.Spacing.lg) {
                        Spacer(minLength: TempoDesign.Spacing.lg)
                        Image(systemName: phase == .paused ? "pause.circle.fill" : "hand.raised.fill")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(phase == .paused ? TempoDesign.Palette.caution : TempoDesign.Palette.accentSoft)
                        if phase == .ready {
                            Text("Sesi privat")
                                .font(TempoDesign.Typography.pageTitle)
                        }
                        Text(message).multilineTextAlignment(.center).foregroundStyle(TempoDesign.Palette.textSecondary)
                        content
                        Spacer(minLength: TempoDesign.Spacing.lg)
                    }
                    .frame(maxWidth: TempoDesign.readableContentWidth, minHeight: 620)
                    .padding(TempoDesign.Spacing.lg)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(ticker) { _ in tick() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { interruptionPause() }
        }
        .onChange(of: intensity) { _, value in
            if assistanceEnabled, phase == .active, value >= prescription.pauseThreshold { thresholdPause() }
            qualifyCurrentCycleIfNeeded()
        }
        .onDisappear { warningTask?.cancel(); speaker.stopSpeaking(at: .immediate) }
        .alert("Sesi belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { save() } } message: { Text("Pemulihan tidak akan dijadwalkan ulang sampai catatan lokal berhasil disimpan.") }
        .accessibilityIdentifier("private.session.timer")
    }

    private var privateActiveScreen: some View {
        VStack(spacing: TempoDesign.Spacing.md) {
            HStack {
                TempoStatusBadge("Putaran \(cycleTracker.completedCycles + 1)", tone: .accent)
                Spacer()
                Button("Selesai") { phase = .reflection }
                    .font(TempoDesign.Typography.supporting.weight(.semibold))
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                    .frame(minWidth: 64, minHeight: 44)
                    .accessibilityIdentifier("private.session.finish")
            }
            Spacer(minLength: 4)
            Image(systemName: "waveform.path")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(TempoDesign.Palette.accentSoft)
                .accessibilityHidden(true)
            Text("Ikuti ritme tubuhmu")
                .font(TempoDesign.Typography.pageTitle)
                .multilineTextAlignment(.center)
            Text("Saat mulai mendekati batas, tandai zonanya atau langsung tekan jeda.")
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 4)
            TempoSessionActiveControls(
                intensity: $intensity,
                threshold: prescription.pauseThreshold,
                onPause: manualPause,
                onEmergency: emergencyPause
            )
        }
        .frame(maxWidth: TempoDesign.readableContentWidth, maxHeight: .infinity)
        .padding(.horizontal, TempoDesign.Spacing.lg)
        .padding(.vertical, TempoDesign.Spacing.sm)
        .accessibilityIdentifier("private.session.active.fixed")
    }

    private var privateRecoveryScreen: some View {
        TempoSessionRecoveryControls(
            intensity: $intensity,
            threshold: prescription.pauseThreshold,
            elapsedSeconds: currentRecoverySeconds,
            minimumSeconds: prescription.recoverySeconds,
            cycleCount: cycleTracker.completedCycles,
            continueTitle: "Lanjutkan dengan pelan",
            onContinue: resumeFromRecovery,
            onFinish: { phase = .reflection }
        )
        .accessibilityIdentifier("private.recovery")
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .ready:
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                if !advisories.isEmpty {
                    TempoSurfaceCard(tint: TempoDesign.Palette.caution, emphasis: .tinted) {
                        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                            Text("Saran ringan").font(TempoDesign.Typography.cardTitle)
                            ForEach(advisories, id: \.self) { Text("• \($0.message)").font(TempoDesign.Typography.supporting) }
                        }
                    }
                }
                Toggle("Bantuan start–stop", isOn: $assistanceEnabled)
                    .tint(TempoDesign.Palette.accent)
                    .accessibilityIdentifier("private.assistance.toggle")
                if assistanceEnabled {
                    Toggle("Prompt suara lokal", isOn: $spokenPromptsEnabled).tint(TempoDesign.Palette.accent)
                    Text("Zona batas mulai di \(prescription.pauseThreshold)/10 · pemulihan minimal \(prescription.recoverySeconds) detik")
                        .font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
                }
                TempoPrimaryButton("Mulai dengan pelan", icon: "play.fill") { start() }
                TempoSecondaryButton("Kembali", icon: "xmark", tone: .neutral) { dismiss() }
            }
        case .active:
            EmptyView()
        case .warning:
            EmptyView()
        case .recovery:
            EmptyView()
        case .paused:
            VStack(spacing: TempoDesign.Spacing.sm) {
                TempoPrimaryButton("Lanjut bila siap", icon: "play.fill") { phase = .active }
                TempoSecondaryButton("Akhiri sesi", icon: "checkmark", tone: .positive) { phase = .reflection }
            }
        case .reflection:
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                Text("Refleksi setelah sesi").font(TempoDesign.Typography.sectionTitle)
                Picker("Hasil sesi", selection: $outcome) {
                    Text("Lebih tenang").tag("Lebih tenang")
                    Text("Masih tegang").tag("Masih tegang")
                    Text("Butuh istirahat").tag("Butuh istirahat")
                }.pickerStyle(.segmented)
                TempoPostSessionSymptomPicker(selection: $symptomAfter)
                Toggle("Simpan catatan opsional", isOn: $saveDetails).tint(TempoDesign.Palette.accent)
                if saveDetails { TextField("Catatan singkat", text: $note, axis: .vertical).textFieldStyle(.roundedBorder) }
                TempoPrimaryButton("Simpan dan selesai", icon: "checkmark") { save() }
            }
            .padding(TempoDesign.Spacing.md)
            .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
        case .saved:
            TempoStatusBadge("Tersimpan lokal. Sesi ini memengaruhi pemulihan, bukan skor latihan terpandu.", tone: .positive)
        }
    }

    private var warningContent: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "hand.raised.fill").font(.system(size: 76, weight: .bold)).foregroundStyle(.white)
            Text(warningReason == .emergency ? "STOP SEKARANG — LEPAS TANGAN" : "STOP — LEPAS TANGAN")
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 440)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stop. Lepas tangan.")
        .accessibilityIdentifier("private.pause.warning")
    }

    private var message: String {
        switch phase {
        case .ready: "Pilih apakah TEMPO membantu mengatur jeda. Kamu tetap memegang keputusan sesi."
        case .active: assistanceEnabled ? "Perbarui intensitas dengan satu tangan. TEMPO akan menghentikan siklus di ambang program." : "Timer berjalan. Jeda dan akhiri kapan pun dibutuhkan."
        case .warning: ""
        case .recovery:
            cycleTracker.recoveryQualified
                ? "Siklus ini sudah tercatat. Kamu dapat melanjutkan dengan pelan atau cukup untuk hari ini."
                : (canResume ? "Pemulihan minimum terpenuhi dan intensitas sudah turun." : "Lanjut hanya setelah waktu minimum selesai dan intensitas maksimal 4.")
        case .paused: "Timer aktif berhenti selama jeda."
        case .reflection: "Catat hasil secukupnya agar jadwal pemulihan berikutnya akurat."
        case .saved: ""
        }
    }

    private func tick() {
        guard scenePhase == .active,
              startedAt != nil,
              ![.ready, .paused, .reflection, .saved].contains(phase) else { return }
        totalSessionSeconds += 1
        switch phase {
        case .active:
            activeSeconds += 1
            if assistanceEnabled, activeSeconds.isMultiple(of: prescription.checkInIntervalSeconds) {
                if hapticsEnabled { TempoFeedback.selection() }
                speak("Cek intensitas")
            }
            if totalSessionSeconds >= prescription.maximumDurationSeconds {
                // The soft duration cap ended this run, so do not record it as
                // an intentional user stop in the private-session outcome.
                stoppedIntentionally = false
                phase = .reflection
            }
        case .recovery:
            currentRecoverySeconds += 1
            totalRecoverySeconds += 1
            qualifyCurrentCycleIfNeeded()
        default: break
        }
    }

    private func start() {
        startedAt = .now
        phase = .active
        if hapticsEnabled { TempoFeedback.impact(.light) }
    }

    private func manualPause() {
        guard phase == .active else { return }
        manualPauseCount += 1
        if assistanceEnabled {
            beginRecovery(for: .manual)
        } else {
            phase = .paused
            if hapticsEnabled { TempoFeedback.impact(.light) }
        }
    }

    private func emergencyPause() {
        guard phase == .active else { return }
        emergencyPauseCount += 1
        tooFast = true
        enterWarning(for: .emergency)
    }

    private func thresholdPause() {
        guard phase == .active else { return }
        thresholdPauseCount += 1
        enterWarning(for: .threshold)
    }

    private func interruptionPause() {
        guard phase == .active else { return }
        interruptionPauseCount += 1
        beginRecovery(for: .interruption)
    }

    /// Threshold and emergency pauses deliberately use a short warning state;
    /// manual and interruption pauses never use this red treatment.
    private func enterWarning(for reason: PrivatePauseReason) {
        guard phase == .active else { return }
        warningReason = reason
        phase = .warning
        if hapticsEnabled { TempoFeedback.notification(reason == .emergency ? .error : .warning) }
        speak("Stop. Lepas tangan.")
        warningTask?.cancel()
        warningTask = Task { @MainActor in
            // Keep this red warning brief, but give VoiceOver and UI automation
            // enough time to perceive it before the recovery screen replaces it.
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, phase == .warning else { return }
            beginRecovery(for: reason)
        }
    }

    private func beginRecovery(for reason: PrivatePauseReason) {
        guard phase == .active || phase == .warning else { return }
        warningReason = nil
        currentRecoverySeconds = 0
        cycleTracker.beginRecovery(reason: reason, assistanceEnabled: assistanceEnabled)
        // A regular non-assisted pause and an app interruption are never a
        // completed training cycle. Emergency remains eligible when a real
        // recovery is completed, even though it is marked as too fast.
        phase = .recovery
        if hapticsEnabled, (reason == .manual || reason == .interruption) { TempoFeedback.impact(.medium) }
    }

    private func qualifyCurrentCycleIfNeeded() {
        guard phase == .recovery else { return }
        if cycleTracker.qualifyRecovery(
            elapsedSeconds: currentRecoverySeconds,
            intensity: intensity,
            minimumRecoverySeconds: prescription.recoverySeconds
        ), hapticsEnabled {
            TempoFeedback.notification(.success)
        }
    }

    private func resumeFromRecovery() {
        guard canResume else { return }
        currentRecoverySeconds = 0
        cycleTracker.resumeActivePhase()
        phase = .active
        if hapticsEnabled { TempoFeedback.impact(.light) }
    }

    private func speak(_ text: String) {
        guard spokenPromptsEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID")
        utterance.rate = 0.42
        speaker.speak(utterance)
    }

    private func save() {
        guard let startedAt else { dismiss(); return }
        let painAfter = symptomAfter == .pain
        let irritationAfter = symptomAfter == .irritation
        if painAfter || irritationAfter {
            let reason = painAfter ? "safety.private-session-pain" : "safety.private-session-irritation"
            let severity = painAfter ? RecommendationSeverity.urgent.rawValue : RecommendationSeverity.caution.rawValue
            guard history.recordSafetyHold(reasonCode: reason, severity: severity, source: "private-session") else { saveFailed = true; return }
        }
        guard history.addPrivateSession(
            startedAt: startedAt,
            elapsedSeconds: totalSessionSeconds,
            pauseCount: manualPauseCount + thresholdPauseCount + emergencyPauseCount + interruptionPauseCount,
            outcome: outcome,
            note: note.isEmpty ? nil : note,
            saveDetails: saveDetails,
            activeSeconds: activeSeconds,
            totalRecoverySeconds: totalRecoverySeconds,
            manualPauseCount: manualPauseCount,
            emergencyPauseCount: emergencyPauseCount,
            completedCycles: cycleTracker.completedCycles,
            terminalState: stoppedIntentionally ? "intentional-stop" : "ended",
            assistanceEnabled: assistanceEnabled,
            tooFast: tooFast,
            stoppedIntentionally: stoppedIntentionally,
            painAfter: painAfter,
            irritationAfter: irritationAfter,
            thresholdPauseCount: thresholdPauseCount,
            interruptionPauseCount: interruptionPauseCount
        ) else { saveFailed = true; return }
        phase = .saved
        if painAfter || irritationAfter { coordinator.open(.healthCheck) } else { dismiss() }
    }
}

struct TempoGuidedSessionScreen: View {
    let plannedDayID: UUID?
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var machine = GuidedSessionMachine()
    @State private var prescription = SessionPrescription(preparationSeconds: 45, activeTargetSeconds: 600, recoverySeconds: 40, maximumCycles: 2, pauseThreshold: 7, maximumDurationSeconds: 1_200, checkInIntervalSeconds: 45, reasons: [])
    @State private var startedAt: Date?
    @State private var preparationElapsed = 0
    @State private var activeElapsed = 0
    @State private var currentRecoverySeconds = 0
    @State private var totalRecoverySeconds = 0
    @State private var totalElapsed = 0
    @State private var intensity = 3
    @State private var preAnxiety = 3
    @State private var eligibilityMessage: String?
    @State private var showReflection = false
    @State private var postFeeling = "Lebih tenang"
    @State private var symptomAfter: PostSessionSymptom = .none
    @State private var saveFailed = false
    @State private var saved = false
    @State private var sessionPersisted = false
    @State private var arousalEvents: [LocalArousalEvent] = []
    @State private var pauseCycles: [LocalPauseCycle] = []
    @State private var pendingPauseStart: Int?
    @State private var pendingPauseIntensity = 3
    @State private var warningTask: Task<Void, Never>?
    @State private var warningPulse = false
    @State private var recoveryReadyNotified = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(plannedDayID: UUID? = nil) { self.plannedDayID = plannedDayID }

    var body: some View {
        ZStack {
            background
            if eligibilityMessage == nil, !showReflection, isImmersiveState {
                guidedImmersiveContent
            } else {
                VStack(spacing: TempoDesign.Spacing.lg) {
                    header
                    Spacer(minLength: 0)
                    if let eligibilityMessage { blocked(eligibilityMessage) }
                    else if showReflection { reflection }
                    else { stateContent }
                    Spacer(minLength: 0)
                    if eligibilityMessage == nil && !showReflection && !machine.isTerminal { footer }
                }
                .frame(maxWidth: TempoDesign.readableContentWidth, maxHeight: .infinity)
                .padding(TempoDesign.Spacing.lg)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { configure() }
        .onDisappear { warningTask?.cancel() }
        .onReceive(ticker) { now in tick(now) }
        .onChange(of: intensity) { _, level in
            handleIntensityChange(level)
            notifyRecoveryReadyIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .alert("Sesi belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { saveSession() } } message: { Text("TEMPO mempertahankan status rencana sampai catatan sesi tersimpan lokal.") }
        .accessibilityIdentifier("guided.session")
    }

    private var isImmersiveState: Bool {
        [.activeLow, .activeRising, .warning, .pausedRecovery].contains(machine.state)
    }

    @ViewBuilder private var guidedImmersiveContent: some View {
        switch machine.state {
        case .activeLow, .activeRising:
            VStack(spacing: TempoDesign.Spacing.md) {
                HStack {
                    TempoStatusBadge("Putaran \(machine.cycles + 1) dari \(machine.maximumCycles)", tone: .accent)
                    Spacer()
                    Button("Selesai") { finishEarly() }
                        .font(TempoDesign.Typography.supporting.weight(.semibold))
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                        .frame(minWidth: 64, minHeight: 44)
                        .accessibilityIdentifier("guided.session.finish")
                }
                Spacer(minLength: 4)
                Image(systemName: "waveform.path")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(TempoDesign.Palette.accentSoft)
                    .accessibilityHidden(true)
                Text("Ikuti ritme tubuhmu")
                    .font(TempoDesign.Typography.pageTitle)
                    .multilineTextAlignment(.center)
                Text("Tandai saat intensitas berubah. TEMPO memulai jeda ketika kamu memilih zona batas.")
                    .font(TempoDesign.Typography.supporting)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 4)
                TempoSessionActiveControls(
                    intensity: $intensity,
                    threshold: prescription.pauseThreshold,
                    onPause: { beginRecovery(reason: .manual) },
                    onEmergency: { beginRecovery(reason: .almostTooLate) }
                )
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, maxHeight: .infinity)
            .padding(.horizontal, TempoDesign.Spacing.lg)
            .padding(.vertical, TempoDesign.Spacing.sm)
            .accessibilityIdentifier("guided.session.active.fixed")
        case .warning:
            warning
                .padding(TempoDesign.Spacing.lg)
        case .pausedRecovery:
            TempoSessionRecoveryControls(
                intensity: $intensity,
                threshold: prescription.pauseThreshold,
                elapsedSeconds: currentRecoverySeconds,
                minimumSeconds: prescription.recoverySeconds,
                cycleCount: machine.cycles,
                continueTitle: willCompleteAfterRecovery ? "Lanjut ke refleksi" : "Lanjutkan dengan pelan",
                onContinue: continueGuidedAfterRecovery,
                onFinish: finishGuidedFromRecovery
            )
            .frame(maxWidth: TempoDesign.readableContentWidth, maxHeight: .infinity)
            .padding(TempoDesign.Spacing.lg)
            .accessibilityIdentifier("guided.recovery")
        default:
            EmptyView()
        }
    }

    private var recoveryIsReady: Bool {
        currentRecoverySeconds >= prescription.recoverySeconds && intensity <= 4
    }

    private var willCompleteAfterRecovery: Bool {
        machine.lastPauseReason != .interruption && machine.cycles + 1 >= machine.maximumCycles
    }

    private var background: some View {
        Group {
            if machine.state == .warning { Color(red: 0.30, green: 0.01, blue: 0.03) }
            else if machine.state == .pausedRecovery { TempoDesign.Palette.caution.opacity(0.12) }
            else { TempoDesign.Palette.canvas }
        }.ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: TempoDesign.Spacing.xs) {
            Text("Sesi terpandu").font(TempoDesign.Typography.overline).foregroundStyle(TempoDesign.Palette.accentSoft)
            Text(tempoDuration(totalElapsed)).font(.system(size: 42, weight: .bold, design: .rounded)).monospacedDigit()
            HStack(spacing: TempoDesign.Spacing.sm) {
                timerLabel("Aktif", activeElapsed, tint: TempoDesign.Palette.accentSoft)
                timerLabel("Pulih", totalRecoverySeconds, tint: TempoDesign.Palette.positive)
                timerLabel("Total", totalElapsed, tint: TempoDesign.Palette.textSecondary)
            }
        }
        .foregroundStyle(TempoDesign.Palette.textPrimary)
    }

    private func timerLabel(_ title: String, _ seconds: Int, tint: Color) -> some View {
        VStack(spacing: 1) { Text(title).font(TempoDesign.Typography.caption); Text(tempoDuration(seconds)).font(.caption.monospacedDigit()) }
            .foregroundStyle(tint).frame(minWidth: 56)
    }

    @ViewBuilder private var stateContent: some View {
        switch machine.state {
        case .precheck: precheck
        case .prepare: preparation
        case .activeLow, .activeRising: EmptyView()
        case .warning: warning
        case .pausedRecovery: EmptyView()
        case .resumeReady: resume
        case .completed, .earlyCompletion, .timeLimitReached: completed
        case .cancelled, .safetyAbort: cancelled
        }
    }

    private var precheck: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "shield.lefthalf.filled").font(.system(size: 48)).foregroundStyle(TempoDesign.Palette.accentSoft)
            Text("Mulai saat ruang dan waktumu cukup.").font(TempoDesign.Typography.sectionTitle).multilineTextAlignment(.center)
            Text("Sesi memakai jeda, ambang \(prescription.pauseThreshold)/10, dan pemulihan minimal \(prescription.recoverySeconds) detik. Bila ada nyeri atau gejala baru, berhenti dan buka pemeriksaan.")
                .foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            reflectionPicker("Kecemasan sebelum", value: $preAnxiety)
            TempoPrimaryButton("Mulai persiapan", icon: "play.fill") { beginPreparation() }
            TempoSecondaryButton("Ada gejala", icon: "cross.case.fill", tone: .caution) { machine.abortForSafety(); coordinator.open(.healthCheck) }
        }
    }

    private var preparation: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            BreathingOrbView().frame(width: 150, height: 150)
            Text("Persiapan").font(TempoDesign.Typography.pageTitle)
            Text("\(tempoDuration(max(0, prescription.preparationSeconds - preparationElapsed)))").font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
            Text("Turunkan bahu, longgarkan rahang, dan kenali sinyal tubuh tanpa mengejar hasil.").foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            TempoSecondaryButton("Saya siap lebih awal", icon: "arrow.right") { beginActive() }
        }
    }

    private var warning: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.7), lineWidth: 8).frame(width: 150, height: 150).scaleEffect(warningPulse ? 1.18 : 0.88).opacity(warningPulse ? 0.15 : 0.9)
                Image(systemName: "hand.raised.fill").font(.system(size: 72)).foregroundStyle(.white)
            }
            Text("STOP — LEPAS TANGAN").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text("Diam dan ambil napas perlahan. Pemulihan dimulai otomatis.")
                .font(.title3).multilineTextAlignment(.center).foregroundStyle(.white)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.8).repeatForever(autoreverses: false)) { warningPulse = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Peringatan. Berhenti sekarang dan mulai pemulihan.")
        .accessibilityAddTraits(.isHeader)
    }

    private var resume: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundStyle(TempoDesign.Palette.positive)
            Text(machine.cycles >= machine.maximumCycles ? "Sesi cukup untuk hari ini." : "Jeda tercatat.").font(TempoDesign.Typography.pageTitle).multilineTextAlignment(.center)
            Text(machine.cycles >= machine.maximumCycles ? "Tidak perlu menambah putaran. Lanjutkan ke refleksi dan pemulihan." : "Kamu dapat melanjutkan dengan tempo ringan atau mengakhiri lebih awal.")
                .foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            if machine.cycles >= machine.maximumCycles {
                TempoPrimaryButton("Lanjut ke refleksi", icon: "checkmark") { machine.complete(); showReflection = true }
            } else {
                TempoPrimaryButton("Lanjutkan dengan pelan", icon: "play.fill") { beginActive() }
                TempoSecondaryButton("Cukup untuk hari ini", icon: "checkmark", tone: .positive) { finishEarly() }
            }
        }
    }

    private var completed: some View {
        VStack(spacing: TempoDesign.Spacing.md) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(TempoDesign.Palette.positive)
            Text("Sesi selesai").font(TempoDesign.Typography.pageTitle)
            TempoPrimaryButton("Isi refleksi singkat", icon: "arrow.right") { showReflection = true }
        }
    }

    private var cancelled: some View {
        VStack(spacing: TempoDesign.Spacing.md) {
            Text("Sesi dihentikan").font(TempoDesign.Typography.pageTitle)
            Text("Tidak apa-apa berhenti. Gunakan pemulihan atau pemeriksaan bila tubuh terasa tidak nyaman.").foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            TempoPrimaryButton("Kembali", icon: "arrow.left") { dismiss() }
        }
    }

    private func blocked(_ message: String) -> some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "bed.double.fill").font(.system(size: 50)).foregroundStyle(TempoDesign.Palette.caution)
            Text("Sesi terpandu belum tersedia").font(TempoDesign.Typography.pageTitle).multilineTextAlignment(.center)
            Text(message).foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            TempoPrimaryButton("Pilih pemulihan", icon: "wind") { coordinator.open(.breathing(nil, "Pemulihan", 300)) }
        }
    }

    private var footer: some View {
        HStack {
            Button(machine.state == .precheck ? "Kembali" : "Akhiri sesi") {
                if machine.state == .precheck { dismiss() }
                else { finishEarly() }
            }
            .foregroundStyle(TempoDesign.Palette.textSecondary)
            .frame(minHeight: 44)
            Spacer()
            Text("Target: \(machine.maximumCycles) jeda").font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textTertiary)
        }
        .accessibilityIdentifier("guided.footer")
    }

    private var reflection: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            Text("Refleksi singkat").font(TempoDesign.Typography.pageTitle)
            Text("Catat seperlunya. Sinyal nyeri atau iritasi akan membuka safety hold.").foregroundStyle(TempoDesign.Palette.textSecondary)
            Text("Bagaimana kondisi tubuhmu sekarang?").font(TempoDesign.Typography.cardTitle)
            Picker("Kondisi setelah sesi", selection: $postFeeling) {
                Text("Lebih tenang").tag("Lebih tenang")
                Text("Masih tegang").tag("Masih tegang")
                Text("Butuh istirahat").tag("Butuh istirahat")
            }
            .pickerStyle(.segmented)
            TempoPostSessionSymptomPicker(selection: $symptomAfter)
            TempoPrimaryButton("Simpan sesi", icon: "checkmark") { saveSession() }
        }
        .padding(TempoDesign.Spacing.md)
        .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
    }

    private func reflectionPicker(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            HStack { Text(title).font(TempoDesign.Typography.cardTitle); Spacer(); Text("\(value.wrappedValue)/10").monospacedDigit() }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: 1...10, step: 1).tint(TempoDesign.Palette.accentSoft)
        }
    }

    private func configure() {
        let eligibility = history.guidedEligibility
        guard eligibility.isAllowed else { eligibilityMessage = eligibility.message; return }
        prescription = history.sessionPrescription
        machine = GuidedSessionMachine(maximumCycles: prescription.maximumCycles, maximumDurationSeconds: prescription.maximumDurationSeconds)
    }
    private func beginPreparation() {
        startedAt = .now
        machine.start()
        if hapticsEnabled { TempoFeedback.impact(.light) }
    }

    private func beginActive() {
        let previousState = machine.state
        machine.beginActive()
        guard [.activeLow, .activeRising].contains(machine.state), previousState != machine.state else { return }
        recoveryReadyNotified = false
        arousalEvents.append(LocalArousalEvent(
            timestampOffset: totalElapsed,
            level: intensity,
            eventType: previousState == .resumeReady ? "active-resume" : "active-start"
        ))
        if hapticsEnabled { TempoFeedback.selection() }
    }
    private func tick(_ now: Date) {
        _ = now
        guard scenePhase == .active, startedAt != nil, !machine.isTerminal else { return }
        totalElapsed += 1
        switch machine.state {
        case .prepare:
            preparationElapsed += 1
            if preparationElapsed >= prescription.preparationSeconds { beginActive() }
        case .activeLow, .activeRising:
            activeElapsed += 1
            if activeElapsed.isMultiple(of: prescription.checkInIntervalSeconds), hapticsEnabled { TempoFeedback.selection() }
            if activeElapsed >= prescription.activeTargetSeconds, machine.cycles > 0 {
                machine.complete()
                showReflection = true
            }
        case .pausedRecovery:
            currentRecoverySeconds += 1
            totalRecoverySeconds += 1
            notifyRecoveryReadyIfNeeded()
        default: break
        }
        machine.updateElapsed(totalSeconds: totalElapsed)
        if machine.state == .timeLimitReached { showReflection = true }
    }
    private func beginRecovery(reason: GuidedPauseReason) {
        pendingPauseStart = totalElapsed
        pendingPauseIntensity = intensity
        let changed = reason == .almostTooLate ? machine.emergencyWarning() : machine.pause(reason: reason)
        guard changed else { pendingPauseStart = nil; return }
        arousalEvents.append(LocalArousalEvent(timestampOffset: totalElapsed, level: intensity, eventType: reason.rawValue))
        if reason == .almostTooLate { startWarningTransition() }
        else {
            currentRecoverySeconds = 0
            recoveryReadyNotified = false
            if hapticsEnabled { TempoFeedback.impact(.medium) }
        }
    }
    private func recover() {
        let previousState = machine.state
        let previousCycles = machine.cycles
        let shouldConfirmWithHaptic = !recoveryReadyNotified
        machine.recovered(level: intensity, elapsedSeconds: currentRecoverySeconds, minimumSeconds: prescription.recoverySeconds)
        guard previousState == .pausedRecovery, machine.state != .pausedRecovery else { return }
        pauseCycles.append(LocalPauseCycle(
            index: pauseCycles.count + 1,
            startOffset: pendingPauseStart ?? max(0, totalElapsed - currentRecoverySeconds),
            endOffset: totalElapsed,
            arousalBefore: pendingPauseIntensity,
            arousalAfter: intensity,
            lateStop: machine.lastPauseReason == .almostTooLate,
            successful: machine.cycles > previousCycles || machine.lastPauseReason == .interruption
        ))
        pendingPauseStart = nil
        currentRecoverySeconds = 0
        if hapticsEnabled, shouldConfirmWithHaptic { TempoFeedback.notification(.success) }
    }

    private func continueGuidedAfterRecovery() {
        guard recoveryIsReady else { return }
        recover()
        if machine.state == .completed {
            showReflection = true
        } else if machine.state == .resumeReady {
            beginActive()
        }
    }

    private func finishGuidedFromRecovery() {
        if recoveryIsReady { recover() }
        if machine.state == .completed {
            showReflection = true
        } else {
            finishEarly()
        }
    }

    private func saveSession() {
        guard !saved else { dismiss(); return }
        let painAfter = symptomAfter == .pain
        let irritationAfter = symptomAfter == .irritation
        let postScore: Int
        switch postFeeling {
        case "Masih tegang": postScore = 6
        case "Butuh istirahat": postScore = 8
        default: postScore = 3
        }
        if !sessionPersisted {
            finalizePendingPauseIfNeeded()
            guard history.addSession(
                startedAt: startedAt,
                cycles: machine.cycles,
                terminalState: machine.state,
                targetCycles: prescription.maximumCycles,
                pauseThreshold: prescription.pauseThreshold,
                maximumDurationSeconds: prescription.maximumDurationSeconds,
                preAnxiety: preAnxiety,
                durationSeconds: totalElapsed,
                lateStopOccurred: machine.lateStopOccurred,
                postAnxiety: postScore,
                postTension: postScore,
                painAfter: painAfter,
                irritationAfter: irritationAfter,
                outcome: postFeeling,
                arousalEvents: arousalEvents,
                pauseCycles: pauseCycles,
                activeSeconds: activeElapsed,
                recoverySeconds: totalRecoverySeconds
            ) else { saveFailed = true; return }
            sessionPersisted = true
        }
        let meaningfulEarlyCompletion = machine.state == .earlyCompletion && (machine.cycles > 0 || activeElapsed >= min(120, prescription.activeTargetSeconds / 3))
        if let plannedDayID, ([.completed, .timeLimitReached].contains(machine.state) || meaningfulEarlyCompletion) {
            guard history.completePlanItem(id: plannedDayID, performedKind: .guided, completedAt: .now) else { saveFailed = true; return }
        }
        saved = true
        if painAfter || irritationAfter { coordinator.open(.healthCheck) }
        else { dismiss() }
    }
    private func handleIntensityChange(_ level: Int) {
        guard machine.state == .activeLow || machine.state == .activeRising else { return }
        arousalEvents.append(LocalArousalEvent(timestampOffset: totalElapsed, level: level, eventType: "check-in"))
        guard machine.rising(level: level, threshold: prescription.pauseThreshold) else { return }
        pendingPauseStart = totalElapsed
        pendingPauseIntensity = level
        arousalEvents.append(LocalArousalEvent(timestampOffset: totalElapsed, level: level, eventType: GuidedPauseReason.threshold.rawValue))
        startWarningTransition()
    }

    private func startWarningTransition() {
        if hapticsEnabled { TempoFeedback.notification(.warning) }
        warningTask?.cancel()
        warningTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, machine.advanceWarningToRecovery() else { return }
            currentRecoverySeconds = 0
            recoveryReadyNotified = false
            warningPulse = false
        }
    }

    private func notifyRecoveryReadyIfNeeded() {
        guard recoveryIsReady, !recoveryReadyNotified else { return }
        recoveryReadyNotified = true
        if hapticsEnabled { TempoFeedback.notification(.success) }
    }

    private func finishEarly() {
        // Preparation has not begun the active training. Leaving here should
        // not create an invalid, non-terminal session record or complete the
        // scheduled activity.
        if machine.state == .prepare {
            machine.cancel()
            dismiss()
            return
        }
        machine.earlyCompletion()
        guard machine.state == .earlyCompletion else { return }
        showReflection = true
    }

    /// A user may end from the warning or recovery screen before tapping
    /// "Periksa kesiapan". Keep that incomplete pause in the session record
    /// so threshold, manual, emergency, and interruption events are not
    /// discarded merely because the session ended early.
    private func finalizePendingPauseIfNeeded() {
        guard let startOffset = pendingPauseStart else { return }
        pauseCycles.append(LocalPauseCycle(
            index: pauseCycles.count + 1,
            startOffset: startOffset,
            endOffset: max(startOffset, totalElapsed),
            arousalBefore: pendingPauseIntensity,
            arousalAfter: intensity,
            lateStop: machine.lastPauseReason == .almostTooLate,
            successful: false
        ))
        pendingPauseStart = nil
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        guard phase != .active, (machine.state == .activeLow || machine.state == .activeRising) else { return }
        pendingPauseStart = totalElapsed
        pendingPauseIntensity = intensity
        if machine.pause(reason: .interruption) {
            currentRecoverySeconds = 0
            arousalEvents.append(LocalArousalEvent(timestampOffset: totalElapsed, level: intensity, eventType: GuidedPauseReason.interruption.rawValue))
        }
    }
}

struct TempoBreathingSessionScreen: View {
    let plannedDayID: UUID?
    let title: String
    let duration: Int
    @Environment(LocalHistory.self) private var history
    @Environment(\.dismiss) private var dismiss
    @State private var remaining: Int
    @State private var running = false
    @State private var completed = false
    @State private var saveFailed = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(plannedDayID: UUID?, title: String, duration: Int) {
        self.plannedDayID = plannedDayID; self.title = title; self.duration = max(30, duration); _remaining = State(initialValue: max(30, duration))
    }

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.xl) {
            Spacer()
            BreathingOrbView().frame(width: 160, height: 160)
            Text(title).font(TempoDesign.Typography.pageTitle)
            Text(tempoDuration(remaining)).font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
            Text(completed ? "Selesai. Kamu tidak perlu menambah apa pun hari ini." : "Ikuti napas dengan perlahan. Biarkan jeda memberi tubuh waktu turun.")
                .multilineTextAlignment(.center).foregroundStyle(TempoDesign.Palette.textSecondary)
            if completed { TempoPrimaryButton("Kembali", icon: "checkmark") { dismiss() } }
            else { TempoPrimaryButton(running ? "Jeda" : "Mulai", icon: running ? "pause.fill" : "play.fill") { running.toggle() } }
            Spacer()
        }
        .padding(TempoDesign.Spacing.lg).frame(maxWidth: .infinity, maxHeight: .infinity).background(TempoDesign.Palette.canvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .onReceive(ticker) { _ in if running && remaining > 0 { remaining -= 1; if remaining == 0 { finish() } } }
        .alert("Status rencana belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { finish() } } message: { Text("Sesi selesai, tetapi catatan lokal perlu disimpan terlebih dahulu.") }
        .accessibilityIdentifier("breathing.session")
    }
    private func finish() {
        running = false
        let performedKind = plannedDayID.flatMap { id in history.plannedDays.first(where: { $0.id == id })?.effectiveKind } ?? .breathing
        if let plannedDayID, !history.completePlanItem(id: plannedDayID, performedKind: performedKind, completedAt: .now) { saveFailed = true; return }
        completed = true
        TempoFeedback.notification(.success)
    }
}

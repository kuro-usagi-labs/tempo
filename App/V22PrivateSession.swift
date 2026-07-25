import SwiftUI
import Combine
import AVFoundation

private func tempoV22Duration(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    return "\(safe / 60):\(String(format: "%02d", safe % 60))"
}

enum TempoPrivateReflectionOutcome: String, CaseIterable, Identifiable {
    case planned
    case tooFast
    case intentionalStop
    case discomfort
    case rest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planned: "Sesuai rencana"
        case .tooFast: "Terasa terlalu cepat"
        case .intentionalStop: "Saya berhenti sengaja"
        case .discomfort: "Tubuh terasa tidak nyaman"
        case .rest: "Butuh istirahat"
        }
    }

    var storedValue: String {
        switch self {
        case .planned: "Lebih tenang"
        case .tooFast: "Terasa terlalu cepat"
        case .intentionalStop: "Berhenti dengan sengaja"
        case .discomfort: "Tubuh terasa tidak nyaman"
        case .rest: "Butuh istirahat"
        }
    }
}

/// Review-only private session presentation. It keeps the existing cycle,
/// timer, persistence, safety-hold, and recovery semantics while replacing the
/// dashboard-like layout with one-handed controls and persisted completion.
struct TempoV22PrivateSessionScreen: View {
    let advisories: [ImmediateActionAdvisory]

    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("privateAssistanceEnabled") private var assistanceEnabled = true
    @AppStorage("privateSpokenPromptsEnabled") private var spokenPromptsEnabled = false

    @State private var speaker = AVSpeechSynthesizer()
    @State private var phase: Phase = .ready
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
    @State private var intensity = TempoIntensityZone.calm.numericValue
    @State private var reflectionOutcome: TempoPrivateReflectionOutcome = .planned
    @State private var painAfter = false
    @State private var irritationAfter = false
    @State private var showDetails = false
    @State private var note = ""
    @State private var saveFailed = false
    @State private var warningReason: PrivatePauseReason?
    @State private var warningTask: Task<Void, Never>?
    @State private var persistedRecord: LocalPrivateSession?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum Phase: Equatable {
        case ready
        case active
        case warning
        case recovery
        case paused
        case reflection
        case completion
    }

    private var prescription: SessionPrescription { history.sessionPrescription }
    private var canResume: Bool { currentRecoverySeconds >= prescription.recoverySeconds && intensity <= TempoIntensityZone.rising.numericValue }
    private var isSessionControlPhase: Bool { phase == .active }

    init(advisories: [ImmediateActionAdvisory] = []) {
        self.advisories = advisories
    }

    var body: some View {
        ZStack {
            background
            Group {
                switch phase {
                case .ready: ready
                case .active: active
                case .warning: warning
                case .recovery: recovery
                case .paused: paused
                case .reflection: reflection
                case .completion: completion
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSessionControlPhase {
                TempoStickyActionBar {
                    TempoSessionControlBar(
                        pauseTitle: "Jeda",
                        dangerTitle: "Mendekati batas",
                        finishTitle: "Selesai",
                        pause: manualPause,
                        danger: emergencyPause,
                        finish: { phase = .reflection }
                    )
                    .accessibilityIdentifier("private.controls")
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(ticker) { _ in tick() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { interruptionPause() }
        }
        .onChange(of: intensity) { _, value in
            if assistanceEnabled, phase == .active, value >= prescription.pauseThreshold {
                thresholdPause()
            }
            qualifyCurrentCycleIfNeeded()
        }
        .onDisappear {
            warningTask?.cancel()
            speaker.stopSpeaking(at: .immediate)
        }
        .alert("Sesi belum tersimpan", isPresented: $saveFailed) {
            Button("Coba lagi") { save() }
            Button("Tetap di sini", role: .cancel) {}
        } message: {
            Text("Completion summary tidak ditampilkan sampai record private session berhasil tersimpan.")
        }
        .accessibilityIdentifier("private.session.v22")
    }

    private var background: some View {
        Group {
            if phase == .warning {
                Color(red: 0.32, green: 0.02, blue: 0.03)
            } else if phase == .recovery {
                TempoDesign.Palette.positive.opacity(0.08)
            } else {
                TempoDesign.Palette.canvas
            }
        }
        .ignoresSafeArea()
    }

    private var ready: some View {
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xl) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(TempoDesign.Palette.accentSoft)
                    Text("Sesi privat").font(TempoDesign.Typography.pageTitle)
                    Text("Kamu tetap memegang keputusan. Bantuan hanya mengatur check-in, warning, dan recovery.")
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                }
                if !advisories.isEmpty {
                    TempoCompactStatusRow(
                        title: "Saran ringan",
                        detail: advisories.map(\.message).joined(separator: " "),
                        icon: "info.circle.fill",
                        tone: .caution
                    )
                    .padding(TempoDesign.Spacing.md)
                    .background(TempoDesign.Palette.caution.opacity(0.10), in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
                }
                TempoSurfaceCard {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                        Toggle("Bantuan start–stop", isOn: $assistanceEnabled)
                            .tint(TempoDesign.Palette.accent)
                            .accessibilityIdentifier("private.assistance.toggle")
                        if assistanceEnabled {
                            Toggle("Prompt suara lokal", isOn: $spokenPromptsEnabled)
                                .tint(TempoDesign.Palette.accent)
                            TempoCompactStatusRow(
                                title: "Ambang \(prescription.pauseThreshold)/10",
                                detail: "Pemulihan minimum \(prescription.recoverySeconds) detik · maksimum \(tempoV22Duration(prescription.maximumDurationSeconds))",
                                icon: "slider.horizontal.3",
                                tone: .accent
                            )
                        }
                    }
                }
                TempoPrimaryButton("Mulai dengan pelan", icon: "play.fill") { start() }
                    .accessibilityIdentifier("private.start")
                TempoSecondaryButton("Kembali", icon: "xmark", tone: .neutral) { dismiss() }
            }
        }
    }

    private var active: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            TempoSessionHeader(
                title: "Sesi privat",
                primaryValue: tempoV22Duration(totalSessionSeconds),
                primaryLabel: "waktu sesi",
                secondaryItems: [
                    ("Aktif", tempoV22Duration(activeSeconds)),
                    ("Siklus", "\(cycleTracker.completedCycles + 1)"),
                    ("Ambang", "\(prescription.pauseThreshold)/10")
                ]
            )
            Spacer(minLength: 0)
            VStack(spacing: TempoDesign.Spacing.md) {
                Text("Perbarui hanya saat zona berubah.")
                    .font(TempoDesign.Typography.pageTitle)
                    .multilineTextAlignment(.center)
                Text(assistanceEnabled ? "TEMPO akan memicu warning ketika nilai internal mencapai ambang program." : "Timer berjalan tanpa warning otomatis. Jeda kapan pun dibutuhkan.")
                    .font(TempoDesign.Typography.supporting)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                if assistanceEnabled {
                    TempoIntensityZoneControl(numericValue: $intensity, accessibilityIdentifier: "private.intensity")
                } else {
                    TempoCompactStatusRow(
                        title: "Bantuan start–stop mati",
                        detail: "Jeda dan selesai tetap tersedia di bawah.",
                        icon: "timer",
                        tone: .neutral
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(.horizontal, TempoDesign.Spacing.lg)
        .padding(.top, TempoDesign.Spacing.lg)
        .padding(.bottom, 104)
    }

    private var warning: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 76, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)
            Text(warningReason == .emergency ? "STOP SEKARANG" : "STOP — LEPAS TANGAN")
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Lepas tangan dan diamkan tubuh.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stop sekarang. Lepas tangan dan diamkan tubuh.")
        .accessibilityIdentifier("private.pause.warning")
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: "Stop sekarang. Lepas tangan.")
        }
    }

    private var recovery: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            TempoSessionHeader(
                title: "Pemulihan",
                primaryValue: tempoV22Duration(max(0, prescription.recoverySeconds - currentRecoverySeconds)),
                primaryLabel: "minimum tersisa",
                secondaryItems: [
                    ("Total pulih", tempoV22Duration(totalRecoverySeconds)),
                    ("Siklus", "\(cycleTracker.completedCycles)"),
                    ("Zona", TempoIntensityZone(numericValue: intensity).title)
                ]
            )
            Spacer(minLength: 0)
            VStack(spacing: TempoDesign.Spacing.md) {
                if cycleTracker.recoveryQualified {
                    TempoStatusBadge("Siklus ini siap disimpan", tone: .positive, icon: "checkmark.circle.fill")
                }
                Text(canResume ? "Tubuh berada di zona yang dapat dilanjutkan." : "Tunggu sampai zona Tenang atau Mulai naik.")
                    .font(TempoDesign.Typography.sectionTitle)
                    .multilineTextAlignment(.center)
                TempoIntensityZoneControl(numericValue: $intensity, accessibilityIdentifier: "private.recovery.intensity")
                TempoPrimaryButton(canResume ? "Lanjutkan dengan pelan" : "Tunggu hingga siap", icon: "play.fill", isEnabled: canResume) {
                    resumeFromRecovery()
                }
                TempoSecondaryButton("Cukup untuk hari ini", icon: "checkmark", tone: .positive) {
                    phase = .reflection
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.lg)
        .accessibilityIdentifier("private.recovery")
    }

    private var paused: some View {
        VStack(spacing: TempoDesign.Spacing.xl) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(TempoDesign.Palette.caution)
            Text("Timer aktif dijeda").font(TempoDesign.Typography.pageTitle)
            Text("Waktu background tidak dihitung sebagai waktu aktif.")
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            TempoPrimaryButton("Lanjut bila siap", icon: "play.fill") { phase = .active }
            TempoSecondaryButton("Selesai", icon: "checkmark", tone: .positive) { phase = .reflection }
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.lg)
    }

    private var reflection: some View {
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                Text("Bagaimana sesi berakhir?").font(TempoDesign.Typography.pageTitle)
                Text("Pilih satu jawaban utama. Detail tambahan hanya muncul bila diperlukan.")
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                ForEach(TempoPrivateReflectionOutcome.allCases) { option in
                    TempoSelectionCard(
                        title: option.title,
                        subtitle: reflectionSubtitle(option),
                        icon: reflectionIcon(option),
                        selected: reflectionOutcome == option,
                        tone: option == .discomfort ? .caution : .accent
                    ) {
                        reflectionOutcome = option
                    }
                }
                if reflectionOutcome == .discomfort {
                    TempoSurfaceCard(tint: TempoDesign.Palette.caution, emphasis: .tinted) {
                        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                            Toggle("Ada nyeri", isOn: $painAfter).tint(TempoDesign.Palette.critical)
                            Toggle("Ada iritasi", isOn: $irritationAfter).tint(TempoDesign.Palette.caution)
                        }
                    }
                }
                DisclosureGroup("Tambahkan detail", isExpanded: $showDetails) {
                    TextField("Catatan singkat", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .padding(.top, TempoDesign.Spacing.sm)
                }
                .tint(TempoDesign.Palette.accentSoft)
                TempoPrimaryButton("Simpan sesi", icon: "checkmark") { save() }
                    .accessibilityIdentifier("private.save")
            }
        }
    }

    private var completion: some View {
        let record = persistedRecord
        return TempoScreenContainer {
            TempoCompletionSummary(
                title: "Sesi tersimpan",
                message: completionMessage(record),
                metrics: completionMetrics(record),
                primaryTitle: painAfter || irritationAfter ? "Buka pemeriksaan" : "Kembali ke Hari Ini",
                secondaryTitle: "Lihat Program",
                primaryAction: {
                    if painAfter || irritationAfter {
                        coordinator.open(.healthCheck)
                    } else {
                        coordinator.selectedTab = .today
                        coordinator.popToRoot()
                    }
                },
                secondaryAction: {
                    coordinator.selectedTab = .program
                    coordinator.popToRoot()
                }
            )
            .frame(maxWidth: TempoDesign.Layout.compactContentWidth)
        }
        .accessibilityIdentifier("private.completion")
    }

    private func reflectionSubtitle(_ option: TempoPrivateReflectionOutcome) -> String? {
        switch option {
        case .planned: "Sesi berakhir tanpa keluhan atau dorongan mendesak."
        case .tooFast: "Emergency atau mendekati batas terasa terlalu cepat."
        case .intentionalStop: "Keputusan berhenti dibuat sebelum target maksimum."
        case .discomfort: "Pilih ini untuk mencatat nyeri atau iritasi."
        case .rest: "Pemulihan tambahan terasa lebih realistis."
        }
    }

    private func reflectionIcon(_ option: TempoPrivateReflectionOutcome) -> String {
        switch option {
        case .planned: "checkmark.circle.fill"
        case .tooFast: "bolt.fill"
        case .intentionalStop: "hand.raised.fill"
        case .discomfort: "cross.case.fill"
        case .rest: "bed.double.fill"
        }
    }

    private func completionMessage(_ record: LocalPrivateSession?) -> String {
        guard let record else { return "Record lokal berhasil dibuat." }
        let next = history.upcomingPlan.first { $0.scheduleDate > record.completedAt }
        if let next {
            return "Pemulihan dan rencana berikutnya sudah dihitung ulang. Langkah selanjutnya: \(tempoActivityName(next.effectiveKind)) pada \(next.scheduleDate.formatted(date: .abbreviated, time: .shortened))."
        }
        return "Pemulihan sudah dicatat. Tidak ada aktivitas tambahan yang perlu dikejar sekarang."
    }

    private func completionMetrics(_ record: LocalPrivateSession?) -> [TempoCompletionMetric] {
        guard let record else { return [] }
        return [
            TempoCompletionMetric(id: "active", title: "Waktu aktif", value: tempoV22Duration(record.activeSeconds ?? 0), icon: "timer"),
            TempoCompletionMetric(id: "recovery", title: "Pemulihan", value: tempoV22Duration(record.totalRecoverySeconds ?? 0), icon: "leaf.fill"),
            TempoCompletionMetric(id: "cycles", title: "Siklus", value: "\(record.completedCycles ?? 0)", icon: "repeat"),
            TempoCompletionMetric(id: "pauses", title: "Total jeda", value: "\(record.pauseCount)", icon: "pause.fill"),
            TempoCompletionMetric(id: "emergency", title: "Emergency", value: "\(record.emergencyPauseCount ?? 0)", icon: "hand.raised.fill"),
            TempoCompletionMetric(id: "outcome", title: "Hasil", value: record.outcome ?? "Minimal", icon: "checkmark.seal.fill")
        ]
    }

    private func tick() {
        guard scenePhase == .active,
              startedAt != nil,
              ![.ready, .paused, .reflection, .completion].contains(phase)
        else { return }
        totalSessionSeconds += 1
        switch phase {
        case .active:
            activeSeconds += 1
            if assistanceEnabled,
               activeSeconds.isMultiple(of: prescription.checkInIntervalSeconds) {
                if hapticsEnabled { TempoFeedback.selection() }
                speak("Cek zona intensitas")
            }
            if totalSessionSeconds >= prescription.maximumDurationSeconds {
                reflectionOutcome = .rest
                phase = .reflection
            }
        case .recovery:
            currentRecoverySeconds += 1
            totalRecoverySeconds += 1
            qualifyCurrentCycleIfNeeded()
        default:
            break
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
        reflectionOutcome = .tooFast
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

    private func enterWarning(for reason: PrivatePauseReason) {
        guard phase == .active else { return }
        warningReason = reason
        phase = .warning
        if hapticsEnabled {
            TempoFeedback.notification(reason == .emergency ? .error : .warning)
        }
        speak("Stop. Lepas tangan.")
        warningTask?.cancel()
        warningTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled, phase == .warning else { return }
            beginRecovery(for: reason)
        }
    }

    private func beginRecovery(for reason: PrivatePauseReason) {
        guard phase == .active || phase == .warning else { return }
        warningReason = nil
        currentRecoverySeconds = 0
        cycleTracker.beginRecovery(reason: reason, assistanceEnabled: assistanceEnabled)
        phase = .recovery
        if hapticsEnabled, reason == .manual || reason == .interruption {
            TempoFeedback.impact(.medium)
        }
    }

    private func qualifyCurrentCycleIfNeeded() {
        guard phase == .recovery else { return }
        if cycleTracker.qualifyRecovery(
            elapsedSeconds: currentRecoverySeconds,
            intensity: intensity,
            minimumRecoverySeconds: prescription.recoverySeconds
        ), hapticsEnabled {
            TempoFeedback.notification(.success)
            UIAccessibility.post(notification: .announcement, argument: "Siklus ini siap disimpan.")
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
        guard let startedAt else {
            dismiss()
            return
        }

        let tooFast = reflectionOutcome == .tooFast || emergencyPauseCount > 0
        let stoppedIntentionally = reflectionOutcome == .intentionalStop || reflectionOutcome == .planned
        if painAfter || irritationAfter {
            let reason = painAfter ? "safety.private-session-pain" : "safety.private-session-irritation"
            let severity = painAfter ? RecommendationSeverity.urgent.rawValue : RecommendationSeverity.caution.rawValue
            guard history.recordSafetyHold(reasonCode: reason, severity: severity, source: "private-session") else {
                saveFailed = true
                return
            }
        }

        guard history.addPrivateSession(
            startedAt: startedAt,
            elapsedSeconds: totalSessionSeconds,
            pauseCount: manualPauseCount + thresholdPauseCount + emergencyPauseCount + interruptionPauseCount,
            outcome: reflectionOutcome.storedValue,
            note: note.isEmpty ? nil : note,
            saveDetails: showDetails,
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
        ) else {
            saveFailed = true
            return
        }

        persistedRecord = history.privateSessions
            .filter { abs($0.startedAt.timeIntervalSince(startedAt)) < 1 }
            .max { $0.completedAt < $1.completedAt }
            ?? history.privateSessions.max { $0.completedAt < $1.completedAt }
        phase = .completion
        if hapticsEnabled { TempoFeedback.notification(.success) }
    }
}

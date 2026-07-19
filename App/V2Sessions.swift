import SwiftUI
import Combine
import AVFoundation

private func tempoDuration(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    return "\(safe / 60):\(String(format: "%02d", safe % 60))"
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
        let request = ImmediateActionRequest(
            choice: choice,
            intensity: intensity,
            anxiety: Int((history.currentAnxiety ?? 5).rounded()),
            sleepHours: history.programContext.sleepHours,
            hoursSinceLastGuidedSession: history.hoursSinceLastSession,
            hoursSinceLastPrivateSession: history.hoursSinceLastPrivateSession,
            guidedSessionsLast7Days: history.guidedSessionsLast7Days,
            guidedEligibility: history.guidedEligibility,
            hasPhysicalSymptoms: symptomReported
        )
        let result = ImmediateActionRouter().route(request)
        let recommendation: Recommendation
        switch result.destination {
        case .healthCheck:
            recommendation = Recommendation(.healthCheck, .urgent, "safety.immediate-symptoms", "Gejala fisik perlu diperiksa sebelum melanjutkan.", blocked: true)
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
            TempoPrimaryButton("Pilih sesi privat", icon: "hand.raised.fill") { coordinator.open(.privateSession([])) }
            TempoSecondaryButton("Reset lima menit", icon: "wind", tone: .caution) { coordinator.open(.breathing(nil, "Reset lima menit", 300)) }
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
                    }.buttonStyle(TempoTactileButtonStyle())
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Intensitas saat ini")
        .accessibilityValue("\(value) dari 10")
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
    @State private var emergencyPauseCount = 0
    @State private var completedCycles = 0
    @State private var intensity = 3
    @State private var saveDetails = false
    @State private var outcome = "Lebih tenang"
    @State private var note = ""
    @State private var tooFast = false
    @State private var stoppedIntentionally = true
    @State private var painAfter = false
    @State private var irritationAfter = false
    @State private var saveFailed = false
    @State private var warningTask: Task<Void, Never>?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum PrivatePhase: String, Equatable { case ready, active, warning, recovery, paused, reflection, saved }
    private var prescription: SessionPrescription { history.sessionPrescription }
    private var canResume: Bool { currentRecoverySeconds >= prescription.recoverySeconds && intensity <= 4 }

    init(advisories: [ImmediateActionAdvisory] = []) { self.advisories = advisories }

    var body: some View {
        ZStack {
            (phase == .warning ? Color(red: 0.32, green: 0.02, blue: 0.03) : TempoDesign.Palette.canvas).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: TempoDesign.Spacing.lg) {
                    Spacer(minLength: TempoDesign.Spacing.lg)
                    if phase == .warning { warningContent }
                    else {
                        Image(systemName: phase == .recovery || phase == .paused ? "pause.circle.fill" : "hand.raised.fill")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(phase == .recovery || phase == .paused ? TempoDesign.Palette.caution : TempoDesign.Palette.accentSoft)
                        Text(phase == .ready ? "Sesi privat" : tempoDuration(totalSessionSeconds))
                            .font(phase == .ready ? TempoDesign.Typography.pageTitle : .system(size: 58, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(message).multilineTextAlignment(.center).foregroundStyle(TempoDesign.Palette.textSecondary)
                        content
                    }
                    Spacer(minLength: TempoDesign.Spacing.lg)
                }
                .frame(maxWidth: TempoDesign.readableContentWidth, minHeight: 620)
                .padding(TempoDesign.Spacing.lg)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(ticker) { _ in tick() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active, phase == .active, assistanceEnabled { enterWarning(emergency: false) }
        }
        .onChange(of: intensity) { _, value in
            if assistanceEnabled, phase == .active, value >= prescription.pauseThreshold { enterWarning(emergency: false) }
        }
        .onDisappear { warningTask?.cancel(); speaker.stopSpeaking(at: .immediate) }
        .alert("Sesi belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { save() } } message: { Text("Pemulihan tidak akan dijadwalkan ulang sampai catatan lokal berhasil disimpan.") }
        .accessibilityIdentifier("private.session.timer")
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
                Toggle("Bantuan start–stop", isOn: $assistanceEnabled).tint(TempoDesign.Palette.accent)
                if assistanceEnabled {
                    Toggle("Prompt suara lokal", isOn: $spokenPromptsEnabled).tint(TempoDesign.Palette.accent)
                    Text("Ambang otomatis \(prescription.pauseThreshold)/10 · pemulihan minimal \(prescription.recoverySeconds) detik")
                        .font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
                }
                TempoPrimaryButton("Mulai dengan pelan", icon: "play.fill") { start() }
                TempoSecondaryButton("Kembali", icon: "xmark", tone: .neutral) { dismiss() }
            }
        case .active:
            VStack(spacing: TempoDesign.Spacing.md) {
                if assistanceEnabled {
                    TempoStatusBadge("Siklus \(completedCycles + 1) · ambang \(prescription.pauseThreshold)/10", tone: .accent)
                    TempoIntensitySelector(value: $intensity, accent: intensity >= prescription.pauseThreshold - 1 ? TempoDesign.Palette.caution : TempoDesign.Palette.accentSoft)
                }
                TempoPrimaryButton(assistanceEnabled ? "Jeda sekarang" : "Jeda", icon: "pause.fill") { manualPause() }
                TempoSecondaryButton("Hampir keluar", icon: "hand.raised.fill", tone: .critical) { enterWarning(emergency: true) }
                Button("Akhiri sesi") { phase = .reflection }.foregroundStyle(TempoDesign.Palette.textSecondary).frame(minHeight: 44)
            }
        case .warning:
            EmptyView()
        case .recovery:
            VStack(spacing: TempoDesign.Spacing.md) {
                Text("Pulih \(tempoDuration(currentRecoverySeconds))").font(TempoDesign.Typography.sectionTitle).monospacedDigit()
                Text("Total pemulihan \(tempoDuration(totalRecoverySeconds)) · \(completedCycles) siklus").font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
                TempoIntensitySelector(value: $intensity, accent: TempoDesign.Palette.positive)
                TempoPrimaryButton(canResume ? "Lanjutkan dengan pelan" : "Tunggu hingga siap", icon: "play.fill") { resumeFromRecovery() }
                    .disabled(!canResume)
                TempoSecondaryButton("Cukup untuk hari ini", icon: "checkmark", tone: .positive) { phase = .reflection }
            }
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
                Toggle("Terasa terlalu cepat", isOn: $tooFast).tint(TempoDesign.Palette.caution)
                Toggle("Berhenti dengan sengaja", isOn: $stoppedIntentionally).tint(TempoDesign.Palette.accent)
                Toggle("Ada nyeri", isOn: $painAfter).tint(TempoDesign.Palette.critical)
                Toggle("Ada iritasi", isOn: $irritationAfter).tint(TempoDesign.Palette.caution)
                Toggle("Simpan catatan opsional", isOn: $saveDetails).tint(TempoDesign.Palette.accent)
                if saveDetails { TextField("Catatan singkat", text: $note, axis: .vertical).textFieldStyle(.roundedBorder) }
                TempoPrimaryButton("Simpan dan pulih", icon: "checkmark") { save() }
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
            Text("STOP — LEPAS TANGAN").font(.system(size: 31, weight: .black, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 440)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stop. Lepas tangan.")
    }

    private var message: String {
        switch phase {
        case .ready: "Pilih apakah TEMPO membantu mengatur jeda. Kamu tetap memegang keputusan sesi."
        case .active: assistanceEnabled ? "Perbarui intensitas dengan satu tangan. TEMPO akan menghentikan siklus di ambang program." : "Timer berjalan. Jeda dan akhiri kapan pun dibutuhkan."
        case .warning: ""
        case .recovery: canResume ? "Pemulihan minimum terpenuhi dan intensitas sudah turun." : "Lanjut hanya setelah waktu minimum selesai dan intensitas maksimal 4."
        case .paused: "Timer aktif berhenti selama jeda."
        case .reflection: "Catat hasil secukupnya agar jadwal pemulihan berikutnya akurat."
        case .saved: ""
        }
    }

    private func tick() {
        guard scenePhase == .active, startedAt != nil, ![.ready, .reflection, .saved].contains(phase) else { return }
        totalSessionSeconds += 1
        switch phase {
        case .active:
            activeSeconds += 1
            if assistanceEnabled, activeSeconds.isMultiple(of: prescription.checkInIntervalSeconds) {
                if hapticsEnabled { TempoFeedback.selection() }
                speak("Cek intensitas")
            }
            if totalSessionSeconds >= prescription.maximumDurationSeconds { phase = .reflection }
        case .recovery:
            currentRecoverySeconds += 1
            totalRecoverySeconds += 1
        default: break
        }
    }

    private func start() {
        startedAt = .now
        phase = .active
        if hapticsEnabled { TempoFeedback.impact(.light) }
    }

    private func manualPause() {
        manualPauseCount += 1
        if assistanceEnabled { enterWarning(emergency: false) }
        else { phase = .paused; if hapticsEnabled { TempoFeedback.impact(.light) } }
    }

    private func enterWarning(emergency: Bool) {
        guard phase == .active else { return }
        if emergency { emergencyPauseCount += 1 }
        phase = .warning
        if hapticsEnabled { TempoFeedback.notification(.warning) }
        speak("Stop. Lepas tangan.")
        warningTask?.cancel()
        warningTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, phase == .warning else { return }
            currentRecoverySeconds = 0
            phase = .recovery
        }
    }

    private func resumeFromRecovery() {
        guard canResume else { return }
        completedCycles += 1
        currentRecoverySeconds = 0
        phase = .active
        if hapticsEnabled { TempoFeedback.notification(.success) }
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
        if painAfter || irritationAfter {
            let reason = painAfter ? "safety.private-session-pain" : "safety.private-session-irritation"
            let severity = painAfter ? RecommendationSeverity.urgent.rawValue : RecommendationSeverity.caution.rawValue
            guard history.recordSafetyHold(reasonCode: reason, severity: severity, source: "private-session") else { saveFailed = true; return }
        }
        guard history.addPrivateSession(
            startedAt: startedAt,
            elapsedSeconds: totalSessionSeconds,
            pauseCount: manualPauseCount + emergencyPauseCount,
            outcome: outcome,
            note: note.isEmpty ? nil : note,
            saveDetails: saveDetails,
            activeSeconds: activeSeconds,
            totalRecoverySeconds: totalRecoverySeconds,
            manualPauseCount: manualPauseCount,
            emergencyPauseCount: emergencyPauseCount,
            completedCycles: completedCycles,
            terminalState: stoppedIntentionally ? "intentional-stop" : "ended",
            assistanceEnabled: assistanceEnabled,
            tooFast: tooFast,
            stoppedIntentionally: stoppedIntentionally,
            painAfter: painAfter,
            irritationAfter: irritationAfter
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
    @State private var postAnxiety = 3
    @State private var postTension = 3
    @State private var painAfter = false
    @State private var irritationAfter = false
    @State private var saveFailed = false
    @State private var saved = false
    @State private var sessionPersisted = false
    @State private var arousalEvents: [LocalArousalEvent] = []
    @State private var pauseCycles: [LocalPauseCycle] = []
    @State private var pendingPauseStart: Int?
    @State private var pendingPauseIntensity = 3
    @State private var warningTask: Task<Void, Never>?
    @State private var warningPulse = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(plannedDayID: UUID? = nil) { self.plannedDayID = plannedDayID }

    var body: some View {
        ZStack {
            background
            VStack(spacing: TempoDesign.Spacing.lg) {
                header
                Spacer(minLength: 0)
                if let eligibilityMessage { blocked(eligibilityMessage) }
                else if showReflection { reflection }
                else { stateContent }
                Spacer(minLength: 0)
                if eligibilityMessage == nil && !showReflection { footer }
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, maxHeight: .infinity)
            .padding(TempoDesign.Spacing.lg)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { configure() }
        .onDisappear { warningTask?.cancel() }
        .onReceive(ticker) { now in tick(now) }
        .onChange(of: intensity) { _, level in handleIntensityChange(level) }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .alert("Sesi belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { saveSession() } } message: { Text("TEMPO mempertahankan status rencana sampai catatan sesi tersimpan lokal.") }
        .accessibilityIdentifier("guided.session")
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
        case .activeLow, .activeRising: active
        case .warning: warning
        case .pausedRecovery: recovery
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

    private var active: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            ZStack {
                Circle().stroke(TempoDesign.Palette.surfaceRaised, lineWidth: 14)
                Circle().trim(from: 0, to: min(1, Double(activeElapsed) / Double(prescription.activeTargetSeconds)))
                    .stroke(TempoDesign.Palette.accentSoft, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack { Text("Aktif").font(TempoDesign.Typography.caption); Text(tempoDuration(activeElapsed)).font(.title2.bold().monospacedDigit()) }
            }
            .frame(width: 150, height: 150)
            Text("Ikuti ritme yang ringan.").font(TempoDesign.Typography.pageTitle).multilineTextAlignment(.center)
            Text("Check-in angka ini kapan pun berubah. Ambang otomatis akan mengaktifkan peringatan dan jeda.")
                .foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            TempoIntensitySelector(value: $intensity, accent: TempoDesign.Palette.accentSoft)
            TempoSecondaryButton("Jeda sekarang", icon: "pause.fill", tone: .caution) { beginRecovery(reason: .manual) }
            TempoSecondaryButton("Hampir keluar", icon: "hand.raised.fill", tone: .critical) { beginRecovery(reason: .almostTooLate) }
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

    private var recovery: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "leaf.fill").font(.system(size: 52)).foregroundStyle(TempoDesign.Palette.positive)
            Text("Pemulihan").font(TempoDesign.Typography.pageTitle)
            Text("\(tempoDuration(max(0, prescription.recoverySeconds - currentRecoverySeconds)))").font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
            Text("Total pemulihan \(tempoDuration(totalRecoverySeconds))").font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
            Text("Pilih angka di bawah 5 hanya bila tubuh benar-benar lebih tenang.").foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            TempoIntensitySelector(value: $intensity, accent: TempoDesign.Palette.positive)
            TempoPrimaryButton("Periksa kesiapan", icon: "checkmark") { recover() }
        }
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
                TempoPrimaryButton("Lanjutkan dengan pelan", icon: "play.fill") { machine.beginActive() }
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
    }

    private var reflection: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            Text("Refleksi singkat").font(TempoDesign.Typography.pageTitle)
            Text("Catat seperlunya. Sinyal nyeri atau iritasi akan membuka safety hold.").foregroundStyle(TempoDesign.Palette.textSecondary)
            reflectionPicker("Kecemasan setelah", value: $postAnxiety)
            reflectionPicker("Ketegangan setelah", value: $postTension)
            Toggle("Ada nyeri setelah sesi", isOn: $painAfter).tint(TempoDesign.Palette.critical)
            Toggle("Ada iritasi setelah sesi", isOn: $irritationAfter).tint(TempoDesign.Palette.caution)
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
    private func beginPreparation() { startedAt = .now; machine.start(); TempoFeedback.impact(.light) }
    private func beginActive() { machine.beginActive(); TempoFeedback.selection() }
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
            if hapticsEnabled { TempoFeedback.impact(.medium) }
        }
    }
    private func recover() {
        let previousState = machine.state
        let previousCycles = machine.cycles
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
        if hapticsEnabled { TempoFeedback.notification(.success) }
    }
    private func saveSession() {
        guard !saved else { dismiss(); return }
        if !sessionPersisted {
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
                postAnxiety: postAnxiety,
                postTension: postTension,
                painAfter: painAfter,
                irritationAfter: irritationAfter,
                outcome: machine.state.rawValue,
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
            warningPulse = false
        }
    }

    private func finishEarly() {
        machine.earlyCompletion()
        showReflection = true
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
    }
    private func finish() {
        running = false
        let performedKind = plannedDayID.flatMap { id in history.plannedDays.first(where: { $0.id == id })?.effectiveKind } ?? .breathing
        if let plannedDayID, !history.completePlanItem(id: plannedDayID, performedKind: performedKind, completedAt: .now) { saveFailed = true; return }
        completed = true
        TempoFeedback.notification(.success)
    }
}

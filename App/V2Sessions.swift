import SwiftUI
import Combine

private func tempoDuration(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    return "\(safe / 60):\(String(format: "%02d", safe % 60))"
}

private enum TempoImmediateChoice: String, CaseIterable, Identifiable, Equatable {
    case privateSession
    case reset
    case guided

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
    @State private var choice: TempoImmediateChoice = .reset
    @State private var intensity = 5
    @State private var symptomReported = false
    @State private var saveFailed = false

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
            ForEach(TempoImmediateChoice.allCases) { option in
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
        if symptomReported {
            var context = DecisionContext()
            context.programPhase = history.effectiveProgramPhase
            context.intent = .training
            context.pain = true
            let recommendation = RuleEngine().evaluate(context)
            if history.add(intensity: intensity, trigger: .desire, intent: .training, recommendation: recommendation) {
                replaceWith(.healthCheck)
            } else { saveFailed = true }
            return
        }
        let intent: UrgeIntent
        switch choice {
        case .privateSession: intent = .privateSession
        case .reset: intent = .calm
        case .guided: intent = .training
        }
        var context = DecisionContext()
        context.programPhase = history.effectiveProgramPhase
        context.urgeIntensity = intensity
        context.intent = intent
        context.trigger = intensity >= 8 ? .stress : .desire
        context.anxiety = Int((history.currentAnxiety ?? 5).rounded())
        context.hoursSinceLastSession = history.hoursSinceLastSession
        context.guidedSessionsLast7Days = history.guidedSessionsLast7Days
        let recommendation = RuleEngine().evaluate(context)
        guard history.add(intensity: intensity, trigger: context.trigger ?? .desire, intent: intent, recommendation: recommendation) else { saveFailed = true; return }
        switch recommendation.action {
        case .healthCheck: replaceWith(.healthCheck)
        case .privateSession: replaceWith(.privateSession)
        case .guidedSession:
            if history.guidedEligibility.isAllowed { replaceWith(.guided(nil)) }
            else { replaceWith(.breathing(nil, "Pemulihan", 300)) }
        case .urgeSurf, .regulate, .recovery: replaceWith(.breathing(nil, "Reset lima menit", 300))
        case .exercise: replaceWith(.cardio(nil))
        case .education: replaceWith(.lesson(nil, "Jeda sebelum memilih"))
        }
    }

    private func replaceWith(_ route: TempoRoute) {
        if coordinator.path.last == .immediateAction { coordinator.path.removeLast() }
        coordinator.open(route)
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
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var startedAt: Date?
    @State private var pausedAt: Date?
    @State private var pausedSeconds = 0
    @State private var elapsed = 0
    @State private var pauseCount = 0
    @State private var phase: PrivatePhase = .ready
    @State private var saveDetails = false
    @State private var outcome = "Lebih tenang"
    @State private var note = ""
    @State private var symptomAfter = false
    @State private var saveFailed = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum PrivatePhase: Equatable { case ready, active, paused, reflection, saved }

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.xl) {
            Spacer()
            Image(systemName: phase == .paused ? "pause.circle.fill" : "hand.raised.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(phase == .paused ? TempoDesign.Palette.caution : TempoDesign.Palette.accentSoft)
            Text(phase == .ready ? "Sesi privat" : tempoDuration(elapsed))
                .font(phase == .ready ? TempoDesign.Typography.pageTitle : .system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(message).multilineTextAlignment(.center).foregroundStyle(TempoDesign.Palette.textSecondary).padding(.horizontal, TempoDesign.Spacing.xl)
            content
            Spacer()
        }
        .padding(TempoDesign.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TempoDesign.Palette.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(ticker) { _ in updateElapsed() }
        .alert("Sesi belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { save() } } message: { Text("Pemulihan tidak akan dijadwalkan ulang sampai catatan lokal berhasil disimpan.") }
        .accessibilityIdentifier("private.session.timer")
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .ready:
            VStack(spacing: TempoDesign.Spacing.sm) {
                TempoPrimaryButton("Mulai dengan pelan", icon: "play.fill") { start() }
                TempoSecondaryButton("Kembali", icon: "xmark", tone: .neutral) { dismiss() }
            }
        case .active:
            VStack(spacing: TempoDesign.Spacing.sm) {
                TempoPrimaryButton("Jeda", icon: "pause.fill") { pause() }
                TempoSecondaryButton("Butuh jeda darurat", icon: "hand.raised.fill", tone: .caution) { emergencyPause() }
                Button("Akhiri sesi") { phase = .reflection }.foregroundStyle(TempoDesign.Palette.textSecondary).frame(minHeight: 44)
            }
        case .paused:
            VStack(spacing: TempoDesign.Spacing.sm) {
                TempoPrimaryButton("Lanjut bila siap", icon: "play.fill") { resume() }
                TempoSecondaryButton("Akhiri dan pulih", icon: "checkmark", tone: .positive) { phase = .reflection }
            }
        case .reflection:
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                Text("Cek pulih singkat").font(TempoDesign.Typography.sectionTitle)
                Picker("Setelah sesi", selection: $outcome) {
                    Text("Lebih tenang").tag("Lebih tenang")
                    Text("Masih tegang").tag("Masih tegang")
                    Text("Butuh istirahat").tag("Butuh istirahat")
                }.pickerStyle(.segmented)
                Toggle("Simpan detail ringkas (opsional)", isOn: $saveDetails).tint(TempoDesign.Palette.accent)
                if saveDetails { TextField("Catatan singkat", text: $note, axis: .vertical).textFieldStyle(.roundedBorder) }
                Toggle("Ada nyeri atau iritasi baru", isOn: $symptomAfter).tint(TempoDesign.Palette.critical)
                TempoPrimaryButton("Simpan dan pulih", icon: "checkmark") { save() }
            }
            .padding(TempoDesign.Spacing.md)
            .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
        case .saved:
            TempoStatusBadge("Tersimpan secara lokal. Rencana berikutnya memberi ruang pemulihan.", tone: .positive)
        }
    }

    private var message: String {
        switch phase {
        case .ready: "Tidak ada durasi yang harus dikejar. Berhenti jika tubuh terasa tidak nyaman."
        case .active: "Jaga tempo yang pelan. Jeda adalah pilihan yang valid kapan pun."
        case .paused: "Ambil napas dan beri tubuh waktu turun sebelum memutuskan langkah berikutnya."
        case .reflection: "Detail bersifat opsional. Yang penting adalah memberi ruang pemulihan setelahnya."
        case .saved: ""
        }
    }

    private func updateElapsed() {
        guard phase == .active, let startedAt else { return }
        elapsed = max(elapsed, Int(Date.now.timeIntervalSince(startedAt)) - pausedSeconds)
    }
    private func start() { startedAt = .now; phase = .active; if hapticsEnabled { TempoFeedback.impact(.light) } }
    private func pause() { pausedAt = .now; pauseCount += 1; phase = .paused; if hapticsEnabled { TempoFeedback.impact(.medium) } }
    private func emergencyPause() { pausedAt = .now; pauseCount += 1; phase = .paused; if hapticsEnabled { TempoFeedback.notification(.warning) } }
    private func resume() {
        if let pausedAt { pausedSeconds += Int(Date.now.timeIntervalSince(pausedAt)) }
        self.pausedAt = nil; phase = .active
    }
    private func save() {
        updateElapsed()
        guard let startedAt else { dismiss(); return }
        if symptomAfter, !history.recordSafetyHold(reasonCode: "safety.private-session-symptom", severity: RecommendationSeverity.caution.rawValue, source: "private-session") { saveFailed = true; return }
        guard history.addPrivateSession(startedAt: startedAt, elapsedSeconds: elapsed, pauseCount: pauseCount, outcome: outcome, note: note.isEmpty ? nil : note, saveDetails: saveDetails) else { saveFailed = true; return }
        phase = .saved
        if symptomAfter { coordinator.open(.healthCheck) }
        else { dismiss() }
    }
}

struct TempoGuidedSessionScreen: View {
    let plannedDayID: UUID?
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var machine = GuidedSessionMachine()
    @State private var prescription = SessionPrescription(preparationSeconds: 90, activeTargetSeconds: 600, recoverySeconds: 40, maximumCycles: 2, pauseThreshold: 7, maximumDurationSeconds: 1_200, checkInIntervalSeconds: 45, reasons: [])
    @State private var startedAt: Date?
    @State private var lastTick = Date.now
    @State private var preparationElapsed = 0
    @State private var activeElapsed = 0
    @State private var recoveryElapsed = 0
    @State private var totalElapsed = 0
    @State private var intensity = 3
    @State private var eligibilityMessage: String?
    @State private var showReflection = false
    @State private var postAnxiety = 3
    @State private var postTension = 3
    @State private var painAfter = false
    @State private var irritationAfter = false
    @State private var saveFailed = false
    @State private var saved = false
    @State private var warningTask: Task<Void, Never>?
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
        .alert("Sesi belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { saveSession() } } message: { Text("TEMPO mempertahankan status rencana sampai catatan sesi tersimpan lokal.") }
        .accessibilityIdentifier("guided.session")
    }

    private var background: some View {
        Group {
            if machine.state == .warning { TempoDesign.Palette.critical.opacity(0.22) }
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
                timerLabel("Pulih", recoveryElapsed, tint: TempoDesign.Palette.positive)
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
            TempoPrimaryButton("Mulai persiapan", icon: "play.fill") { beginPreparation() }
            TempoSecondaryButton("Ada gejala", icon: "cross.case.fill", tone: .caution) { machine.abortForSafety(); coordinator.open(.healthCheck) }
        }
    }

    private var preparation: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "lungs.fill").font(.system(size: 50)).foregroundStyle(TempoDesign.Palette.accentSoft)
            Text("Persiapan").font(TempoDesign.Typography.pageTitle)
            Text("\(tempoDuration(max(0, prescription.preparationSeconds - preparationElapsed)))").font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
            Text("Turunkan bahu, longgarkan rahang, dan kenali sinyal tubuh tanpa mengejar hasil.").foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            TempoSecondaryButton("Saya siap lebih awal", icon: "arrow.right") { beginActive() }
        }
    }

    private var active: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "waveform.path.ecg").font(.system(size: 50)).foregroundStyle(TempoDesign.Palette.accentSoft)
            Text("Ikuti ritme yang ringan.").font(TempoDesign.Typography.pageTitle).multilineTextAlignment(.center)
            Text("Check-in angka ini kapan pun berubah. Ambang otomatis akan mengaktifkan peringatan dan jeda.")
                .foregroundStyle(TempoDesign.Palette.textSecondary).multilineTextAlignment(.center)
            TempoIntensitySelector(value: $intensity, accent: TempoDesign.Palette.accentSoft)
            TempoSecondaryButton("Jeda sekarang", icon: "pause.fill", tone: .caution) { beginRecovery(reason: .manual) }
            TempoSecondaryButton("Mendekati batas", icon: "hand.raised.fill", tone: .critical) { beginRecovery(reason: .almostTooLate) }
        }
    }

    private var warning: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "exclamationmark.octagon.fill").font(.system(size: 72)).foregroundStyle(TempoDesign.Palette.critical)
            Text("BERHENTI SEKARANG").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(TempoDesign.Palette.textPrimary)
            Text("Hands off. Diam. Ambil napas perlahan. TEMPO akan masuk ke pemulihan setelah peringatan ini terlihat.")
                .font(.title3).multilineTextAlignment(.center).foregroundStyle(TempoDesign.Palette.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Peringatan. Berhenti sekarang dan mulai pemulihan.")
        .accessibilityAddTraits(.isHeader)
    }

    private var recovery: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "leaf.fill").font(.system(size: 52)).foregroundStyle(TempoDesign.Palette.positive)
            Text("Pemulihan").font(TempoDesign.Typography.pageTitle)
            Text("\(tempoDuration(max(0, prescription.recoverySeconds - recoveryElapsed)))").font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
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
                TempoSecondaryButton("Cukup untuk hari ini", icon: "checkmark", tone: .positive) { machine.earlyCompletion(); showReflection = true }
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
                else { machine.earlyCompletion(); showReflection = true }
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
    private func beginPreparation() { startedAt = .now; lastTick = .now; machine.start(); TempoFeedback.impact(.light) }
    private func beginActive() { machine.beginActive(); TempoFeedback.selection() }
    private func tick(_ now: Date) {
        guard startedAt != nil, !machine.isTerminal else { return }
        let delta = max(0, Int(now.timeIntervalSince(lastTick)))
        guard delta > 0 else { return }
        lastTick = now
        totalElapsed += delta
        switch machine.state {
        case .prepare:
            preparationElapsed += delta
            if preparationElapsed >= prescription.preparationSeconds { beginActive() }
        case .activeLow, .activeRising, .warning: activeElapsed += delta
        case .pausedRecovery: recoveryElapsed += delta
        default: break
        }
        machine.updateElapsed(totalSeconds: totalElapsed)
        if machine.state == .timeLimitReached { showReflection = true }
    }
    private func beginRecovery(reason: GuidedPauseReason) {
        let changed: Bool
        if reason == .almostTooLate { changed = machine.emergencyPause() }
        else { changed = machine.pause(reason: reason) }
        guard changed else { return }
        recoveryElapsed = 0
        if hapticsEnabled { TempoFeedback.notification(reason == .almostTooLate ? .warning : .success) }
    }
    private func recover() {
        machine.recovered(level: intensity, elapsedSeconds: recoveryElapsed, minimumSeconds: prescription.recoverySeconds)
        if machine.state != .pausedRecovery { TempoFeedback.notification(.success) }
    }
    private func saveSession() {
        guard !saved else { dismiss(); return }
        guard history.addSession(startedAt: startedAt, cycles: machine.cycles, terminalState: machine.state, targetCycles: prescription.maximumCycles, pauseThreshold: prescription.pauseThreshold, maximumDurationSeconds: prescription.maximumDurationSeconds, preAnxiety: nil, durationSeconds: totalElapsed, lateStopOccurred: machine.lateStopOccurred, postAnxiety: postAnxiety, postTension: postTension, painAfter: painAfter, irritationAfter: irritationAfter, outcome: machine.state.rawValue, activeSeconds: activeElapsed, recoverySeconds: recoveryElapsed) else { saveFailed = true; return }
        if let plannedDayID, [.completed, .timeLimitReached].contains(machine.state) {
            guard history.completeTodayPlan(id: plannedDayID, performedKind: .guided) else { saveFailed = true; return }
        }
        saved = true
        if painAfter || irritationAfter { coordinator.open(.healthCheck) }
        else { dismiss() }
    }
    private func handleIntensityChange(_ level: Int) {
        guard machine.state == .activeLow || machine.state == .activeRising else { return }
        guard machine.rising(level: level, threshold: prescription.pauseThreshold) else { return }
        if hapticsEnabled { TempoFeedback.notification(.warning) }
        warningTask?.cancel()
        warningTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, machine.advanceWarningToRecovery() else { return }
            recoveryElapsed = 0
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
        if let plannedDayID, !history.completeTodayPlan(id: plannedDayID, performedKind: performedKind) { saveFailed = true; return }
        completed = true
        TempoFeedback.notification(.success)
    }
}

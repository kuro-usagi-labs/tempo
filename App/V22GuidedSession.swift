import SwiftUI
import Combine

/// Review-only guided-session presentation. The deterministic state machine is
/// unchanged; this view only consolidates controls, pre-fills current readiness,
/// and displays a completion summary from the persisted LocalSession record.
struct TempoV22GuidedSessionScreen: View {
    let plannedDayID: UUID?

    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var machine = GuidedSessionMachine()
    @State private var prescription = SessionPrescription(
        preparationSeconds: 45,
        activeTargetSeconds: 600,
        recoverySeconds: 40,
        maximumCycles: 2,
        pauseThreshold: 7,
        maximumDurationSeconds: 1_200,
        checkInIntervalSeconds: 45,
        reasons: []
    )
    @State private var startedAt: Date?
    @State private var preparationElapsed = 0
    @State private var activeElapsed = 0
    @State private var currentRecoverySeconds = 0
    @State private var totalRecoverySeconds = 0
    @State private var totalElapsed = 0
    @State private var intensity = TempoIntensityZone.calm.numericValue
    @State private var preAnxiety = 3
    @State private var editingPreAnxiety = false
    @State private var eligibilityMessage: String?
    @State private var showReflection = false
    @State private var postAnxiety = 3
    @State private var postTension = 3
    @State private var painAfter = false
    @State private var irritationAfter = false
    @State private var saveFailed = false
    @State private var sessionPersisted = false
    @State private var arousalEvents: [LocalArousalEvent] = []
    @State private var pauseCycles: [LocalPauseCycle] = []
    @State private var pendingPauseStart: Int?
    @State private var pendingPauseIntensity = TempoIntensityZone.calm.numericValue
    @State private var warningTask: Task<Void, Never>?
    @State private var warningPulse = false
    @State private var persistedRecord: LocalSession?
    @State private var showingCompletion = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isActive: Bool {
        machine.state == .activeLow || machine.state == .activeRising
    }

    private var canCheckRecovery: Bool {
        currentRecoverySeconds >= prescription.recoverySeconds
    }

    init(plannedDayID: UUID? = nil) {
        self.plannedDayID = plannedDayID
    }

    var body: some View {
        ZStack {
            background
            Group {
                if let eligibilityMessage {
                    blocked(eligibilityMessage)
                } else if showingCompletion {
                    completion
                } else if showReflection {
                    reflection
                } else {
                    stateContent
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isActive && !showReflection && !showingCompletion {
                TempoStickyActionBar {
                    TempoSessionControlBar(
                        pauseTitle: "Jeda",
                        dangerTitle: "Mendekati batas",
                        finishTitle: "Selesai",
                        pause: { beginRecovery(reason: .manual) },
                        danger: { beginRecovery(reason: .almostTooLate) },
                        finish: finishEarly
                    )
                    .accessibilityIdentifier("guided.controls")
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { configure() }
        .onDisappear { warningTask?.cancel() }
        .onReceive(ticker) { now in tick(now) }
        .onChange(of: intensity) { _, value in handleIntensityChange(value) }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .alert("Sesi belum tersimpan", isPresented: $saveFailed) {
            Button("Coba lagi") { saveSession() }
            Button("Tetap di sini", role: .cancel) {}
        } message: {
            Text("Completion summary dan status rencana tidak berubah sampai record guided session tersimpan lokal.")
        }
        .accessibilityIdentifier("guided.session.v22")
    }

    private var background: some View {
        Group {
            if machine.state == .warning {
                Color(red: 0.30, green: 0.01, blue: 0.03)
            } else if machine.state == .pausedRecovery {
                TempoDesign.Palette.positive.opacity(0.08)
            } else {
                TempoDesign.Palette.canvas
            }
        }
        .ignoresSafeArea()
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
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xl) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 48))
                        .foregroundStyle(TempoDesign.Palette.accentSoft)
                    Text("Sesi terpandu").font(TempoDesign.Typography.pageTitle)
                    Text("Mulai saat ruang dan waktumu cukup. Gejala baru selalu memiliki prioritas atas target sesi.")
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                }
                TempoCompactStatusRow(
                    title: "Ambang \(prescription.pauseThreshold)/10 · target \(prescription.maximumCycles) jeda",
                    detail: "Pemulihan minimum \(prescription.recoverySeconds) detik · target aktif \(tempoV22Duration(prescription.activeTargetSeconds))",
                    icon: "timer",
                    tone: .accent
                )
                .padding(TempoDesign.Spacing.md)
                .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))

                VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                    HStack {
                        Text("Kecemasan sebelum").font(TempoDesign.Typography.sectionTitle)
                        Spacer()
                        TempoStatusBadge("\(preAnxiety)/10", tone: preAnxiety >= 8 ? .caution : .accent)
                    }
                    if let readiness = history.todayReadiness, !editingPreAnxiety {
                        TempoCompactStatusRow(
                            title: "Diisi dari readiness hari ini",
                            detail: "Kecemasan \(readiness.anxietyToday)/10 · tidur \(readiness.sleepHoursLastNight.formatted(.number.precision(.fractionLength(0...1)))) jam",
                            icon: "checkmark.circle.fill",
                            tone: .positive,
                            actionTitle: "Ubah"
                        ) {
                            editingPreAnxiety = true
                        }
                    } else {
                        anxietySlider("Kecemasan sebelum", value: $preAnxiety)
                    }
                }
                TempoPrimaryButton("Mulai persiapan", icon: "play.fill") { beginPreparation() }
                    .accessibilityIdentifier("guided.start")
                TempoSecondaryButton("Ada gejala", icon: "cross.case.fill", tone: .caution) {
                    machine.abortForSafety()
                    coordinator.open(.healthCheck)
                }
                TempoSecondaryButton("Kembali", icon: "chevron.left", tone: .neutral) { dismiss() }
            }
        }
    }

    private var preparation: some View {
        VStack(spacing: TempoDesign.Spacing.xl) {
            TempoSessionHeader(
                title: "Persiapan",
                primaryValue: tempoV22Duration(max(0, prescription.preparationSeconds - preparationElapsed)),
                primaryLabel: "tersisa",
                secondaryItems: [("Target aktif", tempoV22Duration(prescription.activeTargetSeconds))]
            )
            Spacer(minLength: 0)
            BreathingOrbView().frame(width: 150, height: 150)
            Text("Turunkan bahu dan longgarkan rahang.")
                .font(TempoDesign.Typography.pageTitle)
                .multilineTextAlignment(.center)
            Text("Kenali sinyal tubuh tanpa mengejar hasil.")
                .foregroundStyle(TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
            TempoSecondaryButton("Saya siap lebih awal", icon: "arrow.right") { beginActive() }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.lg)
    }

    private var active: some View {
        VStack(spacing: TempoDesign.Spacing.md) {
            TempoSessionHeader(
                title: "Sesi terpandu",
                primaryValue: tempoV22Duration(activeElapsed),
                primaryLabel: "waktu aktif",
                secondaryItems: [
                    ("Pulih", tempoV22Duration(totalRecoverySeconds)),
                    ("Siklus", "\(machine.cycles + 1)/\(machine.maximumCycles)"),
                    ("Zona", TempoIntensityZone(numericValue: intensity).title)
                ]
            )
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(TempoDesign.Palette.surfaceElevated, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: min(1, Double(activeElapsed) / Double(max(1, prescription.activeTargetSeconds))))
                    .stroke(TempoDesign.Palette.accentSoft, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 0.3), value: activeElapsed)
                Image(systemName: "waveform.path")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(TempoDesign.Palette.accentSoft)
            }
            .frame(width: 126, height: 126)
            Text("Ikuti ritme yang ringan.")
                .font(TempoDesign.Typography.pageTitle)
                .multilineTextAlignment(.center)
            Text("Pindahkan zona hanya ketika sensasinya benar-benar berubah.")
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
            TempoIntensityZoneControl(numericValue: $intensity, accessibilityIdentifier: "guided.intensity")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(.horizontal, TempoDesign.Spacing.lg)
        .padding(.top, TempoDesign.Spacing.md)
        .padding(.bottom, 104)
        .accessibilityIdentifier("guided.active")
    }

    private var warning: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 8)
                    .frame(width: 150, height: 150)
                    .scaleEffect(warningPulse ? 1.18 : 0.88)
                    .opacity(warningPulse ? 0.15 : 0.9)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
            }
            Text("STOP — LEPAS TANGAN")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Diam dan ambil napas perlahan. Pemulihan dimulai otomatis.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.lg)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.8).repeatForever(autoreverses: false)) {
                    warningPulse = true
                }
            }
            UIAccessibility.post(notification: .announcement, argument: "Stop. Lepas tangan. Pemulihan dimulai.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Peringatan. Berhenti sekarang dan mulai pemulihan.")
        .accessibilityIdentifier("guided.warning")
    }

    private var recovery: some View {
        VStack(spacing: TempoDesign.Spacing.md) {
            TempoSessionHeader(
                title: "Pemulihan",
                primaryValue: tempoV22Duration(max(0, prescription.recoverySeconds - currentRecoverySeconds)),
                primaryLabel: "minimum tersisa",
                secondaryItems: [
                    ("Aktif", tempoV22Duration(activeElapsed)),
                    ("Total pulih", tempoV22Duration(totalRecoverySeconds)),
                    ("Zona", TempoIntensityZone(numericValue: intensity).title)
                ]
            )
            Spacer(minLength: 0)
            Text(canCheckRecovery ? "Periksa apakah tubuh sudah cukup turun." : "Biarkan waktu minimum selesai terlebih dahulu.")
                .font(TempoDesign.Typography.pageTitle)
                .multilineTextAlignment(.center)
            Text("Lanjut hanya pada zona Tenang atau Mulai naik.")
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
            TempoIntensityZoneControl(numericValue: $intensity, accessibilityIdentifier: "guided.recovery.intensity")
            TempoPrimaryButton("Periksa kesiapan", icon: "checkmark", isEnabled: canCheckRecovery) {
                recover()
            }
            TempoSecondaryButton("Cukup untuk hari ini", icon: "checkmark", tone: .positive) {
                finishEarly()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.lg)
        .accessibilityIdentifier("guided.recovery")
    }

    private var resume: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(TempoDesign.Palette.positive)
            Text(machine.cycles >= machine.maximumCycles ? "Sesi cukup untuk hari ini." : "Jeda tercatat.")
                .font(TempoDesign.Typography.pageTitle)
                .multilineTextAlignment(.center)
            Text(machine.cycles >= machine.maximumCycles ? "Tidak perlu menambah putaran." : "Lanjut dengan tempo ringan atau akhiri lebih awal.")
                .foregroundStyle(TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
            if machine.cycles >= machine.maximumCycles {
                TempoPrimaryButton("Lanjut ke refleksi", icon: "checkmark") {
                    machine.complete()
                    showReflection = true
                }
            } else {
                TempoPrimaryButton("Lanjutkan dengan pelan", icon: "play.fill") { beginActive() }
                TempoSecondaryButton("Cukup untuk hari ini", icon: "checkmark", tone: .positive) { finishEarly() }
            }
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.lg)
    }

    private var completed: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 58))
                .foregroundStyle(TempoDesign.Palette.positive)
            Text("Sesi selesai").font(TempoDesign.Typography.pageTitle)
            TempoPrimaryButton("Isi refleksi singkat", icon: "arrow.right") { showReflection = true }
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.lg)
    }

    private var cancelled: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Text("Sesi dihentikan").font(TempoDesign.Typography.pageTitle)
            Text("Tidak apa-apa berhenti. Gunakan pemulihan atau pemeriksaan bila tubuh terasa tidak nyaman.")
                .foregroundStyle(TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
            TempoPrimaryButton("Kembali", icon: "arrow.left") { dismiss() }
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.lg)
    }

    private func blocked(_ message: String) -> some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 50))
                .foregroundStyle(TempoDesign.Palette.caution)
            Text("Sesi terpandu belum tersedia")
                .font(TempoDesign.Typography.pageTitle)
                .multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
            TempoPrimaryButton("Pilih pemulihan", icon: "wind") {
                coordinator.open(.breathing(nil, "Pemulihan", 300))
            }
            TempoSecondaryButton("Kembali", icon: "chevron.left", tone: .neutral) { dismiss() }
        }
        .frame(maxWidth: TempoDesign.Layout.compactContentWidth, maxHeight: .infinity)
        .padding(TempoDesign.Spacing.lg)
    }

    private var reflection: some View {
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                Text("Refleksi singkat").font(TempoDesign.Typography.pageTitle)
                Text("Nilai setelah sesi membantu prescription berikutnya. Gejala baru membuka safety hold.")
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                anxietySlider("Kecemasan setelah", value: $postAnxiety)
                anxietySlider("Ketegangan setelah", value: $postTension)
                Toggle("Ada nyeri setelah sesi", isOn: $painAfter)
                    .tint(TempoDesign.Palette.critical)
                Toggle("Ada iritasi setelah sesi", isOn: $irritationAfter)
                    .tint(TempoDesign.Palette.caution)
                TempoPrimaryButton("Simpan sesi", icon: "checkmark") { saveSession() }
                    .accessibilityIdentifier("guided.save")
            }
        }
    }

    private var completion: some View {
        let record = persistedRecord
        return TempoScreenContainer {
            TempoCompletionSummary(
                title: "Latihan tersimpan",
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
        .accessibilityIdentifier("guided.completion")
    }

    private func anxietySlider(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            HStack {
                Text(title).font(TempoDesign.Typography.cardTitle)
                Spacer()
                Text("\(value.wrappedValue)/10").font(TempoDesign.Typography.numeric)
            }
            Slider(
                value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }),
                in: 1...10,
                step: 1
            )
            .tint(TempoDesign.Palette.accentSoft)
        }
    }

    private func configure() {
        let eligibility = history.guidedEligibility
        guard eligibility.isAllowed else {
            eligibilityMessage = eligibility.message
            return
        }
        prescription = history.sessionPrescription
        machine = GuidedSessionMachine(
            maximumCycles: prescription.maximumCycles,
            maximumDurationSeconds: prescription.maximumDurationSeconds
        )
        if let readiness = history.todayReadiness {
            preAnxiety = readiness.anxietyToday
            postAnxiety = readiness.anxietyToday
            editingPreAnxiety = false
        } else {
            preAnxiety = min(10, max(1, Int((history.currentAnxiety ?? 3).rounded())))
            postAnxiety = preAnxiety
            editingPreAnxiety = true
        }
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
            if activeElapsed.isMultiple(of: prescription.checkInIntervalSeconds), hapticsEnabled {
                TempoFeedback.selection()
            }
            if activeElapsed >= prescription.activeTargetSeconds, machine.cycles > 0 {
                machine.complete()
                showReflection = true
            }
        case .pausedRecovery:
            currentRecoverySeconds += 1
            totalRecoverySeconds += 1
        default:
            break
        }
        machine.updateElapsed(totalSeconds: totalElapsed)
        if machine.state == .timeLimitReached { showReflection = true }
    }

    private func beginRecovery(reason: GuidedPauseReason) {
        pendingPauseStart = totalElapsed
        pendingPauseIntensity = intensity
        let changed = reason == .almostTooLate ? machine.emergencyWarning() : machine.pause(reason: reason)
        guard changed else {
            pendingPauseStart = nil
            return
        }
        arousalEvents.append(LocalArousalEvent(
            timestampOffset: totalElapsed,
            level: intensity,
            eventType: reason.rawValue
        ))
        if reason == .almostTooLate {
            startWarningTransition()
        } else {
            currentRecoverySeconds = 0
            if hapticsEnabled { TempoFeedback.impact(.medium) }
        }
    }

    private func recover() {
        guard canCheckRecovery else { return }
        let previousState = machine.state
        let previousCycles = machine.cycles
        machine.recovered(
            level: intensity,
            elapsedSeconds: currentRecoverySeconds,
            minimumSeconds: prescription.recoverySeconds
        )
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

    private func handleIntensityChange(_ level: Int) {
        guard isActive else { return }
        arousalEvents.append(LocalArousalEvent(
            timestampOffset: totalElapsed,
            level: level,
            eventType: "check-in"
        ))
        guard machine.rising(level: level, threshold: prescription.pauseThreshold) else { return }
        pendingPauseStart = totalElapsed
        pendingPauseIntensity = level
        arousalEvents.append(LocalArousalEvent(
            timestampOffset: totalElapsed,
            level: level,
            eventType: GuidedPauseReason.threshold.rawValue
        ))
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
        if machine.state == .prepare {
            machine.cancel()
            dismiss()
            return
        }
        machine.earlyCompletion()
        guard machine.state == .earlyCompletion else { return }
        showReflection = true
    }

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
        guard phase != .active, isActive else { return }
        pendingPauseStart = totalElapsed
        pendingPauseIntensity = intensity
        if machine.pause(reason: .interruption) {
            currentRecoverySeconds = 0
            arousalEvents.append(LocalArousalEvent(
                timestampOffset: totalElapsed,
                level: intensity,
                eventType: GuidedPauseReason.interruption.rawValue
            ))
        }
    }

    private func saveSession() {
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
                postAnxiety: postAnxiety,
                postTension: postTension,
                painAfter: painAfter,
                irritationAfter: irritationAfter,
                outcome: machine.state.rawValue,
                arousalEvents: arousalEvents,
                pauseCycles: pauseCycles,
                activeSeconds: activeElapsed,
                recoverySeconds: totalRecoverySeconds
            ) else {
                saveFailed = true
                return
            }
            sessionPersisted = true
        }

        let meaningfulEarly = machine.state == .earlyCompletion && (
            machine.cycles > 0 || activeElapsed >= min(120, prescription.activeTargetSeconds / 3)
        )
        if let plannedDayID,
           ([.completed, .timeLimitReached].contains(machine.state) || meaningfulEarly) {
            guard history.completePlanItem(id: plannedDayID, performedKind: .guided, completedAt: .now) else {
                saveFailed = true
                return
            }
        }

        persistedRecord = history.sessions
            .filter { record in
                guard let start = record.startedAt, let startedAt else { return false }
                return abs(start.timeIntervalSince(startedAt)) < 1
            }
            .max { $0.completedAt < $1.completedAt }
            ?? history.sessions.max { $0.completedAt < $1.completedAt }
        showReflection = false
        showingCompletion = true
        if hapticsEnabled { TempoFeedback.notification(.success) }
    }

    private func completionMessage(_ record: LocalSession?) -> String {
        guard let record else { return "Record guided session berhasil disimpan." }
        let next = history.upcomingPlan.first { $0.scheduleDate > record.completedAt }
        if let next {
            return "Prescription dan plan sudah membaca hasil ini. Langkah berikutnya: \(tempoActivityName(next.effectiveKind)) pada \(next.scheduleDate.formatted(date: .abbreviated, time: .shortened))."
        }
        return "Prescription sudah membaca hasil ini. Tidak ada target tambahan yang perlu dikejar sekarang."
    }

    private func completionMetrics(_ record: LocalSession?) -> [TempoCompletionMetric] {
        guard let record else { return [] }
        let warnings = record.pauseCycles?.filter { !$0.lateStop && $0.arousalBefore >= (record.pauseThreshold ?? 7) }.count ?? 0
        let emergency = record.pauseCycles?.filter(\.lateStop).count ?? (record.lateStopOccurred == true ? 1 : 0)
        return [
            TempoCompletionMetric(id: "active", title: "Waktu aktif", value: tempoV22Duration(record.activeSeconds ?? 0), icon: "timer"),
            TempoCompletionMetric(id: "recovery", title: "Pemulihan", value: tempoV22Duration(record.recoverySeconds ?? 0), icon: "leaf.fill"),
            TempoCompletionMetric(id: "cycles", title: "Siklus", value: "\(record.cycles)", icon: "repeat"),
            TempoCompletionMetric(id: "warnings", title: "Threshold", value: "\(warnings)", icon: "exclamationmark.circle.fill"),
            TempoCompletionMetric(id: "emergency", title: "Emergency", value: "\(emergency)", icon: "hand.raised.fill"),
            TempoCompletionMetric(id: "anxiety", title: "Kecemasan akhir", value: "\(record.postAnxiety ?? postAnxiety)/10", icon: "waveform.path.ecg")
        ]
    }
}

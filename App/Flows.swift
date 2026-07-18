import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct UrgeCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalHistory.self) private var history
    @AppStorage("discreetTerminology") private var discreetTerminology = false
    @State private var step = 0; @State private var intensity = 5; @State private var trigger: UrgeTrigger = .desire; @State private var intent: UrgeIntent = .calm
    @State private var safetyAnswers = SafetyScreeningAnswers()
    @State private var result: Recommendation?
    @State private var saveFailed = false
    var body: some View { NavigationStack { ScrollView { VStack(spacing: 28) {
        HStack { ForEach(0..<4, id: \.self) { i in Capsule().fill(i <= step ? Color.indigo : Color.white.opacity(0.15)).frame(height: 5) } }.padding(.horizontal)
        if let result { RecommendationView(result: result, initialIntensity: intensity, dismiss: dismiss) } else { Group { switch step { case 0: intensityQuestion; case 1: triggerQuestion; case 2: intentQuestion; default: safetyQuestion } }; Button(step == 3 ? "Lihat rekomendasi" : "Lanjut") { advance() }.buttonStyle(.borderedProminent).controlSize(.large).padding() }
    }.padding(.top) }.navigationTitle("Check-in cepat").toolbar { Button("Tutup") { dismiss() } }.alert("Data belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") {} } message: { Text("TEMPO tidak dapat menyimpan check-in dengan aman. Rekomendasi belum diterapkan.") } } }
    private var intensityQuestion: some View { VStack(spacing: 20) { Text("Seberapa kuat intensitasnya?").font(.title2.bold()); Text("\(intensity)").font(.largeTitle.bold().monospacedDigit()).foregroundStyle(intensity >= 7 ? .orange : .indigo); Slider(value: Binding(get: { Double(intensity) }, set: { intensity = Int($0.rounded()) }), in: 1...10, step: 1).padding(.horizontal, 28).accessibilityLabel("Intensitas").accessibilityValue("\(intensity) dari 10"); Text("Tidak ada jawaban yang salah. Cukup perhatikan apa yang terasa sekarang.").multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal) } }
    private var triggerQuestion: some View { ChoiceQuestion(title: "Apa konteksnya sekarang?", selection: $trigger, labels: [.init(.desire, discreetTerminology ? "Dorongan fisik" : "Gairah seksual"), .init(.boredom, "Bosan"), .init(.stress, "Stres"), .init(.loneliness, "Kesepian"), .init(.sleep, "Sulit tidur")]) }
    private var intentQuestion: some View { ChoiceQuestion(title: "Apa yang kamu butuhkan?", selection: $intent, labels: [.init(.calm, "Menenangkan diri"), .init(.training, "Latihan kontrol"), .init(.privateSession, "Sesi pribadi")]) }
    private var safetyQuestion: some View { VStack(spacing: 20) { Text("Periksa tanda keselamatan").font(.title2.bold()).multilineTextAlignment(.center); SafetyScreeningFields(answers: $safetyAnswers).padding().background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16)); Text("Keluhan akan menghentikan latihan dan mengarahkanmu ke panduan yang sesuai.").foregroundStyle(.secondary).multilineTextAlignment(.center) }.padding() }
    private func advance() { if step < 3 { step += 1 } else { var c = DecisionContext(); c.programPhase = history.effectiveProgramPhase; c.urgeIntensity = intensity; c.trigger = trigger; c.intent = intent; safetyAnswers.apply(to: &c); c.anxiety = Int((history.currentAnxiety ?? 5).rounded()); c.hoursSinceLastSession = history.hoursSinceLastSession; c.guidedSessionsLast7Days = history.guidedSessionsLast7Days; let recommendation = RuleEngine().evaluate(c); if history.add(intensity: intensity, trigger: trigger, intent: intent, recommendation: recommendation) { result = recommendation } else { saveFailed = true } } }
}

struct ChoiceOption<T: Hashable>: Identifiable { let value: T; let title: String; var id: T { value }; init(_ value: T, _ title: String) { self.value = value; self.title = title } }
struct ChoiceQuestion<T: Hashable>: View { let title: String; @Binding var selection: T; let labels: [ChoiceOption<T>]; var body: some View { VStack(alignment: .leading, spacing: 14) { Text(title).font(.title2.bold()).padding(.bottom, 12); ForEach(labels) { item in Button { selection = item.value } label: { HStack { Text(item.title); Spacer(); if selection == item.value { Image(systemName: "checkmark.circle.fill") } }.padding().background(selection == item.value ? Color.indigo.opacity(0.6) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16)) } } }.padding() } }

struct RecommendationView: View {
    let result: Recommendation
    let initialIntensity: Int
    let dismiss: DismissAction
    @State private var showAction = false
    @State private var alternativeAction: RecommendedAction?
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: result.blocksGuidedTraining ? "cross.case.fill" : "sparkles").font(.system(.largeTitle)).foregroundStyle(result.blocksGuidedTraining ? .red : .cyan)
            Text(title).font(.title.bold()).multilineTextAlignment(.center)
            Text(result.message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Mengapa rekomendasi ini?").font(.headline)
            Text("TEMPO memeriksa keselamatan, pemulihan, intensitas, dan tujuanmu sebelum memberi saran.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(primaryTitle) { alternativeAction = nil; showAction = true }.buttonStyle(.borderedProminent).controlSize(.large)
            if !result.reasonCode.hasPrefix("safety.") {
                Menu("Pilihan aman lainnya") {
                    Button("Napas lima menit") { alternativeAction = .urgeSurf; showAction = true }
                    Button("Baca materi singkat") { alternativeAction = .education; showAction = true }
                    if result.action != .privateSession { Button("Panduan sesi pribadi") { alternativeAction = .privateSession; showAction = true } }
                }
            }
            Button("Tutup") { dismiss() }.foregroundStyle(.secondary).frame(minHeight: 44)
        }
        .padding()
        .sheet(isPresented: $showAction) { actionDestination }
    }
    private var title: String { switch result.action { case .healthCheck: "Hentikan latihan dulu"; case .recovery: "Waktunya pemulihan"; case .regulate, .urgeSurf: "Mari tenangkan ritme"; case .guidedSession: "Kamu siap berlatih"; case .privateSession: "Tetap pelan dan aman"; default: "Langkah kecil untuk hari ini" } }
    private var primaryTitle: String { switch result.action { case .healthCheck: "Buka health check"; case .recovery, .regulate, .urgeSurf: "Mulai napas terpandu"; case .guidedSession: "Mulai guided session"; case .privateSession: "Buka panduan aman"; case .education: "Baca materi singkat"; default: "Buka langkah berikutnya" } }
    @ViewBuilder private var actionDestination: some View {
        switch alternativeAction ?? result.action {
        case .healthCheck: HealthCheckView()
        case .guidedSession: NavigationStack { GuidedSessionView() }
        case .privateSession: NavigationStack { PrivateSessionGuidanceView() }
        case .urgeSurf, .regulate: NavigationStack { UrgeSurfView(initialIntensity: initialIntensity) }
        case .education: NavigationStack { LessonView(title: "Jeda sebelum memilih", body: "Dorongan dapat berubah jika diberi sedikit waktu. Perhatikan apakah konteksnya adalah keinginan, bosan, stres, kesepian, atau sulit tidur; pilih tindakan yang paling sesuai tanpa menghakimi diri.").toolbar { Button("Tutup") { showAction = false } } }
        default: NavigationStack { BreathingView(title: "Napas pemulihan", duration: 300).toolbar { Button("Tutup") { showAction = false } } }
        }
    }
}

struct UrgeSurfView: View {
    let initialIntensity: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalHistory.self) private var history
    @State private var startedAt = Date.now
    @State private var remaining = 300
    @State private var finalIntensity: Int
    @State private var saveFailed = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(initialIntensity: Int) {
        self.initialIntensity = initialIntensity
        _finalIntensity = State(initialValue: initialIntensity)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Reset lima menit").font(.title.bold())
                BreathingOrbView()
                if remaining > 0 {
                    Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))").font(.title.monospacedDigit())
                    Text("Amati dorongan seperti gelombang. Kamu tidak harus melawan atau langsung bertindak.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                } else {
                    Text("Nilai ulang").font(.headline)
                    Slider(value: Binding(get: { Double(finalIntensity) }, set: { finalIntensity = Int($0.rounded()) }), in: 1...10, step: 1)
                        .accessibilityLabel("Intensitas setelah reset").accessibilityValue("\(finalIntensity) dari 10")
                    Text("Intensitas sekarang: \(finalIntensity)/10").monospacedDigit()
                    Button("Simpan hasil") {
                        if history.addUrgeOutcome(initialIntensity: initialIntensity, finalIntensity: finalIntensity) { dismiss() }
                        else { saveFailed = true }
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                }
            }.frame(maxWidth: .infinity, minHeight: 540).padding()
        }
        .navigationTitle("Reset")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { now in remaining = max(0, 300 - Int(now.timeIntervalSince(startedAt))) }
        .alert("Hasil belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") {} } message: { Text("TEMPO tidak dapat menyimpan penilaian ulang dengan aman.") }
    }
}

struct PrivateSessionGuidanceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Pilihan pribadi yang aman", systemImage: "hand.raised.fill").font(.title2.bold()).foregroundStyle(.indigo)
                Text("Mulai tanpa terburu-buru, berhenti bila ada nyeri atau iritasi, dan jangan mengejar durasi tertentu.")
                Text("Jika intensitas meningkat cepat, hands off dan beri waktu sampai tubuh turun. Jangan langsung mengulang setelah tubuh terasa lelah atau tidak nyaman.").foregroundStyle(.secondary)
                Text("Pilihan ini tidak dihitung sebagai guided session dan tidak membuka safety hold atau batas pemulihan.").font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }.navigationTitle("Panduan privat").navigationBarTitleDisplayMode(.inline)
    }
}

struct ExerciseRestrictionBlockedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Gerak sedang dijeda", systemImage: "cross.case.fill")
        } description: {
            Text("Baseline mencatat pembatasan aktivitas. Minta penilaian tenaga kesehatan sebelum memulai latihan gerak.")
        }
        .navigationTitle("Gerak")
    }
}

struct TrainingView: View {
    @Environment(LocalHistory.self) private var history
    var body: some View {
        NavigationStack {
            List {
                Section("Sesi") {
                    if history.hasPendingSafetyWrite {
                        NavigationLink { HealthCheckView() } label: {
                            Label("Guided session dikunci · pulihkan safety hold", systemImage: "exclamationmark.shield.fill").foregroundStyle(.red)
                        }
                        Text("Penyimpanan safety hold sebelumnya belum berhasil. Gate tetap tertutup sampai pemeriksaan ulang tersimpan.").font(.caption).foregroundStyle(.secondary)
                    } else if let hold = history.activeSafetyHold {
                        NavigationLink { HealthCheckView() } label: {
                            Label("Guided session dijeda · periksa gejala", systemImage: "cross.case.fill").foregroundStyle(.red)
                        }
                        Text("Safety hold aktif sejak \(hold.createdAt.formatted(date: .abbreviated, time: .omitted)). Tidak dapat dilewati.").font(.caption).foregroundStyle(.secondary)
                    } else if history.guidedEligibility.reason == .baselineRequired {
                        Label("Lengkapi baseline dari tab Hari ini", systemImage: "checklist").foregroundStyle(.orange)
                    } else if !history.guidedEligibility.isAllowed {
                        Label("Guided session dijeda untuk pemulihan", systemImage: "bed.double.fill").foregroundStyle(.orange)
                    } else {
                        NavigationLink { GuidedSessionView() } label: {
                            Label("Guided control session", systemImage: "timer")
                        }
                    }
                    NavigationLink { BreathingView(title: "Urge surfing", duration: 300) } label: {
                        Label("Urge surfing · 5 menit", systemImage: "wind")
                    }
                    NavigationLink { BreathingView(title: "Napas pemulihan", duration: 60) } label: {
                        Label("Napas pemulihan", systemImage: "circle.dotted")
                    }
                }
                Section("Gerak") {
                    if history.activeSafetyHold?.severity == RecommendationSeverity.urgent.rawValue || history.baseline?.hasExerciseRestriction == true {
                        Label("Gerak dijeda sampai kondisi dinilai aman", systemImage: "cross.case.fill").foregroundStyle(.orange)
                    } else {
                        NavigationLink { ExerciseDetailView(kind: .walk) } label: {
                            Label("Jalan santai · 20 menit", systemImage: "figure.walk")
                        }
                        NavigationLink { ExerciseDetailView(kind: .strength) } label: {
                            Label("Kekuatan pemula", systemImage: "figure.strengthtraining.traditional")
                        }
                    }
                }
            }.navigationTitle("Latihan")
        }
    }
}

struct GuidedEligibilityBlockedView: View {
    let eligibility: GuidedEligibility
    var body: some View {
        ContentUnavailableView {
            Label("Guided session belum tersedia", systemImage: eligibility.reason == .safetyHold ? "cross.case.fill" : "bed.double.fill")
        } description: {
            Text(eligibility.message)
        }
        .navigationTitle("Pemulihan")
    }
}

struct ExerciseDetailView: View {
    enum Kind { case walk, strength }
    let kind: Kind
    @Environment(LocalHistory.self) private var history
    @State private var plannedDayID: UUID?
    @State private var completed = false
    @State private var activityLogged = false
    @State private var perceivedDifficulty = 3
    @State private var painReported = false
    @State private var saveFailed = false

    init(kind: Kind, plannedDayID: UUID? = nil) {
        self.kind = kind
        _plannedDayID = State(initialValue: plannedDayID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: kind == .walk ? "figure.walk" : "figure.strengthtraining.traditional").font(.system(size: 54)).foregroundStyle(.cyan)
                Text(kind == .walk ? "Jalan santai" : "Kekuatan pemula").font(.largeTitle.bold())
                Text(kind == .walk ? "Berjalan dengan tempo nyaman selama 15–20 menit. Kamu masih harus bisa berbicara tanpa terengah-engah." : "Lakukan dengan tempo nyaman. Berhenti jika muncul nyeri tajam, pusing, nyeri dada, atau sesak yang tidak biasa.").foregroundStyle(.secondary)
                if kind == .strength {
                    Card { VStack(alignment: .leading, spacing: 10) {
                        Text("Rangkaian").font(.headline)
                        Text("• Wall atau incline push-up: 2 × 6–10\n• Chair squat: 2 × 8–12\n• Glute bridge: 2 × 8–12\n• Bird dog: 2 × 6 per sisi\n• Calf raise: 2 × 10–15")
                    } }
                }
                valueControl
                Toggle("Ada nyeri tajam, pusing, nyeri dada, atau sesak tidak biasa", isOn: $painReported)
                    .tint(.red)
                Button(completed ? "Aktivitas selesai" : "Tandai selesai") { saveActivity() }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(completed)
                Text("Gerak mendukung kesehatan umum, suasana hati, tidur, dan pengelolaan stres. Ini bukan pengobatan untuk kondisi seksual.").font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }.navigationTitle("Aktivitas").navigationBarTitleDisplayMode(.inline)
            .onAppear { captureMatchingPlanIfNeeded() }
            .alert("Aktivitas belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { saveActivity() } } message: { Text("TEMPO tidak dapat menyimpan catatan atau status rencana dengan aman.") }
    }

    private func saveActivity() {
        guard !completed else { return }
        let activityKind: ActivityKind = kind == .walk ? .cardio : .strength
        captureMatchingPlanIfNeeded()
        if !activityLogged {
            if painReported, !history.recordSafetyHold(reasonCode: "safety.exercise-symptom", severity: RecommendationSeverity.urgent.rawValue, source: "exercise") { saveFailed = true; return }
            guard history.addExercise(kind: kind == .walk ? "Jalan santai" : "Kekuatan pemula", durationMinutes: kind == .walk ? 20 : 15, perceivedDifficulty: perceivedDifficulty, painReported: painReported) else { saveFailed = true; return }
            activityLogged = true
        }
        if let plannedDayID, !history.completeTodayPlan(id: plannedDayID, performedKind: activityKind) {
            saveFailed = true
            return
        }
        saveFailed = false
        completed = true
    }

    private func captureMatchingPlanIfNeeded() {
        guard plannedDayID == nil, let todayPlan = history.todayPlan, todayPlan.status == .planned else { return }
        let activityKind: ActivityKind = kind == .walk ? .cardio : .strength
        let effectiveKind = PlanActivityResolver().effectiveKind(
            todayPlan.kind,
            exerciseRestricted: history.baseline?.hasExerciseRestriction == true,
            guidedAllowed: history.guidedEligibility.isAllowed,
            isToday: true
        )
        if effectiveKind == activityKind { plannedDayID = todayPlan.id }
    }

    private var valueControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Tingkat kesulitan").font(.headline); Spacer(); Text("\(perceivedDifficulty)/10").monospacedDigit() }
            Slider(value: Binding(get: { Double(perceivedDifficulty) }, set: { perceivedDifficulty = Int($0.rounded()) }), in: 1...10, step: 1)
                .accessibilityLabel("Tingkat kesulitan aktivitas").accessibilityValue("\(perceivedDifficulty) dari 10")
        }
    }
}

struct GuidedSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LocalHistory.self) private var history
    @State private var plannedDayID: UUID?
    @State private var machine = GuidedSessionMachine()
    @State private var arousal = 3
    @State private var anxiety = 3
    @State private var safetyAnswers = SafetyScreeningAnswers()
    @State private var hasPrivateTime = true
    @State private var willFollowPrompts = true
    @State private var eligibilityMessage: String?
    @State private var sessionStartedAt: Date?
    @State private var prepareStartedAt: Date?
    @State private var recoveryStartedAt: Date?
    @State private var totalElapsed = 0
    @State private var prepareElapsed = 0
    @State private var recoveryElapsed = 0
    @State private var strongWarningPlayed = false
    @State private var gentleWarningPlayed = false
    @State private var resultSaved = false
    @State private var showEndOptions = false
    @State private var showPostCheck = false
    @State private var postAnxiety = 3
    @State private var postTension = 3
    @State private var painAfter = false
    @State private var irritationAfter = false
    @State private var outcome = "Lebih tenang"
    @State private var note = ""
    @State private var saveFailed = false
    @State private var planCompletionPending = false
    @State private var arousalEvents: [LocalArousalEvent] = []
    @State private var pauseCycles: [LocalPauseCycle] = []
    @State private var pauseStartedOffset: Int?
    @State private var pauseStartedLevel: Int?
    @State private var pauseWasLate = false
    @AccessibilityFocusState private var recoveryFocused: Bool
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let preparationMinimum = 90
    private let recoveryMinimum = 30

    init(plannedDayID: UUID? = nil) {
        _plannedDayID = State(initialValue: plannedDayID)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                if !showPostCheck && eligibilityMessage == nil {
                    Text(stateTitle).font(.title.bold()).multilineTextAlignment(.center)
                    Text(stateMessage).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }

                Group {
                    if let eligibilityMessage { eligibilityBlockedContent(eligibilityMessage) }
                    else if showPostCheck { postCheckContent }
                    else if machine.state == .precheck { precheckContent }
                    else if machine.state == .prepare { prepareContent }
                    else if [.activeLow, .activeRising, .warning].contains(machine.state) { arousalControls }
                    else if machine.state == .pausedRecovery { recoveryContent }
                    else if machine.state == .resumeReady { resumeContent }
                    else { terminalContent }
                }

                if !showPostCheck && !isTerminal {
                    Button(machine.state == .precheck ? "Batal" : "Akhiri sesi", role: .cancel) {
                        if machine.state == .precheck { cancelAndDismiss() } else { showEndOptions = true }
                    }
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
                }
            }
            .padding(24)
        }
        .background(machine.state == .pausedRecovery ? Color.red.opacity(0.12) : Color.black)
        .navigationBarBackButtonHidden(true)
        .onAppear { configureEligibility() }
        .onReceive(timer) { now in updateTimes(now: now) }
        .onChange(of: arousal) { _, newValue in handleArousalChange(newValue) }
        .onChange(of: machine.state) { _, newState in handleStateChange(newState) }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .confirmationDialog("Bagaimana ingin mengakhiri sesi?", isPresented: $showEndOptions, titleVisibility: .visible) {
            if machine.state != .prepare { Button("Selesaikan dan isi refleksi") { machine.complete() } }
            Button("Batalkan sesi", role: .destructive) { cancelAndDismiss() }
            Button("Lanjutkan sesi", role: .cancel) {}
        }
        .alert(planCompletionPending ? "Status rencana belum tersimpan" : "Sesi belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { retrySave() } } message: {
            Text(planCompletionPending ? "Catatan sesi sudah aman, tetapi status rencana perlu dicoba lagi." : "Data belum dapat disimpan dengan aman. Jangan mulai sesi baru sebelum penyimpanan berhasil.")
        }
    }

    private var precheckContent: some View {
        VStack(spacing: 18) {
            valueControl(title: "Kecemasan saat ini", value: $anxiety)
            valueControl(title: "Intensitas saat ini", value: $arousal)
            SafetyScreeningFields(answers: $safetyAnswers)
                .padding().background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            Toggle("Saya punya waktu dan ruang privat", isOn: $hasPrivateTime)
            Toggle("Saya bersedia mengikuti instruksi berhenti", isOn: $willFollowPrompts)
            Button(safetyAnswers.hasAny ? "Hentikan dan lihat panduan" : "Mulai persiapan") {
                guard history.guidedEligibility.isAllowed else { eligibilityMessage = history.guidedEligibility.message; return }
                if safetyAnswers.hasAny { machine.abortForSafety() }
                else {
                    sessionStartedAt = .now
                    prepareStartedAt = .now
                    postAnxiety = anxiety
                    arousalEvents.append(LocalArousalEvent(timestampOffset: 0, level: arousal, eventType: "precheck"))
                    machine.start()
                }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(!safetyAnswers.hasAny && (!hasPrivateTime || !willFollowPrompts))
        }
    }

    private var prepareContent: some View {
        VStack(spacing: 18) {
            BreathingOrbView()
            Text(prepareElapsed >= preparationMinimum ? "Persiapan selesai" : "Tenangkan tubuh · \(preparationMinimum - prepareElapsed) dtk")
                .font(.headline.monospacedDigit())
            Text("Rilekskan rahang, perut, paha, dan bokong. Durasi bukan target.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Saya siap mulai") { beginActive() }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(prepareElapsed < preparationMinimum)
        }
    }

    private var arousalControls: some View {
        VStack(spacing: 16) {
            elapsedLabel
            Text("Intensitas: \(arousal)").font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(arousal >= 7 ? .red : arousal >= 6 ? .orange : .indigo)
            Slider(value: Binding(get: { Double(arousal) }, set: { arousal = Int($0.rounded()) }), in: 1...10, step: 1)
                .accessibilityLabel("Intensitas saat ini")
                .accessibilityValue("\(arousal) dari 10, \(arousalMeaning)")
            HStack {
                Button("Stabil") { arousal = max(1, arousal - 1) }.buttonStyle(.bordered)
                Button("Naik") { arousal = min(10, arousal + 1) }.buttonStyle(.bordered)
            }
            Button("Pause sekarang") { beginRecovery(strong: false) }
                .buttonStyle(.borderedProminent).tint(.indigo).controlSize(.large)
            Button("Hampir terlambat") { beginRecovery(strong: true) }
                .buttonStyle(.bordered).tint(.orange)
            Button("Sesi berakhir lebih cepat") { machine.earlyCompletion() }
                .foregroundStyle(.secondary).frame(minHeight: 44)
        }
    }

    private var recoveryContent: some View {
        VStack(spacing: 18) {
            BreathingOrbView()
            Text(recoveryElapsed >= recoveryMinimum ? "Nilai ulang intensitasmu" : "Pemulihan · \(recoveryMinimum - recoveryElapsed) dtk")
                .font(.headline.monospacedDigit())
                .accessibilityFocused($recoveryFocused)
            valueControl(title: "Intensitas sekarang", value: $arousal)
            Button("Lanjut setelah intensitas 4 atau lebih rendah") {
                recoverAndContinue()
            }
            .buttonStyle(.borderedProminent)
            .disabled(recoveryElapsed < recoveryMinimum || arousal > 4)
            Button("Akhiri dengan aman") { machine.complete() }.buttonStyle(.bordered)
        }
    }

    private var resumeContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 54)).foregroundStyle(.green)
            Text("Siklus \(machine.cycles) selesai").font(.headline)
            Button("Lanjut perlahan") { beginActive() }.buttonStyle(.borderedProminent).controlSize(.large)
            Button("Cukup untuk hari ini") { machine.complete() }.buttonStyle(.bordered)
        }
    }

    @ViewBuilder private var terminalContent: some View {
        let safety = machine.state == .safetyAbort
        Image(systemName: safety ? "cross.case.fill" : "checkmark.circle.fill")
            .font(.system(size: 56)).foregroundStyle(safety ? .red : .green)
        Text(safety ? "Hentikan latihan dulu" : "Sesi selesai").font(.title2.bold())
        Text(safety ? "Keluhan fisik perlu dinilai tenaga kesehatan sebelum latihan dilanjutkan." : terminalMessage)
            .foregroundStyle(.secondary).multilineTextAlignment(.center)
        if safety {
            Button("Tutup") { dismiss() }.buttonStyle(.borderedProminent)
                .disabled(history.activeSafetyHold == nil)
        } else {
            Button("Lanjut ke refleksi") { showPostCheck = true }.buttonStyle(.borderedProminent)
        }
    }

    private var postCheckContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.text.square.fill").font(.system(size: 48)).foregroundStyle(.indigo)
            Text("Refleksi singkat").font(.title.bold())
            Text("Catat kondisi tubuh, bukan nilai keberhasilan.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            valueControl(title: "Kecemasan setelah sesi", value: $postAnxiety)
            valueControl(title: "Ketegangan tubuh", value: $postTension)
            Toggle("Ada nyeri berat atau nyeri baru setelah sesi", isOn: $painAfter)
                .tint(.red)
            Toggle("Ada iritasi ringan setelah sesi", isOn: $irritationAfter)
            Picker("Perasaan setelah sesi", selection: $outcome) {
                ForEach(["Lebih tenang", "Sama saja", "Lelah", "Tidak nyaman"], id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            TextField("Catatan privat (opsional)", text: $note, axis: .vertical)
                .lineLimit(2...5)
            Button("Simpan dan selesai") { savePostCheckAndDismiss() }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private func valueControl(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.headline); Spacer(); Text("\(value.wrappedValue)/10").monospacedDigit().foregroundStyle(.secondary) }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: 1...10, step: 1)
                .accessibilityLabel(title)
                .accessibilityValue("\(value.wrappedValue) dari 10")
        }
        .padding().background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var elapsedLabel: some View {
        Text("Waktu sesi \(totalElapsed / 60):\(String(format: "%02d", totalElapsed % 60))")
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
    }

    private var isTerminal: Bool { [.completed, .earlyCompletion, .cancelled, .safetyAbort, .timeLimitReached].contains(machine.state) }
    private var stateTitle: String { switch machine.state { case .precheck: "Periksa dulu"; case .prepare: "Tenangkan tubuh"; case .activeLow, .activeRising: "Tetap sadar"; case .warning: "Berhenti sekarang"; case .pausedRecovery: "Biarkan intensitas turun"; case .resumeReady: "Kembali dalam rentang aman"; default: "" } }
    private var stateMessage: String { switch machine.state { case .prepare: "Persiapan pelan membantu tubuh tidak mengejar durasi."; case .pausedRecovery: "Hands off. Tarik napas dan nilai ulang setelah jeda minimum."; default: "TEMPO mendukung latihan terstruktur, bukan diagnosis medis." } }
    private var terminalMessage: String { switch machine.state { case .earlyCompletion: "Berakhir lebih cepat bukan kegagalan dan tidak perlu langsung diulang."; case .timeLimitReached: "Batas waktu tercapai. Beri tubuh waktu untuk pulih."; default: "Ini data yang berguna, bukan penilaian atas dirimu." } }
    private var arousalMeaning: String { arousal >= history.adaptivePauseThreshold ? "berhenti sekarang" : arousal >= 6 ? "mulai naik" : "rentang rendah" }

    private func eligibilityBlockedContent(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: history.guidedEligibility.reason == .safetyHold ? "cross.case.fill" : "bed.double.fill")
                .font(.system(size: 54)).foregroundStyle(.orange)
            Text("Guided session belum tersedia").font(.title2.bold()).multilineTextAlignment(.center)
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Tutup") { dismiss() }.buttonStyle(.borderedProminent)
        }
    }

    private func beginActive() {
        machine.beginActive()
        arousal = min(arousal, 4)
        strongWarningPlayed = false
        gentleWarningPlayed = false
        recoveryStartedAt = nil
        recoveryElapsed = 0
    }

    private func beginRecovery(strong: Bool) {
        let didPause = strong ? machine.emergencyPause() : machine.pause()
        guard didPause else { return }
        recoveryStartedAt = .now
        recoveryElapsed = 0
        beginPauseRecord(eventType: strong ? "almost-too-late" : "manual-pause", late: strong)
        if strong {
            playStrongWarningOnce()
            UIAccessibility.post(notification: .announcement, argument: "Berhenti sekarang. Hands off. Bernapas.")
        }
        else if hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        recoveryFocused = true
    }

    private func handleArousalChange(_ level: Int) {
        guard [.activeLow, .activeRising, .warning].contains(machine.state) else { return }
        arousalEvents.append(LocalArousalEvent(timestampOffset: totalElapsed, level: level, eventType: "level"))
        arousalEvents = Array(arousalEvents.suffix(120))
        let crossedThreshold = machine.rising(level: level, threshold: history.adaptivePauseThreshold)
        if crossedThreshold {
            playStrongWarningOnce()
            recoveryStartedAt = .now
            recoveryElapsed = 0
            beginPauseRecord(eventType: "threshold", late: false)
            recoveryFocused = true
            UIAccessibility.post(notification: .announcement, argument: "Berhenti sekarang. Hands off. Bernapas.")
        } else if level == 6, !gentleWarningPlayed {
            gentleWarningPlayed = true
            if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            UIAccessibility.post(notification: .announcement, argument: "Mulai melambat. Lembutkan tubuh.")
        }
    }

    private func handleStateChange(_ state: GuidedSessionState) {
        if state == .safetyAbort || state == .cancelled { saveImmediatelyIfNeeded(state) }
    }

    private func updateTimes(now: Date) {
        if let start = sessionStartedAt { totalElapsed = max(totalElapsed, max(0, Int(now.timeIntervalSince(start)))) }
        if let start = prepareStartedAt { prepareElapsed = max(prepareElapsed, max(0, Int(now.timeIntervalSince(start)))) }
        if let start = recoveryStartedAt { recoveryElapsed = max(recoveryElapsed, max(0, Int(now.timeIntervalSince(start)))) }
        machine.updateElapsed(totalSeconds: totalElapsed)
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        let now = Date.now
        updateTimes(now: now)
        guard phase != .active,
              [.activeLow, .activeRising, .warning].contains(machine.state)
        else { return }
        machine.pause(reason: .interruption)
        recoveryStartedAt = now
        recoveryElapsed = 0
        beginPauseRecord(eventType: "interruption", late: false)
    }

    private func playStrongWarningOnce() {
        guard !strongWarningPlayed else { return }
        strongWarningPlayed = true
        if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    }

    private func saveImmediatelyIfNeeded(_ state: GuidedSessionState) {
        guard !resultSaved else { return }
        if state == .safetyAbort {
            guard history.recordSafetyHold(reasonCode: safetyAnswers.reasonCode, severity: safetyAnswers.severity.rawValue, source: "guided-session") else { saveFailed = true; return }
        }
        let saved = history.addSession(startedAt: sessionStartedAt, cycles: machine.cycles, terminalState: state, targetCycles: machine.maximumCycles, pauseThreshold: history.adaptivePauseThreshold, maximumDurationSeconds: machine.maximumDurationSeconds, preAnxiety: anxiety, durationSeconds: totalElapsed, lateStopOccurred: machine.lateStopOccurred, arousalEvents: arousalEvents, pauseCycles: pauseCycles)
        if saved {
            resultSaved = true
            if state == .completed || state == .earlyCompletion || state == .timeLimitReached,
               !completePlannedGuidedActivity() {
                planCompletionPending = true
                saveFailed = true
            }
        } else { saveFailed = true }
    }

    private func savePostCheckAndDismiss() {
        guard !resultSaved else { dismiss(); return }
        let saved = history.addSession(startedAt: sessionStartedAt, cycles: machine.cycles, terminalState: machine.state, targetCycles: machine.maximumCycles, pauseThreshold: history.adaptivePauseThreshold, maximumDurationSeconds: machine.maximumDurationSeconds, preAnxiety: anxiety, durationSeconds: totalElapsed, lateStopOccurred: machine.lateStopOccurred, postAnxiety: postAnxiety, postTension: postTension, painAfter: painAfter, irritationAfter: irritationAfter, outcome: outcome, note: note.isEmpty ? nil : note, arousalEvents: arousalEvents, pauseCycles: pauseCycles)
        guard saved else { saveFailed = true; return }
        resultSaved = true
        if completePlannedGuidedActivity() { dismiss() }
        else {
            planCompletionPending = true
            saveFailed = true
        }
    }

    private func completePlannedGuidedActivity() -> Bool {
        guard let plannedDayID else { return true }
        return history.completeTodayPlan(id: plannedDayID, performedKind: .guided)
    }

    private func cancelAndDismiss() {
        machine.cancel()
        saveImmediatelyIfNeeded(.cancelled)
        if resultSaved { dismiss() }
    }

    private func configureEligibility() {
        if plannedDayID == nil,
           let todayPlan = history.todayPlan,
           todayPlan.status == .planned,
           todayPlan.kind == .guided {
            plannedDayID = todayPlan.id
        }
        let eligibility = history.guidedEligibility
        guard eligibility.isAllowed else { eligibilityMessage = eligibility.message; return }
        if machine.state == .precheck {
            machine = GuidedSessionMachine(maximumCycles: history.targetCycles, maximumDurationSeconds: 1_200)
        }
    }

    private func retrySave() {
        if planCompletionPending {
            if completePlannedGuidedActivity() {
                planCompletionPending = false
                saveFailed = false
                if showPostCheck { dismiss() }
            } else { saveFailed = true }
            return
        }
        if showPostCheck { savePostCheckAndDismiss() }
        else if machine.state == .safetyAbort || machine.state == .cancelled { saveImmediatelyIfNeeded(machine.state) }
    }

    private func beginPauseRecord(eventType: String, late: Bool) {
        pauseStartedOffset = totalElapsed
        pauseStartedLevel = arousal
        pauseWasLate = late
        arousalEvents.append(LocalArousalEvent(timestampOffset: totalElapsed, level: arousal, eventType: eventType))
    }

    private func recoverAndContinue() {
        let cyclesBefore = machine.cycles
        machine.recovered(level: arousal, elapsedSeconds: recoveryElapsed)
        guard machine.state != .pausedRecovery else { return }
        if machine.cycles > cyclesBefore {
            let start = pauseStartedOffset ?? max(0, totalElapsed - recoveryElapsed)
            pauseCycles.append(LocalPauseCycle(index: machine.cycles, startOffset: start, endOffset: totalElapsed, arousalBefore: pauseStartedLevel ?? arousal, arousalAfter: arousal, lateStop: pauseWasLate, successful: true))
        }
        pauseStartedOffset = nil
        pauseStartedLevel = nil
        pauseWasLate = false
        arousalEvents.append(LocalArousalEvent(timestampOffset: totalElapsed, level: arousal, eventType: machine.cycles > cyclesBefore ? "recovered" : "interruption-resumed"))
    }
}

struct BreathingView: View {
    let title: String
    let duration: Int
    let plannedKind: ActivityKind?
    let plannedDayID: UUID?
    @Environment(LocalHistory.self) private var history
    @State private var remaining: Int
    @State private var completionLogged = false
    @State private var planSaveFailed = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    init(title: String, duration: Int, plannedKind: ActivityKind? = nil, plannedDayID: UUID? = nil) { self.title = title; self.duration = duration; self.plannedKind = plannedKind; self.plannedDayID = plannedDayID; _remaining = State(initialValue: duration) }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(title).font(.title.bold())
                BreathingOrbView()
                Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))").font(.title.monospacedDigit())
                    .accessibilityLabel("Sisa waktu \(remaining / 60) menit \(remaining % 60) detik")
                Text("Tarik napas perlahan. Perhatikan sensasi tanpa harus bertindak.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, minHeight: 520).padding()
        }
        .onReceive(timer) { _ in
            if remaining > 0 { remaining -= 1 }
            if remaining == 0, !completionLogged, !planSaveFailed { completePlannedActivity() }
        }
        .alert("Status rencana belum tersimpan", isPresented: $planSaveFailed) { Button("Coba lagi") { completePlannedActivity() } } message: { Text("Latihan napas selesai, tetapi status rencana perlu dicoba lagi.") }
    }

    private func completePlannedActivity() {
        guard let plannedKind else { completionLogged = true; return }
        let saved: Bool
        if let plannedDayID { saved = history.completeTodayPlan(id: plannedDayID, performedKind: plannedKind) }
        else { saved = history.completeTodayPlan(kind: plannedKind) }
        completionLogged = saved
        planSaveFailed = !saved
    }
}

struct BreathingOrbView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    var body: some View {
        Circle().fill(LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 150, height: 150).shadow(color: .cyan.opacity(0.5), radius: 24)
            .scaleEffect(expanded || reduceMotion ? 1 : 0.72)
            .animation(reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: expanded)
            .onAppear { expanded = true }
            .accessibilityLabel("Panduan napas")
    }
}

struct ProgressView: View {
    @Environment(LocalHistory.self) private var history
    var body: some View {
        NavigationStack {
            if history.checkIns.isEmpty && history.sessions.isEmpty && history.exercises.isEmpty {
                ContentUnavailableView("Belum ada progres", systemImage: "chart.line.uptrend.xyaxis", description: Text("Selesaikan check-in atau aktivitas pertamamu untuk melihat tren privat."))
                    .navigationTitle("Progres")
            } else {
                List {
                    Section("Skor saat ini") {
                        scoreRow("Kesadaran", value: history.scoreSnapshot.awareness, color: .cyan)
                        scoreRow("Kontrol", value: history.scoreSnapshot.control, color: .indigo)
                        scoreRow("Pemulihan", value: history.scoreSnapshot.recovery, color: .green)
                        scoreRow("Ketenangan", value: history.scoreSnapshot.calm, color: .mint)
                        scoreRow("Konsistensi", value: history.scoreSnapshot.consistency, color: .orange)
                        Text("Skor merangkum kebiasaan dan kualitas jeda, bukan membandingkanmu dengan orang lain.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Ringkasan privat") {
                        HStack { Text("Total check-in"); Spacer(); Text("\(history.checkIns.count)").monospacedDigit() }
                        if !history.checkIns.isEmpty { HStack { Text("Rata-rata intensitas"); Spacer(); Text(String(format: "%.1f", averageIntensity)).monospacedDigit() } }
                        if !history.urgeOutcomes.isEmpty {
                            HStack { Text("Rata-rata sebelum reset"); Spacer(); Text(String(format: "%.1f", averageUrgeBefore)).monospacedDigit() }
                            HStack { Text("Rata-rata sesudah reset"); Spacer(); Text(String(format: "%.1f", averageUrgeAfter)).monospacedDigit() }
                            HStack { Text("Perubahan rata-rata"); Spacer(); Text(String(format: "%+.1f", averageUrgeChange)).monospacedDigit() }
                            Text("Nilai perubahan negatif berarti intensitas menurun.").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack { Text("Safety hold tercatat"); Spacer(); Text("\(history.safetyHoldCount)").monospacedDigit() }
                        HStack { Text("Guided session"); Spacer(); Text("\(history.sessions.count)").monospacedDigit() }
                        HStack { Text("Aktivitas gerak"); Spacer(); Text("\(history.exercises.count)").monospacedDigit() }
                    }
                    Section("Tren pribadi") {
                        if let anxiety = history.currentAnxiety { HStack { Text("Kecemasan terbaru"); Spacer(); Text(String(format: "%.1f / 10", anxiety)).monospacedDigit() } }
                        if let tension = history.currentTension { HStack { Text("Ketegangan terbaru"); Spacer(); Text(String(format: "%.1f / 10", tension)).monospacedDigit() } }
                        HStack { Text("Fase program"); Spacer(); Text(phaseName) }
                        HStack { Text("Tingkat kemandirian"); Spacer(); Text("\(history.independenceLevel) / 4").monospacedDigit() }
                        Text("Nilai ini dibandingkan dengan riwayatmu sendiri dan tidak memakai tolok ukur orang lain.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Aktivitas terbaru") {
                        ForEach(history.checkIns.prefix(10)) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.action.capitalized).font(.headline)
                                Text("Intensitas \(entry.intensity) · \(entry.trigger) · \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if !history.exercises.isEmpty {
                        Section("Gerak terbaru") {
                            ForEach(history.exercises.prefix(5)) { entry in
                                HStack { Label(entry.kind, systemImage: "figure.walk"); Spacer(); Text("\(entry.durationMinutes) mnt").foregroundStyle(.secondary) }
                            }
                        }
                    }
                }.navigationTitle("Progres")
            }
        }
    }
    private var averageIntensity: Double { Double(history.checkIns.map(\.intensity).reduce(0, +)) / Double(history.checkIns.count) }
    private var averageUrgeBefore: Double { Double(history.urgeOutcomes.map(\.initialIntensity).reduce(0, +)) / Double(history.urgeOutcomes.count) }
    private var averageUrgeAfter: Double { Double(history.urgeOutcomes.map(\.finalIntensity).reduce(0, +)) / Double(history.urgeOutcomes.count) }
    private var averageUrgeChange: Double { averageUrgeAfter - averageUrgeBefore }
    private var phaseName: String { switch history.effectiveProgramPhase { case .assessmentRequired: "Baseline"; case .awareness: "Kesadaran"; case .basicControl: "Kontrol dasar"; case .stability: "Stabilitas"; case .transfer: "Transfer"; case .independence: "Mandiri"; case .safetyHold: "Pemulihan" } }
    private func scoreRow(_ title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(value)").font(.headline.monospacedDigit()) }
            SwiftUI.ProgressView(value: Double(value), total: 100).tint(color)
        }.accessibilityElement(children: .combine).accessibilityLabel("\(title), \(value) dari 100")
    }
}

struct LearnView: View {
    private let sections: [LessonSection] = [
        .init("Dasar tubuh", lessons: [
            .init("Pre-ejakulat bukan ejakulasi", "Pre-ejakulat adalah respons tubuh yang dapat terjadi secara normal dan bukan tanda sesi gagal. Catat perubahan tanpa mengejar atau mengoreksinya."),
            .init("Intensitas berbentuk kurva", "Intensitas dapat naik, mendatar, lalu turun. Mengenali perubahan kecil lebih awal memberi ruang untuk memilih melambat atau berhenti."),
            .init("Titik sulit dihentikan", "Ada fase ketika respons tubuh terasa jauh lebih sulit dihentikan. Tujuan latihan adalah mengenali tanda sebelum fase itu, bukan menguji seberapa dekat kamu bisa mendekat."),
            .init("Mengapa ketegangan penting", "Rahang, perut, paha, bokong, dan area panggul sering menegang tanpa disadari. Melembutkan area tersebut membantu pengamatan tubuh dan tidak boleh dipaksakan."),
            .init("Durasi bukan ukuran utama", "Durasi tidak menentukan nilai diri atau keberhasilan. TEMPO lebih menghargai jeda yang tepat, pemulihan, dan keputusan aman.")
        ]),
        .init("Keterampilan latihan", lessons: [
            .init("Cara kerja start–stop", "Mulai pelan, nilai intensitas, lalu berhenti sesuai ambang. Setelah pemulihan minimum dan nilai turun, satu siklus dapat dilanjutkan dengan tenang."),
            .init("Kapan harus melambat", "Level enam adalah sinyal awal untuk mengurangi tempo dan tekanan. Longgarkan tubuh sebelum peringatan berhenti muncul."),
            .init("Menggunakan skala 1–10", "Gunakan angka sebagai bahasa praktis, bukan ujian presisi. Nilai yang konsisten menurut pengalamanmu sendiri lebih berguna daripada membandingkan dengan orang lain."),
            .init("Napas saat pemulihan", "Biarkan embusan sedikit lebih panjang dan jangan menahan napas. Nilai ulang setelah sekurangnya 30 detik; lanjut hanya ketika intensitas empat atau lebih rendah."),
            .init("Kurangi pola terburu-buru", "Mulai dengan sengaja, periksa ketegangan, dan ikuti prompt berhenti. Konsistensi kecil lebih berguna daripada sesi panjang yang dipaksakan."),
            .init("Edging sangat lama bukan target", "Sesi yang terlalu lama dapat menambah kelelahan dan iritasi. TEMPO membatasi durasi dan tidak memberi poin tambahan untuk waktu yang lebih panjang."),
            .init("Mengakhiri tanpa malu", "Sesi boleh berakhir lebih awal, karena pilihan, atau karena batas waktu. Catat kondisi tubuh dan ambil pemulihan tanpa langsung mencoba ulang.")
        ]),
        .init("Kebiasaan dan pikiran", lessons: [
            .init("Stres, tidur, dan kecemasan", "Kurang tidur dan stres dapat mengubah perhatian serta respons tubuh. Pada hari berat, rencana yang lebih ringan tetap merupakan progres."),
            .init("Reset stimulus tanpa menghakimi", "Jika stimulus yang sangat tinggi terasa menjadi kebiasaan, lakukan perubahan bertahap tanpa moral panic. Fokus pada pilihan, tempo, dan bagaimana tubuh merespons."),
            .init("Bosan atau benar-benar ingin", "Dorongan karena bosan, kesepian, atau stres mungkin lebih cocok direspons dengan napas, berjalan, atau aktivitas lain. Check-in membantu memberi jeda sebelum memilih."),
            .init("Jebakan terus menguji", "Mengulang sesi untuk membuktikan hasil dapat menambah tekanan dan iritasi. Satu data yang kurang nyaman tidak perlu segera diperbaiki dengan tes baru."),
            .init("Hindari obsesi streak", "Konsistensi bukan berarti tidak pernah melewatkan hari. Rencana boleh direduksi, dan hari pemulihan juga dihitung sebagai kepatuhan.")
        ]),
        .init("Relasi", lessons: [
            .init("Menjelaskan kepada pasangan", "Gunakan bahasa sederhana tentang tekanan, jeda, dan apa yang membantu. Kamu tidak wajib membagikan angka atau catatan privat dari aplikasi."),
            .init("Sepakati sinyal jeda", "Pilih kata atau isyarat yang mudah dikenali dan dihormati tanpa perdebatan. Jeda adalah keputusan bersama untuk menjaga kenyamanan, bukan tanda kegagalan."),
            .init("Kedekatan di luar penetrasi", "Kedekatan tidak harus berpusat pada penetrasi atau durasi. Ruang tanpa target dapat mengurangi tekanan performa dan membantu komunikasi."),
            .init("Lepaskan tuntutan performa", "Respons tubuh dapat berubah dari hari ke hari. Fokus pada kenyamanan, komunikasi, dan persetujuan daripada hasil yang harus selalu sama.")
        ]),
        .init("Kesehatan dan keselamatan", lessons: [
            .init("Tanda yang perlu dinilai", "Hentikan latihan bila ada nyeri, darah, demam, cedera akut, perih saat kencing, atau cairan tidak biasa. Kondisi berat atau memburuk memerlukan bantuan segera sesuai layanan setempat."),
            .init("Hati-hati dengan produk kebas", "Produk kebas dapat mengurangi sensasi dan menyamarkan tanda iritasi. Jangan mengandalkannya tanpa arahan tenaga kesehatan yang memahami kondisi dan risikonya."),
            .init("Obat resep adalah keputusan klinis", "TEMPO tidak merekomendasikan atau mengatur obat. Manfaat, interaksi, dan efek samping perlu dibahas dengan dokter atau tenaga kesehatan yang berwenang."),
            .init("Kapan latihan mandiri tidak cukup", "Cari penilaian bila perubahan muncul mendadak, menetap, mengganggu, atau disertai gejala lain. Aplikasi tidak dapat membuat diagnosis atau menggantikan pemeriksaan.")
        ]),
        .init("Gerak dan pemulihan", lessons: [
            .init("Rencana jalan pemula", "Mulai dengan 10–15 menit jika belum aktif, lalu tambah perlahan ketika terasa nyaman. Berhenti untuk nyeri tajam, pusing, nyeri dada, atau sesak yang tidak biasa."),
            .init("Progres jogging", "Setelah jalan terasa nyaman, coba satu menit jogging ringan diselingi dua menit berjalan. Tingkatkan waktu bertahap, bukan sekaligus."),
            .init("Kekuatan tanpa alat", "Wall push-up, chair squat, glute bridge, bird dog, dan calf raise dapat membentuk rangkaian pemula. Tambah repetisi sebelum menambah set."),
            .init("Checklist pemulihan tidur", "Perhatikan jam tidur, waktu bangun, kafein malam, dan ketegangan sebelum tidur. Satu malam buruk adalah konteks untuk meringankan rencana, bukan kegagalan."),
            .init("Reset mingguan", "Tinjau apa yang membantu, apa yang terlewat, dan bagaimana tubuh pulih. Pilih satu penyesuaian kecil; jangan menumpuk tugas sebagai hukuman.")
        ])
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.lessons) { lesson in
                            NavigationLink(lesson.title) { LessonView(title: lesson.title, body: lesson.body) }
                        }
                    }
                }
            }.navigationTitle("Belajar")
        }
    }
}

private struct LessonSection: Identifiable {
    let id = UUID()
    let title: String
    let lessons: [LessonItem]
    init(_ title: String, lessons: [LessonItem]) { self.title = title; self.lessons = lessons }
}

private struct LessonItem: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    init(_ title: String, _ body: String) { self.title = title; self.body = body }
}

struct LessonView: View {
    let title: String
    let content: String
    let plannedKind: ActivityKind?
    let plannedDayID: UUID?
    @Environment(LocalHistory.self) private var history
    @State private var completed = false
    @State private var saveFailed = false
    init(title: String, body: String, plannedKind: ActivityKind? = nil, plannedDayID: UUID? = nil) { self.title = title; self.content = body; self.plannedKind = plannedKind; self.plannedDayID = plannedDayID }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title).font(.largeTitle.bold())
                Text(content).font(.body).lineSpacing(5)
                Text("TEMPO adalah panduan wellness dan tidak menggantikan diagnosis atau perawatan medis.").font(.footnote).foregroundStyle(.secondary)
                if plannedKind != nil {
                    Button(completed ? "Materi selesai" : "Tandai selesai") { completeLesson() }
                        .buttonStyle(.borderedProminent).disabled(completed)
                }
            }.padding()
        }
        .navigationTitle("Belajar")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Status rencana belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { completeLesson() } } message: { Text("Materi selesai, tetapi status rencana perlu dicoba lagi.") }
    }

    private func completeLesson() {
        guard let plannedKind else { return }
        let saved: Bool
        if let plannedDayID { saved = history.completeTodayPlan(id: plannedDayID, performedKind: plannedKind) }
        else { saved = history.completeTodayPlan(kind: plannedKind) }
        completed = saved
        saveFailed = !saved
    }
}

struct SettingsView: View {
    @Environment(LocalHistory.self) private var history
    @AppStorage("discreetTerminology") private var discreet = false
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage("notificationSoundsEnabled") private var notificationSoundsEnabled = false
    @State private var showDeletionConfirmation = false
    @State private var showNoteDeletionConfirmation = false
    @State private var showExportPrompt = false
    @State private var showExporter = false
    @State private var exportPassword = ""
    @State private var exportDocument = TempoExportDocument()
    @State private var exportError = false
    @State private var biometricError = false
    @State private var deletionError = false
    @AppStorage("dailyPlanRemindersEnabled") private var remindersEnabled = false
    @AppStorage("dailyPlanReminderHour") private var reminderHour = 9
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Privasi") {
                    Toggle("Terminologi privat", isOn: $discreet)
                    Label("Konten selalu disamarkan saat aplikasi di latar belakang", systemImage: "eye.slash.fill")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Toggle("Minta Face ID / kode saat membuka aplikasi", isOn: biometricBinding)
                    Button("Export data terenkripsi") { exportPassword = ""; showExportPrompt = true }
                    Button("Hapus semua catatan teks") { showNoteDeletionConfirmation = true }
                    Button("Hapus semua data", role: .destructive) { showDeletionConfirmation = true }
                }
                Section("Preferensi") {
                    Toggle("Haptics", isOn: $haptics)
                    Toggle("Suara notifikasi", isOn: $notificationSoundsEnabled)
                        .onChange(of: notificationSoundsEnabled) { _, enabled in
                            if remindersEnabled { Task { await LocalNotifications.requestAndScheduleDailyPlan(hour: reminderHour, soundEnabled: enabled) } }
                        }
                    Toggle("Pengingat rencana harian", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, enabled in
                            if enabled { Task { await LocalNotifications.requestAndScheduleDailyPlan(hour: reminderHour, soundEnabled: notificationSoundsEnabled) } }
                            else { LocalNotifications.removeDailyPlan() }
                        }
                    if remindersEnabled {
                        Stepper("Waktu pengingat: \(String(format: "%02d:00", reminderHour))", value: $reminderHour, in: 8...21)
                            .onChange(of: reminderHour) { _, hour in Task { await LocalNotifications.requestAndScheduleDailyPlan(hour: hour, soundEnabled: notificationSoundsEnabled) } }
                    }
                    NavigationLink("Tentang keselamatan") { Text("TEMPO bukan alat diagnosis atau layanan darurat. Nyeri, perdarahan, demam, perih saat kencing, atau cairan tidak biasa memerlukan penilaian profesional.").padding() }
                    NavigationLink("Tentang rule engine") { RuleEngineInfoView() }
                }
            }.navigationTitle("Pengaturan")
        }
        .confirmationDialog("Hapus seluruh data lokal?", isPresented: $showDeletionConfirmation, titleVisibility: .visible) {
            Button("Hapus semua data", role: .destructive) {
                guard history.deleteAll() else { deletionError = true; return }
                LocalNotifications.removeAll()
                if let domain = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: domain) }
                discreet = false
                haptics = true
                biometricLockEnabled = false
                notificationSoundsEnabled = false
                remindersEnabled = false
                reminderHour = 9
                onboardingCompleted = false
            }
        } message: { Text("Tindakan ini menghapus preferensi dan data lokal yang tersimpan. Ini tidak dapat dibatalkan.") }
        .confirmationDialog("Hapus semua catatan teks privat?", isPresented: $showNoteDeletionConfirmation, titleVisibility: .visible) {
            Button("Hapus catatan teks", role: .destructive) { if !history.deleteAllNotes() { deletionError = true } }
        } message: { Text("Skor dan ringkasan sesi tetap disimpan; hanya isi catatan opsional yang dihapus.") }
        .alert("Lindungi file export", isPresented: $showExportPrompt) {
            SecureField("Password minimal 8 karakter", text: $exportPassword)
            Button("Buat file") { createExport() }
            Button("Batal", role: .cancel) {}
        } message: { Text("Password tidak disimpan oleh TEMPO. Simpan password ini sendiri karena file tidak dapat dibuka tanpanya.") }
        .alert("Export gagal", isPresented: $exportError) { Button("OK") {} } message: { Text("Gunakan password minimal 8 karakter dan coba kembali.") }
        .alert("Kunci perangkat tidak tersedia", isPresented: $biometricError) { Button("OK") {} } message: { Text("Aktifkan kode perangkat atau biometrik terlebih dahulu agar TEMPO tidak terkunci tanpa jalan masuk.") }
        .alert("Penghapusan belum selesai", isPresented: $deletionError) { Button("Coba lagi") {} } message: { Text("Penyimpanan aman belum dapat dihapus. TEMPO mempertahankan tampilan data agar tidak memberi kesan palsu bahwa data sudah hilang.") }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: UTType.data, defaultFilename: "Tempo-Export.tempo") { _ in }
    }

    private func createExport() {
        guard let data = history.makeExportData(), let encrypted = try? EncryptedExport.encrypt(data, password: exportPassword) else { exportError = true; return }
        exportDocument = TempoExportDocument(data: encrypted)
        showExporter = true
    }
    private var biometricBinding: Binding<Bool> {
        Binding(get: { biometricLockEnabled }, set: { enabled in
            if !enabled { biometricLockEnabled = false; return }
            Task {
                if await PrivacyLock.authenticate() { biometricLockEnabled = true }
                else { biometricError = true }
            }
        })
    }
}

struct RuleEngineInfoView: View {
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("Rule engine lokal").font(.largeTitle.bold())
            Text("TEMPO tidak menggunakan AI, akun, atau koneksi internet untuk menentukan rekomendasi.")
            Card { VStack(alignment: .leading, spacing: 8) { Text("Urutan keputusan").font(.headline); Text("1. Tanda keselamatan\n2. Pemulihan dan batas frekuensi\n3. Regulasi kecemasan\n4. Check-in dorongan\n5. Latihan, gerak, atau edukasi") } }
            Text("Dengan jawaban dan riwayat yang sama, TEMPO akan memberikan hasil yang sama. Setiap rekomendasi menyertakan alasan yang sederhana.").foregroundStyle(.secondary)
        }.padding() }.navigationTitle("Rule engine").navigationBarTitleDisplayMode(.inline)
    }
}

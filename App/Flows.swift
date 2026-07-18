import SwiftUI
import UIKit

struct UrgeCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalHistory.self) private var history
    @State private var step = 0; @State private var intensity = 5; @State private var trigger: UrgeTrigger = .desire; @State private var intent: UrgeIntent = .calm; @State private var hasSafetyFlag = false
    @State private var result: Recommendation?
    var body: some View { NavigationStack { VStack(spacing: 28) {
        HStack { ForEach(0..<4, id: \.self) { i in Capsule().fill(i <= step ? Color.indigo : Color.white.opacity(0.15)).frame(height: 5) } }.padding(.horizontal)
        if let result { RecommendationView(result: result, dismiss: dismiss) } else { Group { switch step { case 0: intensityQuestion; case 1: triggerQuestion; case 2: intentQuestion; default: safetyQuestion } }.frame(maxHeight: .infinity); Button(step == 3 ? "Lihat rekomendasi" : "Lanjut") { advance() }.buttonStyle(.borderedProminent).controlSize(.large).padding() }
    }.padding(.top).navigationTitle("Check-in cepat").toolbar { Button("Tutup") { dismiss() } } } }
    private var intensityQuestion: some View { VStack(spacing: 20) { Text("Seberapa kuat intensitasnya?").font(.title2.bold()); Text("\(intensity)").font(.system(size: 76, weight: .bold, design: .rounded)).foregroundStyle(intensity >= 7 ? .orange : .indigo); Slider(value: Binding(get: { Double(intensity) }, set: { intensity = Int($0.rounded()) }), in: 1...10, step: 1).padding(.horizontal, 28); Text("Tidak ada jawaban yang salah. Cukup perhatikan apa yang terasa sekarang.").multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal) } }
    private var triggerQuestion: some View { ChoiceQuestion(title: "Apa konteksnya sekarang?", selection: $trigger, labels: [.init(.desire, "Gairah seksual"), .init(.boredom, "Bosan"), .init(.stress, "Stres"), .init(.loneliness, "Kesepian"), .init(.sleep, "Sulit tidur")]) }
    private var intentQuestion: some View { ChoiceQuestion(title: "Apa yang kamu butuhkan?", selection: $intent, labels: [.init(.calm, "Menenangkan diri"), .init(.training, "Latihan kontrol"), .init(.privateSession, "Sesi pribadi")]) }
    private var safetyQuestion: some View { VStack(spacing: 20) { Text("Ada nyeri, cedera, perih saat kencing, atau cairan tidak biasa?").font(.title2.bold()).multilineTextAlignment(.center); Toggle("Ya, ada keluhan", isOn: $hasSafetyFlag).padding().background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16)); Text("Keluhan apa pun akan menghentikan latihan dan mengarahkanmu ke health check.").foregroundStyle(.secondary).multilineTextAlignment(.center) }.padding() }
    private func advance() { if step < 3 { step += 1 } else { var c = DecisionContext(); c.urgeIntensity = intensity; c.trigger = trigger; c.intent = intent; c.pain = hasSafetyFlag; let recommendation = RuleEngine().evaluate(c); history.add(intensity: intensity, trigger: trigger, intent: intent, recommendation: recommendation); result = recommendation } }
}

struct ChoiceOption<T: Hashable>: Identifiable { let value: T; let title: String; var id: T { value }; init(_ value: T, _ title: String) { self.value = value; self.title = title } }
struct ChoiceQuestion<T: Hashable>: View { let title: String; @Binding var selection: T; let labels: [ChoiceOption<T>]; var body: some View { VStack(alignment: .leading, spacing: 14) { Text(title).font(.title2.bold()).padding(.bottom, 12); ForEach(labels) { item in Button { selection = item.value } label: { HStack { Text(item.title); Spacer(); if selection == item.value { Image(systemName: "checkmark.circle.fill") } }.padding().background(selection == item.value ? Color.indigo.opacity(0.6) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16)) } } }.padding() } }

struct RecommendationView: View { let result: Recommendation; let dismiss: DismissAction; var body: some View { VStack(spacing: 18) { Image(systemName: result.blocksGuidedTraining ? "cross.case.fill" : "sparkles").font(.system(size: 52)).foregroundStyle(result.blocksGuidedTraining ? .red : .cyan); Text(title).font(.title.bold()).multilineTextAlignment(.center); Text(result.message).foregroundStyle(.secondary).multilineTextAlignment(.center); Text("Mengapa rekomendasi ini?").font(.headline); Text("TEMPO memeriksa keselamatan, pemulihan, intensitas, dan tujuanmu sebelum memberi saran.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center); Button("Selesai") { dismiss() }.buttonStyle(.borderedProminent) }.padding() }
    private var title: String { switch result.action { case .healthCheck: "Hentikan latihan dulu"; case .recovery: "Waktunya pemulihan"; case .regulate, .urgeSurf: "Mari tenangkan ritme"; case .guidedSession: "Kamu siap berlatih"; case .privateSession: "Tetap pelan dan aman"; default: "Langkah kecil untuk hari ini" } }
}

struct TrainingView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Sesi") {
                    NavigationLink { GuidedSessionView() } label: {
                        Label("Guided control session", systemImage: "timer")
                    }
                    NavigationLink { BreathingView(title: "Urge surfing", duration: 300) } label: {
                        Label("Urge surfing · 5 menit", systemImage: "wind")
                    }
                    NavigationLink { BreathingView(title: "Napas pemulihan", duration: 60) } label: {
                        Label("Napas pemulihan", systemImage: "circle.dotted")
                    }
                }
                Section("Gerak") {
                    NavigationLink { ExerciseDetailView(kind: .walk) } label: {
                        Label("Jalan santai · 20 menit", systemImage: "figure.walk")
                    }
                    NavigationLink { ExerciseDetailView(kind: .strength) } label: {
                        Label("Kekuatan pemula", systemImage: "figure.strengthtraining.traditional")
                    }
                }
            }.navigationTitle("Latihan")
        }
    }
}

struct ExerciseDetailView: View {
    enum Kind { case walk, strength }
    let kind: Kind
    @State private var completed = false
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
                Button(completed ? "Aktivitas selesai" : "Tandai selesai") { completed = true }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(completed)
                Text("Gerak mendukung kesehatan umum, suasana hati, tidur, dan pengelolaan stres. Ini bukan pengobatan untuk kondisi seksual.").font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }.navigationTitle("Aktivitas").navigationBarTitleDisplayMode(.inline)
    }
}

struct GuidedSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalHistory.self) private var history
    @State private var machine = GuidedSessionMachine()
    @State private var arousal = 3
    @State private var anxiety = 3
    @State private var safetyConcern = false
    @State private var hasPrivateTime = true
    @State private var willFollowPrompts = true
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
    @State private var irritationAfter = false
    @State private var outcome = "Lebih tenang"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let preparationMinimum = 90
    private let recoveryMinimum = 30
    private let maximumSessionDuration = 1_200

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                if !showPostCheck {
                    Text(stateTitle).font(.title.bold()).multilineTextAlignment(.center)
                    Text(stateMessage).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }

                Group {
                    if showPostCheck { postCheckContent }
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
        .onReceive(timer) { now in updateTimes(now: now) }
        .onChange(of: arousal) { _, newValue in handleArousalChange(newValue) }
        .onChange(of: machine.state) { _, newState in handleStateChange(newState) }
        .confirmationDialog("Bagaimana ingin mengakhiri sesi?", isPresented: $showEndOptions, titleVisibility: .visible) {
            Button("Selesaikan dan isi refleksi") { machine.complete() }
            Button("Batalkan sesi", role: .destructive) { cancelAndDismiss() }
            Button("Lanjutkan sesi", role: .cancel) {}
        }
    }

    private var precheckContent: some View {
        VStack(spacing: 18) {
            valueControl(title: "Kecemasan saat ini", value: $anxiety)
            valueControl(title: "Intensitas saat ini", value: $arousal)
            Toggle("Saya mengalami nyeri atau iritasi", isOn: $safetyConcern)
            Toggle("Saya punya waktu dan ruang privat", isOn: $hasPrivateTime)
            Toggle("Saya bersedia mengikuti instruksi berhenti", isOn: $willFollowPrompts)
            Button(safetyConcern ? "Hentikan dan lihat panduan" : "Mulai persiapan") {
                if safetyConcern { machine.abortForSafety() }
                else {
                    sessionStartedAt = .now
                    prepareStartedAt = .now
                    postAnxiety = anxiety
                    machine.start()
                }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(!safetyConcern && (!hasPrivateTime || !willFollowPrompts))
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
            valueControl(title: "Intensitas sekarang", value: $arousal)
            Button("Lanjut setelah intensitas 4 atau lebih rendah") {
                machine.recovered(level: arousal, elapsedSeconds: recoveryElapsed)
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
            Toggle("Ada nyeri atau iritasi setelah sesi", isOn: $irritationAfter)
            Picker("Perasaan setelah sesi", selection: $outcome) {
                ForEach(["Lebih tenang", "Sama saja", "Lelah", "Tidak nyaman"], id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            Button("Simpan dan selesai") { savePostCheckAndDismiss() }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private func valueControl(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.headline); Spacer(); Text("\(value.wrappedValue)/10").monospacedDigit().foregroundStyle(.secondary) }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: 1...10, step: 1)
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

    private func beginActive() {
        machine.beginActive()
        arousal = min(arousal, 4)
        strongWarningPlayed = false
        gentleWarningPlayed = false
        recoveryStartedAt = nil
        recoveryElapsed = 0
    }

    private func beginRecovery(strong: Bool) {
        if strong { machine.emergencyPause() } else { machine.pause() }
        recoveryStartedAt = .now
        recoveryElapsed = 0
        if strong { playStrongWarningOnce() }
        else if hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }

    private func handleArousalChange(_ level: Int) {
        guard [.activeLow, .activeRising, .warning].contains(machine.state) else { return }
        machine.rising(level: level, threshold: 7)
        if level >= 7 {
            playStrongWarningOnce()
            machine.pause()
            recoveryStartedAt = .now
            recoveryElapsed = 0
        } else if level == 6, !gentleWarningPlayed {
            gentleWarningPlayed = true
            if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }

    private func handleStateChange(_ state: GuidedSessionState) {
        if state == .safetyAbort || state == .cancelled { saveImmediatelyIfNeeded(state) }
    }

    private func updateTimes(now: Date) {
        if let start = sessionStartedAt { totalElapsed = max(0, Int(now.timeIntervalSince(start))) }
        if let start = prepareStartedAt { prepareElapsed = max(0, Int(now.timeIntervalSince(start))) }
        if let start = recoveryStartedAt { recoveryElapsed = max(0, Int(now.timeIntervalSince(start))) }
        if totalElapsed >= maximumSessionDuration && !isTerminal { machine.reachTimeLimit() }
    }

    private func playStrongWarningOnce() {
        guard !strongWarningPlayed else { return }
        strongWarningPlayed = true
        if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    }

    private func saveImmediatelyIfNeeded(_ state: GuidedSessionState) {
        guard !resultSaved else { return }
        history.addSession(cycles: machine.cycles, terminalState: state, durationSeconds: totalElapsed)
        resultSaved = true
    }

    private func savePostCheckAndDismiss() {
        guard !resultSaved else { dismiss(); return }
        history.addSession(cycles: machine.cycles, terminalState: machine.state, durationSeconds: totalElapsed, postAnxiety: postAnxiety, postTension: postTension, irritationAfter: irritationAfter, outcome: outcome)
        resultSaved = true
        dismiss()
    }

    private func cancelAndDismiss() {
        machine.cancel()
        saveImmediatelyIfNeeded(.cancelled)
        dismiss()
    }
}

struct BreathingView: View {
    let title: String
    let duration: Int
    @State private var remaining: Int
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    init(title: String, duration: Int) { self.title = title; self.duration = duration; _remaining = State(initialValue: duration) }
    var body: some View {
        VStack(spacing: 24) {
            Text(title).font(.title.bold())
            BreathingOrbView()
            Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))").font(.title.monospacedDigit())
            Text("Tarik napas perlahan. Perhatikan sensasi tanpa harus bertindak.").foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding().onReceive(timer) { _ in if remaining > 0 { remaining -= 1 } }
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
            if history.checkIns.isEmpty {
                ContentUnavailableView("Belum ada progres", systemImage: "chart.line.uptrend.xyaxis", description: Text("Selesaikan check-in atau aktivitas pertamamu untuk melihat tren privat."))
                    .navigationTitle("Progres")
            } else {
                List {
                    Section("Ringkasan privat") {
                        HStack { Text("Total check-in"); Spacer(); Text("\(history.checkIns.count)").monospacedDigit() }
                        HStack { Text("Rata-rata intensitas"); Spacer(); Text(String(format: "%.1f", averageIntensity)).monospacedDigit() }
                        HStack { Text("Safety hold"); Spacer(); Text("\(history.checkIns.filter(\.blocksTraining).count)").monospacedDigit() }
                        HStack { Text("Guided session"); Spacer(); Text("\(history.sessions.count)").monospacedDigit() }
                    }
                    Section("Aktivitas terbaru") {
                        ForEach(history.checkIns.prefix(10)) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.action.capitalized).font(.headline)
                                Text("Intensitas \(entry.intensity) · \(entry.trigger) · \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }.navigationTitle("Progres")
            }
        }
    }
    private var averageIntensity: Double { Double(history.checkIns.map(\.intensity).reduce(0, +)) / Double(history.checkIns.count) }
}

struct LearnView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Dasar tubuh") {
                    NavigationLink("Gairah adalah kurva, bukan sakelar") { LessonView(title: "Gairah adalah kurva", body: "Intensitas dapat naik dan turun. Mengenali perubahan lebih awal memberi ruang untuk memperlambat atau berhenti tanpa tekanan.") }
                    NavigationLink("Pre-ejakulat bukan kegagalan") { LessonView(title: "Respons normal", body: "Pre-ejakulat adalah respons tubuh yang normal dan tidak berarti sesi gagal. Fokus aplikasi ini adalah kesadaran dan pilihan yang aman.") }
                }
                Section("Keterampilan") {
                    NavigationLink("Kapan perlu melambat") { LessonView(title: "Melambat lebih awal", body: "Saat intensitas mulai meningkat, kurangi tempo dan tekanan. Rilekskan rahang, perut, paha, dan bokong.") }
                    NavigationLink("Napas pemulihan") { BreathingView(title: "Napas pemulihan", duration: 60) }
                }
                Section("Kesehatan") {
                    NavigationLink("Tanda yang perlu diperiksa") { LessonView(title: "Hentikan latihan dan cari bantuan", body: "Hentikan latihan dan pertimbangkan penilaian profesional bila ada nyeri berat, perdarahan, demam, perih saat kencing, cairan tidak biasa, cedera akut, atau perubahan fungsi yang mendadak.") }
                }
            }.navigationTitle("Belajar")
        }
    }
}

struct LessonView: View {
    let title: String
    let content: String
    init(title: String, body: String) { self.title = title; self.content = body }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 20) { Text(title).font(.largeTitle.bold()); Text(content).font(.body).lineSpacing(5); Text("TEMPO adalah panduan wellness dan tidak menggantikan diagnosis atau perawatan medis.").font(.footnote).foregroundStyle(.secondary) }.padding() }.navigationTitle("Belajar").navigationBarTitleDisplayMode(.inline) }
}

struct SettingsView: View {
    @Environment(LocalHistory.self) private var history
    @AppStorage("discreetTerminology") private var discreet = false
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("privacyCoverEnabled") private var privacyCoverEnabled = false
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @State private var showDeletionConfirmation = false
    @AppStorage("dailyPlanRemindersEnabled") private var remindersEnabled = false
    @AppStorage("baselineCompleted") private var baselineCompleted = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Privasi") {
                    Toggle("Terminologi privat", isOn: $discreet)
                    Toggle("Tutup konten saat aplikasi di latar belakang", isOn: $privacyCoverEnabled)
                    Toggle("Minta Face ID / kode saat membuka aplikasi", isOn: $biometricLockEnabled)
                    Button("Hapus semua data", role: .destructive) { showDeletionConfirmation = true }
                }
                Section("Preferensi") {
                    Toggle("Haptics", isOn: $haptics)
                    Toggle("Pengingat rencana harian", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, enabled in
                            if enabled { Task { await LocalNotifications.requestAndScheduleDailyPlan() } }
                            else { LocalNotifications.removeDailyPlan() }
                        }
                    NavigationLink("Tentang keselamatan") { Text("TEMPO bukan alat diagnosis atau layanan darurat. Nyeri, perdarahan, demam, perih saat kencing, atau cairan tidak biasa memerlukan penilaian profesional.").padding() }
                    NavigationLink("Tentang rule engine") { RuleEngineInfoView() }
                }
            }.navigationTitle("Pengaturan")
        }
        .confirmationDialog("Hapus seluruh data lokal?", isPresented: $showDeletionConfirmation, titleVisibility: .visible) {
            Button("Hapus semua data", role: .destructive) {
                discreet = false
                haptics = true
                privacyCoverEnabled = false
                biometricLockEnabled = false
                remindersEnabled = false
                baselineCompleted = false
                onboardingCompleted = false
                UserDefaults.standard.removeObject(forKey: "privacyLockEnabled")
                LocalNotifications.removeAll()
                history.deleteAll()
            }
        } message: { Text("Tindakan ini menghapus preferensi dan data lokal yang tersimpan. Ini tidak dapat dibatalkan.") }
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

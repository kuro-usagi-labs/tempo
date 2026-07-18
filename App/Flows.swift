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
    @State private var seconds = 0
    @State private var safetyConcern = false
    @State private var isPrepared = false
    @State private var resultSaved = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 22) {
            Text(stateTitle).font(.title.bold()).multilineTextAlignment(.center)
            Text(stateMessage).foregroundStyle(.secondary).multilineTextAlignment(.center)

            if machine.state == .precheck {
                Toggle("Saya memiliki nyeri atau iritasi", isOn: $safetyConcern)
                    .padding().background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                Button(safetyConcern ? "Lihat health check" : "Mulai persiapan") {
                    if safetyConcern { machine.abortForSafety() } else { machine.start() }
                }.buttonStyle(.borderedProminent).controlSize(.large)
            } else if machine.state == .prepare {
                BreathingOrbView()
                Button("Saya siap") { machine.beginActive() }.buttonStyle(.borderedProminent).controlSize(.large)
            } else if [.activeLow, .activeRising, .warning].contains(machine.state) {
                arousalControls
            } else if machine.state == .pausedRecovery {
                BreathingOrbView()
                Text("Pemulihan · \(max(0, 30 - seconds)) dtk").font(.headline.monospacedDigit())
                Button("Intensitas sudah 4 atau lebih rendah") {
                    guard seconds >= 30 else { return }
                    machine.recovered(level: arousal)
                }.buttonStyle(.borderedProminent).disabled(seconds < 30 || arousal > 4)
            } else if machine.state == .resumeReady {
                Text("Siklus \(machine.cycles) selesai").font(.headline)
                Button("Lanjut perlahan") { machine.beginActive() }.buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                terminalContent
            }

            Button("Akhiri sesi", role: .cancel) { dismiss() }.foregroundStyle(.secondary)
        }
        .padding()
        .background(machine.state == .warning ? Color.red.opacity(0.22) : Color.black)
        .navigationBarBackButtonHidden(true)
        .onReceive(timer) { _ in tick() }
        .onChange(of: arousal) { _, newValue in
            guard [.activeLow, .activeRising, .warning].contains(machine.state) else { return }
            machine.rising(level: newValue, threshold: 7)
            if newValue >= 7 { playWarningHaptic() }
        }
        .onChange(of: machine.state) { _, newState in
            guard !resultSaved, [.completed, .earlyCompletion, .safetyAbort, .timeLimitReached].contains(newState) else { return }
            history.addSession(cycles: machine.cycles, terminalState: newState)
            resultSaved = true
        }
    }

    private var arousalControls: some View {
        VStack(spacing: 16) {
            Text("Intensitas: \(arousal)").font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(arousal >= 7 ? .red : arousal >= 6 ? .orange : .indigo)
            Slider(value: Binding(get: { Double(arousal) }, set: { arousal = Int($0.rounded()) }), in: 1...10, step: 1)
            HStack {
                Button("Stabil") { arousal = max(1, arousal - 1) }.buttonStyle(.bordered)
                Button("Naik") { arousal = min(10, arousal + 1) }.buttonStyle(.bordered)
            }
            Button(machine.state == .warning ? "Pause sekarang" : "Pause") {
                machine.pause(); seconds = 0; playWarningHaptic()
            }.buttonStyle(.borderedProminent).tint(machine.state == .warning ? .red : .indigo).controlSize(.large)
            Button("Hampir terlambat") { machine.earlyCompletion() }.foregroundStyle(.orange)
        }
    }

    @ViewBuilder private var terminalContent: some View {
        Image(systemName: machine.state == .safetyAbort ? "cross.case.fill" : "checkmark.circle.fill")
            .font(.system(size: 56)).foregroundStyle(machine.state == .safetyAbort ? .red : .green)
        Text(machine.state == .safetyAbort ? "Hentikan latihan dulu" : "Sesi selesai").font(.title2.bold())
        Text(machine.state == .safetyAbort ? "Keluhan fisik perlu dinilai tenaga kesehatan sebelum latihan dilanjutkan." : "Ini data yang berguna, bukan penilaian atas dirimu.")
            .foregroundStyle(.secondary).multilineTextAlignment(.center)
    }

    private var stateTitle: String { switch machine.state { case .precheck: "Periksa dulu"; case .prepare: "Tenangkan tubuh"; case .activeLow, .activeRising: "Tetap sadar"; case .warning: "Pause sekarang"; case .pausedRecovery: "Biarkan intensitas turun"; case .resumeReady: "Kembali dalam rentang aman"; default: "" } }
    private var stateMessage: String { switch machine.state { case .warning: "Hands off. Tarik napas dan biarkan tubuh melunak."; case .prepare: "Rilekskan rahang, perut, paha, dan bokong. Jangan mengejar durasi."; case .pausedRecovery: "Kamu dapat lanjut hanya setelah jeda minimum dan intensitas turun."; default: "TEMPO mendukung latihan terstruktur, bukan diagnosis medis." } }
    private func tick() { guard ![.precheck, .completed, .earlyCompletion, .cancelled, .safetyAbort, .timeLimitReached].contains(machine.state) else { return }; seconds += 1; if seconds >= 1_200 { machine.reachTimeLimit() } }
    private func playWarningHaptic() { guard hapticsEnabled else { return }; UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
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

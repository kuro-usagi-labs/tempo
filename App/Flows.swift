import SwiftUI

struct UrgeCheckInView: View {
    @Environment(\.dismiss) private var dismiss
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
    private func advance() { if step < 3 { step += 1 } else { var c = DecisionContext(); c.urgeIntensity = intensity; c.trigger = trigger; c.intent = intent; c.pain = hasSafetyFlag; result = RuleEngine().evaluate(c) } }
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
                    Label("Guided control session", systemImage: "timer")
                    Label("Urge surfing · 5 menit", systemImage: "wind")
                    Label("Napas pemulihan", systemImage: "circle.dotted")
                }
                Section("Gerak") {
                    Label("Jalan santai · 20 menit", systemImage: "figure.walk")
                    Label("Kekuatan pemula", systemImage: "figure.strengthtraining.traditional")
                }
            }.navigationTitle("Latihan")
        }
    }
}

struct ProgressView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Belum ada progres", systemImage: "chart.line.uptrend.xyaxis", description: Text("Selesaikan check-in atau aktivitas pertamamu untuk melihat tren privat."))
                .navigationTitle("Progres")
        }
    }
}

struct LearnView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Dasar tubuh") { Text("Gairah adalah kurva, bukan sakelar"); Text("Pre-ejakulat bukan kegagalan") }
                Section("Keterampilan") { Text("Kapan perlu melambat"); Text("Napas pemulihan") }
                Section("Kesehatan") { Text("Tanda yang perlu diperiksa") }
            }.navigationTitle("Belajar")
        }
    }
}

struct SettingsView: View {
    @State private var discreet = false
    @State private var haptics = true
    var body: some View {
        NavigationStack {
            Form {
                Section("Privasi") {
                    Toggle("Terminologi privat", isOn: $discreet)
                    NavigationLink("Kunci aplikasi") { Text("Face ID dan PIN akan tersedia saat autentikasi perangkat dikonfigurasi.").padding() }
                    Button("Hapus semua data", role: .destructive) {}
                }
                Section("Preferensi") {
                    Toggle("Haptics", isOn: $haptics)
                    NavigationLink("Tentang keselamatan") { Text("TEMPO bukan alat diagnosis atau layanan darurat. Nyeri, perdarahan, demam, perih saat kencing, atau cairan tidak biasa memerlukan penilaian profesional.").padding() }
                }
            }.navigationTitle("Pengaturan")
        }
    }
}

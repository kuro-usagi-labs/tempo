import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("privacyLockEnabled") private var privacyLockEnabled = false
    @State private var privacyCovered = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    var body: some View {
        ZStack {
        if onboardingCompleted {
        TabView {
            TodayView().tabItem { Label("Hari ini", systemImage: "sparkles") }
            TrainingView().tabItem { Label("Latihan", systemImage: "figure.mind.and.body") }
            ProgressView().tabItem { Label("Progres", systemImage: "chart.line.uptrend.xyaxis") }
            LearnView().tabItem { Label("Belajar", systemImage: "book") }
            SettingsView().tabItem { Label("Pengaturan", systemImage: "gearshape") }
        }.tint(Color(red: 0.47, green: 0.42, blue: 1))
        } else {
            OnboardingView()
        }
        if privacyCovered {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "circle.fill").font(.system(size: 36)).foregroundStyle(.indigo)
                Text("TEMPO").font(.headline)
            }.accessibilityLabel("Layar privat")
        }
        }
        .onChange(of: scenePhase) { _, phase in
            if privacyLockEnabled && phase != .active { privacyCovered = true }
            if phase == .active { privacyCovered = false }
        }
    }
}

struct OnboardingView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("discreetTerminology") private var discreetTerminology = false
    @State private var page = 0
    @State private var confirmedAdult = false
    private let pages = [
        ("Build control without pressure", "TEMPO memberi rencana terstruktur untuk kesadaran, jeda, pemulihan, gerak, dan kebiasaan sehat."),
        ("Privat secara desain", "Jawaban dan riwayatmu tetap pada iPhone ini. Tidak ada akun dan tidak ada internet yang dibutuhkan."),
        ("Bukan diagnosis", "Nyeri, perih saat kencing, cairan tidak biasa, darah, demam, atau perubahan mendadak perlu penilaian profesional."),
        ("Istirahat juga latihan", "TEMPO dapat menyarankan napas, jalan, atau pemulihan, bukan sesi tambahan.")
    ]
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "circle.hexagongrid.fill").font(.system(size: 64)).foregroundStyle(.indigo)
            Text(pages[page].0).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(pages[page].1).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack { ForEach(0..<pages.count, id: \.self) { index in Capsule().fill(index == page ? Color.indigo : Color.white.opacity(0.2)).frame(width: index == page ? 28 : 8, height: 8) } }
            if page == pages.count - 1 {
                Toggle("Saya mengonfirmasi bahwa saya berusia 18 tahun atau lebih", isOn: $confirmedAdult).font(.subheadline)
                Toggle("Gunakan istilah privat", isOn: $discreetTerminology)
            }
            Spacer()
            Button(page == pages.count - 1 ? "Mulai dengan aman" : "Lanjut") {
                if page == pages.count - 1 { onboardingCompleted = true } else { page += 1 }
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(page == pages.count - 1 && !confirmedAdult)
        }.padding(28).background(Color.black.ignoresSafeArea())
    }
}

struct TodayView: View {
    @State private var showCheckIn = false
    @State private var showBreathing = false
    @State private var showHealthCheck = false
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) {
        Text("TEMPO").font(.caption.weight(.bold)).foregroundStyle(.cyan)
        Text("Ritme yang lebih tenang.").font(.largeTitle.bold())
        Card { VStack(alignment: .leading, spacing: 12) { Text("Fase kesadaran · Minggu 1").foregroundStyle(.secondary); Text("Mulai aktivitas hari ini").font(.title2.bold()); Text("Napas singkat dan jalan santai · 20 menit").foregroundStyle(.secondary); Button("Mulai") { showBreathing = true }.buttonStyle(.borderedProminent) } }
        Button { showCheckIn = true } label: { HStack { Image(systemName: "bolt.heart.fill"); VStack(alignment: .leading) { Text("Aku lagi terangsang").font(.headline); Text("Dapatkan rekomendasi privat dalam 15 detik").font(.caption).opacity(0.8) }; Spacer(); Image(systemName: "chevron.right") }.padding().frame(maxWidth: .infinity).background(Color.indigo.opacity(0.65), in: RoundedRectangle(cornerRadius: 24)) }.accessibilityLabel("Aku lagi terangsang, mulai check-in cepat")
        Button { showHealthCheck = true } label: { HStack { Image(systemName: "cross.case.fill"); Text("Aku punya keluhan").font(.headline); Spacer(); Image(systemName: "chevron.right") }.padding().frame(maxWidth: .infinity).background(Color.red.opacity(0.22), in: RoundedRectangle(cornerRadius: 20)) }
        HStack { Metric(title: "Kesadaran", value: "—"); Metric(title: "Pemulihan", value: "—") }
    }.padding() }.background(Color(red: 0.035, green: 0.04, blue: 0.05)).navigationBarHidden(true).sheet(isPresented: $showCheckIn) { UrgeCheckInView() }.sheet(isPresented: $showBreathing) { NavigationStack { BreathingView(title: "Napas singkat", duration: 240).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Tutup") { showBreathing = false } } } } }.sheet(isPresented: $showHealthCheck) { HealthCheckView() } } }
}

struct HealthCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var symptom = false
    var body: some View { NavigationStack { VStack(spacing: 20) { Image(systemName: "cross.case.fill").font(.system(size: 50)).foregroundStyle(.red); Text("Health check").font(.title.bold()); Text("Apakah kamu mengalami nyeri berat, darah, demam, perih saat kencing, cairan tidak biasa, atau cedera akut?").multilineTextAlignment(.center); Toggle("Ya, ada keluhan", isOn: $symptom).padding().background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16)); Text(symptom ? "Hentikan latihan seksual untuk saat ini. Kondisi tersebut perlu penilaian tenaga kesehatan yang sesuai." : "Jika tidak ada tanda di atas, kamu tetap dapat memilih pemulihan atau check-in privat.").foregroundStyle(symptom ? .red : .secondary).multilineTextAlignment(.center); Button("Selesai") { dismiss() }.buttonStyle(.borderedProminent) }.padding().navigationTitle("Kesehatan").toolbar { Button("Tutup") { dismiss() } } } }
}
struct Card<Content: View>: View { @ViewBuilder var content: Content; var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.08, green: 0.095, blue: 0.13), in: RoundedRectangle(cornerRadius: 24)) } }
struct Metric: View { let title: String; let value: String; var body: some View { VStack(alignment: .leading) { Text(title).foregroundStyle(.secondary); Text(value).font(.title.bold()) }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18)) } }

import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("privacyLockEnabled") private var privacyLockEnabled = false
    @State private var privacyCovered = false
    var body: some View {
        ZStack {
        TabView {
            TodayView().tabItem { Label("Hari ini", systemImage: "sparkles") }
            TrainingView().tabItem { Label("Latihan", systemImage: "figure.mind.and.body") }
            ProgressView().tabItem { Label("Progres", systemImage: "chart.line.uptrend.xyaxis") }
            LearnView().tabItem { Label("Belajar", systemImage: "book") }
            SettingsView().tabItem { Label("Pengaturan", systemImage: "gearshape") }
        }.tint(Color(red: 0.47, green: 0.42, blue: 1))
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

struct TodayView: View {
    @State private var showCheckIn = false
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) {
        Text("TEMPO").font(.caption.weight(.bold)).foregroundStyle(.cyan)
        Text("Ritme yang lebih tenang.").font(.largeTitle.bold())
        Card { VStack(alignment: .leading, spacing: 12) { Text("Fase kesadaran · Minggu 1").foregroundStyle(.secondary); Text("Mulai aktivitas hari ini").font(.title2.bold()); Text("Napas singkat dan jalan santai · 20 menit").foregroundStyle(.secondary); Button("Mulai") {}.buttonStyle(.borderedProminent) } }
        Button { showCheckIn = true } label: { HStack { Image(systemName: "bolt.heart.fill"); VStack(alignment: .leading) { Text("Aku lagi terangsang").font(.headline); Text("Dapatkan rekomendasi privat dalam 15 detik").font(.caption).opacity(0.8) }; Spacer(); Image(systemName: "chevron.right") }.padding().frame(maxWidth: .infinity).background(Color.indigo.opacity(0.65), in: RoundedRectangle(cornerRadius: 24)) }.accessibilityLabel("Aku lagi terangsang, mulai check-in cepat")
        HStack { Metric(title: "Kesadaran", value: "—"); Metric(title: "Pemulihan", value: "—") }
    }.padding() }.background(Color(red: 0.035, green: 0.04, blue: 0.05)).navigationBarHidden(true).sheet(isPresented: $showCheckIn) { UrgeCheckInView() } } }
}
struct Card<Content: View>: View { @ViewBuilder var content: Content; var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.08, green: 0.095, blue: 0.13), in: RoundedRectangle(cornerRadius: 24)) } }
struct Metric: View { let title: String; let value: String; var body: some View { VStack(alignment: .leading) { Text(title).foregroundStyle(.secondary); Text(value).font(.title.bold()) }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18)) } }

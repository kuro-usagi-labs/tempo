import SwiftUI
import Combine

private func tempoActivityDuration(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    return "\(safe / 60):\(String(format: "%02d", safe % 60))"
}

struct TempoCardioSessionScreen: View {
    let plannedDayID: UUID?
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var phase: CardioPhase = .ready
    @State private var elapsed = 0
    @State private var halfwayCueSent = false
    @State private var difficulty = 4
    @State private var pain = false
    @State private var saveFailed = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum CardioPhase: Equatable { case ready, running, paused, reflection, saved }
    private var prescription: ExercisePrescription? { ExercisePrescriptionEngine().prescription(for: .cardio, context: history.programContext, recentDifficulty: history.recentExerciseDifficulty(for: .cardio)) }
    private var totalSeconds: Int { (prescription?.targetMinutes ?? 20) * 60 }
    private var remaining: Int { max(0, totalSeconds - elapsed) }

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.xl) {
            Spacer()
            Image(systemName: "figure.walk").font(.system(size: 54, weight: .semibold)).foregroundStyle(TempoDesign.Palette.accentSoft)
            Text(title).font(TempoDesign.Typography.pageTitle)
            Text(tempoActivityDuration(remaining)).font(.system(size: 62, weight: .bold, design: .rounded)).monospacedDigit()
            Text(instruction).multilineTextAlignment(.center).foregroundStyle(TempoDesign.Palette.textSecondary).padding(.horizontal, TempoDesign.Spacing.lg)
            sessionContent
            Spacer()
        }
        .padding(TempoDesign.Spacing.lg).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TempoDesign.Palette.canvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .onReceive(ticker) { _ in update() }
        .onChange(of: scenePhase) { _, newPhase in if newPhase != .active, phase == .running { phase = .paused } }
        .alert("Aktivitas belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { save() } } message: { Text("TEMPO menunggu penyimpanan lokal sebelum mengubah status rencana.") }
        .accessibilityIdentifier("cardio.session")
    }

    private var title: String { prescription?.mode == .walkJog ? "Jalan dengan interval ringan" : "Jalan santai" }
    private var instruction: String {
        if phase == .ready { return "Pilih tempo yang masih membuatmu bisa berbicara. Berhenti bila ada nyeri dada, pusing, sesak tidak biasa, atau nyeri tajam." }
        if phase == .reflection { return "Bagaimana rasanya setelah bergerak? Nyeri atau gejala baru akan menjeda rencana." }
        if phase == .saved { return "Gerakmu tercatat. Jangan tambah target untuk mengganti hari yang terlewat." }
        if prescription?.mode == .walkJog { return intervalInstruction }
        return "Pertahankan langkah nyaman. Jeda kapan pun dibutuhkan."
    }
    private var intervalInstruction: String {
        let intervals = prescription?.intervals ?? []
        guard !intervals.isEmpty else { return "Pertahankan langkah nyaman." }
        var total = 0
        for (index, interval) in intervals.enumerated() {
            total += interval
            if elapsed < total { return index.isMultiple(of: 2) ? "Jalan nyaman" : "Tambah tempo sedikit bila tetap nyaman" }
        }
        return "Kembali ke jalan nyaman untuk menutup sesi."
    }

    @ViewBuilder private var sessionContent: some View {
        switch phase {
        case .ready:
            TempoPrimaryButton("Mulai jalan", icon: "play.fill") { start() }
        case .running:
            VStack(spacing: TempoDesign.Spacing.sm) {
                TempoPrimaryButton("Jeda", icon: "pause.fill") { pause() }
                TempoSecondaryButton("Akhiri aktivitas", icon: "checkmark", tone: .positive) { phase = .reflection }
            }
        case .paused:
            VStack(spacing: TempoDesign.Spacing.sm) {
                TempoPrimaryButton("Lanjut", icon: "play.fill") { resume() }
                TempoSecondaryButton("Akhiri aktivitas", icon: "checkmark", tone: .positive) { phase = .reflection }
            }
        case .reflection:
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                HStack { Text("Kesulitan terasa").font(TempoDesign.Typography.cardTitle); Spacer(); Text("\(difficulty)/10").monospacedDigit() }
                Slider(value: Binding(get: { Double(difficulty) }, set: { difficulty = Int($0.rounded()) }), in: 1...10, step: 1).tint(TempoDesign.Palette.accentSoft)
                Toggle("Ada nyeri tajam, pusing, nyeri dada, atau sesak tidak biasa", isOn: $pain).tint(TempoDesign.Palette.critical)
                TempoPrimaryButton("Simpan aktivitas", icon: "checkmark") { save() }
            }
            .padding(TempoDesign.Spacing.md).background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
        case .saved:
            TempoPrimaryButton("Kembali", icon: "arrow.left") { dismiss() }
        }
    }

    private func update() {
        guard scenePhase == .active, phase == .running else { return }
        elapsed += 1
        if !halfwayCueSent && elapsed >= totalSeconds / 2 { halfwayCueSent = true; if hapticsEnabled { TempoFeedback.impact(.medium) } }
        if elapsed >= totalSeconds { phase = .reflection; if hapticsEnabled { TempoFeedback.notification(.success) } }
    }
    private func start() { phase = .running; TempoFeedback.impact(.light) }
    private func pause() { phase = .paused; TempoFeedback.impact(.light) }
    private func resume() { phase = .running }
    private func save() {
        if pain, !history.recordSafetyHold(reasonCode: "safety.exercise-symptom", severity: RecommendationSeverity.urgent.rawValue, source: "cardio") { saveFailed = true; return }
        guard history.addExercise(kind: title, activityKind: .cardio, durationMinutes: max(1, elapsed / 60), perceivedDifficulty: difficulty, painReported: pain) else { saveFailed = true; return }
        if let plannedDayID, !history.completePlanItem(id: plannedDayID, performedKind: .cardio, completedAt: .now) { saveFailed = true; return }
        phase = .saved
        if pain { coordinator.open(.healthCheck) }
    }
}

struct TempoStrengthCircuitScreen: View {
    let plannedDayID: UUID?
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var phase: StrengthPhase = .ready
    @State private var movementIndex = 0
    @State private var setInMovement = 1
    @State private var restRemaining = 0
    @State private var difficulty = 4
    @State private var pain = false
    @State private var saveFailed = false
    @State private var elapsed = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private enum StrengthPhase: Equatable { case ready, working, rest, reflection, saved }

    private var prescription: ExercisePrescription { ExercisePrescriptionEngine().prescription(for: .strength, context: history.programContext, recentDifficulty: history.recentExerciseDifficulty(for: .strength)) ?? ExercisePrescription(mode: .strengthCircuit, targetMinutes: 16, sets: 2, repetitions: 8, restSeconds: 45, reason: .plannedStrength) }
    private let movements = ["Wall / incline push-up", "Chair squat", "Glute bridge", "Bird dog"]
    private var currentMovement: String { movements[min(movementIndex, movements.count - 1)] }

    var body: some View {
        VStack(spacing: TempoDesign.Spacing.xl) {
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 54, weight: .semibold)).foregroundStyle(TempoDesign.Palette.accentSoft)
            Text(phase == .ready ? "Kekuatan ringan" : currentMovement).font(TempoDesign.Typography.pageTitle).multilineTextAlignment(.center)
            Text(message).multilineTextAlignment(.center).foregroundStyle(TempoDesign.Palette.textSecondary).padding(.horizontal, TempoDesign.Spacing.lg)
            content
            Spacer()
        }
        .padding(TempoDesign.Spacing.lg).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TempoDesign.Palette.canvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .onReceive(ticker) { _ in
            guard scenePhase == .active else { return }
            if phase == .working || phase == .rest { elapsed += 1 }
            if phase == .rest && restRemaining > 0 { restRemaining -= 1; if restRemaining == 0 { phase = .working; TempoFeedback.impact(.light) } }
        }
        .alert("Aktivitas belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { save() } } message: { Text("Catatan dan status rencana harus tersimpan lokal terlebih dahulu.") }
        .accessibilityIdentifier("strength.session")
    }

    private var message: String {
        switch phase {
        case .ready: "Dua set ringan dengan teknik nyaman. Berhenti bila muncul nyeri tajam, pusing, nyeri dada, atau sesak tidak biasa."
        case .working: "Set \(setInMovement) dari \(prescription.sets) · \(prescription.repetitions) repetisi nyaman"
        case .rest: "Istirahat \(tempoActivityDuration(restRemaining)). Napas tenang, tidak perlu terburu-buru."
        case .reflection: "Nilai usaha hari ini, bukan performa ideal."
        case .saved: "Aktivitas tercatat. Pemulihan tetap bagian dari program."
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .ready: TempoPrimaryButton("Mulai rangkaian", icon: "play.fill") { phase = .working }
        case .working:
            VStack(spacing: TempoDesign.Spacing.sm) {
                TempoPrimaryButton("Selesaikan set", icon: "checkmark") { completeSet() }
                TempoSecondaryButton("Akhiri lebih awal", icon: "hand.raised.fill", tone: .caution) { phase = .reflection }
            }
        case .rest:
            TempoSecondaryButton("Lewati istirahat", icon: "forward.fill") { restRemaining = 0; phase = .working }
        case .reflection:
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                HStack { Text("Kesulitan terasa").font(TempoDesign.Typography.cardTitle); Spacer(); Text("\(difficulty)/10").monospacedDigit() }
                Slider(value: Binding(get: { Double(difficulty) }, set: { difficulty = Int($0.rounded()) }), in: 1...10, step: 1).tint(TempoDesign.Palette.accentSoft)
                Toggle("Ada nyeri tajam, pusing, nyeri dada, atau sesak tidak biasa", isOn: $pain).tint(TempoDesign.Palette.critical)
                TempoPrimaryButton("Simpan aktivitas", icon: "checkmark") { save() }
            }.padding(TempoDesign.Spacing.md).background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
        case .saved: TempoPrimaryButton("Kembali", icon: "arrow.left") { dismiss() }
        }
    }

    private func completeSet() {
        TempoFeedback.impact(.medium)
        if setInMovement < prescription.sets { setInMovement += 1; restRemaining = prescription.restSeconds; phase = .rest; return }
        if movementIndex < movements.count - 1 { movementIndex += 1; setInMovement = 1; restRemaining = prescription.restSeconds; phase = .rest; return }
        phase = .reflection
        if hapticsEnabled { TempoFeedback.notification(.success) }
    }
    private func save() {
        if pain, !history.recordSafetyHold(reasonCode: "safety.exercise-symptom", severity: RecommendationSeverity.urgent.rawValue, source: "strength") { saveFailed = true; return }
        guard history.addExercise(kind: "Kekuatan ringan", activityKind: .strength, durationMinutes: max(1, elapsed / 60), perceivedDifficulty: difficulty, painReported: pain) else { saveFailed = true; return }
        if let plannedDayID, !history.completePlanItem(id: plannedDayID, performedKind: .strength, completedAt: .now) { saveFailed = true; return }
        phase = .saved
        if pain { coordinator.open(.healthCheck) }
    }
}

struct TempoLessonScreen: View {
    let plannedDayID: UUID?
    let topic: String
    @Environment(LocalHistory.self) private var history
    @Environment(\.dismiss) private var dismiss
    @State private var completed = false
    @State private var saveFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                Image(systemName: "book.closed.fill").font(.system(size: 42)).foregroundStyle(TempoDesign.Palette.accentSoft)
                Text(topic).font(TempoDesign.Typography.pageTitle)
                TempoSurfaceCard {
                    Text("Kenali sinyal awal: perubahan napas, ketegangan tubuh, pikiran yang terasa mendesak, dan keinginan untuk mempercepat. Sinyal awal bukan kegagalan—ia memberi pilihan untuk melambat, berhenti, atau mengambil jeda.")
                        .foregroundStyle(TempoDesign.Palette.textPrimary)
                }
                TempoSurfaceCard(tint: TempoDesign.Palette.positive, emphasis: .tinted) {
                    Text("Tidak ada jawaban yang harus dilaporkan. Cukup bawa satu hal yang kamu sadari ke aktivitas berikutnya.")
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                }
                if completed { TempoStatusBadge("Materi ditandai selesai.", tone: .positive) }
                else { TempoPrimaryButton("Tandai selesai", icon: "checkmark") { complete() } }
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
            .padding(TempoDesign.Spacing.lg)
        }
        .background(TempoDesign.Palette.canvas).navigationTitle("Materi").navigationBarTitleDisplayMode(.inline)
        .alert("Status belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { complete() } } message: { Text("Materi tidak akan ditandai selesai sampai penyimpanan lokal berhasil.") }
    }
    private func complete() {
        if let plannedDayID, !history.completePlanItem(id: plannedDayID, performedKind: .education, completedAt: .now) { saveFailed = true; return }
        completed = true
    }
}

struct TempoWeeklyReviewScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator

    private var dueItems: [LocalPlanDay] { history.plannedDays.filter { $0.scheduleDate <= .now && $0.status != .recovery } }
    private var completedCount: Int { dueItems.filter { $0.status == .completed }.count }
    private var adaptedCount: Int { history.plannedDays.filter { $0.status == .adapted || $0.status == .recovery }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                Text("Tinjauan mingguan").font(TempoDesign.Typography.pageTitle)
                Text("Ringkasan ini memakai data lokal dan tidak membandingkanmu dengan orang lain.").foregroundStyle(TempoDesign.Palette.textSecondary)
                TempoSurfaceCard(tint: TempoDesign.Palette.positive, emphasis: .tinted) {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                        Text("Konsistensi yang sudah jatuh tempo").font(TempoDesign.Typography.cardTitle)
                        if dueItems.isEmpty { Text("Belum ada aktivitas yang jatuh tempo untuk dinilai.").foregroundStyle(TempoDesign.Palette.textSecondary) }
                        else { Text("\(completedCount) dari \(dueItems.count) langkah selesai").font(TempoDesign.Typography.numeric).foregroundStyle(TempoDesign.Palette.positive) }
                    }
                }
                TempoSurfaceCard {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                        Text("Insight minggu ini").font(TempoDesign.Typography.cardTitle)
                        Text(insight).foregroundStyle(TempoDesign.Palette.textSecondary)
                        if adaptedCount > 0 { Text("• \(adaptedCount) aktivitas disesuaikan; pemulihan tetap dihitung sebagai keputusan yang aman.").foregroundStyle(TempoDesign.Palette.textSecondary) }
                    }
                }
                TempoSecondaryButton("Lihat Progres", icon: "chart.line.uptrend.xyaxis", tone: .accent) { coordinator.selectedTab = .progress }
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading).padding(TempoDesign.Spacing.lg)
        }
        .background(TempoDesign.Palette.canvas).navigationBarTitleDisplayMode(.inline)
    }

    private var insight: String {
        if history.sessions.isEmpty && history.exercises.isEmpty { return "Mulai dengan satu langkah kecil. Tidak ada skor yang perlu dikejar sebelum cukup data terkumpul." }
        if history.isHighStress { return "Kecemasan yang tinggi adalah alasan untuk menurunkan tempo, bukan alasan untuk memaksa konsistensi." }
        if history.hasElevatedGuidedSessionAnxietyTrend { return "Sesi terpandu terakhir menunjukkan tren kecemasan lebih tinggi. Ini bukan penilaian kondisi hari ini." }
        if completedCount == dueItems.count && !dueItems.isEmpty { return "Kamu menjaga ritme pada semua langkah yang sudah jatuh tempo. Pertahankan jeda yang realistis." }
        return "Perhatikan waktu atau konteks yang membuat jeda lebih mudah. Rencana dapat disesuaikan tanpa perlu mengejar yang terlewat." }
}

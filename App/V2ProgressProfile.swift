import SwiftUI
import UniformTypeIdentifiers

struct TempoProgressScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator

    private var consistency: Double? { ProgressEngine().consistency(for: history.plannedDays.map(ProgramPlanItem.init(localDay:)), through: .now) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                Text("Progres").font(TempoDesign.Typography.display)
                Text("Semua ringkasan berasal dari perangkat ini. Angka muncul hanya setelah cukup contoh, bukan sebagai nilai diri.")
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                progressState
                consistencyCard
                insightCard
                TempoSecondaryButton("Tinjauan mingguan", icon: "calendar.badge.checkmark", tone: .accent) { coordinator.open(.weeklyReview) }
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
            .padding(TempoDesign.Spacing.lg)
            .padding(.bottom, 112)
        }
        .background(TempoDesign.Palette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("tab.progress")
    }

    @ViewBuilder private var progressState: some View {
        switch history.progressPresentation {
        case .baseline:
            TempoSurfaceCard(tint: TempoDesign.Palette.accent, emphasis: .tinted) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                    Text("Mulai dari pola, bukan skor.").font(TempoDesign.Typography.sectionTitle)
                    Text("Selesaikan beberapa aktivitas atau check-in untuk melihat tren privat yang lebih bermakna.").foregroundStyle(TempoDesign.Palette.textSecondary)
                }
            }
        case let .collecting(samplesNeeded):
            TempoSurfaceCard(tint: TempoDesign.Palette.accentSoft, emphasis: .tinted) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                    Text("Sedang mengenali pola").font(TempoDesign.Typography.sectionTitle)
                    Text("Butuh sekitar \(samplesNeeded) catatan sesi lagi sebelum angka tren ditampilkan.").foregroundStyle(TempoDesign.Palette.textSecondary)
                }
            }
        case let .ready(scores):
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                TempoSectionHeader("Tren pribadimu", detail: "Dibandingkan dengan riwayatmu sendiri.")
                scoreCard("Kesadaran", scores.awareness, TempoDesign.Palette.accentSoft)
                scoreCard("Kontrol", scores.control, TempoDesign.Palette.accent)
                scoreCard("Pemulihan", scores.recovery, TempoDesign.Palette.positive)
                scoreCard("Ketenangan", scores.calm, .mint)
            }
        }
    }

    private var consistencyCard: some View {
        TempoSurfaceCard(tint: TempoDesign.Palette.positive, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                Text("Konsistensi yang sudah jatuh tempo").font(TempoDesign.Typography.cardTitle)
                if let consistency {
                    Text("\(Int((consistency * 100).rounded()))%")
                        .font(.system(size: 42, weight: .bold, design: .rounded)).foregroundStyle(TempoDesign.Palette.positive).monospacedDigit()
                    Text("Menghitung aktivitas yang memang sudah jatuh tempo; pemulihan yang diresepkan tidak dianggap gagal.")
                        .font(TempoDesign.Typography.supporting).foregroundStyle(TempoDesign.Palette.textSecondary)
                } else {
                    Text("Belum ada aktivitas yang jatuh tempo untuk dihitung.").foregroundStyle(TempoDesign.Palette.textSecondary)
                }
            }
        }
    }

    private var insightCard: some View {
        TempoSurfaceCard {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                Label("Insight deterministik", systemImage: "lightbulb.fill").font(TempoDesign.Typography.cardTitle).foregroundStyle(TempoDesign.Palette.accentSoft)
                Text(insight).foregroundStyle(TempoDesign.Palette.textSecondary)
                HStack(spacing: TempoDesign.Spacing.lg) {
                    metric("Check-in", history.checkIns.count)
                    metric("Sesi terpandu", history.sessions.count)
                    metric("Gerak", history.exercises.count)
                }
            }
        }
    }

    private func scoreCard(_ title: String, _ value: Int, _ color: Color) -> some View {
        TempoSurfaceCard {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                HStack { Text(title).font(TempoDesign.Typography.cardTitle); Spacer(); Text("\(value)").font(TempoDesign.Typography.numeric).foregroundStyle(color) }
                SwiftUI.ProgressView(value: Double(value), total: 100).tint(color)
                    .accessibilityLabel("\(title), \(value) dari 100")
            }
        }
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text("\(value)").font(TempoDesign.Typography.numeric); Text(title).font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary) }
    }

    private var insight: String {
        if history.hasSafetyBlock { return "Safety hold sedang aktif. Fokus pada pemeriksaan dan pemulihan sebelum melihat target program." }
        if history.isHighStress { return "Kecemasan yang tinggi membuat Tempo meredakan rencana. Mengikuti pemulihan juga merupakan progres." }
        if let change = history.urgeOutcomes.last, change.finalIntensity < change.initialIntensity { return "Reset terakhir menurunkan intensitas. Perhatikan konteks yang membantumu memberi jeda." }
        if history.privateSessions.isEmpty && history.sessions.isEmpty { return "Belum ada pola sesi untuk disimpulkan. Mulai dari satu langkah ringan yang dijadwalkan." }
        return "Lihat minggu ini sebagai pola, bukan ujian. Penyesuaian yang aman lebih berguna daripada mengejar angka." }
}

struct TempoProfileScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @AppStorage("discreetTerminology") private var discreet = false
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("biometricLockEnabled") private var biometricLock = false
    @AppStorage("notificationSoundsEnabled") private var notificationSounds = false
    @AppStorage("dailyPlanRemindersEnabled") private var reminders = false
    @AppStorage("dailyPlanReminderHour") private var reminderHour = 19
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var showDeletion = false
    @State private var showNotesDeletion = false
    @State private var showExportPassword = false
    @State private var exportPassword = ""
    @State private var exportDocument = TempoExportDocument()
    @State private var showExporter = false
    @State private var exportError = false
    @State private var biometricError = false
    @State private var deletionError = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                Text("Profil").font(TempoDesign.Typography.display)
                baselineCard
                privacyCard
                preferencesCard
                safetyCard
                dataCard
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
            .padding(TempoDesign.Spacing.lg)
            .padding(.bottom, 112)
        }
        .background(TempoDesign.Palette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Hapus seluruh data lokal?", isPresented: $showDeletion, titleVisibility: .visible) {
            Button("Hapus semua data", role: .destructive) { deleteAll() }
        } message: { Text("Catatan, rencana, dan preferensi pada perangkat ini akan dihapus. Tindakan ini tidak dapat dibatalkan.") }
        .confirmationDialog("Hapus semua catatan teks privat?", isPresented: $showNotesDeletion, titleVisibility: .visible) {
            Button("Hapus catatan teks", role: .destructive) { if !history.deleteAllNotes() { deletionError = true } }
        } message: { Text("Ringkasan sesi tetap disimpan, tetapi catatan opsional akan dihapus.") }
        .alert("Lindungi file export", isPresented: $showExportPassword) {
            SecureField("Password minimal 8 karakter", text: $exportPassword)
            Button("Buat file") { createExport() }
            Button("Batal", role: .cancel) {}
        } message: { Text("Password tidak disimpan oleh TEMPO. Simpan sendiri karena file tidak dapat dibuka tanpanya.") }
        .alert("Export gagal", isPresented: $exportError) { Button("Tutup", role: .cancel) {} } message: { Text("Gunakan password minimal 8 karakter dan coba lagi.") }
        .alert("Kunci perangkat tidak tersedia", isPresented: $biometricError) { Button("Tutup", role: .cancel) {} } message: { Text("Aktifkan kode perangkat atau biometrik sebelum menyalakan kunci TEMPO.") }
        .alert("Penghapusan belum selesai", isPresented: $deletionError) { Button("Tutup", role: .cancel) {} } message: { Text("Penyimpanan aman belum dapat dihapus. TEMPO mempertahankan tampilan agar tidak memberi kesan palsu bahwa data sudah hilang.") }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: UTType.data, defaultFilename: "Tempo-Export.tempo") { _ in }
        .accessibilityIdentifier("tab.profile")
    }

    private var baselineCard: some View {
        TempoSurfaceCard {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                Text("Ritme program").font(TempoDesign.Typography.sectionTitle)
                if let baseline = history.baseline {
                    Text("Minggu \(history.programWeek) · \(tempoPhaseName(history.effectiveProgramPhase))").font(TempoDesign.Typography.cardTitle)
                    Text("Tidur baseline \(baseline.sleepHours) jam · kecemasan \(baseline.anxiety)/10").foregroundStyle(TempoDesign.Palette.textSecondary)
                }
            }
        }
    }

    private var privacyCard: some View {
        TempoSurfaceCard(tint: TempoDesign.Palette.accentSoft, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                Label("Privasi", systemImage: "lock.shield.fill").font(TempoDesign.Typography.sectionTitle)
                Text("TEMPO berjalan lokal. Tidak ada akun, AI, analitik, atau koneksi jaringan untuk menentukan rekomendasi.")
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                Toggle("Terminologi privat", isOn: $discreet).tint(TempoDesign.Palette.accent)
                Toggle("Kunci dengan Face ID / kode perangkat", isOn: biometricBinding).tint(TempoDesign.Palette.accent)
            }
        }
    }

    private var preferencesCard: some View {
        TempoSurfaceCard {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                Text("Preferensi").font(TempoDesign.Typography.sectionTitle)
                Toggle("Haptics", isOn: $haptics).tint(TempoDesign.Palette.accent)
                Toggle("Suara pengingat", isOn: $notificationSounds).tint(TempoDesign.Palette.accent)
                    .onChange(of: notificationSounds) { _, _ in syncNotifications() }
                Toggle("Pengingat dari rencana", isOn: $reminders).tint(TempoDesign.Palette.accent)
                    .onChange(of: reminders) { _, enabled in if enabled { syncNotifications() } else { LocalNotifications.removeDailyPlan() } }
                if reminders {
                    Stepper("Jam pengingat cadangan: \(String(format: "%02d:00", reminderHour))", value: $reminderHour, in: 8...21)
                        .onChange(of: reminderHour) { _, _ in syncNotifications() }
                }
            }
        }
    }

    private var safetyCard: some View {
        TempoSurfaceCard(tint: history.hasSafetyBlock ? TempoDesign.Palette.caution : TempoDesign.Palette.positive, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                Text("Keselamatan").font(TempoDesign.Typography.sectionTitle)
                Text(history.hasSafetyBlock ? "Safety hold aktif. Sesi terpandu dijeda sampai pemeriksaan ulang selesai." : "Tidak ada safety hold aktif. TEMPO tetap bukan alat diagnosis atau layanan darurat.")
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                TempoSecondaryButton("Buka pemeriksaan", icon: "cross.case.fill", tone: history.hasSafetyBlock ? .caution : .accent) { coordinator.open(.healthCheck) }
            }
        }
    }

    private var dataCard: some View {
        TempoSurfaceCard {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                Text("Data lokal").font(TempoDesign.Typography.sectionTitle)
                TempoSecondaryButton("Export data terenkripsi", icon: "square.and.arrow.up", tone: .accent) { exportPassword = ""; showExportPassword = true }
                TempoSecondaryButton("Hapus catatan teks", icon: "text.badge.minus", tone: .caution) { showNotesDeletion = true }
                TempoSecondaryButton("Hapus semua data", icon: "trash", tone: .critical) { showDeletion = true }
            }
        }
    }

    private var biometricBinding: Binding<Bool> {
        Binding(get: { biometricLock }, set: { enabled in
            if !enabled { biometricLock = false; return }
            Task {
                if await PrivacyLock.authenticate() { biometricLock = true }
                else { biometricError = true }
            }
        })
    }
    private func syncNotifications() {
        guard reminders else { return }
        Task { await LocalNotifications.requestAndSyncPlan(history.upcomingPlan, fallbackHour: reminderHour, windowEndHour: history.baseline?.reminderEndHour ?? 21, soundEnabled: notificationSounds) }
    }
    private func createExport() {
        guard let data = history.makeExportData(), let encrypted = try? EncryptedExport.encrypt(data, password: exportPassword) else { exportError = true; return }
        exportDocument = TempoExportDocument(data: encrypted)
        showExporter = true
    }
    private func deleteAll() {
        guard history.deleteAll() else { deletionError = true; return }
        LocalNotifications.removeAll()
        discreet = false; haptics = true; biometricLock = false; notificationSounds = false; reminders = false; reminderHour = 19; onboardingCompleted = false
    }
}

/// Embedded health route for the V2 coordinator. It intentionally avoids
/// creating another NavigationStack when pushed from the app shell.
struct TempoHealthCheckScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalHistory.self) private var history
    @State private var answers = SafetyScreeningAnswers()
    @State private var confirmedComplete = false
    @State private var confirmedMedicalFollowUp = false
    @State private var saveFailed = false

    private var hasSymptoms: Bool { answers.hasAny }
    private var requiresMedicalResolutionConfirmation: Bool {
        guard let severity = history.activeSafetyHold?.severity else { return false }
        return severity == RecommendationSeverity.medical.rawValue || severity == RecommendationSeverity.urgent.rawValue
    }

    var body: some View {
        Form {
            Section {
                Label("Pemeriksaan ini tidak membuat diagnosis.", systemImage: "cross.case.fill")
                Text("Jawab semua bagian sebelum melanjutkan. Kondisi berat, memburuk, atau cedera akut memerlukan bantuan medis sesuai layanan setempat.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Tanda keselamatan") {
                SafetyScreeningFields(answers: $answers)
                Toggle("Saya sudah membaca dan menjawab semua bagian", isOn: $confirmedComplete)
                if requiresMedicalResolutionConfirmation && !hasSymptoms {
                    Toggle("Gejala sudah hilang atau dinilai tenaga kesehatan", isOn: $confirmedMedicalFollowUp)
                }
            }
            Section {
                Text(statusMessage).foregroundStyle(hasSymptoms ? .red : .secondary)
                Button(hasSymptoms ? "Simpan dan jeda latihan" : "Konfirmasi tidak ada gejala") { save() }
                    .disabled(!confirmedComplete || (!hasSymptoms && (!history.canResolveActiveSafetyHold || (requiresMedicalResolutionConfirmation && !confirmedMedicalFollowUp))))
            }
        }
        .navigationTitle("Pemeriksaan")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Data belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") { save() } } message: { Text("TEMPO tidak dapat memperbarui safety hold dengan aman.") }
        .accessibilityIdentifier("health.check")
    }

    private var statusMessage: String {
        if hasSymptoms { return answers.severity == .urgent ? "Hentikan latihan dan cari bantuan medis segera sesuai layanan setempat." : "Hentikan latihan dan minta penilaian tenaga kesehatan sebelum melanjutkan." }
        if let hours = history.safetyHoldRemainingHours { return "Masa pemulihan iritasi belum selesai. Periksa ulang setelah sekitar \(hours) jam lagi." }
        return "Jika seluruh jawaban tidak, safety hold aktif dapat diakhiri melalui pemeriksaan ulang lengkap ini."
    }

    private func save() {
        let success = hasSymptoms
            ? history.recordSafetyHold(reasonCode: answers.reasonCode, severity: answers.severity.rawValue, source: "health-check")
            : history.resolveActiveSafetyHoldAfterClearRecheck()
        if success { dismiss() } else { saveFailed = true }
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct TempoV22SettingsScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator

    @AppStorage("discreetTerminology") private var discreet = false
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("biometricLockEnabled") private var biometricLock = false
    @AppStorage("notificationSoundsEnabled") private var notificationSounds = false
    @AppStorage("dailyPlanRemindersEnabled") private var reminders = false
    @AppStorage("dailyPlanReminderHour") private var reminderHour = 19
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    @State private var programExpanded = true
    @State private var privacyExpanded = false
    @State private var sessionExpanded = false
    @State private var reminderExpanded = false
    @State private var activityExpanded = false
    @State private var safetyExpanded = false
    @State private var dataExpanded = false
    @State private var resetExpanded = false

    @State private var showDeletion = false
    @State private var showNotesDeletion = false
    @State private var showExportPassword = false
    @State private var exportPassword = ""
    @State private var exportDocument = TempoExportDocument()
    @State private var showExporter = false
    @State private var exportError = false
    @State private var biometricError = false
    @State private var deletionError = false
    @State private var showActivityPreference = false

    var body: some View {
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                header
                TempoDisclosureSection(title: "Program dan baseline", icon: "calendar.badge.clock", isExpanded: $programExpanded) {
                    programContent
                }
                TempoDisclosureSection(title: "Privasi", icon: "lock.shield.fill", isExpanded: $privacyExpanded) {
                    privacyContent
                }
                TempoDisclosureSection(title: "Sesi", icon: "timer", isExpanded: $sessionExpanded) {
                    sessionContent
                }
                TempoDisclosureSection(title: "Pengingat", icon: "bell.fill", isExpanded: $reminderExpanded) {
                    reminderContent
                }
                TempoDisclosureSection(title: "Preferensi aktivitas", icon: "figure.walk", isExpanded: $activityExpanded) {
                    activityContent
                }
                TempoDisclosureSection(title: "Keselamatan", icon: "cross.case.fill", isExpanded: $safetyExpanded) {
                    safetyContent
                }
                TempoDisclosureSection(title: "Data dan export", icon: "externaldrive.fill", isExpanded: $dataExpanded) {
                    dataContent
                }
                TempoDisclosureSection(title: "Reset dan hapus", icon: "trash.fill", isExpanded: $resetExpanded) {
                    resetContent
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Hapus seluruh data lokal?", isPresented: $showDeletion, titleVisibility: .visible) {
            Button("Hapus semua data", role: .destructive) { deleteAll() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Catatan, rencana, dan preferensi pada perangkat ini akan dihapus. Tindakan ini tidak dapat dibatalkan.")
        }
        .confirmationDialog("Hapus semua catatan teks privat?", isPresented: $showNotesDeletion, titleVisibility: .visible) {
            Button("Hapus catatan teks", role: .destructive) {
                if !history.deleteAllNotes() { deletionError = true }
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Ringkasan sesi tetap disimpan, tetapi catatan opsional akan dihapus.")
        }
        .alert("Lindungi file export", isPresented: $showExportPassword) {
            SecureField("Password minimal 8 karakter", text: $exportPassword)
            Button("Buat file") { createExport() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Password tidak disimpan oleh TEMPO. Simpan sendiri karena file tidak dapat dibuka tanpanya.")
        }
        .alert("Export gagal", isPresented: $exportError) {
            Button("Tutup", role: .cancel) {}
        } message: {
            Text("Gunakan password minimal 8 karakter dan coba lagi.")
        }
        .alert("Kunci perangkat tidak tersedia", isPresented: $biometricError) {
            Button("Tutup", role: .cancel) {}
        } message: {
            Text("Aktifkan kode perangkat atau biometrik sebelum menyalakan kunci TEMPO.")
        }
        .alert("Penghapusan belum selesai", isPresented: $deletionError) {
            Button("Tutup", role: .cancel) {}
        } message: {
            Text("Penyimpanan aman belum dapat dihapus. TEMPO tidak memberi kesan palsu bahwa data sudah hilang.")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: UTType.data,
            defaultFilename: "Tempo-Export.tempo"
        ) { _ in }
        .sheet(isPresented: $showActivityPreference) {
            TempoActivityPreferenceSheet().presentationDetents([.medium, .large])
        }
        .accessibilityIdentifier("tab.settings")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            Text("Pengaturan").font(TempoDesign.Typography.display)
            Text("Privasi, sesi, pengingat, keselamatan, dan data lokal berada di satu tempat.")
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
        }
    }

    private var programContent: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            if let baseline = history.baseline {
                TempoCompactStatusRow(
                    title: "Minggu \(history.programWeek) · \(tempoPhaseName(history.effectiveProgramPhase))",
                    detail: "Tidur baseline \(baseline.sleepHours) jam · kecemasan \(baseline.anxiety)/10",
                    icon: "calendar.badge.clock",
                    tone: .accent
                )
                Text("Baseline adalah titik awal. Daily readiness hari ini tetap memiliki prioritas untuk penyesuaian harian.")
                    .font(TempoDesign.Typography.caption)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
            } else {
                TempoEmptyState(
                    title: "Baseline belum tersedia",
                    message: "Onboarding harus selesai dan tersimpan sebelum program dapat digunakan.",
                    icon: "list.clipboard"
                )
            }
        }
    }

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            Text("TEMPO berjalan lokal tanpa akun, AI, analytics, cloud sync, atau network request untuk menentukan rekomendasi.")
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            Toggle("Terminologi privat", isOn: $discreet)
                .tint(TempoDesign.Palette.accent)
            Toggle("Kunci dengan Face ID / kode perangkat", isOn: biometricBinding)
                .tint(TempoDesign.Palette.accent)
        }
    }

    private var sessionContent: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            Toggle("Haptic feedback", isOn: $haptics)
                .tint(TempoDesign.Palette.accent)
            Text("Haptics digunakan untuk selection, warning, recovery readiness, dan completion. Reduce Motion tetap dihormati oleh komponen UI baru.")
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
        }
    }

    private var reminderContent: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            Toggle("Pengingat dari rencana", isOn: $reminders)
                .tint(TempoDesign.Palette.accent)
                .onChange(of: reminders) { _, enabled in
                    if enabled { syncNotifications() }
                    else { LocalNotifications.removeDailyPlan() }
                }
            Toggle("Suara pengingat", isOn: $notificationSounds)
                .tint(TempoDesign.Palette.accent)
                .disabled(!reminders)
                .onChange(of: notificationSounds) { _, _ in syncNotifications() }
            if reminders {
                Stepper(
                    "Jam pengingat cadangan: \(String(format: "%02d:00", reminderHour))",
                    value: $reminderHour,
                    in: 8...21
                )
                .onChange(of: reminderHour) { _, _ in syncNotifications() }
            }
            Text("Pengingat mengikuti plan terbaru dan menggunakan copy netral.")
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
        }
    }

    private var activityContent: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            TempoCompactStatusRow(
                title: history.activityPreference.legacyDisplayValue,
                detail: "Hanya future plan yang belum disentuh yang dapat disesuaikan.",
                icon: "figure.walk",
                tone: .accent
            )
            TempoSecondaryButton("Ubah preferensi aktivitas", icon: "slider.horizontal.3", tone: .accent) {
                showActivityPreference = true
            }
            .accessibilityIdentifier("profile.activityPreference.open")
        }
    }

    private var safetyContent: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            TempoCompactStatusRow(
                title: history.hasSafetyBlock ? "Safety hold aktif" : "Tidak ada safety hold aktif",
                detail: history.hasSafetyBlock ? "Sesi tetap dijeda sampai pemeriksaan ulang selesai." : "TEMPO tetap bukan alat diagnosis atau layanan darurat.",
                icon: history.hasSafetyBlock ? "exclamationmark.shield.fill" : "checkmark.shield.fill",
                tone: history.hasSafetyBlock ? .caution : .positive
            )
            TempoSecondaryButton("Buka pemeriksaan", icon: "cross.case.fill", tone: history.hasSafetyBlock ? .caution : .accent) {
                coordinator.open(.healthCheck)
            }
            .accessibilityIdentifier("profile.safety.open")
        }
    }

    private var dataContent: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            TempoSecondaryButton("Export data terenkripsi", icon: "square.and.arrow.up", tone: .accent) {
                exportPassword = ""
                showExportPassword = true
            }
            Text("Export menggunakan snapshot data lokal yang sama dengan versi 2.1.3 dan dilindungi password.")
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
        }
    }

    private var resetContent: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            TempoSecondaryButton("Hapus catatan teks", icon: "text.badge.minus", tone: .caution) {
                showNotesDeletion = true
            }
            TempoSecondaryButton("Hapus semua data", icon: "trash", tone: .critical) {
                showDeletion = true
            }
        }
    }

    private var biometricBinding: Binding<Bool> {
        Binding(
            get: { biometricLock },
            set: { enabled in
                if !enabled {
                    biometricLock = false
                    return
                }
                Task {
                    if await PrivacyLock.authenticate() { biometricLock = true }
                    else { biometricError = true }
                }
            }
        )
    }

    private func syncNotifications() {
        guard reminders else { return }
        Task {
            await LocalNotifications.requestAndSyncPlan(
                history.upcomingPlan,
                fallbackHour: reminderHour,
                windowEndHour: history.baseline?.reminderEndHour ?? 21,
                soundEnabled: notificationSounds
            )
        }
    }

    private func createExport() {
        guard let data = history.makeExportData(),
              let encrypted = try? EncryptedExport.encrypt(data, password: exportPassword)
        else {
            exportError = true
            return
        }
        exportDocument = TempoExportDocument(data: encrypted)
        showExporter = true
    }

    private func deleteAll() {
        guard history.deleteAll() else {
            deletionError = true
            return
        }
        LocalNotifications.removeAll()
        TempoOnboardingDraftStore.clear()
        discreet = false
        haptics = true
        biometricLock = false
        notificationSounds = false
        reminders = false
        reminderHour = 19
        onboardingCompleted = false
    }
}

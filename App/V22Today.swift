import SwiftUI

struct TempoV22TodayScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @AppStorage("discreetTerminology") private var discreetTerminology = false

    @State private var showingReadiness = false
    @State private var pendingActivity: LocalPlanDay?

    private var primary: LocalPlanDay? { history.todayPrimaryPlan }
    private var allToday: [LocalPlanDay] {
        history.plannedDays
            .filter { Calendar.current.isDateInToday($0.scheduleDate) }
            .sorted { $0.scheduleDate < $1.scheduleDate }
    }
    private var additionalItems: [LocalPlanDay] {
        guard let primary else { return allToday }
        return allToday.filter { $0.id != primary.id }
    }

    var body: some View {
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xl) {
                header
                if history.hasSafetyBlock { safetyNotice }
                primaryHero
                quickAction
                readiness
                if !additionalItems.isEmpty { additionalAgenda }
                tomorrow
                insight
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingReadiness, onDismiss: { pendingActivity = nil }) {
            TempoCompactReadinessSheet(existing: history.todayReadiness) { sleep, anxiety, energy, symptom in
                saveReadiness(sleep: sleep, anxiety: anxiety, energy: energy, symptom: symptom)
            }
            .presentationDetents([.medium, .large])
        }
        .accessibilityIdentifier("tab.today")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xxs) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(TempoDesign.Typography.supporting)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                Text("Hari Ini")
                    .font(TempoDesign.Typography.display)
                Text("Satu langkah yang realistis sudah cukup.")
                    .font(TempoDesign.Typography.supporting)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
            }
            Spacer()
            TempoStatusBadge("Minggu \(max(1, history.programWeek))", tone: .accent)
        }
    }

    private var safetyNotice: some View {
        TempoCompactStatusRow(
            title: history.hasReadinessSafetyConcern ? "Keluhan hari ini perlu diperiksa" : "Sesi dijeda sementara",
            detail: "Pemeriksaan memiliki prioritas sebelum aktivitas lain.",
            icon: "cross.case.fill",
            tone: .caution,
            actionTitle: "Periksa"
        ) {
            openSafetyRecheck()
        }
        .padding(.horizontal, TempoDesign.Spacing.md)
        .background(TempoDesign.Palette.caution.opacity(0.10), in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
        .accessibilityIdentifier("today.safety.status")
    }

    @ViewBuilder private var primaryHero: some View {
        if let item = primary {
            TempoHeroCard(tint: heroTint(item)) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                            TempoStatusBadge(tempoPlanStatusTitle(item.status), tone: tempoPlanStatusTone(item.status))
                            Text(tempoActivityName(item.effectiveKind))
                                .font(TempoDesign.Typography.pageTitle)
                            Text("\(item.scheduleDate.formatted(date: .omitted, time: .shortened)) · \(item.estimatedMinutes ?? 5) menit")
                                .font(TempoDesign.Typography.supporting)
                                .foregroundStyle(TempoDesign.Palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: tempoActivityIcon(item.effectiveKind))
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(TempoDesign.Palette.accentSoft)
                            .accessibilityHidden(true)
                    }
                    Text(planReason(item))
                        .font(TempoDesign.Typography.supporting)
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                    if item.status.isActionable {
                        TempoPrimaryButton("Mulai", icon: "play.fill", accessibilityHint: "Memulai \(tempoActivityName(item.effectiveKind))") {
                            startPrimary(item)
                        }
                        .accessibilityIdentifier("today.primary.start")
                    } else {
                        TempoCompactStatusRow(
                            title: item.status == .completed ? "Sudah selesai" : "Tidak perlu dikejar lagi",
                            detail: item.status == .completed ? "Rencana hari ini sudah diperbarui dari catatan tersimpan." : nil,
                            icon: item.status == .completed ? "checkmark.circle.fill" : "minus.circle",
                            tone: item.status == .completed ? .positive : .neutral
                        )
                    }
                }
            }
        } else {
            TempoHeroCard(tint: TempoDesign.Palette.positive) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                    Label("Ruang untuk pulih", systemImage: "leaf.fill")
                        .font(TempoDesign.Typography.sectionTitle)
                        .foregroundStyle(TempoDesign.Palette.positive)
                    Text("Tidak ada aktivitas yang perlu dikejar sekarang.")
                        .font(TempoDesign.Typography.pageTitle)
                    Text("Program tetap dapat dilihat tanpa menambah target baru.")
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                    TempoSecondaryButton("Buka Program", icon: "calendar", tone: .accent) {
                        coordinator.selectedTab = .program
                    }
                }
            }
        }
    }

    private var quickAction: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            TempoSectionHeader("Keputusan cepat", detail: "Satu panel, aturan keselamatan yang sama.")
            TempoPrimaryButton(discreetTerminology ? "Mulai sesi privat" : "Aku mau onani sekarang", icon: "hand.raised.fill") {
                coordinator.open(.immediateAction(5))
            }
            .accessibilityIdentifier("today.quick.private")
            TempoSecondaryButton("Aku sedang sangat terangsang", icon: "bolt.heart.fill", tone: .accent) {
                coordinator.open(.immediateAction(9))
            }
            .accessibilityIdentifier("today.quick.high")
        }
    }

    private var readiness: some View {
        TempoCompactStatusRow(
            title: history.todayReadiness == nil ? "Kondisi hari ini belum dikonfirmasi" : readinessTitle,
            detail: history.todayReadiness == nil ? "Diperlukan sebelum aktivitas utama dimulai." : readinessDetail,
            icon: history.todayReadiness == nil ? "sun.max.fill" : "checkmark.circle.fill",
            tone: history.hasReadinessSafetyConcern ? .caution : (history.todayReadiness == nil ? .neutral : .positive),
            actionTitle: history.todayReadiness == nil ? "Isi" : "Ubah"
        ) {
            pendingActivity = nil
            showingReadiness = true
        }
        .padding(.horizontal, TempoDesign.Spacing.sm)
        .accessibilityIdentifier("today.readiness.compact")
    }

    private var additionalAgenda: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            TempoSectionHeader("Agenda tambahan", detail: "Aktivitas utama tidak diulang di sini.", actionTitle: "Program") {
                coordinator.selectedTab = .program
            }
            ForEach(additionalItems) { item in
                TempoNavigationRow(
                    title: tempoActivityName(item.effectiveKind),
                    subtitle: "\(item.scheduleDate.formatted(date: .omitted, time: .shortened)) · \(tempoPlanStatusTitle(item.status))",
                    icon: tempoActivityIcon(item.effectiveKind),
                    tint: tempoPlanStatusTone(item.status).color
                ) {
                    coordinator.open(.plan(item.id), tab: .program)
                }
            }
        }
    }

    private var tomorrow: some View {
        TempoCompactStatusRow(
            title: history.tomorrowPlan.map { tempoActivityName($0.effectiveKind) } ?? "Belum ada aktivitas besok",
            detail: history.tomorrowPlan.map { "Besok · \($0.scheduleDate.formatted(date: .omitted, time: .shortened)) · \($0.estimatedMinutes ?? 5) menit" } ?? "Program akan menampilkan perubahan bila ada.",
            icon: "sunrise.fill",
            tone: .neutral,
            actionTitle: "Lihat"
        ) {
            coordinator.selectedTab = .program
        }
        .padding(.horizontal, TempoDesign.Spacing.sm)
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            Label("Insight hari ini", systemImage: "lightbulb.fill")
                .font(TempoDesign.Typography.cardTitle)
                .foregroundStyle(TempoDesign.Palette.accentSoft)
            Text(history.todayPrescription.insight)
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
        }
        .padding(.vertical, TempoDesign.Spacing.sm)
    }

    private var readinessTitle: String {
        guard let value = history.todayReadiness else { return "Kondisi hari ini" }
        return "Tidur \(value.sleepHoursLastNight.formatted(.number.precision(.fractionLength(0...1)))) jam · energi \(value.energyToday)/10"
    }

    private var readinessDetail: String {
        guard let value = history.todayReadiness else { return "" }
        return value.hasUnresolvedSymptom
            ? "\(value.symptomType.displayName) ditandai · kecemasan \(value.anxietyToday)/10"
            : "Tidak ada keluhan baru · kecemasan \(value.anxietyToday)/10"
    }

    private func heroTint(_ item: LocalPlanDay) -> Color {
        switch item.status {
        case .completed: TempoDesign.Palette.positive
        case .adapted, .recovery: TempoDesign.Palette.caution
        case .planned: TempoDesign.Palette.accent
        case .skipped: TempoDesign.Palette.textTertiary
        }
    }

    private func planReason(_ item: LocalPlanDay) -> String {
        let codes = item.adaptationReasonCodes ?? item.reasonCodes ?? []
        return codes.compactMap(PlanReason.init(rawValue:)).first?.shortExplanation ?? "Langkah ini disusun dari ritme dan pemulihanmu."
    }

    private func startPrimary(_ item: LocalPlanDay) {
        guard history.todayReadiness != nil else {
            pendingActivity = item
            showingReadiness = true
            return
        }
        guard !history.hasSafetyBlock else {
            openSafetyRecheck()
            return
        }
        open(item)
    }

    private func saveReadiness(sleep: Double, anxiety: Int, energy: Int, symptom: DailySymptomType) -> Bool {
        guard history.saveDailyReadiness(
            sleepHoursLastNight: sleep,
            anxietyToday: anxiety,
            energyToday: energy,
            symptomType: symptom
        ) else { return false }

        let shouldOpen = pendingActivity != nil
        pendingActivity = nil
        if symptom.requiresSafetyHold || history.hasSafetyBlock {
            openSafetyRecheck()
        } else if shouldOpen, let updated = history.todayPrimaryPlan, updated.status.isActionable {
            open(updated)
        }
        return true
    }

    private func openSafetyRecheck() {
        if let hold = history.activeSafetyHold,
           RecommendationSeverity(rawValue: hold.severity) == .caution,
           hold.reasonCode.localizedCaseInsensitiveContains("irritation") {
            coordinator.open(.safetyRecoveryBlock(hold.reasonCode, hold.recheckNotBefore), tab: .profile)
        } else {
            coordinator.open(.healthCheck, tab: .profile)
        }
    }

    private func open(_ item: LocalPlanDay) {
        switch item.effectiveKind {
        case .guided: coordinator.open(.guided(item.id))
        case .breathing: coordinator.open(.breathing(item.id, "Napas singkat", (item.estimatedMinutes ?? 5) * 60))
        case .recovery: coordinator.open(.breathing(item.id, "Pemulihan", (item.estimatedMinutes ?? 5) * 60))
        case .cardio: coordinator.open(.cardio(item.id))
        case .strength: coordinator.open(.strength(item.id))
        case .education: coordinator.open(.lesson(item.id, "Kesadaran sebelum intensitas"))
        case .review: coordinator.open(.weeklyReview)
        }
    }
}

struct TempoCompactReadinessSheet: View {
    let existing: DailyReadinessRecord?
    let onSave: (Double, Int, Int, DailySymptomType) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var sleep: Double
    @State private var anxiety: Int
    @State private var energy: Int
    @State private var noSymptoms: Bool
    @State private var symptomType: DailySymptomType
    @State private var editingDetails: Bool
    @State private var saveFailed = false

    init(existing: DailyReadinessRecord?, onSave: @escaping (Double, Int, Int, DailySymptomType) -> Bool) {
        self.existing = existing
        self.onSave = onSave
        _sleep = State(initialValue: existing?.sleepHoursLastNight ?? 7)
        _anxiety = State(initialValue: existing?.anxietyToday ?? 5)
        _energy = State(initialValue: existing?.energyToday ?? 6)
        _noSymptoms = State(initialValue: existing?.hasUnresolvedSymptom != true)
        _symptomType = State(initialValue: existing?.hasUnresolvedSymptom == true ? (existing?.symptomType ?? .mildIrritation) : .mildIrritation)
        _editingDetails = State(initialValue: existing == nil)
    }

    var body: some View {
        NavigationStack {
            TempoScreenContainer {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                        Text("Kondisi hari ini").font(TempoDesign.Typography.pageTitle)
                        Text("Konfirmasi nilai singkat ini sebelum aktivitas utama. Hanya hari ini yang disesuaikan.")
                            .font(TempoDesign.Typography.supporting)
                            .foregroundStyle(TempoDesign.Palette.textSecondary)
                    }
                    summary
                    if editingDetails { details }
                    Toggle("Tidak ada nyeri atau keluhan baru", isOn: $noSymptoms)
                        .tint(TempoDesign.Palette.positive)
                        .accessibilityIdentifier("today.readiness.noSymptoms")
                    if !noSymptoms { symptomChoices }
                }
            }
            .safeAreaInset(edge: .bottom) {
                TempoStickyActionBar {
                    VStack(spacing: TempoDesign.Spacing.xs) {
                        TempoPrimaryButton("Konfirmasi dan mulai", icon: "checkmark") {
                            if onSave(sleep, anxiety, energy, noSymptoms ? .none : symptomType) {
                                dismiss()
                            } else {
                                saveFailed = true
                            }
                        }
                        .accessibilityIdentifier("today.readiness.confirm")
                        Button(editingDetails ? "Sembunyikan detail" : "Ubah nilai") {
                            editingDetails.toggle()
                        }
                        .font(TempoDesign.Typography.supporting.weight(.semibold))
                        .foregroundStyle(TempoDesign.Palette.accentSoft)
                        .frame(minHeight: 40)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Nanti") { dismiss() } }
            }
            .alert("Check-in belum tersimpan", isPresented: $saveFailed) {
                Button("Tutup", role: .cancel) {}
            } message: {
                Text("Aktivitas tidak dibuka sampai catatan lokal berhasil disimpan.")
            }
        }
    }

    private var summary: some View {
        TempoCompactStatusRow(
            title: "Tidur \(sleep.formatted(.number.precision(.fractionLength(0...1)))) jam · energi \(energy)/10",
            detail: "Kecemasan \(anxiety)/10",
            icon: "sun.max.fill",
            tone: .accent
        )
        .padding(.horizontal, TempoDesign.Spacing.md)
        .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
    }

    private var details: some View {
        VStack(spacing: TempoDesign.Spacing.md) {
            compactScale("Tidur tadi malam", value: $sleep, range: 0...12, step: 0.5, suffix: " jam")
            compactIntegerScale("Kecemasan", value: $anxiety)
            compactIntegerScale("Energi", value: $energy)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var symptomChoices: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            Text("Keluhan yang paling sesuai").font(TempoDesign.Typography.cardTitle)
            ForEach([DailySymptomType.mildIrritation, .pain, .urinaryOrDischarge, .bloodOrFever], id: \.self) { type in
                TempoSelectionCard(
                    title: type.displayName,
                    subtitle: nil,
                    icon: type == .mildIrritation ? "leaf.fill" : "cross.case.fill",
                    selected: symptomType == type,
                    tone: type == .mildIrritation ? .caution : .critical
                ) {
                    symptomType = type
                }
            }
        }
    }

    private func compactIntegerScale(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            HStack { Text(title).font(TempoDesign.Typography.cardTitle); Spacer(); Text("\(value.wrappedValue)/10").monospacedDigit() }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: 1...10, step: 1)
                .tint(TempoDesign.Palette.accentSoft)
        }
    }

    private func compactScale(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            HStack { Text(title).font(TempoDesign.Typography.cardTitle); Spacer(); Text("\(value.wrappedValue.formatted(.number.precision(.fractionLength(0...1))))\(suffix)").monospacedDigit() }
            Slider(value: value, in: range, step: step).tint(TempoDesign.Palette.accentSoft)
        }
    }
}

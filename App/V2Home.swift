import Foundation
import SwiftUI

func tempoActivityName(_ kind: ActivityKind) -> String {
    switch kind {
    case .guided: "Sesi terpandu"
    case .breathing: "Napas singkat"
    case .cardio: "Jalan santai"
    case .strength: "Kekuatan ringan"
    case .recovery: "Pemulihan"
    case .education: "Materi singkat"
    case .review: "Tinjauan mingguan"
    }
}

func tempoActivityIcon(_ kind: ActivityKind) -> String {
    switch kind {
    case .guided: "timer"
    case .breathing: "wind"
    case .cardio: "figure.walk"
    case .strength: "figure.strengthtraining.traditional"
    case .recovery: "bed.double.fill"
    case .education: "book.closed"
    case .review: "calendar.badge.checkmark"
    }
}

func tempoPhaseName(_ phase: ProgramPhase) -> String {
    switch phase {
    case .assessmentRequired: "Baseline"
    case .awareness: "Kesadaran"
    case .basicControl: "Kontrol dasar"
    case .stability: "Stabilitas"
    case .transfer: "Transfer"
    case .independence: "Mandiri"
    case .safetyHold: "Pemulihan"
    }
}

func tempoPlanStatusTitle(_ status: LocalPlanStatus) -> String {
    switch status {
    case .planned: "Terjadwal"
    case .completed: "Selesai"
    case .skipped: "Dilewati"
    case .adapted: "Disesuaikan"
    case .recovery: "Pemulihan"
    }
}

func tempoPlanStatusTone(_ status: LocalPlanStatus) -> TempoBadgeTone {
    switch status {
    case .planned: .accent
    case .completed: .positive
    case .skipped: .neutral
    case .adapted, .recovery: .caution
    }
}

struct TempoTodayScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @AppStorage("discreetTerminology") private var discreetTerminology = false
    @State private var showingReadinessCheckIn = false
    @State private var pendingPrimaryActivity: LocalPlanDay?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xl) {
                header.tempoEntrance()
                if history.hasSafetyBlock { safetyStatus.tempoEntrance(delay: 0.03) }
                readinessCard.tempoEntrance(delay: 0.06)
                primaryCard.tempoEntrance(delay: 0.09)
                quickActions.tempoEntrance(delay: 0.12)
                todayTimeline.tempoEntrance(delay: 0.15)
                tomorrowPreview.tempoEntrance(delay: 0.18)
                insightCard.tempoEntrance(delay: 0.21)
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
            .padding(.horizontal, TempoDesign.Spacing.lg)
            .padding(.vertical, TempoDesign.Spacing.lg)
            .padding(.bottom, 112)
        }
        .background(TempoDesign.Palette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingReadinessCheckIn, onDismiss: { pendingPrimaryActivity = nil }) {
            TempoDailyReadinessCheckInSheet(existing: history.todayReadiness) { sleepHours, anxiety, energy, irritationOrPain in
                saveReadiness(
                    sleepHoursLastNight: sleepHours,
                    anxietyToday: anxiety,
                    energyToday: energy,
                    irritationOrPain: irritationOrPain
                )
            }
            .presentationDetents([.medium, .large])
        }
        .accessibilityIdentifier("tab.today")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.xxs) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(TempoDesign.Typography.supporting)
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                    Text("Hari Ini")
                        .font(TempoDesign.Typography.display)
                        .foregroundStyle(TempoDesign.Palette.textPrimary)
                }
                Spacer()
                TempoStatusBadge("Minggu \(max(1, history.programWeek)) · \(tempoPhaseName(history.effectiveProgramPhase))", tone: .accent)
            }
            Text("Satu langkah yang realistis cukup untuk menjaga ritme.")
                .font(.title3)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
        }
    }

    private var safetyStatus: some View {
        HStack(spacing: TempoDesign.Spacing.sm) {
            TempoStatusBadge(
                history.hasReadinessSafetyConcern ? "Nyeri atau iritasi perlu diperiksa" : "Latihan dijeda sementara",
                tone: .caution,
                icon: "cross.case.fill"
            )
            Spacer()
            Button("Periksa") { coordinator.open(.healthCheck, tab: .profile) }
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.caution)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, TempoDesign.Spacing.md)
        .padding(.vertical, TempoDesign.Spacing.sm)
        .background(TempoDesign.Palette.caution.opacity(0.10), in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
    }

    private var readinessCard: some View {
        TempoSurfaceCard(tint: TempoDesign.Palette.accentSoft, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.xxs) {
                        Text("Check-in 20 detik").font(TempoDesign.Typography.cardTitle)
                        if let readiness = history.todayReadiness {
                            Text("Kondisi hari ini · Tidur \(readiness.sleepHoursLastNight.formatted(.number.precision(.fractionLength(0...1)))) jam")
                                .font(TempoDesign.Typography.supporting)
                                .foregroundStyle(TempoDesign.Palette.textSecondary)
                            Text("Kecemasan \(readiness.anxietyToday)/10 · energi \(readiness.energyToday)/10")
                                .font(TempoDesign.Typography.supporting)
                                .foregroundStyle(TempoDesign.Palette.textSecondary)
                        } else {
                            Text("Perbarui kondisi hari ini sebelum memulai aktivitas utama.")
                                .font(TempoDesign.Typography.supporting)
                                .foregroundStyle(TempoDesign.Palette.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: history.todayReadiness == nil ? "sun.max.fill" : "checkmark.circle.fill")
                        .foregroundStyle(TempoDesign.Palette.accentSoft)
                        .accessibilityHidden(true)
                }
                if history.hasReadinessSafetyConcern {
                    TempoStatusBadge("Nyeri atau iritasi ditandai", tone: .caution, icon: "cross.case.fill")
                }
                TempoSecondaryButton(history.todayReadiness == nil ? "Isi check-in" : "Perbarui", icon: "slider.horizontal.3", tone: .accent) {
                    pendingPrimaryActivity = nil
                    showingReadinessCheckIn = true
                }
                .accessibilityIdentifier("today.readiness.open")
            }
        }
    }

    private var primaryCard: some View {
        Group {
            if let item = history.todayPlan {
                TempoSurfaceCard(tint: TempoDesign.Palette.accent, emphasis: .tinted) {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                                TempoStatusBadge(tempoPlanStatusTitle(item.status), tone: tempoPlanStatusTone(item.status))
                                Text(tempoActivityName(item.effectiveKind)).font(TempoDesign.Typography.pageTitle)
                                Text("\(item.scheduleDate.formatted(date: .omitted, time: .shortened)) · \(item.estimatedMinutes ?? 5) menit")
                                    .font(TempoDesign.Typography.supporting).foregroundStyle(TempoDesign.Palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: tempoActivityIcon(item.effectiveKind)).font(.system(size: 28, weight: .semibold)).foregroundStyle(TempoDesign.Palette.accentSoft)
                        }
                        Text(planReason(item))
                            .font(TempoDesign.Typography.supporting)
                            .foregroundStyle(TempoDesign.Palette.textSecondary)
                        if item.status.isActionable {
                            TempoPrimaryButton("Mulai", icon: "play.fill", accessibilityHint: "Memulai \(tempoActivityName(item.effectiveKind))") {
                                openPrimaryActivity(item)
                            }
                            .accessibilityIdentifier("today.primary.start")
                        } else {
                            TempoStatusBadge(item.status == .completed ? "Kamu sudah menyelesaikan langkah ini." : "Langkah ini tidak perlu dikejar lagi.", tone: item.status == .completed ? .positive : .neutral)
                        }
                    }
                }
            } else {
                TempoSurfaceCard {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                        Text("Ruang untuk pulih").font(TempoDesign.Typography.sectionTitle)
                        Text("Tidak ada aktivitas yang perlu dikejar sekarang. Lihat Program bila ingin memeriksa rencana berikutnya.")
                            .foregroundStyle(TempoDesign.Palette.textSecondary)
                        TempoSecondaryButton("Buka Program", icon: "calendar") { coordinator.selectedTab = .program }
                    }
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            TempoSectionHeader("Butuh keputusan cepat?", detail: "Tiga langkah singkat, tanpa formulir panjang.")
            TempoPrimaryButton(discreetTerminology ? "Mulai sesi privat" : "Aku mau onani sekarang", icon: "hand.raised.fill") {
                openImmediateAction(initialIntensity: 5)
            }
            TempoSecondaryButton("Aku sedang sangat terangsang", icon: "bolt.heart.fill", tone: .caution) {
                openImmediateAction(initialIntensity: 8)
            }
        }
    }

    private var todayTimeline: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            TempoSectionHeader("Ritme hari ini", detail: "Rencana lokal, dengan alasan yang dapat dilihat.", actionTitle: "Program") { coordinator.selectedTab = .program }
            let items = history.upcomingPlan.filter { Calendar.current.isDateInToday($0.scheduleDate) }
            if items.isEmpty {
                TempoSurfaceCard { Text("Tidak ada agenda tambahan hari ini.").foregroundStyle(TempoDesign.Palette.textSecondary) }
            } else {
                ForEach(items) { item in
                    Button { coordinator.open(.plan(item.id), tab: .program) } label: {
                        HStack(spacing: TempoDesign.Spacing.sm) {
                            Text(item.scheduleDate.formatted(date: .omitted, time: .shortened)).font(.caption.monospacedDigit()).foregroundStyle(TempoDesign.Palette.textTertiary).frame(width: 52, alignment: .leading)
                            Image(systemName: tempoActivityIcon(item.effectiveKind)).foregroundStyle(TempoDesign.Palette.accentSoft).frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tempoActivityName(item.effectiveKind)).font(TempoDesign.Typography.cardTitle).foregroundStyle(TempoDesign.Palette.textPrimary)
                                Text(planReason(item)).font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(TempoDesign.Palette.textTertiary)
                        }
                        .padding(TempoDesign.Spacing.md)
                        .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
                    }
                    .buttonStyle(TempoTactileButtonStyle())
                }
            }
        }
    }

    private var tomorrowPreview: some View {
        TempoSurfaceCard {
            HStack(spacing: TempoDesign.Spacing.md) {
                Image(systemName: "sunrise.fill").font(.title2).foregroundStyle(TempoDesign.Palette.accentSoft)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Besok").font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textTertiary)
                    if let tomorrow = history.tomorrowPlan {
                        Text(tempoActivityName(tomorrow.effectiveKind)).font(TempoDesign.Typography.cardTitle)
                        Text("\(tomorrow.scheduleDate.formatted(date: .omitted, time: .shortened)) · \(tomorrow.estimatedMinutes ?? 5) menit").font(TempoDesign.Typography.supporting).foregroundStyle(TempoDesign.Palette.textSecondary)
                    } else {
                        Text("Belum ada aktivitas yang perlu disiapkan.").font(TempoDesign.Typography.cardTitle)
                    }
                }
                Spacer()
                Button { coordinator.selectedTab = .program } label: { Image(systemName: "arrow.right") }
                    .foregroundStyle(TempoDesign.Palette.accentSoft).frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private var insightCard: some View {
        TempoSurfaceCard(tint: TempoDesign.Palette.positive, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                Label("Insight privat", systemImage: "lightbulb.fill").font(TempoDesign.Typography.cardTitle).foregroundStyle(TempoDesign.Palette.positive)
                Text(history.todayPrescription.insight).foregroundStyle(TempoDesign.Palette.textPrimary)
            }
        }
    }

    private func planReason(_ item: LocalPlanDay) -> String {
        let codes = item.adaptationReasonCodes ?? item.reasonCodes ?? []
        return codes.compactMap(PlanReason.init(rawValue:)).first?.shortExplanation ?? "Langkah ini disusun dari ritme dan pemulihanmu."
    }

    private func openPrimaryActivity(_ item: LocalPlanDay) {
        guard history.todayReadiness != nil else {
            pendingPrimaryActivity = item
            showingReadinessCheckIn = true
            return
        }
        guard !history.hasSafetyBlock else {
            coordinator.open(.healthCheck, tab: .profile)
            return
        }
        openActivity(item)
    }

    private func openImmediateAction(initialIntensity: Int) {
        coordinator.open(.immediateAction(initialIntensity))
    }

    private func saveReadiness(
        sleepHoursLastNight: Double,
        anxietyToday: Int,
        energyToday: Int,
        irritationOrPain: Bool
    ) -> Bool {
        guard history.saveDailyReadiness(
            sleepHoursLastNight: sleepHoursLastNight,
            anxietyToday: anxietyToday,
            energyToday: energyToday,
            irritationOrPain: irritationOrPain
        ) else { return false }

        let shouldOpenPrimary = pendingPrimaryActivity != nil
        pendingPrimaryActivity = nil
        if irritationOrPain || history.hasSafetyBlock {
            coordinator.open(.healthCheck, tab: .profile)
        } else if shouldOpenPrimary, let updated = history.todayPrimaryPlan, updated.status.isActionable {
            openActivity(updated)
        }
        return true
    }

    private func openActivity(_ item: LocalPlanDay) {
        switch item.effectiveKind {
        case .guided:
            coordinator.open(.guided(item.id))
        case .breathing:
            coordinator.open(.breathing(item.id, "Napas singkat", (item.estimatedMinutes ?? 5) * 60))
        case .recovery:
            coordinator.open(.breathing(item.id, "Pemulihan", (item.estimatedMinutes ?? 5) * 60))
        case .cardio:
            coordinator.open(.cardio(item.id))
        case .strength:
            coordinator.open(.strength(item.id))
        case .education:
            coordinator.open(.lesson(item.id, "Kesadaran sebelum intensitas"))
        case .review:
            coordinator.open(.weeklyReview)
        }
    }
}

/// A deliberately compact, local-only readiness check. It asks only for the
/// inputs that can safely adapt today's plan and never attempts a diagnosis.
struct TempoDailyReadinessCheckInSheet: View {
    let existing: DailyReadinessRecord?
    let onSave: (Double, Int, Int, Bool) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var sleepHours: Double
    @State private var anxiety: Int
    @State private var energy: Int
    @State private var irritationOrPain: Bool
    @State private var saveFailed = false

    init(existing: DailyReadinessRecord?, onSave: @escaping (Double, Int, Int, Bool) -> Bool) {
        self.existing = existing
        self.onSave = onSave
        _sleepHours = State(initialValue: existing?.sleepHoursLastNight ?? 7)
        _anxiety = State(initialValue: existing?.anxietyToday ?? 5)
        _energy = State(initialValue: existing?.energyToday ?? 5)
        _irritationOrPain = State(initialValue: existing?.irritationOrPain ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                        Text("Check-in 20 detik").font(TempoDesign.Typography.pageTitle)
                        Text("Jawaban ini hanya menyesuaikan langkah hari ini. Tidak ada diagnosis, akun, atau data yang dikirim keluar perangkat.")
                            .foregroundStyle(TempoDesign.Palette.textSecondary)
                    }
                    readinessSlider(
                        title: "Kecemasan hari ini",
                        value: $anxiety,
                        suffix: "/10",
                        accessibilityIdentifier: "today.readiness.anxiety"
                    )
                    readinessSlider(
                        title: "Energi hari ini",
                        value: $energy,
                        suffix: "/10",
                        accessibilityIdentifier: "today.readiness.energy"
                    )
                    readinessSleepSlider(
                        title: "Tidur tadi malam",
                        value: $sleepHours,
                        suffix: " jam",
                        accessibilityIdentifier: "today.readiness.sleep"
                    )
                    TempoSurfaceCard(tint: irritationOrPain ? TempoDesign.Palette.caution : TempoDesign.Palette.surface, emphasis: irritationOrPain ? .tinted : .standard) {
                        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                            Toggle("Ada nyeri atau iritasi yang perlu diperiksa", isOn: $irritationOrPain)
                                .tint(TempoDesign.Palette.caution)
                            if irritationOrPain {
                                Text("TEMPO akan menjeda aktivitas dan mengarahkanmu ke pemeriksaan setelah disimpan.")
                                    .font(TempoDesign.Typography.supporting)
                                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                            }
                        }
                    }
                    TempoPrimaryButton("Simpan check-in", icon: "checkmark", accessibilityHint: "Menyimpan kondisi hari ini secara lokal") {
                        if onSave(sleepHours, anxiety, energy, irritationOrPain) {
                            dismiss()
                        } else {
                            saveFailed = true
                        }
                    }
                    .accessibilityIdentifier("today.readiness.save")
                }
                .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
                .padding(TempoDesign.Spacing.lg)
            }
            .background(TempoDesign.Palette.canvas)
            .navigationTitle(existing == nil ? "Kondisi hari ini" : "Perbarui kondisi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nanti") { dismiss() }
                }
            }
            .alert("Check-in belum tersimpan", isPresented: $saveFailed) {
                Button("Tutup", role: .cancel) {}
            } message: {
                Text("TEMPO tidak akan mengubah rencana atau membuka aktivitas sampai catatan lokal tersimpan.")
            }
        }
    }

    private func readinessSlider(
        title: String,
        value: Binding<Int>,
        suffix: String,
        range: ClosedRange<Int> = 1...10,
        accessibilityIdentifier: String
    ) -> some View {
        TempoSurfaceCard {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                HStack {
                    Text(title).font(TempoDesign.Typography.cardTitle)
                    Spacer()
                    Text("\(value.wrappedValue)\(suffix)")
                        .font(TempoDesign.Typography.numeric)
                        .foregroundStyle(TempoDesign.Palette.accentSoft)
                }
                Slider(
                    value: Binding(
                        get: { Double(value.wrappedValue) },
                        set: { value.wrappedValue = Int($0.rounded()) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .tint(TempoDesign.Palette.accent)
                .accessibilityIdentifier(accessibilityIdentifier)
            }
        }
    }

    private func readinessSleepSlider(
        title: String,
        value: Binding<Double>,
        suffix: String,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            HStack {
                Text(title).font(TempoDesign.Typography.cardTitle)
                Spacer()
                Text("\(value.wrappedValue.formatted(.number.precision(.fractionLength(0...1))))\(suffix)")
                    .font(TempoDesign.Typography.supporting)
                    .monospacedDigit()
                    .foregroundStyle(TempoDesign.Palette.accentSoft)
            }
            Slider(value: value, in: 0...12, step: 0.5)
                .tint(TempoDesign.Palette.accent)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}

struct TempoProgramScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private var currentWeekStart: Date { WeeklyPlanGenerator.startOfMonday(for: selectedDay) }
    private var weekDays: [Date] { (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: currentWeekStart) } }
    private var selectedItems: [LocalPlanDay] { history.plannedDays.filter { Calendar.current.isDate($0.scheduleDate, inSameDayAs: selectedDay) }.sorted { $0.scheduleDate < $1.scheduleDate } }
    private var availableWeekStarts: [Date] {
        Array(
            Set(history.plannedDays.map { WeeklyPlanGenerator.startOfMonday(for: $0.scheduleDate) } + [currentWeekStart])
        ).sorted()
    }
    private var previousAvailableWeek: Date? { availableWeekStarts.last { $0 < currentWeekStart } }
    private var nextAvailableWeek: Date? { availableWeekStarts.first { $0 > currentWeekStart } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                header
                weekNavigation
                calendarStrip
                selectedDayPlan
                TempoSecondaryButton("Tinjauan mingguan", icon: "chart.bar", tone: .positive) { coordinator.open(.weeklyReview) }
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
            .padding(.horizontal, TempoDesign.Spacing.lg)
            .padding(.vertical, TempoDesign.Spacing.lg)
            .padding(.bottom, 112)
        }
        .background(TempoDesign.Palette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("tab.program")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            Text("Program").font(TempoDesign.Typography.display)
            Text("Pilih hari untuk melihat waktu, alasan, status, dan penyesuaian rencana.")
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            TempoStatusBadge("\(currentWeekStart.formatted(.dateTime.month(.wide).year())) · Minggu \(max(1, history.programWeek))", tone: .accent)
        }
    }

    /// Navigates only between weeks that already exist in local plan history.
    /// Viewing an older or future week never writes, regenerates, or mutates
    /// the plan; it only changes this screen's selected date.
    private var weekNavigation: some View {
        VStack(spacing: TempoDesign.Spacing.sm) {
            HStack(spacing: TempoDesign.Spacing.sm) {
                Button { selectWeek(previousAvailableWeek) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(TempoTactileButtonStyle())
                .foregroundStyle(previousAvailableWeek == nil ? TempoDesign.Palette.textTertiary : TempoDesign.Palette.accentSoft)
                .disabled(previousAvailableWeek == nil)
                .accessibilityLabel("Minggu sebelumnya")
                .accessibilityIdentifier("program.week.previous")

                Text(weekRangeTitle)
                    .font(TempoDesign.Typography.cardTitle)
                    .foregroundStyle(TempoDesign.Palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("program.week.range")

                Button { selectWeek(nextAvailableWeek) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(TempoTactileButtonStyle())
                .foregroundStyle(nextAvailableWeek == nil ? TempoDesign.Palette.textTertiary : TempoDesign.Palette.accentSoft)
                .disabled(nextAvailableWeek == nil)
                .accessibilityLabel("Minggu berikutnya")
                .accessibilityIdentifier("program.week.next")
            }
            Button("Hari Ini") { selectedDay = Calendar.current.startOfDay(for: .now) }
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.accentSoft)
                .frame(minHeight: 38)
                .accessibilityIdentifier("program.week.today")
        }
        .padding(TempoDesign.Spacing.sm)
        .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
    }

    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TempoDesign.Spacing.xs) {
                ForEach(weekDays, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDay)
                    Button { selectedDay = date } label: {
                        VStack(spacing: 5) {
                            Text(date.formatted(.dateTime.weekday(.narrow))).font(TempoDesign.Typography.caption)
                            Text(date.formatted(.dateTime.day())).font(TempoDesign.Typography.cardTitle)
                            Circle().fill(hasItem(on: date) ? TempoDesign.Palette.accentSoft : .clear).frame(width: 5, height: 5)
                        }
                        .foregroundStyle(isSelected ? Color.white : TempoDesign.Palette.textSecondary)
                        .frame(width: 52, height: 68)
                        .background(isSelected ? TempoDesign.Palette.accent : TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
                    }
                    .buttonStyle(TempoTactileButtonStyle())
                    .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                }
            }
        }
    }

    private var selectedDayPlan: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            TempoSectionHeader(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)), detail: selectedItems.isEmpty ? "Tidak ada rencana tersimpan untuk tanggal ini." : "Ketuk aktivitas untuk rincian dan pilihan aman.")
            if selectedItems.isEmpty {
                TempoSurfaceCard { Text("Tanggal ini dibiarkan longgar. Kamu tidak perlu menambah target sendiri.").foregroundStyle(TempoDesign.Palette.textSecondary) }
            }
            ForEach(selectedItems) { item in
                TempoNavigationRow(
                    title: tempoActivityName(item.effectiveKind),
                    subtitle: "\(item.scheduleDate.formatted(date: .omitted, time: .shortened)) · \(item.estimatedMinutes ?? 5) menit · \(tempoPlanStatusTitle(item.status))",
                    icon: tempoActivityIcon(item.effectiveKind),
                    tint: tempoPlanStatusTone(item.status).color
                ) { coordinator.open(.plan(item.id)) }
            }
        }
    }

    private func hasItem(on date: Date) -> Bool { history.plannedDays.contains { Calendar.current.isDate($0.scheduleDate, inSameDayAs: date) } }

    private var weekRangeTitle: String {
        guard let end = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStart) else {
            return currentWeekStart.formatted(.dateTime.day().month(.abbreviated).year())
        }
        let formatter = DateIntervalFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: currentWeekStart, to: end)
    }

    private func selectWeek(_ weekStart: Date?) {
        guard let weekStart else { return }
        let offset = Calendar.current.dateComponents([.day], from: currentWeekStart, to: selectedDay).day ?? 0
        selectedDay = Calendar.current.date(byAdding: .day, value: min(6, max(0, offset)), to: weekStart) ?? weekStart
    }
}

struct TempoPlanDetailScreen: View {
    let planID: UUID
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var actionFailed = false

    private var item: LocalPlanDay? { history.plannedDays.first { $0.id == planID } }

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                        Image(systemName: tempoActivityIcon(item.effectiveKind)).font(.system(size: 38, weight: .semibold)).foregroundStyle(TempoDesign.Palette.accentSoft)
                        Text(tempoActivityName(item.effectiveKind)).font(TempoDesign.Typography.pageTitle)
                        TempoStatusBadge(tempoPlanStatusTitle(item.status), tone: tempoPlanStatusTone(item.status))
                        TempoSurfaceCard {
                            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                                detailRow("Waktu", item.scheduleDate.formatted(date: .abbreviated, time: .shortened))
                                detailRow("Durasi", "\(item.estimatedMinutes ?? 5) menit")
                                detailRow("Fase", tempoPhaseName(item.phase))
                                if let original = item.originalKind { detailRow("Rencana awal", tempoActivityName(original)) }
                            }
                        }
                        TempoSurfaceCard(tint: TempoDesign.Palette.accentSoft, emphasis: .tinted) {
                            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                                Text("Mengapa ini ada di rencana?").font(TempoDesign.Typography.cardTitle)
                                ForEach(reasonTexts(item), id: \.self) { Text("• \($0)").foregroundStyle(TempoDesign.Palette.textSecondary) }
                            }
                        }
                        if item.status.isActionable {
                            if Calendar.current.isDateInToday(item.scheduleDate) {
                                TempoPrimaryButton("Mulai aktivitas", icon: "play.fill") { open(item) }
                            } else if item.scheduleDate > .now {
                                TempoStatusBadge("Aktivitas tersedia pada tanggalnya.", tone: .neutral, icon: "calendar")
                            }
                            TempoSecondaryButton("Saya tidak tersedia", icon: "calendar.badge.exclamationmark", tone: .caution) {
                                if history.markPlanUnavailable(id: item.id) { dismiss() } else { actionFailed = true }
                            }
                            TempoSecondaryButton("Tunda dengan aman", icon: "arrow.right.circle", tone: .accent) {
                                if history.postponePlan(id: item.id) { dismiss() } else { actionFailed = true }
                            }
                        }
                    }
                    .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
                    .padding(TempoDesign.Spacing.lg)
                }
                .background(TempoDesign.Palette.canvas)
                .navigationTitle("Rincian")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("Rencana tidak ditemukan", systemImage: "calendar.badge.exclamationmark", description: Text("Data rencana mungkin telah disesuaikan. Kembali ke Program untuk melihat versi terbaru."))
            }
        }
        .alert("Rencana belum dapat diubah", isPresented: $actionFailed) { Button("Tutup", role: .cancel) {} } message: { Text("TEMPO tidak mengubah catatan historis atau jadwal tanpa penyimpanan lokal yang berhasil.") }
    }

    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) { Text(key).foregroundStyle(TempoDesign.Palette.textSecondary); Spacer(); Text(value).multilineTextAlignment(.trailing) }
    }

    private func reasonTexts(_ item: LocalPlanDay) -> [String] {
        let reasons = (item.adaptationReasonCodes ?? item.reasonCodes ?? []).compactMap(PlanReason.init(rawValue:)).map(\.shortExplanation)
        return reasons.isEmpty ? ["Rencana ini dibuat dari fase, pemulihan, dan konteks baseline."] : reasons
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

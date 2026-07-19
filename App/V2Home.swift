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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xl) {
                header.tempoEntrance()
                if history.hasSafetyBlock { safetyCard.tempoEntrance(delay: 0.03) }
                primaryCard.tempoEntrance(delay: 0.06)
                quickActions.tempoEntrance(delay: 0.09)
                todayTimeline.tempoEntrance(delay: 0.12)
                tomorrowPreview.tempoEntrance(delay: 0.15)
                insightCard.tempoEntrance(delay: 0.18)
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
            .padding(.horizontal, TempoDesign.Spacing.lg)
            .padding(.vertical, TempoDesign.Spacing.lg)
            .padding(.bottom, 112)
        }
        .background(TempoDesign.Palette.canvas)
        .toolbar(.hidden, for: .navigationBar)
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

    private var safetyCard: some View {
        TempoSurfaceCard(tint: TempoDesign.Palette.caution, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                TempoStatusBadge("Latihan dijeda", tone: .caution, icon: "cross.case.fill")
                Text("Fokus hari ini adalah pemulihan dan pemeriksaan ulang, bukan mengejar sesi.")
                    .font(TempoDesign.Typography.cardTitle)
                    .foregroundStyle(TempoDesign.Palette.textPrimary)
                TempoSecondaryButton("Lihat pemeriksaan", icon: "arrow.right", tone: .caution) {
                    coordinator.open(.healthCheck, tab: .profile)
                }
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
                                openActivity(item)
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
                coordinator.open(.immediateAction)
            }
            TempoSecondaryButton("Aku sedang sangat terangsang", icon: "bolt.heart.fill", tone: .caution) {
                coordinator.open(.immediateAction)
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

struct TempoProgramScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private var currentWeekStart: Date { WeeklyPlanGenerator.startOfMonday(for: selectedDay) }
    private var weekDays: [Date] { (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: currentWeekStart) } }
    private var selectedItems: [LocalPlanDay] { history.upcomingPlan.filter { Calendar.current.isDate($0.scheduleDate, inSameDayAs: selectedDay) } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                header
                calendarStrip
                selectedDayPlan
                nextWeekPreview
                TempoSecondaryButton("Tinjauan mingguan", icon: "chart.bar", tone: .positive) { coordinator.open(.weeklyReview) }
            }
            .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
            .padding(.horizontal, TempoDesign.Spacing.lg)
            .padding(.vertical, TempoDesign.Spacing.lg)
            .padding(.bottom, 112)
        }
        .background(TempoDesign.Palette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { selectedDay = Calendar.current.startOfDay(for: .now) }
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
                        .frame(width: 52, minHeight: 68)
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
            TempoSectionHeader(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)), detail: selectedItems.isEmpty ? "Tidak ada rencana tersimpan untuk hari ini." : "Ketuk aktivitas untuk rincian dan pilihan aman.")
            if selectedItems.isEmpty {
                TempoSurfaceCard { Text("Hari ini dibiarkan longgar. Kamu tidak perlu menambah target sendiri.").foregroundStyle(TempoDesign.Palette.textSecondary) }
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

    private var nextWeekPreview: some View {
        let nextMonday = Calendar.current.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
        let items = history.upcomingPlan.filter { Calendar.current.isDate($0.scheduleDate, inSameDayAs: nextMonday) }
        return TempoSurfaceCard(tint: TempoDesign.Palette.accentSoft, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                Text("Senin berikutnya").font(TempoDesign.Typography.cardTitle)
                if let first = items.first {
                    Text("\(tempoActivityName(first.effectiveKind)) · \(first.scheduleDate.formatted(date: .omitted, time: .shortened))").foregroundStyle(TempoDesign.Palette.textSecondary)
                } else {
                    Text("Rencana berikutnya akan muncul setelah minggu ini tersimpan.").foregroundStyle(TempoDesign.Palette.textSecondary)
                }
                Button("Lihat minggu berikutnya") { selectedDay = nextMonday }
                    .foregroundStyle(TempoDesign.Palette.accentSoft).frame(minHeight: 44)
            }
        }
    }

    private func hasItem(on date: Date) -> Bool { history.upcomingPlan.contains { Calendar.current.isDate($0.scheduleDate, inSameDayAs: date) } }
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
                            TempoPrimaryButton("Mulai aktivitas", icon: "play.fill") { open(item) }
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

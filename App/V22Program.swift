import SwiftUI

struct TempoV22ProgramScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private var currentWeekStart: Date { WeeklyPlanGenerator.startOfMonday(for: selectedDay) }
    private var displayedProgramWeek: Int { history.displayedProgramWeek(for: currentWeekStart) }
    private var weekDays: [Date] { (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: currentWeekStart) } }
    private var weekItems: [LocalPlanDay] {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
        return history.plannedDays.filter { $0.scheduleDate >= currentWeekStart && $0.scheduleDate < end }
    }
    private var selectedItems: [LocalPlanDay] {
        history.plannedDays
            .filter { Calendar.current.isDate($0.scheduleDate, inSameDayAs: selectedDay) }
            .sorted { $0.scheduleDate < $1.scheduleDate }
    }

    private var availableWeekStarts: [Date] {
        let calendar = Calendar.current
        let plannedWeeks = history.plannedDays.map { WeeklyPlanGenerator.startOfMonday(for: $0.scheduleDate) }
        guard let completedAt = history.baseline?.completedAt else {
            return Array(Set(plannedWeeks + [currentWeekStart])).sorted()
        }
        let firstWeek = WeeklyPlanGenerator.startOfMonday(for: completedAt)
        let maximumWeek = calendar.date(byAdding: .day, value: 11 * 7, to: firstWeek) ?? firstWeek
        let currentProgramWeek = WeeklyPlanGenerator.startOfMonday(for: .now)
        let latestKnownWeek = min(maximumWeek, max(currentProgramWeek, plannedWeeks.max() ?? firstWeek))
        var programWeeks: [Date] = []
        var cursor = firstWeek
        while cursor <= latestKnownWeek {
            programWeeks.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return Array(Set(programWeeks + plannedWeeks.filter { $0 <= maximumWeek } + [currentWeekStart])).sorted()
    }

    private var previousWeek: Date? { availableWeekStarts.last { $0 < currentWeekStart } }
    private var nextWeek: Date? { availableWeekStarts.first { $0 > currentWeekStart } }

    var body: some View {
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                header
                weekNavigation
                weeklySummary
                calendar
                dayPlan
                TempoSecondaryButton("Tinjauan mingguan", icon: "chart.bar", tone: .positive) {
                    coordinator.open(.weeklyReview)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("tab.program")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            Text("Program").font(TempoDesign.Typography.display)
            Text("Lihat ritme, status, dan penyesuaian tanpa mengubah rencana hanya karena membuka tanggal.")
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            TempoStatusBadge("\(currentWeekStart.formatted(.dateTime.month(.wide).year())) · Minggu \(displayedProgramWeek)", tone: .accent)
                .accessibilityIdentifier("program.week.badge")
                .accessibilityValue("Minggu \(displayedProgramWeek)")
        }
    }

    private var weekNavigation: some View {
        HStack(spacing: TempoDesign.Spacing.sm) {
            weekButton(icon: "chevron.left", label: "Minggu sebelumnya", date: previousWeek)
            VStack(spacing: 2) {
                Text(weekRangeTitle).font(TempoDesign.Typography.cardTitle)
                Button("Hari Ini") { selectedDay = Calendar.current.startOfDay(for: .now) }
                    .font(TempoDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(TempoDesign.Palette.accentSoft)
                    .frame(minHeight: 34)
                    .accessibilityIdentifier("program.week.today")
            }
            .frame(maxWidth: .infinity)
            weekButton(icon: "chevron.right", label: "Minggu berikutnya", date: nextWeek)
        }
        .padding(TempoDesign.Spacing.sm)
        .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
    }

    private func weekButton(icon: String, label: String, date: Date?) -> some View {
        Button {
            guard let date else { return }
            selectWeek(date)
        } label: {
            Image(systemName: icon).frame(width: 44, height: 44)
        }
        .buttonStyle(TempoTactileButtonStyle())
        .foregroundStyle(date == nil ? TempoDesign.Palette.textTertiary : TempoDesign.Palette.accentSoft)
        .disabled(date == nil)
        .accessibilityLabel(label)
        .accessibilityIdentifier(icon == "chevron.left" ? "program.week.previous" : "program.week.next")
    }

    private var weeklySummary: some View {
        let summary = calculateWeeklySummary()
        return TempoCompactStatusRow(
            title: summary.title,
            detail: summary.detail,
            icon: summary.completed == summary.required && summary.required > 0 ? "checkmark.circle.fill" : "calendar.badge.clock",
            tone: summary.completed == summary.required && summary.required > 0 ? .positive : .accent
        )
        .padding(.horizontal, TempoDesign.Spacing.md)
        .background(TempoDesign.Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
        .accessibilityIdentifier("program.week.summary")
    }

    private var calendar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TempoDesign.Spacing.xs) {
                ForEach(Array(weekDays.enumerated()), id: \.element) { index, date in
                    let items = weekItems.filter { Calendar.current.isDate($0.scheduleDate, inSameDayAs: date) }
                    TempoCalendarDayCell(
                        date: date,
                        state: TempoCalendarVisualResolver.state(for: items),
                        selected: Calendar.current.isDate(date, inSameDayAs: selectedDay),
                        isToday: Calendar.current.isDateInToday(date)
                    ) {
                        selectedDay = date
                    }
                    .accessibilityIdentifier("program.day.\(index)")
                }
            }
        }
    }

    private var dayPlan: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            TempoSectionHeader(
                selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                detail: selectedItems.isEmpty ? "Tanggal ini dibiarkan longgar." : "Ketuk aktivitas untuk rincian dan pilihan."
            )
            if selectedItems.isEmpty {
                TempoEmptyState(
                    title: "Tidak ada rencana",
                    message: "Kamu tidak perlu menambah target sendiri untuk mengisi tanggal ini.",
                    icon: "calendar"
                )
            } else {
                ForEach(selectedItems) { item in
                    TempoNavigationRow(
                        title: tempoActivityName(item.effectiveKind),
                        subtitle: "\(item.scheduleDate.formatted(date: .omitted, time: .shortened)) · \(item.estimatedMinutes ?? 5) menit · \(tempoPlanStatusTitle(item.status))",
                        icon: TempoCalendarVisualResolver.state(for: [item]).symbol,
                        tint: TempoCalendarVisualResolver.state(for: [item]).tone.color
                    ) {
                        coordinator.open(.plan(item.id))
                    }
                    .accessibilityIdentifier(planAccessibilityIdentifier(item))
                }
            }
        }
    }

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

    private func selectWeek(_ start: Date) {
        let offset = Calendar.current.dateComponents([.day], from: currentWeekStart, to: selectedDay).day ?? 0
        selectedDay = Calendar.current.date(byAdding: .day, value: min(6, max(0, offset)), to: start) ?? start
    }

    private func calculateWeeklySummary() -> (title: String, detail: String, completed: Int, required: Int) {
        let engine = ProgressEngine()
        let items = weekItems.map(ProgramPlanItem.init(localDay:))
        let requiredItems = items.filter { engine.consistencyEligibility(for: $0, through: .now) == .required }
        let completed = requiredItems.filter { $0.status == .completed }.count
        if requiredItems.isEmpty {
            let upcoming = items.filter { $0.scheduledAt > .now && $0.status.isActionable }.count
            return (
                upcoming == 0 ? "Belum ada aktivitas yang perlu dihitung" : "\(upcoming) aktivitas mendatang",
                "Aktivitas yang belum jatuh tempo tidak memengaruhi konsistensi.",
                0,
                0
            )
        }
        return (
            "\(completed) dari \(requiredItems.count) aktivitas selesai",
            "Pemulihan yang dikecualikan karena safety atau kondisi harian tidak dihitung sebagai gagal.",
            completed,
            requiredItems.count
        )
    }

    private func planAccessibilityIdentifier(_ item: LocalPlanDay) -> String {
        if item.rescheduledFromID != nil { return "program.plan.replacement" }
        if item.status == .skipped,
           let reasons = item.adaptationReasonCodes,
           reasons.contains(PlanReason.postponed.rawValue) || reasons.contains(PlanReason.safeReschedule.rawValue) {
            return "program.plan.postponedSource"
        }
        return "program.plan.actionable"
    }
}

struct TempoV22PlanDetailScreen: View {
    let planID: UUID
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var confirmation: Confirmation?
    @State private var error: TempoUserFacingError?
    @State private var successMessage: String?

    private enum Confirmation: String, Identifiable {
        case recovery
        case move
        var id: String { rawValue }
    }

    private var item: LocalPlanDay? { history.plannedDays.first { $0.id == planID } }

    var body: some View {
        TempoScreenContainer {
            if let item {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                    header(item)
                    details(item)
                    reasons(item)
                    actions(item)
                }
            } else {
                TempoEmptyState(
                    title: "Rencana tidak ditemukan",
                    message: "Data mungkin telah disesuaikan. Kembali ke Program untuk melihat versi terbaru.",
                    icon: "calendar.badge.exclamationmark"
                )
            }
        }
        .navigationTitle("Rincian")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            confirmation == .recovery ? "Ganti aktivitas dengan pemulihan?" : "Pindahkan ke hari lain?",
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
            titleVisibility: .visible
        ) {
            if confirmation == .recovery {
                Button("Ganti dengan pemulihan") { replaceWithRecovery() }
            } else if confirmation == .move {
                Button("Cari satu slot aman") { moveToAnotherDay() }
            }
            Button("Batal", role: .cancel) { confirmation = nil }
        } message: {
            Text(confirmation == .recovery ? "Aktivitas tidak dipindahkan. TEMPO menyimpan penyesuaian dan memperbarui pengingat." : "TEMPO memakai constraint scheduler yang sama dengan auto-reschedule dan tidak membuat rantai replacement.")
        }
        .alert(item: $error) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("Tutup"))
            )
        }
        .overlay(alignment: .top) {
            if let successMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .font(TempoDesign.Typography.supporting.weight(.semibold))
                    .foregroundStyle(TempoDesign.Palette.positive)
                    .padding(.horizontal, TempoDesign.Spacing.md)
                    .padding(.vertical, TempoDesign.Spacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, TempoDesign.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("plan.detail.success")
            }
        }
    }

    private func header(_ item: LocalPlanDay) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                Image(systemName: tempoActivityIcon(item.effectiveKind))
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(TempoDesign.Palette.accentSoft)
                Text(tempoActivityName(item.effectiveKind)).font(TempoDesign.Typography.pageTitle)
                HStack {
                    TempoStatusBadge(tempoPlanStatusTitle(item.status), tone: tempoPlanStatusTone(item.status))
                    if item.rescheduledFromID != nil {
                        TempoStatusBadge("Pengganti", tone: .accent, icon: "arrow.triangle.swap")
                    }
                }
            }
            Spacer()
        }
    }

    private func details(_ item: LocalPlanDay) -> some View {
        VStack(spacing: TempoDesign.Spacing.sm) {
            detailRow("Waktu", item.scheduleDate.formatted(date: .abbreviated, time: .shortened))
            detailRow("Durasi", "\(item.estimatedMinutes ?? 5) menit")
            detailRow("Fase", tempoPhaseName(item.phase))
            if let original = item.originalKind { detailRow("Rencana awal", tempoActivityName(original)) }
        }
        .padding(.vertical, TempoDesign.Spacing.sm)
        .overlay(alignment: .bottom) { Divider().overlay(TempoDesign.Palette.hairline) }
    }

    private func reasons(_ item: LocalPlanDay) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            Text("Mengapa ini ada di rencana?").font(TempoDesign.Typography.sectionTitle)
            ForEach(reasonTexts(item), id: \.self) { reason in
                Label(reason, systemImage: "circle.fill")
                    .font(TempoDesign.Typography.supporting)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
            }
        }
    }

    @ViewBuilder private func actions(_ item: LocalPlanDay) -> some View {
        if item.status.isActionable {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                if Calendar.current.isDateInToday(item.scheduleDate) {
                    TempoPrimaryButton("Mulai aktivitas", icon: "play.fill") { open(item) }
                } else if item.scheduleDate > .now {
                    TempoCompactStatusRow(
                        title: "Aktivitas tersedia pada tanggalnya",
                        detail: item.scheduleDate.formatted(date: .long, time: .shortened),
                        icon: "calendar",
                        tone: .neutral
                    )
                }

                actionChoice(
                    title: "Ganti dengan pemulihan",
                    detail: "Aktivitas ini tidak dipindahkan.",
                    icon: "leaf.fill",
                    tone: .caution
                ) {
                    confirmation = .recovery
                }
                .accessibilityIdentifier("plan.detail.recovery")

                if item.rescheduledFromID == nil {
                    actionChoice(
                        title: "Pindahkan ke hari lain",
                        detail: "TEMPO mencari satu slot aman.",
                        icon: "arrow.right.circle",
                        tone: .accent
                    ) {
                        confirmation = .move
                    }
                    .accessibilityIdentifier("plan.detail.postpone")
                } else {
                    TempoCompactStatusRow(
                        title: "Aktivitas ini sudah pernah dipindahkan",
                        detail: "Replacement tidak dapat membuat replacement berikutnya.",
                        icon: "checkmark.circle.fill",
                        tone: .neutral
                    )
                    .accessibilityIdentifier("plan.detail.alreadyRescheduled")
                }
            }
        }
    }

    private func actionChoice(title: String, detail: String, icon: String, tone: TempoBadgeTone, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: TempoDesign.Spacing.sm) {
                Image(systemName: icon).foregroundStyle(tone.color).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(TempoDesign.Typography.cardTitle)
                    Text(detail).font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(TempoDesign.Palette.textTertiary)
            }
            .padding(TempoDesign.Spacing.md)
            .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
        }
        .buttonStyle(TempoTactileButtonStyle())
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(TempoDesign.Palette.textSecondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private func reasonTexts(_ item: LocalPlanDay) -> [String] {
        let reasons = (item.adaptationReasonCodes ?? item.reasonCodes ?? [])
            .compactMap(PlanReason.init(rawValue:))
            .map(\.shortExplanation)
        return reasons.isEmpty ? ["Rencana ini dibuat dari fase, pemulihan, dan konteks baseline."] : reasons
    }

    private func replaceWithRecovery() {
        confirmation = nil
        guard history.markPlanUnavailable(id: planID) else {
            error = TempoUserFacingError(
                id: "plan-recovery-failed",
                title: "Rencana belum dapat diubah",
                message: "Penyimpanan lokal gagal, sehingga aktivitas lama tetap dipertahankan."
            )
            return
        }
        showSuccess("Aktivitas diganti dengan pemulihan")
    }

    private func moveToAnotherDay() {
        confirmation = nil
        guard history.postponePlan(id: planID) else {
            error = TempoUserFacingError(
                id: "plan-move-failed",
                title: "Belum ada slot aman",
                message: "TEMPO tidak memindahkan aktivitas karena constraint jadwal atau penyimpanan belum terpenuhi."
            )
            return
        }
        guard let replacement = history.plannedDays.first(where: { $0.rescheduledFromID == planID }) else {
            showSuccess("Aktivitas dipindahkan")
            return
        }
        showSuccess("Slot aman ditemukan")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            if !coordinator.path.isEmpty { coordinator.path.removeLast() }
            coordinator.open(.plan(replacement.id))
        }
    }

    private func showSuccess(_ message: String) {
        withAnimation(.snappy(duration: TempoDesign.Motion.quick)) { successMessage = message }
        TempoFeedback.notification(.success)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy(duration: TempoDesign.Motion.quick)) { successMessage = nil }
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

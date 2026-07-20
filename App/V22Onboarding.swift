import Foundation
import SwiftUI

enum TempoMovementFrequency: String, Codable, CaseIterable, Identifiable {
    case rarely
    case onceOrTwice
    case threeOrFour
    case almostDaily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rarely: "Jarang bergerak"
        case .onceOrTwice: "1–2 kali per minggu"
        case .threeOrFour: "3–4 kali per minggu"
        case .almostDaily: "Hampir setiap hari"
        }
    }

    var weeklyMinutes: Int {
        switch self {
        case .rarely: 0
        case .onceOrTwice: 60
        case .threeOrFour: 150
        case .almostDaily: 240
        }
    }

    init(weeklyMinutes: Int) {
        switch weeklyMinutes {
        case ..<30: self = .rarely
        case 30..<120: self = .onceOrTwice
        case 120..<210: self = .threeOrFour
        default: self = .almostDaily
        }
    }
}

struct TempoOnboardingDraft: Codable, Equatable {
    var step = 0
    var adultConfirmed = false
    var discreetTerminology = false
    var onset = "Sudah cukup lama"
    var context = "Keduanya"
    var control = 5
    var anxiety = 5
    var sleepHours = 7
    var movementFrequency: TempoMovementFrequency = .onceOrTwice
    var canWalk = true
    var exerciseRestricted = false
    var activityPreference: ActivityPreference = .noPreference
    var safeSpace = true
    var rushedHabit = false
    var highStimulus = false
    var severeOrPelvicPain = false
    var bloodOrFever = false
    var urinaryOrDischarge = false
    var acuteInjury = false
    var mildIrritation = false
    var remindersEnabled = false
    var reminderHour = 19
    var reminderEndHour = 21

    var safetyAnswers: SafetyScreeningAnswers {
        SafetyScreeningAnswers(
            severeOrPelvicPain: severeOrPelvicPain,
            bloodOrFever: bloodOrFever,
            urinaryOrDischarge: urinaryOrDischarge,
            acuteInjury: acuteInjury,
            mildIrritation: mildIrritation
        )
    }

    mutating func apply(_ answers: SafetyScreeningAnswers) {
        severeOrPelvicPain = answers.severeOrPelvicPain
        bloodOrFever = answers.bloodOrFever
        urinaryOrDischarge = answers.urinaryOrDischarge
        acuteInjury = answers.acuteInjury
        mildIrritation = answers.mildIrritation
    }
}

extension SafetyScreeningAnswers {
    init(
        severeOrPelvicPain: Bool,
        bloodOrFever: Bool,
        urinaryOrDischarge: Bool,
        acuteInjury: Bool,
        mildIrritation: Bool
    ) {
        self.severeOrPelvicPain = severeOrPelvicPain
        self.bloodOrFever = bloodOrFever
        self.urinaryOrDischarge = urinaryOrDischarge
        self.acuteInjury = acuteInjury
        self.mildIrritation = mildIrritation
    }
}

enum TempoOnboardingDraftStore {
    private static let key = "tempo.onboarding-draft.v2.2"

    static func load(defaults: UserDefaults = .standard) -> TempoOnboardingDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TempoOnboardingDraft.self, from: data)
    }

    @discardableResult
    static func save(_ draft: TempoOnboardingDraft, defaults: UserDefaults = .standard) -> Bool {
        guard let data = try? JSONEncoder().encode(draft) else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// Seven-step onboarding backed by a durable local draft. It uses the real
/// baseline model and `WeeklyPlanGenerator`, so the final preview is never mock.
struct TempoV22Onboarding: View {
    @Environment(LocalHistory.self) private var history
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("discreetTerminology") private var discreetTerminology = false
    @AppStorage("dailyPlanRemindersEnabled") private var remindersEnabled = false
    @AppStorage("dailyPlanReminderHour") private var reminderHour = 19

    @State private var draft = TempoOnboardingDraftStore.load() ?? TempoOnboardingDraft()
    @State private var saving = false
    @State private var saveFailed = false

    private let totalSteps = 7

    var body: some View {
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xl) {
                progress
                stepContent
            }
        }
        .safeAreaInset(edge: .bottom) {
            TempoStickyActionBar { controls }
        }
        .onAppear { restoreAppStorageFromDraft() }
        .onChange(of: draft) { _, value in
            _ = TempoOnboardingDraftStore.save(value)
            discreetTerminology = value.discreetTerminology
            remindersEnabled = value.remindersEnabled
            reminderHour = value.reminderHour
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { _ = TempoOnboardingDraftStore.save(draft) }
        }
        .alert("Baseline belum tersimpan", isPresented: $saveFailed) {
            Button("Coba lagi") { finish() }
            Button("Tetap di sini", role: .cancel) {}
        } message: {
            Text("TEMPO tetap menyimpan draft onboarding dan tidak masuk ke Hari Ini sampai baseline lokal berhasil disimpan.")
        }
        .accessibilityIdentifier("onboarding.v22")
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            HStack {
                Text("TEMPO")
                    .font(TempoDesign.Typography.overline)
                    .tracking(1.5)
                    .foregroundStyle(TempoDesign.Palette.accentSoft)
                Spacer()
                Text("\(draft.step + 1) / \(totalSteps)")
                    .font(TempoDesign.Typography.caption)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
            }
            ProgressView(value: Double(draft.step + 1), total: Double(totalSteps))
                .tint(TempoDesign.Palette.accent)
                .accessibilityLabel("Kemajuan onboarding")
        }
    }

    @ViewBuilder private var stepContent: some View {
        switch draft.step {
        case 0: introduction
        case 1: goalAndControl
        case 2: baselineCondition
        case 3: realisticActivity
        case 4: habitContext
        case 5: safetyAndReminder
        case 6: preview
        default: EmptyView()
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(TempoDesign.Palette.accentSoft)
            Text("Ritme yang lebih tenang, tetap privat.")
                .font(TempoDesign.Typography.display)
            Text("TEMPO membantu membangun jeda, pemulihan, dan kebiasaan gerak. Semua keputusan dan catatan tetap di iPhone ini.")
                .font(.title3)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            TempoSurfaceCard(tint: TempoDesign.Palette.accentSoft, emphasis: .tinted) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    Button { draft.adultConfirmed.toggle() } label: {
                        HStack(spacing: TempoDesign.Spacing.sm) {
                            Image(systemName: draft.adultConfirmed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(draft.adultConfirmed ? TempoDesign.Palette.accentSoft : TempoDesign.Palette.textSecondary)
                            Text("Saya berusia 18 tahun atau lebih")
                                .font(TempoDesign.Typography.cardTitle)
                            Spacer()
                        }
                        .frame(minHeight: 48)
                    }
                    .buttonStyle(TempoTactileButtonStyle())
                    .accessibilityIdentifier("onboarding.adultConfirmed")
                    Toggle("Gunakan istilah yang lebih privat", isOn: $draft.discreetTerminology)
                        .tint(TempoDesign.Palette.accent)
                }
            }
            Text("TEMPO bukan alat diagnosis. Nyeri, darah, demam, cedera, atau keluhan saluran kemih memerlukan pemeriksaan yang sesuai.")
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(TempoDesign.Palette.textTertiary)
        }
    }

    private var goalAndControl: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Text("Tujuan dan kondisi awal")
                .font(TempoDesign.Typography.pageTitle)
            selectionGroup(
                title: "Apa yang ingin kamu benahi?",
                options: ["Kontrol dan jeda", "Kecemasan atau stres", "Keduanya"],
                selection: $draft.context
            )
            selectionGroup(
                title: "Kapan pola ini mulai terasa mengganggu?",
                options: ["Baru berubah", "Sudah cukup lama", "Belum yakin"],
                selection: $draft.onset
            )
            scaleCard(
                title: "Seberapa mudah kamu memberi jeda?",
                value: $draft.control,
                lower: "Sulit sekali",
                upper: "Cukup bisa"
            )
        }
    }

    private var baselineCondition: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Text("Kondisi dasar")
                .font(TempoDesign.Typography.pageTitle)
            scaleCard(
                title: "Kecemasan akhir-akhir ini",
                value: $draft.anxiety,
                lower: "Rendah",
                upper: "Sangat tinggi"
            )
            TempoSurfaceCard {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                    HStack {
                        Text("Rata-rata tidur per malam").font(TempoDesign.Typography.cardTitle)
                        Spacer()
                        Text("\(draft.sleepHours) jam").font(TempoDesign.Typography.numeric)
                    }
                    Slider(
                        value: Binding(get: { Double(draft.sleepHours) }, set: { draft.sleepHours = Int($0.rounded()) }),
                        in: 3...12,
                        step: 1
                    )
                    .tint(TempoDesign.Palette.accentSoft)
                }
            }
        }
    }

    private var realisticActivity: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Text("Aktivitas yang realistis")
                .font(TempoDesign.Typography.pageTitle)
            VStack(spacing: TempoDesign.Spacing.sm) {
                ForEach(TempoMovementFrequency.allCases) { frequency in
                    TempoSelectionCard(
                        title: frequency.title,
                        subtitle: "Disimpan sebagai sekitar \(frequency.weeklyMinutes) menit per minggu.",
                        icon: "figure.walk",
                        selected: draft.movementFrequency == frequency,
                        tone: .accent
                    ) {
                        draft.movementFrequency = frequency
                    }
                }
            }
            TempoSurfaceCard {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    Toggle("Saya bisa jalan santai sekitar 20 menit", isOn: $draft.canWalk)
                        .tint(TempoDesign.Palette.accent)
                    Toggle("Ada pembatasan aktivitas dari tenaga kesehatan", isOn: $draft.exerciseRestricted)
                        .tint(TempoDesign.Palette.caution)
                }
            }
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                Text("Preferensi aktivitas").font(TempoDesign.Typography.sectionTitle)
                Text("Preferensi bukan target. Safety dan pemulihan tetap memiliki prioritas.")
                    .font(TempoDesign.Typography.supporting)
                    .foregroundStyle(TempoDesign.Palette.textSecondary)
                ForEach(ActivityPreference.allCases, id: \.self) { preference in
                    TempoSelectionCard(
                        title: preference.legacyDisplayValue,
                        subtitle: activityPreferenceAvailability(preference),
                        icon: activityPreferenceIcon(preference),
                        selected: draft.activityPreference == preference,
                        tone: .accent
                    ) {
                        if activityPreferenceAllowed(preference) {
                            draft.activityPreference = preference
                        }
                    }
                    .opacity(activityPreferenceAllowed(preference) ? 1 : 0.55)
                    .accessibilityIdentifier("onboarding.activityPreference.\(preference.rawValue)")
                }
            }
        }
    }

    private var habitContext: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Text("Konteks kebiasaan")
                .font(TempoDesign.Typography.pageTitle)
            Text("Jawaban ini mengubah tempo awal dan jenis materi, bukan memberi label pada dirimu.")
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            TempoSurfaceCard {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    Toggle("Saya biasanya punya ruang yang aman dan privat", isOn: $draft.safeSpace)
                        .tint(TempoDesign.Palette.accent)
                    Toggle("Saya sering merasa terburu-buru", isOn: $draft.rushedHabit)
                        .tint(TempoDesign.Palette.accent)
                    Toggle("Saya sering terpapar rangsangan tinggi", isOn: $draft.highStimulus)
                        .tint(TempoDesign.Palette.accent)
                }
            }
        }
    }

    private var safetyAndReminder: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Text("Keselamatan dan pengingat")
                .font(TempoDesign.Typography.pageTitle)
            TempoDisclosureSection(title: "Pemeriksaan singkat", icon: "cross.case.fill", isExpanded: .constant(true)) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                    Text("Centang hanya bila terjadi sekarang atau baru-baru ini. TEMPO akan menjeda sesi dan menampilkan langkah aman.")
                        .font(TempoDesign.Typography.supporting)
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                    SafetyScreeningFields(answers: safetyBinding)
                }
            }
            TempoDisclosureSection(title: "Pengingat lokal", icon: "bell.fill", isExpanded: $draft.remindersEnabled) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                    Toggle("Aktifkan pengingat rencana", isOn: $draft.remindersEnabled)
                        .tint(TempoDesign.Palette.accent)
                    if draft.remindersEnabled {
                        Stepper("Jam pengingat: \(String(format: "%02d:00", draft.reminderHour))", value: $draft.reminderHour, in: 8...21)
                        Stepper("Akhiri setelah: \(String(format: "%02d:00", draft.reminderEndHour))", value: $draft.reminderEndHour, in: draft.reminderHour...22)
                    }
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Text("Minggu pertamamu")
                .font(TempoDesign.Typography.pageTitle)
            Text("Preview dihitung langsung dari baseline draft dan generator program yang sama dengan aplikasi.")
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            ForEach(previewItems) { item in
                TempoCompactStatusRow(
                    title: item.scheduledAt.formatted(.dateTime.weekday(.wide)),
                    detail: "\(tempoActivityName(item.effectiveKind)) · \(item.estimatedMinutes) menit · \(item.scheduledAt.formatted(date: .omitted, time: .shortened))",
                    icon: tempoActivityIcon(item.effectiveKind),
                    tone: item.status == .recovery ? .caution : .accent
                )
                .padding(.horizontal, TempoDesign.Spacing.sm)
                .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: TempoDesign.Spacing.sm) {
            if draft.step > 0 {
                TempoSecondaryButton("Kembali", icon: "chevron.left", tone: .neutral) {
                    draft.step -= 1
                }
            }
            if draft.step == totalSteps - 1 {
                TempoPrimaryButton(saving ? "Menyimpan…" : "Masuk ke Hari Ini", icon: "arrow.right", isEnabled: !saving) {
                    finish()
                }
                .accessibilityIdentifier("onboarding.finish")
            } else {
                TempoPrimaryButton("Lanjut", icon: "arrow.right", isEnabled: canAdvance) {
                    draft.step += 1
                }
                .accessibilityIdentifier("onboarding.next")
            }
        }
    }

    private var canAdvance: Bool {
        draft.step != 0 || draft.adultConfirmed
    }

    private var safetyBinding: Binding<SafetyScreeningAnswers> {
        Binding(
            get: { draft.safetyAnswers },
            set: { draft.apply($0) }
        )
    }

    private var previewItems: [ProgramPlanItem] {
        WeeklyPlanGenerator().generate(weekStarting: .now, weeks: 1, context: previewContext)
    }

    private var previewContext: ProgramContext {
        ProgramContext(
            phase: .awareness,
            baselineCompleted: true,
            anxiety: draft.anxiety,
            sleepHours: Double(draft.sleepHours),
            exerciseRestricted: draft.exerciseRestricted,
            canWalkTwentyMinutes: draft.canWalk,
            hasSafeActivitySpace: draft.safeSpace,
            rushedHabit: draft.rushedHabit,
            highStimulusPattern: draft.highStimulus,
            hasSafetyHold: draft.safetyAnswers.hasAny,
            preferredActivity: draft.activityPreference.legacyDisplayValue,
            activityPreference: draft.activityPreference
        )
    }

    private func selectionGroup(title: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            Text(title).font(TempoDesign.Typography.sectionTitle)
            ForEach(options, id: \.self) { option in
                TempoSelectionCard(
                    title: option,
                    subtitle: nil,
                    icon: "circle.grid.cross.fill",
                    selected: selection.wrappedValue == option,
                    tone: .accent
                ) {
                    selection.wrappedValue = option
                }
            }
        }
    }

    private func scaleCard(title: String, value: Binding<Int>, lower: String, upper: String) -> some View {
        TempoSurfaceCard(tint: TempoDesign.Palette.accent, emphasis: .tinted) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                Text(title).font(TempoDesign.Typography.sectionTitle)
                HStack {
                    Text(lower).font(TempoDesign.Typography.caption)
                    Spacer()
                    Text("\(value.wrappedValue)/10").font(TempoDesign.Typography.numeric)
                    Spacer()
                    Text(upper).font(TempoDesign.Typography.caption)
                }
                Slider(
                    value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }),
                    in: 1...10,
                    step: 1
                )
                .tint(TempoDesign.Palette.accentSoft)
            }
        }
    }

    private func activityPreferenceAllowed(_ preference: ActivityPreference) -> Bool {
        switch preference {
        case .walkJog:
            return draft.canWalk && !draft.exerciseRestricted
        case .homeStrength:
            return draft.safeSpace && !draft.exerciseRestricted
        default:
            return true
        }
    }

    private func activityPreferenceAvailability(_ preference: ActivityPreference) -> String? {
        guard !activityPreferenceAllowed(preference) else { return nil }
        switch preference {
        case .walkJog: return "Memerlukan kemampuan jalan 20 menit tanpa pembatasan aktivitas."
        case .homeStrength: return "Memerlukan ruang aman dan tanpa pembatasan aktivitas."
        default: return nil
        }
    }

    private func activityPreferenceIcon(_ preference: ActivityPreference) -> String {
        switch preference {
        case .walking: "figure.walk"
        case .walkJog: "figure.run"
        case .homeStrength: "figure.strengthtraining.traditional"
        case .breathingMobility: "wind"
        case .noPreference: "slider.horizontal.3"
        }
    }

    private func restoreAppStorageFromDraft() {
        discreetTerminology = draft.discreetTerminology
        remindersEnabled = draft.remindersEnabled
        reminderHour = draft.reminderHour
    }

    private func finish() {
        guard !saving else { return }
        saving = true
        let safety = draft.safetyAnswers
        let baseline = LocalBaseline(
            completedAt: .now,
            onset: draft.onset,
            difficultyContext: draft.context,
            perceivedControl: draft.control,
            anxiety: draft.anxiety,
            sleepHours: draft.sleepHours,
            activityLevel: draft.movementFrequency == .rarely ? "Jarang" : "Aktif",
            weeklyMovementMinutes: draft.movementFrequency.weeklyMinutes,
            canWalkTwentyMinutes: draft.canWalk,
            hasExerciseRestriction: draft.exerciseRestricted,
            hasSafeActivitySpace: draft.safeSpace,
            preferredActivity: draft.activityPreference.legacyDisplayValue,
            activityPreference: draft.activityPreference,
            rushedHabit: draft.rushedHabit,
            highStimulusPattern: draft.highStimulus,
            hasSafetySymptoms: safety.hasAny,
            rulesetVersion: RulesetVersion.current.rawValue,
            reminderStartHour: draft.remindersEnabled ? draft.reminderHour : nil,
            reminderEndHour: draft.remindersEnabled ? draft.reminderEndHour : nil,
            adultConfirmed: draft.adultConfirmed
        )
        let saved = history.saveBaseline(
            baseline,
            safetyReasonCode: safety.hasAny ? safety.reasonCode : nil,
            safetySeverity: safety.hasAny ? safety.severity.rawValue : nil
        )
        if saved { _ = history.refreshPlan(force: true) }
        saving = false
        guard saved else {
            saveFailed = true
            return
        }

        discreetTerminology = draft.discreetTerminology
        remindersEnabled = draft.remindersEnabled
        reminderHour = draft.reminderHour
        TempoOnboardingDraftStore.clear()
        onboardingCompleted = true

        if draft.remindersEnabled {
            Task {
                await LocalNotifications.requestAndSyncPlan(
                    history.upcomingPlan,
                    fallbackHour: draft.reminderHour,
                    windowEndHour: draft.reminderEndHour,
                    soundEnabled: false
                )
            }
        }
    }
}

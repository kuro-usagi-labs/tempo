import SwiftUI

/// A short, sequential baseline. It does not enter Today until both the
/// baseline and the first persisted two-week plan have been written locally.
struct TempoV2Onboarding: View {
    @Environment(LocalHistory.self) private var history
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("discreetTerminology") private var discreetTerminology = false
    @AppStorage("dailyPlanRemindersEnabled") private var remindersEnabled = false
    @AppStorage("dailyPlanReminderHour") private var reminderHour = 19
    @State private var reminderEndHour = 21

    @State private var step = 0
    @State private var adultConfirmed = false
    @State private var onset = "Sudah cukup lama"
    @State private var context = "Keduanya"
    @State private var control = 5
    @State private var anxiety = 5
    @State private var sleepHours = 7
    @State private var weeklyMovement = 60
    @State private var canWalk = true
    @State private var exerciseRestricted = false
    @State private var activityPreference: ActivityPreference = .noPreference
    @State private var safeSpace = true
    @State private var rushedHabit = false
    @State private var highStimulus = false
    @State private var safety = SafetyScreeningAnswers()
    @State private var saving = false
    @State private var saveFailed = false

    private let totalSteps = 12

    var body: some View {
        ZStack {
            TempoDesign.Palette.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.xl) {
                    progress
                    stepContent
                    controls
                }
                .frame(maxWidth: TempoDesign.readableContentWidth, alignment: .leading)
                .padding(.horizontal, TempoDesign.Spacing.lg)
                .padding(.vertical, TempoDesign.Spacing.xl)
            }
        }
        .alert("Baseline belum tersimpan", isPresented: $saveFailed) {
            Button("Coba lagi") { finish() }
            Button("Tetap di sini", role: .cancel) {}
        } message: {
            Text("TEMPO belum akan masuk ke Hari Ini sampai data lokal tersimpan dengan aman.")
        }
        .accessibilityIdentifier("onboarding.v2")
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            HStack {
                Text("TEMPO").font(TempoDesign.Typography.overline).tracking(1.5).foregroundStyle(TempoDesign.Palette.accentSoft)
                Spacer()
                Text("\(step + 1) / \(totalSteps)").font(TempoDesign.Typography.caption).foregroundStyle(TempoDesign.Palette.textSecondary)
            }
            SwiftUI.ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(TempoDesign.Palette.accent)
                .accessibilityLabel("Kemajuan onboarding")
        }
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case 0: messageStep(icon: "sparkles", title: "Ritme yang lebih tenang.", body: "TEMPO membantu kamu membangun jeda, pemulihan, dan kebiasaan gerak—tanpa target yang perlu dikejar hari ini.")
        case 1: messageStep(icon: "lock.shield", title: "Tetap privat di iPhone ini.", body: "Tidak ada akun, sinkronisasi cloud, analitik, atau koneksi jaringan. Kamu mengendalikan apa yang dicatat.")
        case 2:
            TempoSurfaceCard(tint: TempoDesign.Palette.accentSoft, emphasis: .tinted) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    Label("Sebelum mulai", systemImage: "checkmark.seal") .font(TempoDesign.Typography.sectionTitle)
                    Text("TEMPO untuk dewasa dan bukan alat diagnosis. Gejala nyeri, darah, demam, perih saat kencing, atau cedera perlu pemeriksaan profesional.")
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                    Button { adultConfirmed.toggle() } label: {
                        HStack(spacing: TempoDesign.Spacing.sm) {
                            Image(systemName: adultConfirmed ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(adultConfirmed ? TempoDesign.Palette.accentSoft : TempoDesign.Palette.textSecondary)
                            Text("Saya berusia 18 tahun atau lebih")
                                .font(TempoDesign.Typography.cardTitle)
                            Spacer()
                        }
                        .padding(TempoDesign.Spacing.sm)
                        .background(TempoDesign.Palette.surfaceElevated, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
                    }
                    .buttonStyle(TempoTactileButtonStyle())
                    .accessibilityLabel("Saya berusia 18 tahun atau lebih")
                    .accessibilityValue(adultConfirmed ? "Dikonfirmasi" : "Belum dikonfirmasi")
                    .accessibilityHint("Ketuk untuk mengonfirmasi usia dewasa")
                    .accessibilityAddTraits(adultConfirmed ? .isSelected : [])
                    .accessibilityIdentifier("onboarding.adultConfirmed")
                    Toggle("Gunakan istilah yang lebih privat", isOn: $discreetTerminology).tint(TempoDesign.Palette.accent)
                }
            }
        case 3:
            selectionStep(title: "Apa yang ingin kamu benahi?", subtitle: "Ini hanya membantu TEMPO memilih bahasa dan ritme awal.", options: ["Kontrol dan jeda", "Kecemasan atau stres", "Keduanya"], selection: $context)
        case 4:
            selectionStep(title: "Kapan pola ini mulai terasa mengganggu?", subtitle: "Jawab seperlunya—tidak ada jawaban benar atau salah.", options: ["Baru berubah", "Sudah cukup lama", "Belum yakin"], selection: $onset)
        case 5:
            scaleStep(title: "Seberapa mudah kamu memberi jeda?", subtitle: "Nilai pengalaman saat ini, bukan kemampuan ideal.", value: $control, lower: "Sulit sekali", upper: "Cukup bisa")
        case 6:
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                scaleStep(title: "Seberapa tinggi kecemasan akhir-akhir ini?", subtitle: "Nilai ini hanya merapikan tempo awal.", value: $anxiety, lower: "Rendah", upper: "Sangat tinggi")
                TempoSurfaceCard {
                    VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                        Text("Rata-rata tidur per malam").font(TempoDesign.Typography.cardTitle)
                        Stepper("\(sleepHours) jam", value: $sleepHours, in: 3...12)
                            .foregroundStyle(TempoDesign.Palette.textSecondary)
                    }
                }
            }
        case 7:
            TempoSurfaceCard {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    Text("Gerak yang realistis").font(TempoDesign.Typography.sectionTitle)
                    Text("Rencana gerak dapat diganti pemulihan kapan saja.").foregroundStyle(TempoDesign.Palette.textSecondary)
                    Stepper("Gerak mingguan: \(weeklyMovement) menit", value: $weeklyMovement, in: 0...420, step: 15)
                    Toggle("Saya bisa jalan santai sekitar 20 menit", isOn: $canWalk).tint(TempoDesign.Palette.accent)
                    Toggle("Ada pembatasan aktivitas dari tenaga kesehatan", isOn: $exerciseRestricted).tint(TempoDesign.Palette.caution)
                    Divider().overlay(TempoDesign.Palette.hairline)
                    Text("Aktivitas yang paling realistis untukmu").font(TempoDesign.Typography.cardTitle)
                    Text("Ini adalah preferensi, bukan target. TEMPO tetap memilih pemulihan bila kondisi, jarak sesi, atau batasan aktivitas belum aman.")
                        .font(TempoDesign.Typography.supporting)
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                    ForEach(ActivityPreference.allCases, id: \.self) { preference in
                        Button { activityPreference = preference } label: {
                            HStack(spacing: TempoDesign.Spacing.sm) {
                                Image(systemName: activityPreference == preference ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(activityPreference == preference ? TempoDesign.Palette.accentSoft : TempoDesign.Palette.textSecondary)
                                Text(preference.legacyDisplayValue)
                                    .font(TempoDesign.Typography.supporting)
                                    .foregroundStyle(TempoDesign.Palette.textPrimary)
                                Spacer()
                            }
                            .padding(.vertical, TempoDesign.Spacing.xs)
                        }
                        .buttonStyle(TempoTactileButtonStyle())
                        .accessibilityIdentifier("onboarding.activityPreference.\(preference.rawValue)")
                        .accessibilityAddTraits(activityPreference == preference ? .isSelected : [])
                    }
                }
            }
        case 8:
            TempoSurfaceCard {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    Text("Konteks yang membantu").font(TempoDesign.Typography.sectionTitle)
                    Toggle("Saya biasanya punya ruang yang aman dan privat", isOn: $safeSpace).tint(TempoDesign.Palette.accent)
                    Toggle("Saya sering merasa terburu-buru", isOn: $rushedHabit).tint(TempoDesign.Palette.accent)
                    Toggle("Saya sering merasa paparan rangsangan tinggi", isOn: $highStimulus).tint(TempoDesign.Palette.accent)
                }
            }
        case 9:
            TempoSurfaceCard(tint: TempoDesign.Palette.caution, emphasis: .tinted) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    Label("Pemeriksaan singkat", systemImage: "cross.case") .font(TempoDesign.Typography.sectionTitle)
                    Text("Centang hanya bila terjadi sekarang atau baru-baru ini. Bila ada, TEMPO akan menjeda latihan dan menunjukkan langkah aman.")
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                    SafetyScreeningFields(answers: $safety)
                }
            }
        case 10:
            TempoSurfaceCard {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    Text("Jendela pengingat lokal").font(TempoDesign.Typography.sectionTitle)
                    Text("Pengingat bersifat netral, dibuat dari rencana, dan tidak dikirim ke mana pun.").foregroundStyle(TempoDesign.Palette.textSecondary)
                    Toggle("Aktifkan pengingat rencana", isOn: $remindersEnabled).tint(TempoDesign.Palette.accent)
                    if remindersEnabled {
                        Stepper("Jam pengingat: \(String(format: "%02d:00", reminderHour))", value: $reminderHour, in: 8...21)
                        Stepper("Akhiri pengingat setelah: \(String(format: "%02d:00", reminderEndHour))", value: $reminderEndHour, in: reminderHour...22)
                    }
                }
            }
        case 11: previewStep
        default: EmptyView()
        }
    }

    private var controls: some View {
        HStack(spacing: TempoDesign.Spacing.sm) {
            if step > 0 {
                TempoSecondaryButton("Kembali", icon: "chevron.left") { step -= 1 }
            }
            if step == totalSteps - 1 {
                TempoPrimaryButton(saving ? "Menyimpan…" : "Masuk ke Hari Ini", icon: "arrow.right", isEnabled: !saving) { finish() }
                    .accessibilityIdentifier("onboarding.finish")
            } else {
                TempoPrimaryButton("Lanjut", icon: "arrow.right", isEnabled: canAdvance) { step += 1 }
                    .accessibilityIdentifier("onboarding.next")
            }
        }
    }

    private var canAdvance: Bool { step != 2 || adultConfirmed }

    private func messageStep(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Image(systemName: icon).font(.system(size: 42, weight: .semibold)).foregroundStyle(TempoDesign.Palette.accentSoft)
            Text(title).font(TempoDesign.Typography.display).foregroundStyle(TempoDesign.Palette.textPrimary)
            Text(body).font(.title3).foregroundStyle(TempoDesign.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 390, alignment: .leading)
    }

    private func selectionStep(title: String, subtitle: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Text(title).font(TempoDesign.Typography.pageTitle)
            Text(subtitle).foregroundStyle(TempoDesign.Palette.textSecondary)
            ForEach(options, id: \.self) { option in
                Button { selection.wrappedValue = option } label: {
                    HStack {
                        Text(option).font(TempoDesign.Typography.cardTitle)
                        Spacer()
                        Image(systemName: selection.wrappedValue == option ? "checkmark.circle.fill" : "circle")
                    }
                    .foregroundStyle(selection.wrappedValue == option ? TempoDesign.Palette.accentSoft : TempoDesign.Palette.textPrimary)
                    .padding(TempoDesign.Spacing.md)
                    .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium, style: .continuous))
                }
                .buttonStyle(TempoTactileButtonStyle())
            }
        }
    }

    private func scaleStep(title: String, subtitle: String, value: Binding<Int>, lower: String, upper: String) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
            Text(title).font(TempoDesign.Typography.pageTitle)
            Text(subtitle).foregroundStyle(TempoDesign.Palette.textSecondary)
            TempoSurfaceCard(tint: TempoDesign.Palette.accent, emphasis: .tinted) {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.md) {
                    HStack { Text(lower).font(TempoDesign.Typography.caption); Spacer(); Text("\(value.wrappedValue)/10").font(TempoDesign.Typography.numeric); Spacer(); Text(upper).font(TempoDesign.Typography.caption) }
                    Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: 1...10, step: 1)
                        .tint(TempoDesign.Palette.accentSoft)
                        .accessibilityValue("\(value.wrappedValue) dari 10")
                }
            }
        }
    }

    private var previewStep: some View {
        let preview = WeeklyPlanGenerator().generate(weekStarting: .now, weeks: 1, context: previewContext)
        return VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
            Text("Minggu pertamamu").font(TempoDesign.Typography.pageTitle)
            Text("Rencana ini dibuat dari baseline dan tetap dapat menyesuaikan dengan tidur, kecemasan, pemulihan, serta batasan aktivitas.")
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            ForEach(preview) { item in
                HStack(spacing: TempoDesign.Spacing.sm) {
                    Image(systemName: tempoActivityIcon(item.effectiveKind)).foregroundStyle(TempoDesign.Palette.accentSoft).frame(width: 24)
                    VStack(alignment: .leading) {
                        Text(item.scheduledAt.formatted(.dateTime.weekday(.wide))).font(TempoDesign.Typography.cardTitle)
                        Text("\(tempoActivityName(item.effectiveKind)) · \(item.estimatedMinutes) menit · \(item.scheduledAt.formatted(date: .omitted, time: .shortened))")
                            .font(TempoDesign.Typography.supporting).foregroundStyle(TempoDesign.Palette.textSecondary)
                    }
                    Spacer()
                }
                .padding(TempoDesign.Spacing.md)
                .background(TempoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: TempoDesign.Radius.small, style: .continuous))
            }
        }
    }

    private var previewContext: ProgramContext {
        ProgramContext(
            phase: .awareness,
            baselineCompleted: true,
            anxiety: anxiety,
            sleepHours: Double(sleepHours),
            exerciseRestricted: exerciseRestricted,
            canWalkTwentyMinutes: canWalk,
            hasSafeActivitySpace: safeSpace,
            rushedHabit: rushedHabit,
            highStimulusPattern: highStimulus,
            hasSafetyHold: safety.hasAny,
            preferredActivity: activityPreference.legacyDisplayValue,
            activityPreference: activityPreference
        )
    }

    private func finish() {
        guard !saving else { return }
        saving = true
        let baseline = LocalBaseline(
            completedAt: .now, onset: onset, difficultyContext: context, perceivedControl: control, anxiety: anxiety,
            sleepHours: sleepHours, activityLevel: weeklyMovement == 0 ? "Jarang" : "Aktif", weeklyMovementMinutes: weeklyMovement,
            canWalkTwentyMinutes: canWalk, hasExerciseRestriction: exerciseRestricted, hasSafeActivitySpace: safeSpace,
            preferredActivity: activityPreference.legacyDisplayValue, rushedHabit: rushedHabit,
            highStimulusPattern: highStimulus, hasSafetySymptoms: safety.hasAny, rulesetVersion: RulesetVersion.current.rawValue,
            reminderStartHour: remindersEnabled ? reminderHour : nil, reminderEndHour: remindersEnabled ? reminderEndHour : nil, adultConfirmed: adultConfirmed
        )
        let saved = history.saveBaseline(baseline, safetyReasonCode: safety.hasAny ? safety.reasonCode : nil, safetySeverity: safety.hasAny ? safety.severity.rawValue : nil)
        if saved { _ = history.refreshPlan(force: true) }
        saving = false
        guard saved else { saveFailed = true; return }
        onboardingCompleted = true
        if remindersEnabled {
            Task { await LocalNotifications.requestAndSyncPlan(history.upcomingPlan, fallbackHour: reminderHour, windowEndHour: reminderEndHour, soundEnabled: false) }
        }
    }
}

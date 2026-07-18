import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("privacyCoverEnabled") private var privacyCoverEnabled = true
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage("dailyPlanRemindersEnabled") private var remindersEnabled = false
    @AppStorage("dailyPlanReminderHour") private var reminderHour = 9
    @State private var privacyCovered = false
    @State private var isUnlocked = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    var body: some View {
        ZStack {
        if onboardingCompleted && (!biometricLockEnabled || isUnlocked) {
        TabView {
            TodayView().tabItem { Label("Hari ini", systemImage: "sparkles") }
            TrainingView().tabItem { Label("Latihan", systemImage: "figure.mind.and.body") }
            ProgressView().tabItem { Label("Progres", systemImage: "chart.line.uptrend.xyaxis") }
            LearnView().tabItem { Label("Belajar", systemImage: "book") }
            SettingsView().tabItem { Label("Pengaturan", systemImage: "gearshape") }
        }.tint(Color(red: 0.47, green: 0.42, blue: 1))
        } else {
            if onboardingCompleted { VStack(spacing: 18) { Image(systemName: "lock.fill").font(.system(size: 48)); Text("TEMPO terkunci").font(.title.bold()); Button("Buka") { Task { isUnlocked = await PrivacyLock.authenticate() } }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black) } else { OnboardingView() }
        }
        if privacyCovered {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "circle.fill").font(.system(size: 36)).foregroundStyle(.indigo)
                Text("TEMPO").font(.headline)
            }.accessibilityLabel("Layar privat")
        }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                privacyCovered = privacyCoverEnabled
                if biometricLockEnabled { isUnlocked = false }
            }
            if phase == .active {
                privacyCovered = false
                if remindersEnabled { Task { await LocalNotifications.requestAndScheduleDailyPlan(hour: reminderHour) } }
            }
        }
        .onChange(of: biometricLockEnabled) { _, enabled in if enabled && scenePhase == .active { isUnlocked = true } }
    }
}

struct OnboardingView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("discreetTerminology") private var discreetTerminology = false
    @State private var page = 0
    @State private var confirmedAdult = false
    private let pages = [
        ("Build control without pressure", "TEMPO memberi rencana terstruktur untuk kesadaran, jeda, pemulihan, gerak, dan kebiasaan sehat."),
        ("Privat secara desain", "Jawaban dan riwayatmu tetap pada iPhone ini. Tidak ada akun dan tidak ada internet yang dibutuhkan."),
        ("Bukan diagnosis", "Nyeri, perih saat kencing, cairan tidak biasa, darah, demam, atau perubahan mendadak perlu penilaian profesional."),
        ("Istirahat juga latihan", "TEMPO dapat menyarankan napas, jalan, atau pemulihan, bukan sesi tambahan.")
    ]
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "circle.hexagongrid.fill").font(.system(size: 64)).foregroundStyle(.indigo)
            Text(pages[page].0).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(pages[page].1).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack { ForEach(0..<pages.count, id: \.self) { index in Capsule().fill(index == page ? Color.indigo : Color.white.opacity(0.2)).frame(width: index == page ? 28 : 8, height: 8) } }
            if page == pages.count - 1 {
                Toggle("Saya mengonfirmasi bahwa saya berusia 18 tahun atau lebih", isOn: $confirmedAdult).font(.subheadline)
                Toggle("Gunakan istilah privat", isOn: $discreetTerminology)
            }
            Spacer()
            Button(page == pages.count - 1 ? "Mulai dengan aman" : "Lanjut") {
                if page == pages.count - 1 { onboardingCompleted = true } else { page += 1 }
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(page == pages.count - 1 && !confirmedAdult)
        }.padding(28).background(Color.black.ignoresSafeArea())
    }
}

struct TodayView: View {
    @Environment(LocalHistory.self) private var history
    @State private var showCheckIn = false
    @State private var showBreathing = false
    @State private var showHealthCheck = false
    @State private var showBaseline = false
    @State private var showPrimaryActivity = false
    private var baselineCompleted: Bool { history.baseline != nil }
    private var weeklyPlan: [PlannedActivity] { WeeklyScheduler().beginnerPlan(highStress: (history.baseline?.anxiety ?? 0) >= 8, irritation: history.activeSafetyHold != nil) }
    private var todayIndex: Int { (Calendar.current.component(.weekday, from: .now) + 5) % 7 }
    private var todayActivity: ActivityKind {
        let scheduled = weeklyPlan.first { $0.day == todayIndex }?.kind ?? .breathing
        if scheduled == .guided, (history.hoursSinceLastSession ?? .infinity) <= 24 || history.guidedSessionsLast7Days >= 3 { return .recovery }
        return scheduled
    }
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [TempoPalette.background, TempoPalette.background, TempoPalette.indigo.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        if !baselineCompleted { baselinePrompt }
                        if history.activeSafetyHold != nil { safetyHoldCard } else { todayHero }
                        quickActions
                        progressSnapshot
                        weeklyPlanCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 8) }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCheckIn) { UrgeCheckInView() }
            .sheet(isPresented: $showBreathing) {
                NavigationStack {
                    BreathingView(title: "Napas singkat", duration: 240)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Tutup") { showBreathing = false } } }
                }
            }
            .sheet(isPresented: $showHealthCheck) { HealthCheckView() }
            .sheet(isPresented: $showBaseline) { BaselineView() }
            .sheet(isPresented: $showPrimaryActivity) { NavigationStack { primaryActivityDestination } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(TempoPalette.indigo.opacity(0.18)).frame(width: 32, height: 32)
                    Image(systemName: "waveform.path.ecg").font(.system(size: 14, weight: .semibold)).foregroundStyle(TempoPalette.cyan)
                }
                Text("TEMPO").font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(TempoPalette.cyan)
                Spacer()
                Text("Hari ini").font(.caption.weight(.semibold)).foregroundStyle(TempoPalette.secondary)
            }
            Text("Ritme yang\nlebih tenang.")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .tracking(-1.1)
                .lineSpacing(-2)
                .foregroundStyle(TempoPalette.primary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var baselinePrompt: some View {
        Button { showBaseline = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(TempoPalette.cyan.opacity(0.14)).frame(width: 48, height: 48)
                    Image(systemName: "checklist").font(.system(size: 19, weight: .semibold)).foregroundStyle(TempoPalette.cyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lengkapi baseline").font(.headline).foregroundStyle(TempoPalette.primary)
                    Text("Tidur, kecemasan, aktivitas · 2 menit").font(.subheadline).foregroundStyle(TempoPalette.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).foregroundStyle(TempoPalette.cyan)
            }
            .padding(16)
            .background(TempoPalette.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(TempoPalette.cyan.opacity(0.22), lineWidth: 1) }
        }
        .buttonStyle(TempoPressStyle())
        .accessibilityHint("Membuka penilaian awal dua menit")
    }

    private var todayHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("MINGGU 1 · KESADARAN", systemImage: "sparkles")
                .font(.caption.weight(.bold)).tracking(0.6).foregroundStyle(TempoPalette.cyan)
            VStack(alignment: .leading, spacing: 8) {
                Text(activityLabel(todayActivity)).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(TempoPalette.primary)
                Text(todayReason)
                    .font(.body).foregroundStyle(TempoPalette.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Label(todayDuration, systemImage: "clock").font(.subheadline.weight(.medium)).foregroundStyle(TempoPalette.secondary)
                Spacer()
                Button { showPrimaryActivity = true } label: {
                    HStack(spacing: 8) {
                        Text("Mulai").fontWeight(.semibold)
                        Image(systemName: "arrow.right").font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).frame(minHeight: 48)
                    .background(TempoPalette.indigo, in: Capsule())
                }.buttonStyle(TempoPressStyle())
            }
        }
        .padding(22)
        .background(
            LinearGradient(colors: [TempoPalette.surface2, TempoPalette.surface1], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1) }
    }

    @ViewBuilder private var primaryActivityDestination: some View {
        switch todayActivity {
        case .guided: GuidedSessionView()
        case .breathing: BreathingView(title: "Napas singkat", duration: 240)
        case .recovery: BreathingView(title: "Pemulihan", duration: 300)
        case .cardio: ExerciseDetailView(kind: .walk)
        case .strength: ExerciseDetailView(kind: .strength)
        case .education: LessonView(title: "Kesadaran sebelum intensitas", body: "Perhatikan perubahan napas, ketegangan, dan dorongan sebelum semuanya terasa mendesak. Mengenali sinyal awal memberi lebih banyak pilihan untuk melambat atau berhenti.")
        case .review: LessonView(title: "Tinjauan mingguan", body: "Perhatikan apa yang membantu minggu ini: kapan kamu mengenali kenaikan lebih awal, kapan kamu memilih jeda, dan bagaimana tubuh pulih. Istirahat yang dipatuhi juga merupakan progres.")
        }
    }

    private var todayDuration: String { switch todayActivity { case .guided: "15–20 menit"; case .breathing: "4 menit"; case .recovery: "5 menit"; case .cardio: "20 menit"; case .strength: "15 menit"; case .education: "3 menit"; case .review: "5 menit" } }
    private var todayReason: String {
        if (history.baseline?.anxiety ?? 0) >= 8 { return "Rencana dibuat lebih ringan karena baseline kecemasanmu tinggi." }
        switch todayActivity { case .recovery: return "Jeda membantu tubuh menyerap latihan sebelumnya."; case .cardio, .strength: return "Gerak mendukung tidur, suasana hati, dan pemulihan."; case .review: return "Tinjau minggu tanpa menghakimi hasil."; default: return "Langkah hari ini mengikuti ritme latihan yang aman." }
    }

    private var safetyHoldCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("JEDA KESELAMATAN AKTIF", systemImage: "cross.case.fill")
                .font(.caption.weight(.bold)).tracking(0.6).foregroundStyle(TempoPalette.danger)
            Text("Periksa kondisi sebelum berlatih").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(TempoPalette.primary)
            Text("Guided session dijeda sampai pemeriksaan gejala selesai tanpa tanda peringatan.")
                .foregroundStyle(TempoPalette.secondary)
            Button("Buka health check") { showHealthCheck = true }
                .buttonStyle(.borderedProminent).tint(TempoPalette.danger)
        }
        .padding(22)
        .background(TempoPalette.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(TempoPalette.danger.opacity(0.24), lineWidth: 1) }
    }

    private var quickActions: some View {
        VStack(spacing: 12) {
            TodayActionButton(
                title: "Aku lagi terangsang",
                subtitle: "Rekomendasi privat dalam 15 detik",
                icon: "bolt.heart.fill",
                accent: TempoPalette.indigo
            ) { showCheckIn = true }
            .accessibilityLabel("Aku lagi terangsang, mulai check-in cepat")

            TodayActionButton(
                title: "Aku punya keluhan",
                subtitle: "Periksa tanda keselamatan terlebih dahulu",
                icon: "cross.case.fill",
                accent: TempoPalette.danger
            ) { showHealthCheck = true }
        }
    }

    private var progressSnapshot: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ringkasanmu").font(.headline).foregroundStyle(TempoPalette.primary)
            HStack(spacing: 12) {
                Metric(title: "Kesadaran", value: "\(history.scoreSnapshot.awareness)", icon: "eye.fill", accent: TempoPalette.cyan)
                Metric(title: "Pemulihan", value: "\(history.scoreSnapshot.recovery)", icon: "leaf.fill", accent: TempoPalette.success)
            }
        }
    }

    private var weeklyPlanCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rencana minggu ini").font(.headline).foregroundStyle(TempoPalette.primary).padding(.bottom, 8)
            ForEach(weeklyPlan, id: \.day) { activity in
                HStack(spacing: 12) {
                    Text(dayLabel(activity.day)).font(.caption.weight(.bold)).foregroundStyle(TempoPalette.secondary).frame(width: 34, alignment: .leading)
                    Image(systemName: activityIcon(activity.kind)).font(.system(size: 14, weight: .semibold)).foregroundStyle(TempoPalette.cyan).frame(width: 24)
                    Text(activityLabel(activity.kind)).font(.subheadline).foregroundStyle(TempoPalette.primary)
                    Spacer()
                }
                .frame(minHeight: 44)
                if activity.day != weeklyPlan.last?.day { Divider().overlay(Color.white.opacity(0.06)) }
            }
        }
        .padding(20)
        .background(TempoPalette.surface1, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1) }
    }
}

struct BaselineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalHistory.self) private var history
    @State private var onset = "Belum yakin"
    @State private var context = "Keduanya"
    @State private var control = 5
    @State private var anxiety = 5
    @State private var sleep = 7
    @State private var activity = "Jarang"
    @State private var rushedHabit = false
    @State private var highStimulusPattern = false
    @State private var safetySymptoms = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Pola saat ini") {
                    Picker("Mulai dirasakan", selection: $onset) { ForEach(["Sejak awal", "Perubahan baru", "Belum yakin"], id: \.self) { Text($0).tag($0) } }
                    Picker("Terjadi saat", selection: $context) { ForEach(["Sendiri", "Dengan pasangan", "Keduanya", "Belum yakin"], id: \.self) { Text($0).tag($0) } }
                    Stepper("Kontrol yang dirasakan: \(control)/10", value: $control, in: 1...10)
                }
                Section("Kondisi dasar") {
                    Stepper("Kecemasan: \(anxiety)/10", value: $anxiety, in: 1...10)
                    Stepper("Tidur: \(sleep) jam", value: $sleep, in: 0...12)
                    Picker("Aktivitas mingguan", selection: $activity) { Text("Jarang").tag("Jarang"); Text("Pemula").tag("Pemula"); Text("Rutin").tag("Rutin") }
                }
                Section("Kebiasaan") {
                    Toggle("Sering terburu-buru", isOn: $rushedHabit)
                    Toggle("Terbiasa dengan stimulus sangat tinggi", isOn: $highStimulusPattern)
                }
                Section("Keselamatan") {
                    Toggle("Ada nyeri, cedera, darah, demam, perih saat kencing, atau cairan tidak biasa", isOn: $safetySymptoms)
                    if safetySymptoms { Text("Latihan akan dijeda dan TEMPO akan membuka jalur health check.").foregroundStyle(.red) }
                }
                Section {
                    Button("Simpan baseline") { save() }.buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Baseline")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Tutup") { dismiss() } } }
            .alert("Baseline belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") {} } message: { Text("TEMPO tidak dapat menyimpan data dengan aman. Tidak ada perubahan yang diterapkan.") }
        }
    }

    private func save() {
        let baseline = LocalBaseline(completedAt: .now, onset: onset, difficultyContext: context, perceivedControl: control, anxiety: anxiety, sleepHours: sleep, activityLevel: activity, rushedHabit: rushedHabit, highStimulusPattern: highStimulusPattern, hasSafetySymptoms: safetySymptoms, rulesetVersion: RuleEngine.rulesetVersion)
        if history.saveBaseline(baseline) { UserDefaults.standard.removeObject(forKey: "baselineCompleted"); dismiss() }
        else { saveFailed = true }
    }
}

private enum TempoPalette {
    static let background = Color(red: 0.035, green: 0.039, blue: 0.051)
    static let surface1 = Color(red: 0.082, green: 0.094, blue: 0.125)
    static let surface2 = Color(red: 0.106, green: 0.122, blue: 0.165)
    static let primary = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let secondary = Color(red: 0.68, green: 0.71, blue: 0.77)
    static let indigo = Color(red: 0.47, green: 0.42, blue: 1)
    static let cyan = Color(red: 0.33, green: 0.78, blue: 0.91)
    static let success = Color(red: 0.31, green: 0.83, blue: 0.60)
    static let danger = Color(red: 1, green: 0.25, blue: 0.36)
}

private struct TempoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private struct TodayActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(accent.opacity(0.16)).frame(width: 50, height: 50)
                    Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(TempoPalette.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(TempoPalette.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).foregroundStyle(accent)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TempoPalette.surface1, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(accent.opacity(0.18), lineWidth: 1) }
        }
        .buttonStyle(TempoPressStyle())
    }
}

private func dayLabel(_ day: Int) -> String { ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"][day] }
private func activityLabel(_ kind: ActivityKind) -> String { switch kind { case .guided: "Guided session"; case .breathing: "Napas singkat"; case .cardio: "Jalan / cardio"; case .strength: "Kekuatan pemula"; case .recovery: "Pemulihan"; case .education: "Materi singkat"; case .review: "Tinjauan mingguan" } }
private func activityIcon(_ kind: ActivityKind) -> String { switch kind { case .guided: "timer"; case .breathing: "wind"; case .cardio: "figure.walk"; case .strength: "figure.strengthtraining.traditional"; case .recovery: "bed.double"; case .education: "book"; case .review: "calendar" } }

struct HealthCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalHistory.self) private var history
    @State private var pain = false
    @State private var bloodOrFever = false
    @State private var urinaryOrDischarge = false
    @State private var acuteInjury = false
    @State private var confirmedComplete = false
    @State private var saveFailed = false
    private var hasSymptoms: Bool { pain || bloodOrFever || urinaryOrDischarge || acuteInjury }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Pemeriksaan ini tidak membuat diagnosis. Jawab semua bagian sebelum melanjutkan.", systemImage: "cross.case.fill")
                }
                Section("Tanda keselamatan") {
                    Toggle("Nyeri berat, panggul, testis, atau perut", isOn: $pain)
                    Toggle("Darah, perdarahan, atau demam", isOn: $bloodOrFever)
                    Toggle("Perih saat kencing atau cairan tidak biasa", isOn: $urinaryOrDischarge)
                    Toggle("Cedera, bengkak, atau memar akut", isOn: $acuteInjury)
                    Toggle("Saya sudah membaca dan menjawab semua bagian", isOn: $confirmedComplete)
                }
                Section {
                    Text(hasSymptoms ? "Hentikan latihan. Gejala ini perlu dinilai tenaga kesehatan; kondisi berat atau memburuk memerlukan bantuan segera." : "Jika seluruh jawaban tidak, safety hold dapat diakhiri setelah pemeriksaan ulang ini.")
                        .foregroundStyle(hasSymptoms ? .red : .secondary)
                    Button(hasSymptoms ? "Simpan dan jeda latihan" : "Konfirmasi tidak ada gejala") { save() }
                        .buttonStyle(.borderedProminent).disabled(!confirmedComplete)
                }
            }
            .navigationTitle("Health check")
            .toolbar { Button("Tutup") { dismiss() } }
            .alert("Data belum tersimpan", isPresented: $saveFailed) { Button("Coba lagi") {} } message: { Text("TEMPO tidak dapat memperbarui safety hold dengan aman.") }
        }
    }

    private func save() {
        let success: Bool
        if hasSymptoms {
            let severity = (bloodOrFever || acuteInjury || pain) ? RecommendationSeverity.urgent : .medical
            success = history.recordSafetyHold(reasonCode: "safety.health-check", severity: severity.rawValue, source: "health-check")
        } else {
            success = history.resolveSafetyHoldsAfterClearRecheck()
        }
        if success { dismiss() } else { saveFailed = true }
    }
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TempoPalette.surface1, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1) }
    }
}

struct Metric: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(TempoPalette.primary).monospacedDigit()
                Text(title).font(.subheadline).foregroundStyle(TempoPalette.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(TempoPalette.surface1, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1) }
    }
}

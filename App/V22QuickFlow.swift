import SwiftUI

private extension ImmediateActionChoice {
    var uxTitle: String {
        switch self {
        case .privateSession: "Sesi privat"
        case .reset: "Reset lima menit"
        case .guided: "Sesi terpandu"
        }
    }

    var uxSubtitle: String {
        switch self {
        case .privateSession: "Timer privat dengan bantuan jeda opsional."
        case .reset: "Beri dorongan ruang sebelum memilih langkah berikutnya."
        case .guided: "Latihan terstruktur bila pemulihan dan jadwal memungkinkan."
        }
    }

    var uxIcon: String {
        switch self {
        case .privateSession: "hand.raised.fill"
        case .reset: "wind"
        case .guided: "timer"
        }
    }
}

/// A single-panel replacement for the previous three-page immediate flow.
/// It retains the existing router, persistence, safety hold, and eligibility
/// semantics; only the interaction cost and hierarchy change.
struct TempoImmediateActionSheetScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var selectedChoice: ImmediateActionChoice?
    @State private var intensity: Int
    @State private var noNewSymptoms = true
    @State private var symptomType: DailySymptomType = .mildIrritation
    @State private var saveFailed = false

    init(initialIntensity: Int = 5) {
        // Both Today shortcuts represent an intention to act now. Private is a
        // reversible preselection; reset is never silently selected.
        _selectedChoice = State(initialValue: .privateSession)
        _intensity = State(initialValue: initialIntensity >= 8 ? TempoIntensityZone.critical.numericValue : TempoIntensityZone.medium.numericValue)
    }

    var body: some View {
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.xl) {
                header
                choiceSection
                intensitySection
                symptomSection
            }
        }
        .safeAreaInset(edge: .bottom) {
            TempoStickyActionBar {
                TempoPrimaryButton(
                    ctaTitle,
                    icon: "arrow.right",
                    isEnabled: selectedChoice != nil,
                    accessibilityHint: "Melanjutkan memakai aturan keselamatan dan eligibility yang tersimpan"
                ) {
                    route()
                }
                .accessibilityIdentifier("immediate.start")
            }
        }
        .navigationTitle("Keputusan cepat")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Catatan belum tersimpan", isPresented: $saveFailed) {
            Button("Coba lagi") { route() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("TEMPO tidak meneruskan alur sampai catatan lokal tersimpan dengan aman.")
        }
        .accessibilityIdentifier("immediate.action.v22")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            Text("Apa yang kamu butuhkan sekarang?")
                .font(TempoDesign.Typography.pageTitle)
            Text("Pilih satu langkah, tentukan zona intensitas, lalu konfirmasi kondisi tubuh. Tidak ada reset yang dipilih otomatis.")
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
        }
    }

    private var choiceSection: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            Text("Langkah")
                .font(TempoDesign.Typography.sectionTitle)
            ForEach(ImmediateActionChoice.allCases, id: \.self) { choice in
                TempoSelectionCard(
                    title: choice.uxTitle,
                    subtitle: choice.uxSubtitle,
                    icon: choice.uxIcon,
                    selected: selectedChoice == choice,
                    tone: choice == .reset ? .neutral : .accent
                ) {
                    selectedChoice = choice
                }
                .accessibilityIdentifier("immediate.choice.\(choice.rawValue)")
            }
        }
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Zona intensitas").font(TempoDesign.Typography.sectionTitle)
                Spacer()
                TempoStatusBadge(TempoIntensityZone(numericValue: intensity).title, tone: TempoIntensityZone(numericValue: intensity).tone)
            }
            Text("Lima zona ini tetap disimpan sebagai nilai numerik kompatibel dengan riwayat 2.1.3.")
                .font(TempoDesign.Typography.caption)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
            TempoIntensityZoneControl(numericValue: $intensity, accessibilityIdentifier: "immediate.intensity")
        }
    }

    private var symptomSection: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
            Toggle(isOn: $noNewSymptoms) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tidak ada nyeri atau keluhan baru")
                        .font(TempoDesign.Typography.cardTitle)
                    Text("Matikan bila ada iritasi, nyeri, keluhan saluran kemih, darah, atau demam.")
                        .font(TempoDesign.Typography.caption)
                        .foregroundStyle(TempoDesign.Palette.textSecondary)
                }
            }
            .tint(TempoDesign.Palette.positive)
            .padding(TempoDesign.Spacing.md)
            .background(
                (noNewSymptoms ? TempoDesign.Palette.positive : TempoDesign.Palette.caution).opacity(0.10),
                in: RoundedRectangle(cornerRadius: TempoDesign.Radius.medium)
            )
            .accessibilityIdentifier("immediate.noSymptoms")

            if !noNewSymptoms {
                VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                    Text("Keluhan yang paling sesuai")
                        .font(TempoDesign.Typography.cardTitle)
                    ForEach([DailySymptomType.mildIrritation, .pain, .urinaryOrDischarge, .bloodOrFever], id: \.self) { type in
                        TempoSelectionCard(
                            title: type.displayName,
                            subtitle: type == .mildIrritation ? "TEMPO membuka masa pemulihan dan pemeriksaan ulang." : "TEMPO menghentikan sesi dan membuka pemeriksaan.",
                            icon: type == .mildIrritation ? "leaf.fill" : "cross.case.fill",
                            selected: symptomType == type,
                            tone: type == .mildIrritation ? .caution : .critical
                        ) {
                            symptomType = type
                        }
                        .accessibilityIdentifier("immediate.symptom.\(type.rawValue)")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: TempoDesign.Motion.quick), value: noNewSymptoms)
    }

    private var ctaTitle: String {
        switch selectedChoice {
        case .privateSession: "Mulai sesi privat"
        case .guided: "Mulai sesi terpandu"
        case .reset: "Mulai reset lima menit"
        case .none: "Pilih satu langkah"
        }
    }

    private func route() {
        guard let selectedChoice else { return }
        let intent: UrgeIntent
        switch selectedChoice {
        case .privateSession: intent = .privateSession
        case .reset: intent = .calm
        case .guided: intent = .training
        }

        let activeHold = history.activeSafetyHold
        let todayReadiness = history.todayReadiness
        let immediateAnxiety = todayReadiness?.anxietyToday ?? min(7, history.baseline?.anxiety ?? 5)
        let request = ImmediateActionRequest(
            choice: selectedChoice,
            intensity: intensity,
            anxiety: immediateAnxiety,
            sleepHours: todayReadiness?.sleepHoursLastNight,
            hoursSinceLastGuidedSession: history.hoursSinceLastSession,
            hoursSinceLastPrivateSession: history.hoursSinceLastPrivateSession,
            guidedSessionsLast7Days: history.guidedSessionsLast7Days,
            guidedEligibility: history.guidedEligibility,
            hasCurrentPhysicalSymptoms: !noNewSymptoms,
            hasActiveSafetyHold: history.hasSafetyBlock,
            activeSafetyHoldSeverity: activeHold.flatMap { RecommendationSeverity(rawValue: $0.severity) } ?? (history.hasSafetyBlock ? .medical : nil),
            activeSafetyHoldReason: activeHold?.reasonCode ?? (history.hasSafetyBlock ? "safety.pending-write" : nil),
            activeSafetyHoldRecheckDate: activeHold?.recheckNotBefore
        )
        let result = ImmediateActionRouter().route(request)

        let recommendation: Recommendation
        switch result.destination {
        case .healthCheck:
            recommendation = Recommendation(
                .healthCheck,
                result.activeSafetyHoldSeverity ?? .urgent,
                request.hasCurrentPhysicalSymptoms ? "safety.immediate-\(symptomType.rawValue)" : "immediate.active-safety-hold",
                request.hasCurrentPhysicalSymptoms ? "Gejala fisik perlu diperiksa sebelum melanjutkan." : "Safety hold aktif masih memerlukan pemeriksaan ulang.",
                blocked: true
            )
        case .recoveryBlocked:
            recommendation = Recommendation(.recovery, .caution, "immediate.active-irritation-hold", "Masa pemulihan iritasi masih aktif.", blocked: true)
        case .privateSession:
            recommendation = Recommendation(.privateSession, result.advisories.isEmpty ? .normal : .caution, "immediate.private", "Sesi privat dipilih secara langsung.")
        case .guided:
            recommendation = Recommendation(.guidedSession, .normal, "immediate.guided", "Sesi terpandu tersedia.")
        case .guidedUnavailable:
            recommendation = Recommendation(.recovery, .caution, "immediate.guided-unavailable", result.guidedEligibility?.message ?? "Sesi terpandu belum tersedia.")
        case .reset:
            recommendation = Recommendation(.urgeSurf, .normal, "immediate.reset", "Reset lima menit dipilih.")
        }

        guard history.add(intensity: intensity, trigger: .desire, intent: intent, recommendation: recommendation) else {
            saveFailed = true
            return
        }

        switch result.destination {
        case .healthCheck:
            replaceWith(.healthCheck)
        case .recoveryBlocked:
            replaceWith(.safetyRecoveryBlock(result.activeSafetyHoldReason, result.activeSafetyHoldRecheckDate))
        case .privateSession:
            replaceWith(.privateSession(result.advisories))
        case .guided:
            replaceWith(.guided(nil))
        case .guidedUnavailable:
            let eligibility = result.guidedEligibility ?? history.guidedEligibility
            replaceWith(.guidedUnavailable(eligibility.reason, eligibility.message, history.guidedNextAvailableAt))
        case .reset:
            replaceWith(.breathing(nil, "Reset lima menit", 300))
        }
    }

    private func replaceWith(_ route: TempoRoute) {
        if let last = coordinator.path.last, case .immediateAction = last {
            coordinator.path.removeLast()
        }
        coordinator.open(route)
    }
}

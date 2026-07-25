import SwiftUI

/// Review-branch health check with explicit, full-row confirmation controls.
/// The persisted safety semantics remain in `LocalHistory`; this view only
/// replaces an unreliable custom Toggle hit target.
struct TempoV22HealthCheckScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalHistory.self) private var history

    @State private var answers = SafetyScreeningAnswers()
    @State private var confirmedComplete = false
    @State private var confirmedMedicalFollowUp = false
    @State private var confirmedAllActiveHoldsResolved = false
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if history.requiresMultipleHoldConfirmation {
                Section {
                    ForEach(history.unresolvedSafetyHoldSummaries) { summary in
                        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
                            Text(summary.title)
                                .font(TempoDesign.Typography.cardTitle)
                            Text(summary.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("health.check.holdSummary.\(summary.id.uuidString)")
                    }
                } header: {
                    Text("Ada beberapa catatan keselamatan aktif")
                        .accessibilityIdentifier("health.check.multipleHolds")
                }
            } else if let activeHold = history.activeSafetyHold {
                Section("Safety hold aktif") {
                    Text(activeHoldReason(activeHold.reasonCode))
                        .foregroundStyle(.secondary)
                    if let recheck = activeHold.recheckNotBefore, recheck > .now {
                        Text("Pemeriksaan ulang tersedia sekitar \(recheck.formatted(date: .abbreviated, time: .shortened)).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Tanda keselamatan") {
                SafetyScreeningFields(answers: $answers)

                confirmationRow(
                    "Saya sudah membaca dan menjawab semua bagian",
                    isConfirmed: $confirmedComplete,
                    identifier: "health.check.confirmed"
                )

                if requiresMedicalResolutionConfirmation && !hasSymptoms {
                    confirmationRow(
                        "Gejala sudah hilang atau dinilai tenaga kesehatan",
                        isConfirmed: $confirmedMedicalFollowUp,
                        identifier: "health.check.medicalFollowUp"
                    )
                }

                if history.requiresMultipleHoldConfirmation && !hasSymptoms {
                    confirmationRow(
                        "Saya memastikan semua keluhan yang tercatat sudah hilang atau sudah dinilai tenaga kesehatan.",
                        isConfirmed: $confirmedAllActiveHoldsResolved,
                        identifier: "health.check.confirmedAllActiveHoldsResolved"
                    )
                }
            }

            Section {
                Text(statusMessage)
                    .foregroundStyle(hasSymptoms ? .red : .secondary)

                Button(hasSymptoms ? "Simpan dan jeda latihan" : "Konfirmasi tidak ada gejala") {
                    save()
                }
                .disabled(!canSubmit)
                .accessibilityIdentifier("health.check.submit")
                .accessibilityValue(submitAccessibilityValue)
            }
        }
        .navigationTitle("Pemeriksaan")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Data belum tersimpan", isPresented: $saveFailed) {
            Button("Coba lagi") { save() }
        } message: {
            Text("TEMPO tidak dapat memperbarui safety hold dengan aman.")
        }
        .accessibilityIdentifier("health.check")
    }

    private var statusMessage: String {
        if hasSymptoms {
            return answers.severity == .urgent
                ? "Hentikan latihan dan cari bantuan medis segera sesuai layanan setempat."
                : "Hentikan latihan dan minta penilaian tenaga kesehatan sebelum melanjutkan."
        }
        if let hours = history.safetyHoldRemainingHours {
            return "Masa pemulihan iritasi belum selesai. Periksa ulang setelah sekitar \(hours) jam lagi."
        }
        return "Jika seluruh jawaban tidak, safety hold aktif dapat diakhiri melalui pemeriksaan ulang lengkap ini."
    }

    private var canSubmit: Bool {
        guard confirmedComplete else { return false }
        if hasSymptoms { return true }
        guard history.canResolveActiveSafetyHold else { return false }
        if requiresMedicalResolutionConfirmation && !confirmedMedicalFollowUp { return false }
        if history.requiresMultipleHoldConfirmation && !confirmedAllActiveHoldsResolved { return false }
        return true
    }

    private var submitAccessibilityValue: String {
        canSubmit ? "Siap" : "Belum siap. Lengkapi semua konfirmasi yang diperlukan."
    }

    private func confirmationRow(
        _ title: String,
        isConfirmed: Binding<Bool>,
        identifier: String
    ) -> some View {
        Button {
            isConfirmed.wrappedValue.toggle()
        } label: {
            HStack(alignment: .center, spacing: TempoDesign.Spacing.sm) {
                Image(systemName: isConfirmed.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isConfirmed.wrappedValue ? TempoDesign.Palette.accentSoft : TempoDesign.Palette.textSecondary)
                    .accessibilityHidden(true)

                Text(title)
                    .foregroundStyle(TempoDesign.Palette.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: TempoDesign.Spacing.sm)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityValue(isConfirmed.wrappedValue ? "1" : "0")
        .accessibilityHint("Ketuk untuk mengubah konfirmasi")
    }

    private func activeHoldReason(_ code: String) -> String {
        let normalized = code.lowercased()
        if normalized.contains("blood") { return "Darah pernah dilaporkan. Aktivitas tetap dijeda sampai pemeriksaan ulang aman." }
        if normalized.contains("fever") { return "Demam pernah dilaporkan. Aktivitas tetap dijeda sampai pemeriksaan ulang aman." }
        if normalized.contains("urinary") { return "Keluhan saluran kemih pernah dilaporkan. Aktivitas tetap dijeda sampai pemeriksaan ulang aman." }
        if normalized.contains("discharge") { return "Cairan tidak biasa pernah dilaporkan. Aktivitas tetap dijeda sampai pemeriksaan ulang aman." }
        if normalized.contains("injury") { return "Cedera pernah dilaporkan. Aktivitas tetap dijeda sampai pemeriksaan ulang aman." }
        if normalized.contains("irritation") { return "Iritasi pernah dilaporkan. Beri tubuh waktu pulih dan lakukan pemeriksaan ulang." }
        if normalized.contains("pain") || normalized.contains("symptom") {
            return "Nyeri atau gejala fisik baru pernah dilaporkan. Aktivitas tetap dijeda sampai pemeriksaan ulang aman."
        }
        return "Safety hold aktif yang tersimpan masih memerlukan pemeriksaan ulang sebelum sesi dapat dimulai."
    }

    private func save() {
        let success = hasSymptoms
            ? history.recordSafetyHold(
                reasonCode: answers.reasonCode,
                severity: answers.severity.rawValue,
                source: "health-check"
            )
            : history.resolveActiveSafetyHoldAfterClearRecheck(
                confirmedAllActiveHoldsResolved: confirmedAllActiveHoldsResolved
            )

        if success {
            dismiss()
        } else {
            saveFailed = true
        }
    }
}

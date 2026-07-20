import Foundation
import SwiftUI

struct TempoProgressTrendEngine {
    private struct Sample {
        let date: Date
        let value: Double
    }

    func trends(
        sessions: [LocalSession],
        privateSessions: [LocalPrivateSession],
        plan: [LocalPlanDay],
        through date: Date = .now
    ) -> [TempoProgressTrend] {
        [
            boundaryTrend(sessions),
            recoveryTrend(sessions: sessions, privateSessions: privateSessions),
            emergencyTrend(sessions: sessions, privateSessions: privateSessions),
            consistencyTrend(plan: plan, through: date),
            anxietyTrend(sessions)
        ]
    }

    private func boundaryTrend(_ sessions: [LocalSession]) -> TempoProgressTrend {
        let samples = sessions.compactMap { session -> Sample? in
            guard let pauses = session.pauseCycles, !pauses.isEmpty else { return nil }
            let controlled = pauses.filter { $0.successful && !$0.lateStop }.count
            return Sample(date: session.completedAt, value: Double(controlled) / Double(pauses.count))
        }
        return comparativeTrend(
            kind: .boundaryAwareness,
            samples: samples,
            higherIsBetter: true,
            stableHeadline: { value in "\(Int((value * 100).rounded()))% jeda tercatat sebelum terlambat" },
            improvingHeadline: "Lebih sering mengenali batas sebelum mendekati terlambat.",
            attentionHeadline: "Jeda terlambat lebih sering muncul pada tiga sesi terakhir.",
            detail: { current, previous in
                guard let previous else { return "Dihitung dari pause cycle sesi terpandu yang benar-benar tersimpan." }
                return "Tiga sesi terakhir \(Int((current * 100).rounded()))%, sebelumnya \(Int((previous * 100).rounded()))%."
            }
        )
    }

    private func recoveryTrend(sessions: [LocalSession], privateSessions: [LocalPrivateSession]) -> TempoProgressTrend {
        var samples = sessions.compactMap { session -> Sample? in
            let seconds: Int?
            if let stored = session.recoverySeconds {
                seconds = stored
            } else if let pauses = session.pauseCycles, !pauses.isEmpty {
                seconds = pauses.reduce(0) { $0 + max(0, $1.endOffset - $1.startOffset) }
            } else {
                seconds = nil
            }
            guard let seconds, seconds > 0 else { return nil }
            return Sample(date: session.completedAt, value: Double(seconds))
        }
        samples += privateSessions.compactMap { session in
            guard let seconds = session.totalRecoverySeconds, seconds > 0 else { return nil }
            return Sample(date: session.completedAt, value: Double(seconds))
        }
        return comparativeTrend(
            kind: .recovery,
            samples: samples,
            higherIsBetter: false,
            stableHeadline: { "Rata-rata pemulihan \(duration(Int($0.rounded())))" },
            improvingHeadline: "Waktu pemulihan rata-rata menjadi lebih singkat.",
            attentionHeadline: "Pemulihan membutuhkan waktu lebih panjang belakangan ini.",
            detail: { current, previous in
                guard let previous else { return "Menggabungkan recovery time guided dan private yang tersimpan." }
                return "Tiga sesi terakhir \(duration(Int(current.rounded()))), sebelumnya \(duration(Int(previous.rounded())))."
            }
        )
    }

    private func emergencyTrend(sessions: [LocalSession], privateSessions: [LocalPrivateSession]) -> TempoProgressTrend {
        var samples = sessions.map { session in
            let count = session.pauseCycles?.filter(\.lateStop).count ?? (session.lateStopOccurred == true ? 1 : 0)
            return Sample(date: session.completedAt, value: Double(count))
        }
        samples += privateSessions.map { session in
            Sample(date: session.completedAt, value: Double(session.emergencyPauseCount ?? (session.tooFast == true ? 1 : 0)))
        }
        return comparativeTrend(
            kind: .emergencyPause,
            samples: samples,
            higherIsBetter: false,
            stableHeadline: { "Rata-rata \($0.formatted(.number.precision(.fractionLength(0...1)))) emergency pause per sesi" },
            improvingHeadline: "Emergency pause lebih jarang pada tiga sesi terakhir.",
            attentionHeadline: "Emergency pause lebih sering pada tiga sesi terakhir.",
            detail: { current, previous in
                guard let previous else { return "Dihitung dari late-stop guided dan emergency pause private." }
                return "Tiga sesi terakhir \(current.formatted(.number.precision(.fractionLength(0...1)))), sebelumnya \(previous.formatted(.number.precision(.fractionLength(0...1))))."
            }
        )
    }

    private func consistencyTrend(plan: [LocalPlanDay], through date: Date) -> TempoProgressTrend {
        let engine = ProgressEngine()
        let items = plan.map(ProgramPlanItem.init(localDay:))
        let current = engine.consistency(for: items, through: date)
        let previousDate = Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date.addingTimeInterval(-7 * 86_400)
        let previous = engine.consistency(for: items, through: previousDate)
        let dueCount = items.filter { engine.consistencyEligibility(for: $0, through: date) == .required }.count

        guard let current else {
            return TempoProgressTrend(
                kind: .consistency,
                state: .insufficient,
                headline: "Belum ada aktivitas yang jatuh tempo.",
                detail: "Aktivitas mendatang dan pemulihan yang dikecualikan tidak dihitung.",
                currentValue: nil,
                previousValue: nil,
                sampleCount: dueCount
            )
        }

        let state: TempoTrendState
        if dueCount < 3 || previous == nil {
            state = .stable
        } else if current - (previous ?? current) >= 0.10 {
            state = .improving
        } else if (previous ?? current) - current >= 0.10 {
            state = .attention
        } else {
            state = .stable
        }
        return TempoProgressTrend(
            kind: .consistency,
            state: state,
            headline: "\(Int((current * 100).rounded()))% aktivitas yang wajib sudah selesai",
            detail: "Source yang ditunda, future item, dan recovery yang dikecualikan tidak masuk denominator.",
            currentValue: current,
            previousValue: previous,
            sampleCount: dueCount
        )
    }

    private func anxietyTrend(_ sessions: [LocalSession]) -> TempoProgressTrend {
        let samples = sessions.compactMap { session -> Sample? in
            guard let post = session.postAnxiety else { return nil }
            return Sample(date: session.completedAt, value: Double(post))
        }
        return comparativeTrend(
            kind: .sessionAnxiety,
            samples: samples,
            higherIsBetter: false,
            stableHeadline: { "Kecemasan setelah sesi rata-rata \($0.formatted(.number.precision(.fractionLength(0...1))))/10" },
            improvingHeadline: "Kecemasan setelah sesi lebih rendah pada tiga sesi terakhir.",
            attentionHeadline: "Kecemasan setelah sesi lebih tinggi pada tiga sesi terakhir.",
            detail: { current, previous in
                guard let previous else { return "Menggunakan nilai post-session, bukan readiness lama sebagai kondisi hari ini." }
                return "Tiga sesi terakhir \(current.formatted(.number.precision(.fractionLength(0...1))))/10, sebelumnya \(previous.formatted(.number.precision(.fractionLength(0...1))))/10."
            }
        )
    }

    private func comparativeTrend(
        kind: TempoProgressTrendKind,
        samples: [Sample],
        higherIsBetter: Bool,
        stableHeadline: (Double) -> String,
        improvingHeadline: String,
        attentionHeadline: String,
        detail: (Double, Double?) -> String
    ) -> TempoProgressTrend {
        let sorted = samples.sorted { $0.date < $1.date }
        guard sorted.count >= 3 else {
            return TempoProgressTrend(
                kind: kind,
                state: .insufficient,
                headline: "Butuh \(max(0, 3 - sorted.count)) catatan lagi.",
                detail: "TEMPO tidak membuat arah tren sebelum minimal tiga sampel tersimpan.",
                currentValue: sorted.last?.value,
                previousValue: nil,
                sampleCount: sorted.count
            )
        }

        let currentWindow = Array(sorted.suffix(3))
        let current = average(currentWindow)
        guard sorted.count >= 6 else {
            return TempoProgressTrend(
                kind: kind,
                state: .stable,
                headline: stableHeadline(current),
                detail: detail(current, nil),
                currentValue: current,
                previousValue: nil,
                sampleCount: sorted.count
            )
        }

        let previousWindow = Array(sorted.dropLast(3).suffix(3))
        let previous = average(previousWindow)
        let relativeChange = previous == 0 ? current - previous : (current - previous) / abs(previous)
        let improved = higherIsBetter ? relativeChange >= 0.10 : relativeChange <= -0.10
        let attention = higherIsBetter ? relativeChange <= -0.10 : relativeChange >= 0.10
        let state: TempoTrendState = improved ? .improving : (attention ? .attention : .stable)
        let headline = improved ? improvingHeadline : (attention ? attentionHeadline : stableHeadline(current))
        return TempoProgressTrend(
            kind: kind,
            state: state,
            headline: headline,
            detail: detail(current, previous),
            currentValue: current,
            previousValue: previous,
            sampleCount: sorted.count
        )
    }

    private func average(_ samples: [Sample]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.value).reduce(0, +) / Double(samples.count)
    }

    private func duration(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return safe >= 60 ? "\(safe / 60)m \(safe % 60)d" : "\(safe)d"
    }
}

struct TempoV22ProgressScreen: View {
    @Environment(LocalHistory.self) private var history
    @Environment(TempoCoordinator.self) private var coordinator
    @State private var showTechnicalScores = false

    private var trends: [TempoProgressTrend] {
        TempoProgressTrendEngine().trends(
            sessions: history.sessions,
            privateSessions: history.privateSessions,
            plan: history.plannedDays
        )
    }

    var body: some View {
        TempoScreenContainer {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.lg) {
                header
                ForEach(trends) { trend in
                    TempoTrendCard(trend: trend)
                }
                technicalScores
                TempoSecondaryButton("Tinjauan mingguan", icon: "calendar.badge.checkmark", tone: .accent) {
                    coordinator.open(.weeklyReview)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("tab.progress")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            Text("Progres").font(TempoDesign.Typography.display)
            Text("Tren berasal dari catatan yang benar-benar tersimpan. Angka teknis tidak digunakan sebagai nilai diri.")
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
        }
    }

    private var technicalScores: some View {
        TempoDisclosureSection(title: "Lihat skor teknis", icon: "function", isExpanded: $showTechnicalScores) {
            VStack(alignment: .leading, spacing: TempoDesign.Spacing.sm) {
                switch history.progressPresentation {
                case .baseline:
                    TempoEmptyState(
                        title: "Belum ada skor teknis",
                        message: "Mulai dari pola dan beberapa aktivitas terlebih dahulu.",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                case let .collecting(samplesNeeded):
                    TempoCompactStatusRow(
                        title: "Sedang mengenali pola",
                        detail: "Butuh sekitar \(samplesNeeded) sesi terpandu lagi.",
                        icon: "ellipsis.circle",
                        tone: .neutral
                    )
                case let .ready(scores):
                    technicalScore("Kesadaran", scores.awareness, tone: .accent)
                    technicalScore("Kontrol", scores.control, tone: .accent)
                    technicalScore("Pemulihan", scores.recovery, tone: .positive)
                    technicalScore("Ketenangan", scores.calm, tone: .positive)
                }
            }
        }
    }

    private func technicalScore(_ title: String, _ value: Int, tone: TempoBadgeTone) -> some View {
        VStack(alignment: .leading, spacing: TempoDesign.Spacing.xs) {
            HStack { Text(title).font(TempoDesign.Typography.cardTitle); Spacer(); Text("\(value)").font(TempoDesign.Typography.numeric).foregroundStyle(tone.color) }
            ProgressView(value: Double(value), total: 100).tint(tone.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value) dari 100")
    }
}

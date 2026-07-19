import SwiftUI

struct SafetyScreeningAnswers: Equatable {
    var severeOrPelvicPain = false
    var bloodOrFever = false
    var urinaryOrDischarge = false
    var acuteInjury = false
    var mildIrritation = false

    var hasAny: Bool {
        severeOrPelvicPain || bloodOrFever || urinaryOrDischarge || acuteInjury || mildIrritation
    }

    var severity: RecommendationSeverity {
        if severeOrPelvicPain || bloodOrFever || acuteInjury { return .urgent }
        if urinaryOrDischarge { return .medical }
        if mildIrritation { return .caution }
        return .normal
    }

    var reasonCode: String {
        if severeOrPelvicPain || bloodOrFever || acuteInjury { return "safety.urgent" }
        if urinaryOrDischarge { return "safety.urinary" }
        if mildIrritation { return "safety.irritation" }
        return "safety.clear"
    }

}

struct SafetyScreeningFields: View {
    @Binding var answers: SafetyScreeningAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Nyeri berat, panggul, testis, atau perut", isOn: $answers.severeOrPelvicPain)
            Toggle("Darah, perdarahan, atau demam", isOn: $answers.bloodOrFever)
            Toggle("Perih saat kencing atau cairan tidak biasa", isOn: $answers.urinaryOrDischarge)
            Toggle("Cedera, bengkak, atau memar akut", isOn: $answers.acuteInjury)
            Toggle("Iritasi atau rasa perih ringan", isOn: $answers.mildIrritation)
        }
    }
}

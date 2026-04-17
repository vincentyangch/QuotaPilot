import SwiftUI

struct RulesSettingsView: View {
    let model: AppModel

    private var thresholdBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.switchThresholdPercent },
            set: { self.model.updateSwitchThreshold($0) }
        )
    }

    private var minimumAdvantageBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.minimumScoreAdvantage },
            set: { self.model.updateMinimumScoreAdvantage($0) }
        )
    }

    private var remainingWeightBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.remainingWeight },
            set: { self.model.updateRemainingWeight($0) }
        )
    }

    private var resetWeightBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.resetWeight },
            set: { self.model.updateResetWeight($0) }
        )
    }

    private var priorityWeightBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.priorityWeight },
            set: { self.model.updatePriorityWeight($0) }
        )
    }

    var body: some View {
        Form {
            Section("Switching Rules") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Switch threshold")
                    Stepper("\(self.thresholdBinding.wrappedValue)% remaining", value: self.thresholdBinding, in: 0...100)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Minimum score advantage")
                    Stepper("\(self.minimumAdvantageBinding.wrappedValue) points", value: self.minimumAdvantageBinding, in: 0...100)
                }
            }

            Section("Scoring Weights") {
                Stepper("Remaining quota weight: \(self.remainingWeightBinding.wrappedValue)", value: self.remainingWeightBinding, in: 0...5)
                Stepper("Reset urgency weight: \(self.resetWeightBinding.wrappedValue)", value: self.resetWeightBinding, in: 0...5)
                Stepper("Profile priority weight: \(self.priorityWeightBinding.wrappedValue)", value: self.priorityWeightBinding, in: 0...5)
            }

            Section("Scope") {
                Text("These rules currently apply separately within Codex and Claude, so each provider keeps its own best active account.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset to defaults") {
                    self.model.resetRules()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(20)
    }
}

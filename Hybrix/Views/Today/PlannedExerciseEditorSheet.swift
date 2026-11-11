import SwiftUI

struct PlannedExerciseEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let slotItem: ComputedPlannedExerciseItem
    let gym: GymProfile
    let allExercises: [Exercise]
    let weightUnit: WeightUnit
    let onSaveOverride: (PlannedExercisePrescriptionOverride) -> Void
    let onResetToDefault: () -> Void

    @State private var workingSets: Int
    @State private var repMin: Int
    @State private var repMax: Int
    @State private var restSeconds: Int
    @State private var targetStartingWeight: Double
    @State private var selectedExercise: Exercise
    @State private var showingSwapList: Bool = false

    init(
        slotItem: ComputedPlannedExerciseItem,
        gym: GymProfile,
        allExercises: [Exercise],
        weightUnit: WeightUnit,
        onSaveOverride: @escaping (PlannedExercisePrescriptionOverride) -> Void,
        onResetToDefault: @escaping () -> Void
    ) {
        self.slotItem = slotItem
        self.gym = gym
        self.allExercises = allExercises
        self.weightUnit = weightUnit
        self.onSaveOverride = onSaveOverride
        self.onResetToDefault = onResetToDefault

        _workingSets = State(initialValue: slotItem.workingSets)
        _repMin = State(initialValue: slotItem.repRangeMin)
        _repMax = State(initialValue: slotItem.repRangeMax)
        _restSeconds = State(initialValue: slotItem.restSeconds)
        _targetStartingWeight = State(initialValue: slotItem.recommendedWeight)
        _selectedExercise = State(initialValue: slotItem.resolution.activeExercise)
    }

    private var estimatedMinutesPreview: Int {
        let setup = 45.0
        let work = Double(workingSets) * Double(selectedExercise.averageSecondsPerWorkingSet + restSeconds)
        return max(2, Int(((setup + work) / 60.0).rounded()))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected Lift for \(gym.name)") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedExercise.name)
                                .font(.headline)
                            Text("\(selectedExercise.primaryMuscle.rawValue) · \(selectedExercise.equipmentSummary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            showingSwapList = true
                        } label: {
                            Label("Swap Lift", systemImage: "arrow.left.arrow.right")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }

                    if !selectedExercise.formCues.isEmpty {
                        Text("💡 \(selectedExercise.formCues)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Customize Prescription for Today") {
                    Stepper(
                        "Working Sets: \(workingSets)",
                        value: $workingSets,
                        in: 1...10
                    )

                    Stepper(
                        "Min Target Reps: \(repMin)",
                        value: $repMin,
                        in: 1...30,
                        onEditingChanged: { _ in
                            if repMax < repMin { repMax = repMin }
                        }
                    )

                    Stepper(
                        "Max Target Reps: \(repMax)",
                        value: $repMax,
                        in: repMin...40
                    )

                    Stepper(
                        "Rest Between Sets: \(restSeconds) sec",
                        value: $restSeconds,
                        in: 30...300,
                        step: 15
                    )
                }

                Section("Target Starting Weight (\(weightUnit.rawValue.uppercased()))") {
                    Stepper(
                        "Starting Load: \(Int(targetStartingWeight)) \(weightUnit.rawValue)",
                        value: $targetStartingWeight,
                        in: 0...1000,
                        step: UserSettings.shared.smallestWeightIncrement
                    )

                    HStack(spacing: 8) {
                        ForEach([-10.0, -5.0, +5.0, +10.0], id: \.self) { delta in
                            Button {
                                targetStartingWeight = max(0, targetStartingWeight + delta)
                            } label: {
                                Text(delta > 0 ? "+\(Int(delta))" : "\(Int(delta))")
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("Exact Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField(
                            "0",
                            value: $targetStartingWeight,
                            format: .number
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.orange)
                        .frame(width: 90)
                        Text(weightUnit.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack {
                        Label("Estimated Slot Time", systemImage: "clock")
                        Spacer()
                        Text("~\(estimatedMinutesPreview) min")
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }

                    if slotItem.hasManualPrescriptionOverride {
                        Button(role: .destructive) {
                            onResetToDefault()
                            dismiss()
                        } label: {
                            Label("Reset to Program Default", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .navigationTitle("Edit Lift Prescription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSaveOverride(
                            PlannedExercisePrescriptionOverride(
                                workingSets: workingSets,
                                repRangeMin: repMin,
                                repRangeMax: max(repMin, repMax),
                                restSeconds: restSeconds,
                                targetStartingWeight: targetStartingWeight,
                                customExercise: selectedExercise
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showingSwapList) {
                ExerciseSwapPickerSheet(
                    slotItem: slotItem,
                    gym: gym,
                    allExercises: allExercises
                ) { picked in
                    selectedExercise = picked
                    targetStartingWeight = picked.baselineWorkingWeightLbs
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

import SwiftUI
import SwiftData

struct WorkoutLogEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let log: WorkoutLog
    @State private var settings = UserSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details & Notes") {
                    HStack {
                        Text("Workout")
                        Spacer()
                        Text(log.dayTemplateName)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(log.date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    TextField("Session Notes", text: Binding(
                        get: { log.notes },
                        set: { log.notes = $0 }
                    ), axis: .vertical)
                    .lineLimit(2...4)
                }

                ForEach(log.sortedExercises) { loggedEx in
                    Section(loggedEx.exercise?.name ?? loggedEx.exerciseNameSnapshot) {
                        ForEach(loggedEx.sortedSets) { setItem in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(setItem.setType == .warmup ? "Warmup \(setItem.setNumber)" : "Set \(setItem.setNumber)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(setItem.setType == .warmup ? .yellow : .orange)
                                    Spacer()
                                    Toggle("Completed", isOn: Binding(
                                        get: { setItem.isCompleted },
                                        set: { setItem.isCompleted = $0 }
                                    ))
                                    .labelsHidden()
                                }

                                HStack(spacing: 12) {
                                    Stepper(
                                        "\(GymProfile.formatCleanNumber(setItem.weight)) \(settings.weightUnit.rawValue)",
                                        value: Binding(
                                            get: { setItem.weight },
                                            set: { setItem.weight = max(0, $0) }
                                        ),
                                        in: 0...1500,
                                        step: settings.smallestWeightIncrement
                                    )
                                    .font(.caption.weight(.semibold))

                                    Stepper(
                                        "\(setItem.reps) reps",
                                        value: Binding(
                                            get: { setItem.reps },
                                            set: { setItem.reps = max(0, $0) }
                                        ),
                                        in: 0...100
                                    )
                                    .font(.caption.weight(.semibold))
                                }

                                if setItem.setType != .warmup {
                                    Stepper(
                                        "Effort: \(setItem.rir) RIR remaining",
                                        value: Binding(
                                            get: { setItem.rir },
                                            set: { setItem.rir = max(0, min(5, $0)) }
                                        ),
                                        in: 0...5
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .navigationTitle("Edit Workout Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        recalculateLogCaloriesAndSave()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func recalculateLogCaloriesAndSave() {
        let completedSets = log.sortedExercises.reduce(0) {
            $0 + $1.sortedSets.filter { $0.isCompleted && $0.setType != .warmup }.count
        }
        log.caloriesBurned = CalorieEstimator.estimateCalories(
            durationSeconds: max(60, log.durationSeconds),
            totalVolumeLbs: log.totalVolumeLbs,
            completedSetsCount: max(1, completedSets),
            finisherDurationSeconds: log.loggedFinisher?.totalDurationSeconds ?? 0,
            finisherFormat: log.loggedFinisher?.format
        )
        try? modelContext.save()
    }
}

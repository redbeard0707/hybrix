import SwiftUI

struct ExerciseHistoryPopupSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    let history: [WorkoutLog]
    let weightUnit: WeightUnit

    private var matchingSessions: [(log: WorkoutLog, sets: [LoggedSet])] {
        var results: [(WorkoutLog, [LoggedSet])] = []
        for log in history.sorted(by: { $0.date > $1.date }) {
            let matchingItems = log.sortedExercises.filter {
                $0.exercise?.id == exercise.id || $0.exerciseNameSnapshot == exercise.name
            }
            let completedSets = matchingItems.flatMap { $0.sortedSets.filter(\.isCompleted) }
            if !completedSets.isEmpty {
                results.append((log, completedSets))
            }
        }
        return results
    }

    private var actualBest: PeriodizationEngine.HistoricalActualBest? {
        PeriodizationEngine.historicalActualBest(for: exercise, in: history)
    }

    var body: some View {
        NavigationStack {
            List {
                // Actual Lift PR Banner (Strict Actual Weight & Reps, NOT e1RM)
                Section("All-Time Actual Lift PR") {
                    if let best = actualBest {
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                                .frame(width: 42, height: 42)
                                .background(Color.yellow.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(GymProfile.formatCleanNumber(best.maxWeight)) \(weightUnit.rawValue) × \(best.maxRepsAtMaxWeight) reps")
                                    .font(.headline.weight(.black))
                                Text("Actual Lift Record · \(best.date.formatted(date: .abbreviated, time: .omitted)) at \(best.gymName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("No completed working sets logged for \(exercise.name) yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Past Sessions (\(matchingSessions.count))") {
                    if matchingSessions.isEmpty {
                        Text("Complete your first session of \(exercise.name) to track set-by-set history here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matchingSessions, id: \.log.id) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(entry.log.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline.weight(.bold))
                                    Text("· 📍 \(entry.log.selectedGym?.name ?? entry.log.selectedGymNameSnapshot)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Wk \(entry.log.weekIndex)")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.18))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }

                                ForEach(entry.sets) { s in
                                    HStack {
                                        Text(s.setType == .warmup ? "Warmup \(s.setNumber)" : "Set \(s.setNumber)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(s.setType == .warmup ? .yellow : .secondary)
                                            .frame(width: 72, alignment: .leading)

                                        Text("\(GymProfile.formatCleanNumber(s.weight)) \(weightUnit.rawValue) × \(s.reps) reps")
                                            .font(.caption.weight(.bold))

                                        Spacer()

                                        if s.setType != .warmup {
                                            Text("\(s.rir) RIR")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Color(.tertiarySystemGroupedBackground))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

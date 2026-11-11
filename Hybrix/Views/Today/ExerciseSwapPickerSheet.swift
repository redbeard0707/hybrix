import SwiftUI

struct ExerciseSwapPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let slotItem: ComputedPlannedExerciseItem
    let gym: GymProfile
    let allExercises: [Exercise]
    let onSelect: (Exercise) -> Void

    @State private var searchText: String = ""
    @State private var showOnlyGymSupported: Bool = true

    private var filteredAllExercises: [Exercise] {
        allExercises.filter { ex in
            let matchesGym = !showOnlyGymSupported || gym.supports(ex)
            let matchesSearch = searchText.isEmpty ||
                ex.name.localizedCaseInsensitiveContains(searchText) ||
                ex.primaryMuscle.rawValue.localizedCaseInsensitiveContains(searchText) ||
                ex.movementPattern.rawValue.localizedCaseInsensitiveContains(searchText)
            return matchesGym && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: gym.iconName)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Swapping for \(gym.name)")
                                .font(.subheadline.weight(.semibold))
                            Text("Original: \(slotItem.resolution.originalExercise.name) (\(slotItem.resolution.originalExercise.movementPattern.rawValue))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Only show lifts supported by \(gym.name)", isOn: $showOnlyGymSupported)
                        .font(.caption)
                }

                if !slotItem.resolution.alternatives.isEmpty && searchText.isEmpty {
                    Section("Best Movement & Muscle Matches at \(gym.name)") {
                        ForEach(slotItem.resolution.alternatives.prefix(6)) { match in
                            Button {
                                onSelect(match.exercise)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(match.exercise.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            if match.exercise.id == slotItem.resolution.activeExercise.id {
                                                Text("Current")
                                                    .font(.caption2.weight(.bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange.opacity(0.2))
                                                    .foregroundStyle(.orange)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        Text(match.matchReason)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(match.exercise.equipmentSummary)
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                    Spacer()
                                    Text("\(match.score)%")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }

                Section("All Available Lifts (\(filteredAllExercises.count))") {
                    ForEach(filteredAllExercises) { ex in
                        Button {
                            onSelect(ex)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("\(ex.primaryMuscle.rawValue) · \(ex.movementPattern.rawValue) · \(ex.equipmentSummary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !gym.supports(ex) {
                                    Text("Missing Gear")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search lifts, muscles, patterns...")
            .navigationTitle("Swap Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

import SwiftUI
import SwiftData

struct ExerciseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var exerciseToEdit: Exercise? = nil

    @State private var name: String = ""
    @State private var movementPattern: MovementPattern = .horizontalPush
    @State private var primaryMuscle: MuscleGroup = .chest
    @State private var secondaryMuscles: Set<MuscleGroup> = []
    @State private var mechanicType: MechanicType = .compound
    @State private var tierPriority: ExerciseTier = .tier2SecondaryCompound
    @State private var selectedEquipment: Set<EquipmentType> = []
    @State private var baselineWeight: Double = 65
    @State private var defaultRestSeconds: Int = 90
    @State private var isUnilateral: Bool = false
    @State private var formCues: String = ""
    @State private var didLoadInitialState: Bool = false
    @State private var showingDeleteExerciseConfirm: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exerciseToEdit == nil ? "Tagged as Custom Addition" : "Custom Tag & Protection")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("Saved lifts are marked with the Custom tag in Gyms & Lifts and will never be replaced by built-in database updates.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Lift Details") {
                    TextField("Exercise Name", text: $name)

                    Picker("Movement Pattern", selection: $movementPattern) {
                        ForEach(MovementPattern.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }

                    Picker("Primary Muscle", selection: $primaryMuscle) {
                        ForEach(MuscleGroup.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }

                    Picker("Mechanic", selection: $mechanicType) {
                        ForEach(MechanicType.allCases) { mt in
                            Text(mt.rawValue).tag(mt)
                        }
                    }

                    Picker("Time-Budget Priority Tier", selection: $tierPriority) {
                        ForEach(ExerciseTier.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }

                    Toggle("Unilateral (Single-Arm / Single-Leg)", isOn: $isUnilateral)
                }

                Section("Baseline Working Load & Rest") {
                    Stepper("Default Working Weight: \(Int(baselineWeight)) lbs", value: $baselineWeight, in: 0...600, step: 5)
                    Stepper("Default Rest Timer: \(defaultRestSeconds)s", value: $defaultRestSeconds, in: 30...240, step: 15)
                    TextField("Form Cues / Setup Notes", text: $formCues, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Secondary Muscles (Optional)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MuscleGroup.allCases.filter { $0 != primaryMuscle }) { muscle in
                                let isSelected = secondaryMuscles.contains(muscle)
                                Button {
                                    if isSelected {
                                        secondaryMuscles.remove(muscle)
                                    } else {
                                        secondaryMuscles.insert(muscle)
                                    }
                                } label: {
                                    Text(muscle.rawValue)
                                        .font(.caption.weight(isSelected ? .bold : .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.orange.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
                                        .foregroundStyle(isSelected ? .orange : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Text(selectedEquipment.isEmpty
                         ? "No equipment selected: defaults to Bodyweight / Floor."
                         : "\(selectedEquipment.count) equipment item(s) selected: \(selectedEquipment.map(\.rawValue).sorted().joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(selectedEquipment.isEmpty ? Color.secondary : Color.orange)
                } header: {
                    Text("Required Equipment")
                }

                ForEach(EquipmentCategory.allCases) { category in
                    Section {
                        ForEach(EquipmentType.items(for: category)) { eq in
                            let isSel = selectedEquipment.contains(eq)
                            Button {
                                if isSel {
                                    selectedEquipment.remove(eq)
                                } else {
                                    selectedEquipment.insert(eq)
                                }
                            } label: {
                                HStack {
                                    Text(eq.rawValue)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSel ? .orange : Color(.tertiaryLabel))
                                }
                            }
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }

                if let existing = exerciseToEdit, existing.isCustom {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteExerciseConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Custom Lift", systemImage: "trash")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("Past workout logs referencing \(existing.name) will remain completely intact.")
                    }
                }
            }
            .navigationTitle(exerciseToEdit == nil ? "Add Custom Lift" : "Edit Lift")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Delete \"\(exerciseToEdit?.name ?? "Custom Lift")\"?",
                isPresented: $showingDeleteExerciseConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Custom Lift", role: .destructive) {
                    if let existing = exerciseToEdit {
                        modelContext.delete(existing)
                        try? modelContext.save()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All past workouts and set history referencing this exercise will remain intact in your history.")
            }
            .onAppear {
                guard !didLoadInitialState else { return }
                didLoadInitialState = true
                if let ex = exerciseToEdit {
                    name = ex.name
                    movementPattern = ex.movementPattern
                    primaryMuscle = ex.primaryMuscle
                    secondaryMuscles = Set(ex.secondaryMuscles)
                    mechanicType = ex.mechanicType
                    tierPriority = ex.tierPriority
                    selectedEquipment = Set(ex.requiredEquipment)
                    baselineWeight = ex.baselineWorkingWeightLbs
                    defaultRestSeconds = ex.defaultRestSeconds
                    isUnilateral = ex.isUnilateral
                    formCues = ex.formCues
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExercise()
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmedName.isEmpty ? "Custom Lift" : trimmedName
        let filteredSecondary = Array(secondaryMuscles.filter { $0 != primaryMuscle })
        let finalEquipment = selectedEquipment.isEmpty ? [.bodyweight] : Array(selectedEquipment)

        if let existing = exerciseToEdit {
            existing.name = finalName
            existing.isCustom = true
            existing.movementPattern = movementPattern
            existing.primaryMuscle = primaryMuscle
            existing.secondaryMuscles = filteredSecondary
            existing.requiredEquipment = finalEquipment
            existing.mechanicType = mechanicType
            existing.tierPriority = tierPriority
            existing.baselineWorkingWeightLbs = baselineWeight
            existing.defaultRestSeconds = defaultRestSeconds
            existing.isUnilateral = isUnilateral
            existing.formCues = formCues
        } else {
            let ex = Exercise(
                name: finalName,
                isCustom: true,
                movementPattern: movementPattern,
                primaryMuscle: primaryMuscle,
                secondaryMuscles: filteredSecondary,
                requiredEquipment: finalEquipment,
                mechanicType: mechanicType,
                tierPriority: tierPriority,
                defaultRestSeconds: defaultRestSeconds,
                baselineWorkingWeightLbs: baselineWeight,
                isUnilateral: isUnilateral,
                formCues: formCues
            )
            modelContext.insert(ex)
        }
        try? modelContext.save()
        dismiss()
    }
}

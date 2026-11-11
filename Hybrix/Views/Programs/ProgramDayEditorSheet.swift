import SwiftUI
import SwiftData

struct PreferredPrimaryLiftsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mesocycle: Mesocycle
    let allExercises: [Exercise]

    private let primaryPatterns: [MovementPattern] = [
        .horizontalPush,
        .inclinePush,
        .verticalPush,
        .horizontalPull,
        .verticalPull,
        .squat,
        .hipHinge,
        .unilateralLeg
    ]

    @State private var selectionsByPattern: [MovementPattern: UUID] = [:]
    @State private var alsoUpdateExistingDaySlots: Bool = true

    init(mesocycle: Mesocycle, allExercises: [Exercise]) {
        self.mesocycle = mesocycle
        self.allExercises = allExercises

        var initial: [MovementPattern: UUID] = [:]
        for pat in primaryPatterns {
            if let savedID = mesocycle.preferredExerciseID(for: pat) {
                initial[pat] = savedID
            } else if let firstDayMatch = mesocycle.sortedDays
                .flatMap(\.sortedSlots)
                .compactMap(\.preferredExercise)
                .first(where: { $0.movementPattern == pat }) {
                initial[pat] = firstDayMatch.id
            }
        }
        _selectionsByPattern = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "star.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text("Choose your preferred primary lift for each movement pattern. Hybrix will automatically use these exercises wherever that pattern appears in \"\(mesocycle.name)\".")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Toggle("Also update existing day templates in this block", isOn: $alsoUpdateExistingDaySlots)
                        .font(.caption)
                }

                Section("Primary Movement Patterns") {
                    ForEach(primaryPatterns) { pattern in
                        let matchingExercises = allExercises.filter {
                            $0.movementPattern == pattern && !$0.isCoreExercise
                        }

                        Picker(pattern.rawValue, selection: Binding(
                            get: {
                                selectionsByPattern[pattern] ?? matchingExercises.first?.id ?? UUID()
                            },
                            set: { newID in
                                selectionsByPattern[pattern] = newID
                            }
                        )) {
                            ForEach(matchingExercises) { ex in
                                Text("\(ex.name) (\(ex.equipmentSummary))").tag(ex.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Preferred Primary Lifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePreferences()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func savePreferences() {
        for pat in primaryPatterns {
            if let chosenID = selectionsByPattern[pat],
               let chosenEx = allExercises.first(where: { $0.id == chosenID }) {
                mesocycle.setPreferredExercise(chosenEx, for: pat)

                if alsoUpdateExistingDaySlots {
                    for day in mesocycle.sortedDays {
                        for slot in day.sortedSlots where slot.tierPriority <= .tier2SecondaryCompound {
                            if slot.preferredExercise?.movementPattern == pat {
                                slot.preferredExercise = chosenEx
                            }
                        }
                    }
                }
            }
        }
        try? modelContext.save()
    }
}

struct ProgramDayEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let dayTemplate: ProgramDayTemplate
    let allExercises: [Exercise]

    @State private var dayName: String
    @State private var focusSummary: String
    @State private var showingAddExercisePicker: Bool = false
    @State private var selectedExerciseToAdd: Exercise? = nil

    init(dayTemplate: ProgramDayTemplate, allExercises: [Exercise]) {
        self.dayTemplate = dayTemplate
        self.allExercises = allExercises
        _dayName = State(initialValue: dayTemplate.name)
        _focusSummary = State(initialValue: dayTemplate.focusSummary)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Day Title & Focus") {
                    TextField("Day Name", text: $dayName)
                    TextField("Focus Summary", text: $focusSummary)
                }

                Section {
                    ForEach(Array(dayTemplate.sortedSlots.enumerated()), id: \.element.id) { idx, slot in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("#\(idx + 1)")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(.orange)

                                Picker("Exercise", selection: Binding(
                                    get: { slot.preferredExercise ?? allExercises.first! },
                                    set: { newEx in
                                        slot.preferredExercise = newEx
                                        slot.tierPriority = newEx.tierPriority
                                        try? modelContext.save()
                                    }
                                )) {
                                    ForEach(allExercises) { ex in
                                        Text(ex.name).tag(ex)
                                    }
                                }
                                .labelsHidden()

                                Spacer()

                                HStack(spacing: 4) {
                                    Button {
                                        moveSlot(at: idx, direction: -1)
                                    } label: {
                                        Image(systemName: "arrow.up")
                                            .font(.caption.weight(.bold))
                                            .frame(width: 26, height: 26)
                                            .background(Color(.tertiarySystemGroupedBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(idx == 0)

                                    Button {
                                        moveSlot(at: idx, direction: 1)
                                    } label: {
                                        Image(systemName: "arrow.down")
                                            .font(.caption.weight(.bold))
                                            .frame(width: 26, height: 26)
                                            .background(Color(.tertiarySystemGroupedBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(idx == dayTemplate.sortedSlots.count - 1)
                                }
                            }

                            HStack(spacing: 12) {
                                Stepper("Sets: \(slot.baseSets)", value: Binding(
                                    get: { slot.baseSets },
                                    set: { slot.baseSets = $0; try? modelContext.save() }
                                ), in: 1...6)
                                .font(.caption)

                                Stepper("Reps: \(slot.repRangeMin)–\(slot.repRangeMax)", value: Binding(
                                    get: { slot.repRangeMax },
                                    set: {
                                        slot.repRangeMax = max(slot.repRangeMin + 1, $0)
                                        try? modelContext.save()
                                    }
                                ), in: 3...25)
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteSlots)

                    Button {
                        showingAddExercisePicker = true
                    } label: {
                        Label("Add Exercise Slot to \(dayName)", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Programmed Lifts (\(dayTemplate.sortedSlots.count))")
                }
            }
            .navigationTitle("Edit Split Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dayTemplate.name = dayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? dayTemplate.name : dayName
                        dayTemplate.focusSummary = focusSummary
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showingAddExercisePicker) {
                NavigationStack {
                    List(allExercises) { ex in
                        Button {
                            let nextIndex = dayTemplate.sortedSlots.count
                            let newSlot = PlannedExerciseSlot(
                                orderIndex: nextIndex,
                                preferredExercise: ex,
                                tierPriority: ex.tierPriority,
                                baseSets: 3,
                                repRangeMin: ex.mechanicType == .compound ? 6 : 10,
                                repRangeMax: ex.mechanicType == .compound ? 10 : 15,
                                restSeconds: ex.defaultRestSeconds,
                                dayTemplate: dayTemplate
                            )
                            modelContext.insert(newSlot)
                            try? modelContext.save()
                            showingAddExercisePicker = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(ex.primaryMuscle.rawValue) · \(ex.movementPattern.rawValue) · \(ex.equipmentSummary)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .navigationTitle("Add Lift to Day")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingAddExercisePicker = false }
                        }
                    }
                }
            }
        }
    }

    private func moveSlot(at idx: Int, direction: Int) {
        var slots = dayTemplate.sortedSlots
        let dest = idx + direction
        guard slots.indices.contains(idx), slots.indices.contains(dest) else { return }
        slots.swapAt(idx, dest)
        for (i, s) in slots.enumerated() {
            s.orderIndex = i
        }
        try? modelContext.save()
    }

    private func deleteSlots(at offsets: IndexSet) {
        let slots = dayTemplate.sortedSlots
        for offset in offsets {
            modelContext.delete(slots[offset])
        }
        let remaining = dayTemplate.sortedSlots
        for (i, s) in remaining.enumerated() {
            s.orderIndex = i
        }
        try? modelContext.save()
    }
}

import SwiftUI
import SwiftData

struct MesocycleBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query private var existingMesocycles: [Mesocycle]

    @State private var name: String = "New Hypertrophy Block"
    @State private var splitType: SplitType = .pushPullLegs
    @State private var progressionModel: ProgressionModel = .linearRIR
    @State private var totalWeeks: Int = 5
    @State private var includesDeload: Bool = true
    @State private var defaultFinisherFormat: FinisherFormat = .emom
    @State private var defaultFinisherMinutes: Int = 10
    @State private var makeActiveImmediately: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Block Identity & Split") {
                    TextField("Mesocycle Name", text: $name)

                    Picker("Program Split", selection: $splitType) {
                        ForEach(SplitType.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }

                    Text(splitType.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Periodization & Auto-Progression") {
                    Picker("Progression Model", selection: $progressionModel) {
                        ForEach(ProgressionModel.allCases) { pm in
                            Text(pm.rawValue).tag(pm)
                        }
                    }

                    Text(progressionModel.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Stepper("Block Length: \(totalWeeks) Weeks", value: $totalWeeks, in: 3...10)
                    Toggle("Final Week is Deload Week", isOn: $includesDeload)
                }

                Section("Default Conditioning Finisher") {
                    Picker("Finisher Style", selection: $defaultFinisherFormat) {
                        ForEach(FinisherFormat.allCases) { f in
                            Text(f.fullTitle).tag(f)
                        }
                    }
                    Stepper("Finisher Duration: \(defaultFinisherMinutes) min", value: $defaultFinisherMinutes, in: 2...30, step: 1)
                }

                Section {
                    Toggle("Set as Active Mesocycle Now", isOn: $makeActiveImmediately)
                }
            }
            .navigationTitle("Create Period Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createMesocycle()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func createMesocycle() {
        if makeActiveImmediately {
            for m in existingMesocycles {
                m.isActive = false
            }
        }

        let newMeso = Mesocycle(
            name: name.isEmpty ? "\(splitType.rawValue) Block" : name,
            splitType: splitType,
            progressionModel: progressionModel,
            startDate: Date(),
            totalWeeks: totalWeeks,
            currentWeek: 1,
            currentDayIndex: 0,
            includesDeload: includesDeload,
            isActive: makeActiveImmediately
        )
        modelContext.insert(newMeso)

        // Populate starter day templates based on splitType
        let dayDefinitions: [(String, String, [MovementPattern])] = {
            switch splitType {
            case .fullBody:
                return [
                    ("Full Body A", "Squat, Horizontal Push & Pull", [.squat, .horizontalPush, .horizontalPull, .kneeFlexion, .lateralDeltoid]),
                    ("Full Body B", "Hinge, Vertical Push & Pull", [.hipHinge, .verticalPush, .verticalPull, .unilateralLeg, .elbowFlexion]),
                    ("Full Body C", "Hypertrophy & Accessories", [.squat, .inclinePush, .horizontalPull, .elbowExtension, .calves])
                ]
            case .pushPullLegs:
                return [
                    ("Push Day", "Chest, Shoulders & Triceps", [.horizontalPush, .verticalPush, .inclinePush, .lateralDeltoid, .elbowExtension]),
                    ("Pull Day", "Lats, Upper Back & Biceps", [.verticalPull, .horizontalPull, .rearDeltoid, .elbowFlexion]),
                    ("Legs Day", "Quads, Hamstrings, Glutes & Calves", [.squat, .hipHinge, .unilateralLeg, .kneeExtension, .kneeFlexion, .calves])
                ]
            case .upperLower, .customSplit:
                return [
                    ("Upper A", "Horizontal Push/Pull + Arms", [.horizontalPush, .horizontalPull, .inclinePush, .verticalPull, .lateralDeltoid, .elbowExtension]),
                    ("Lower A", "Squat, Hinge & Calves", [.squat, .hipHinge, .unilateralLeg, .kneeFlexion, .calves]),
                    ("Upper B", "Vertical Push/Pull + Delts", [.verticalPush, .verticalPull, .horizontalPush, .horizontalPull, .rearDeltoid, .elbowFlexion]),
                    ("Lower B", "Hinge, Unilateral & Quad Iso", [.hipHinge, .unilateralLeg, .squat, .kneeExtension, .calves])
                ]
            }
        }()

        for (dayIdx, def) in dayDefinitions.enumerated() {
            let dayTemplate = ProgramDayTemplate(
                name: def.0,
                focusSummary: def.1,
                orderIndex: dayIdx,
                mesocycle: newMeso
            )
            modelContext.insert(dayTemplate)

            for (slotIdx, pattern) in def.2.enumerated() {
                if let ex = allExercises.first(where: { $0.movementPattern == pattern }) {
                    let slot = PlannedExerciseSlot(
                        orderIndex: slotIdx,
                        preferredExercise: ex,
                        tierPriority: ex.tierPriority,
                        baseSets: 3,
                        repRangeMin: ex.mechanicType == .compound ? 6 : 10,
                        repRangeMax: ex.mechanicType == .compound ? 10 : 15,
                        restSeconds: ex.defaultRestSeconds,
                        dayTemplate: dayTemplate
                    )
                    modelContext.insert(slot)
                }
            }

            let fin = FinisherPrescription(
                title: "\(def.0) \(defaultFinisherFormat.rawValue)",
                format: defaultFinisherFormat,
                durationMinutes: defaultFinisherMinutes,
                movementNames: ["Min 1 (Odd): 16 Cal Row", "Min 2 (Even): 20 Kettlebell Swings"],
                movementRepSchemes: ["~45s effort per minute"],
                dayTemplate: dayTemplate
            )
            modelContext.insert(fin)
        }

        try? modelContext.save()
        dismiss()
    }
}

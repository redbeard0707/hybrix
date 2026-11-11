import SwiftUI
import SwiftData

struct CustomWorkoutBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GymProfile.name) private var gyms: [GymProfile]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var history: [WorkoutLog]

    let onStartPlan: (RecalculatedWorkoutPlan) -> Void

    @State private var settings = UserSettings.shared
    @State private var workoutTitle: String = "Custom Session"
    @State private var selectedGym: GymProfile
    @State private var targetDurationMinutes: Int
    @State private var selectedExercises: [Exercise] = []
    @State private var includeFinisher: Bool = true
    @State private var finisherFormat: FinisherFormat = .emom
    @State private var finisherMinutes: Int = 10
    @State private var finisherMovesText: String = "Min 1 (Odd): 20 Kettlebell Swings, Min 2 (Even): 22 Push-Ups"
    @State private var filterMuscle: MuscleGroup? = nil
    @State private var searchText: String = ""

    init(
        initialGym: GymProfile,
        initialDurationMinutes: Int,
        onStartPlan: @escaping (RecalculatedWorkoutPlan) -> Void
    ) {
        _selectedGym = State(initialValue: initialGym)
        _targetDurationMinutes = State(initialValue: initialDurationMinutes)
        self.onStartPlan = onStartPlan
    }

    private var availableExercisesForGym: [Exercise] {
        allExercises.filter { ex in
            selectedGym.supports(ex) &&
            (filterMuscle == nil || ex.primaryMuscle == filterMuscle) &&
            (searchText.isEmpty || ex.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Setup & Time Budget") {
                    TextField("Workout Title", text: $workoutTitle)

                    Picker("Gym Profile", selection: $selectedGym) {
                        ForEach(gyms) { g in
                            Text(g.name).tag(g)
                        }
                    }

                    Stepper(
                        "Target Duration: \(targetDurationMinutes) min",
                        value: $targetDurationMinutes,
                        in: 20...120,
                        step: 5
                    )

                    HStack {
                        Text("Recommended Lift Count for \(targetDurationMinutes)m:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(recommendedLiftCount) lifts")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }

                Section("Quick Auto-Fill Generators (Fits Time & Gym)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            quickPresetButton("Upper Pump", muscles: [.chest, .lats, .upperBack, .frontDelt, .sideDelt, .biceps, .triceps])
                            quickPresetButton("Lower Strength", muscles: [.quads, .hamstrings, .glutes, .calves])
                            quickPresetButton("Full Body Express", muscles: [.quads, .chest, .lats, .hamstrings, .sideDelt])
                            quickPresetButton("Push Focus", muscles: [.chest, .upperChest, .frontDelt, .sideDelt, .triceps])
                            quickPresetButton("Pull Focus", muscles: [.lats, .upperBack, .rearDelt, .biceps])
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Selected Lifts (\(selectedExercises.count))") {
                    if selectedExercises.isEmpty {
                        Text("Tap a quick generator above or choose lifts below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedExercises) { ex in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(ex.primaryMuscle.rawValue) · \(ex.equipmentSummary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    selectedExercises.removeAll { $0.id == ex.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    if settings.alwaysIncludeCore && !selectedExercises.contains(where: \.isCoreExercise) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.mint)
                            Text("Settings 'Always Include Core' is ON — 1 core lift will be automatically included.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Conditioning Finisher") {
                    Toggle("Include Cardio Finisher", isOn: $includeFinisher)
                    if includeFinisher {
                        Picker("Format", selection: $finisherFormat) {
                            ForEach(FinisherFormat.allCases) { f in
                                Text(f.fullTitle).tag(f)
                            }
                        }
                        Stepper("Finisher Duration: \(finisherMinutes) min", value: $finisherMinutes, in: 2...30, step: 1)
                        TextField("Movements (comma separated)", text: $finisherMovesText)
                            .font(.caption)
                    }
                }

                Section("Add Lifts Supported by \(selectedGym.name)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Button("All") { filterMuscle = nil }
                                .font(.caption.weight(filterMuscle == nil ? .bold : .regular))
                                .buttonStyle(.bordered)
                            ForEach(MuscleGroup.allCases) { m in
                                Button(m.rawValue) { filterMuscle = m }
                                    .font(.caption.weight(filterMuscle == m ? .bold : .regular))
                                    .buttonStyle(.bordered)
                            }
                        }
                    }

                    TextField("Search exercises...", text: $searchText)

                    ForEach(availableExercisesForGym.prefix(25)) { ex in
                        let isAdded = selectedExercises.contains(where: { $0.id == ex.id })
                        Button {
                            if isAdded {
                                selectedExercises.removeAll { $0.id == ex.id }
                            } else {
                                selectedExercises.append(ex)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text("\(ex.primaryMuscle.rawValue) · \(ex.equipmentSummary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundStyle(isAdded ? .green : .orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Build Custom Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Session") {
                        launchCustomPlan()
                    }
                    .fontWeight(.bold)
                    .disabled(selectedExercises.isEmpty && !settings.alwaysIncludeCore)
                }
            }
        }
    }

    private var recommendedLiftCount: Int {
        let finTime = includeFinisher ? (finisherMinutes + 2) : 0
        let remaining = max(12, targetDurationMinutes - 3 - finTime)
        return max(2, min(8, remaining / 7))
    }

    private func quickPresetButton(_ title: String, muscles: [MuscleGroup]) -> some View {
        Button {
            workoutTitle = "\(title) (\(selectedGym.name))"
            var picks: [Exercise] = []
            for m in muscles {
                if picks.count >= recommendedLiftCount { break }
                if let match = allExercises.first(where: { candidate in
                    selectedGym.supports(candidate) &&
                    candidate.primaryMuscle == m &&
                    !picks.contains(where: { p in p.id == candidate.id })
                }) {
                    picks.append(match)
                }
            }
            selectedExercises = picks
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.18))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func launchCustomPlan() {
        let weekProfile = WeekPrescriptionProfile(
            weekNumber: 1,
            totalWeeks: 1,
            phaseTitle: "Custom Ad-Hoc Session",
            phaseSubtitle: "Target 2 RIR",
            isDeload: false,
            targetRIR: 2,
            targetRPE: 8.0,
            compoundExtraSets: 0,
            setVolumeMultiplier: 1.0,
            loadMultiplierVsWeek1: 1.0
        )

        var items: [ComputedPlannedExerciseItem] = []
        for (idx, ex) in selectedExercises.enumerated() {
            let res = EquipmentSwapEngine.resolveExercise(ex, for: selectedGym, allExercises: allExercises, history: history)
            items.append(
                ComputedPlannedExerciseItem(
                    id: UUID(),
                    slotOrderIndex: idx,
                    resolution: res,
                    tierPriority: ex.tierPriority,
                    workingSets: 3,
                    warmupSets: idx == 0 ? 1 : 0,
                    repRangeMin: 8,
                    repRangeMax: 12,
                    targetRIR: 2,
                    restSeconds: (ex.mechanicType == .compound && !ex.isCoreExercise)
                        ? settings.defaultCompoundRestSeconds
                        : settings.defaultIsolationRestSeconds,
                    recommendedWeight: ex.baselineWorkingWeightLbs,
                    hasManualPrescriptionOverride: false,
                    isProtectedCore: ex.isCoreExercise,
                    wasAutoInjectedCore: false,
                    wasTrimmedByTimeBudget: false
                )
            )
        }

        if settings.alwaysIncludeCore && !items.contains(where: { $0.resolution.activeExercise.isCoreExercise }) {
            if let coreRes = EquipmentSwapEngine.selectBestCoreExercise(for: selectedGym, allExercises: allExercises) {
                items.append(
                    ComputedPlannedExerciseItem(
                        id: UUID(),
                        slotOrderIndex: 99,
                        resolution: coreRes,
                        tierPriority: .tierCore,
                        workingSets: 3,
                        warmupSets: 0,
                        repRangeMin: 10,
                        repRangeMax: 15,
                        targetRIR: 2,
                        restSeconds: settings.defaultIsolationRestSeconds,
                        recommendedWeight: coreRes.activeExercise.baselineWorkingWeightLbs,
                        hasManualPrescriptionOverride: false,
                        isProtectedCore: true,
                        wasAutoInjectedCore: true,
                        wasTrimmedByTimeBudget: false
                    )
                )
            }
        }

        let moves = finisherMovesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let finPlan = ComputedFinisherPlan(
            title: "Custom \(finisherFormat.rawValue) Finisher",
            format: finisherFormat,
            programmedDurationMinutes: finisherMinutes,
            effectiveDurationMinutes: finisherMinutes,
            workSeconds: 20,
            restSeconds: 10,
            roundsTarget: 8,
            movements: moves.isEmpty ? ["12 Burpees", "15 Kettlebell Swings"] : moves,
            repSchemes: [],
            wasEquipmentAdjusted: false,
            wasDurationScaledForTimeBudget: false
        )

        let warmupPlan = WarmupGenerator.buildTargetedWarmup(
            for: items,
            gym: selectedGym,
            isEnabled: settings.includeTargetedWarmup,
            durationMinutes: settings.defaultWarmupMinutes
        )

        let plan = RecalculatedWorkoutPlan(
            dayTemplateName: workoutTitle,
            focusSummary: "Custom day workout built for \(selectedGym.name)",
            targetDurationMinutes: targetDurationMinutes,
            gym: selectedGym,
            weekProfile: weekProfile,
            warmupPlan: warmupPlan,
            activeExercises: items,
            trimmedExercises: [],
            finisher: finPlan,
            includeFinisher: includeFinisher,
            alwaysIncludeCoreActive: settings.alwaysIncludeCore
        )

        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onStartPlan(plan)
        }
    }
}

import SwiftUI
import SwiftData

struct ActiveWorkoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var workoutLogs: [WorkoutLog]

    @State private var sessionManager = ActiveWorkoutSessionManager.shared
    @State private var timerManager = WorkoutTimerManager.shared
    @State private var settings = UserSettings.shared

    @State private var showingFinisherModal: Bool = false
    @State private var showingAddExerciseSheet: Bool = false
    @State private var historyPopupExercise: Exercise? = nil
    @State private var activeNumpadTarget: ActiveNumpadTarget? = nil

    // Confirmation Alerts for Discard & Finish
    @State private var showingDiscardConfirmation: Bool = false
    @State private var showingFinishConfirmation: Bool = false
    @State private var showingFinisherEditor: Bool = false

    private var completedWorkingSetsCount: Int {
        sessionManager.sessionItems.reduce(0) {
            $0 + $1.sets.filter { $0.isCompleted && $0.setType != .warmup }.count
        }
    }

    private var totalWorkingSetsCount: Int {
        sessionManager.sessionItems.reduce(0) {
            $0 + $1.sets.filter { $0.setType != .warmup }.count
        }
    }

    var body: some View {
        NavigationStack {
            if let plan = sessionManager.plan, let activeGym = sessionManager.activeGym {
                VStack(spacing: 0) {
                    // Live Top Status Bar (Session Clock + Fixed-Height Rest Timer + Read-Only Gym Badge)
                    liveHeaderBar(plan: plan, activeGym: activeGym)

                    ScrollView {
                        VStack(spacing: 16) {
                            // Intra-Workout Set Autoregulation Banner
                            if let autoMsg = sessionManager.autoregulationBannerMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "bolt.badge.clock.fill")
                                        .foregroundStyle(.orange)
                                    Text(autoMsg)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            sessionManager.autoregulationBannerMessage = nil
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(10)
                                .background(Color.orange.opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Targeted Warmup Checklist if Enabled
                            if plan.warmupPlan.isEnabled && !plan.warmupPlan.drills.isEmpty {
                                liveWarmupCard(plan.warmupPlan)
                            }

                            // Exercise Cards
                            ForEach(Array(sessionManager.sessionItems.enumerated()), id: \.element.id) { exIdx, sessionItem in
                                liveExerciseCard(exIdx: exIdx, item: sessionItem, activeGym: activeGym)
                            }

                            // Add Extra Exercise Button
                            Button {
                                showingAddExerciseSheet = true
                            } label: {
                                Label("Add Exercise to Today's Session", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Conditioning Finisher Block
                            if let fin = sessionManager.finisherPlan {
                                liveFinisherCard(fin)
                            } else {
                                Button {
                                    sessionManager.finisherPlan = ComputedFinisherPlan(
                                        title: "EMOM 8 Finisher",
                                        format: .emom,
                                        programmedDurationMinutes: 8,
                                        effectiveDurationMinutes: 8,
                                        workSeconds: 45,
                                        restSeconds: 15,
                                        roundsTarget: 8,
                                        movements: ["Min 1: 16 Cal Row", "Min 2: 20 Kettlebell Swings"],
                                        repSchemes: ["~45s", "~45s"],
                                        hasManualOverride: true,
                                        wasEquipmentAdjusted: false,
                                        wasDurationScaledForTimeBudget: false
                                    )
                                    showingFinisherEditor = true
                                } label: {
                                    Label("Add Conditioning Finisher", systemImage: "flame.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.orange)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }

                            // Workout Notes
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SESSION NOTES")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                TextField("How did weights feel? Machine seat settings...", text: $sessionManager.sessionNotes, axis: .vertical)
                                    .lineLimit(2...4)
                                    .padding(10)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Bottom Action Bar: Small Discard Button + Large Complete & Save Button
                            HStack(spacing: 12) {
                                Button(role: .destructive) {
                                    showingDiscardConfirmation = true
                                } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: "trash")
                                            .font(.caption.weight(.bold))
                                        Text("Discard")
                                            .font(.caption2.weight(.bold))
                                    }
                                    .foregroundStyle(.red)
                                    .frame(width: 62, height: 52)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.red.opacity(0.28), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Discard Workout")

                                Button {
                                    showingFinishConfirmation = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.headline)
                                        Text(sessionManager.reopenedWorkoutLog != nil ? "Update & Save Reopened Workout" : "Complete & Save Workout")
                                            .font(.headline.weight(.bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.green.opacity(0.25), radius: 6, x: 0, y: 3)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 24)
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                }
                .navigationTitle(plan.dayTemplateName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            sessionManager.minimizeWorkout()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.down.circle.fill")
                                Text("Minimize")
                                    .font(.caption.weight(.bold))
                            }
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Finish") {
                            showingFinishConfirmation = true
                        }
                        .fontWeight(.bold)
                    }
                }
                .sheet(isPresented: $showingFinisherModal) {
                    if let fin = sessionManager.finisherPlan {
                        FinisherTimerView(initialPlan: fin) { result in
                            sessionManager.finisherCompletedResult = result
                        }
                    }
                }
                .sheet(isPresented: $showingFinisherEditor) {
                    if let fin = sessionManager.finisherPlan {
                        PlannedFinisherEditorSheet(
                            currentFinisher: fin,
                            gym: activeGym,
                            onSave: { override in
                                sessionManager.finisherPlan = ComputedFinisherPlan(
                                    title: override.title,
                                    format: override.format,
                                    programmedDurationMinutes: override.durationMinutes,
                                    effectiveDurationMinutes: override.durationMinutes,
                                    workSeconds: override.workSeconds,
                                    restSeconds: override.restSeconds,
                                    roundsTarget: override.roundsTarget,
                                    movements: override.movements,
                                    repSchemes: Array(repeating: "", count: override.movements.count),
                                    hasManualOverride: true,
                                    wasEquipmentAdjusted: false,
                                    wasDurationScaledForTimeBudget: false
                                )
                            },
                            onResetToDefault: {
                                sessionManager.finisherPlan = plan.finisher
                            }
                        )
                    }
                }
                .sheet(item: $historyPopupExercise) { ex in
                    ExerciseHistoryPopupSheet(
                        exercise: ex,
                        history: workoutLogs,
                        weightUnit: settings.weightUnit
                    )
                }
                .sheet(item: $activeNumpadTarget) { target in
                    SetValueNumpadSheet(
                        title: target.field == .weight
                            ? "Set \(target.setNumber) Weight (\(settings.weightUnit.rawValue))"
                            : "Set \(target.setNumber) Reps",
                        isDecimalAllowed: target.field == .weight,
                        initialValueString: target.initialString
                    ) { enteredValue, applyToRemaining in
                        guard sessionManager.sessionItems.indices.contains(target.exIdx),
                              sessionManager.sessionItems[target.exIdx].sets.indices.contains(target.setIdx) else { return }

                        if target.field == .weight {
                            let newW = max(0, enteredValue)
                            sessionManager.sessionItems[target.exIdx].sets[target.setIdx].weight = newW
                            if applyToRemaining {
                                let targetType = sessionManager.sessionItems[target.exIdx].sets[target.setIdx].setType
                                for idx in sessionManager.sessionItems[target.exIdx].sets.indices
                                where idx > target.setIdx
                                    && !sessionManager.sessionItems[target.exIdx].sets[idx].isCompleted
                                    && sessionManager.sessionItems[target.exIdx].sets[idx].setType == targetType {
                                    sessionManager.sessionItems[target.exIdx].sets[idx].weight = newW
                                }
                            }
                        } else {
                            let newReps = max(0, Int(enteredValue.rounded()))
                            sessionManager.sessionItems[target.exIdx].sets[target.setIdx].reps = newReps
                            if applyToRemaining {
                                let targetType = sessionManager.sessionItems[target.exIdx].sets[target.setIdx].setType
                                for idx in sessionManager.sessionItems[target.exIdx].sets.indices
                                where idx > target.setIdx
                                    && !sessionManager.sessionItems[target.exIdx].sets[idx].isCompleted
                                    && sessionManager.sessionItems[target.exIdx].sets[idx].setType == targetType {
                                    sessionManager.sessionItems[target.exIdx].sets[idx].reps = newReps
                                }
                            }
                        }
                        sessionManager.startOrUpdateLiveActivity()
                    }
                }
                .sheet(isPresented: $showingAddExerciseSheet) {
                    AddExerciseToLiveWorkoutSheet(gym: activeGym, allExercises: allExercises) { chosen in
                        let res = EquipmentSwapEngine.resolveExercise(chosen, for: activeGym, allExercises: allExercises)
                        let startRIR = PeriodizationEngine.initialTapRIR(for: plan.weekProfile.targetRIR)
                        let newItem = ComputedPlannedExerciseItem(
                            id: UUID(),
                            slotOrderIndex: sessionManager.sessionItems.count + 1,
                            resolution: res,
                            tierPriority: chosen.tierPriority,
                            workingSets: 3,
                            warmupSets: 0,
                            repRangeMin: 8,
                            repRangeMax: 12,
                            targetRIR: plan.weekProfile.targetRIR,
                            restSeconds: (chosen.mechanicType == .compound && !chosen.isCoreExercise)
                                ? settings.defaultCompoundRestSeconds
                                : settings.defaultIsolationRestSeconds,
                            recommendedWeight: chosen.baselineWorkingWeightLbs,
                            hasManualPrescriptionOverride: false,
                            isProtectedCore: chosen.isCoreExercise,
                            wasAutoInjectedCore: false,
                            wasTrimmedByTimeBudget: false
                        )
                        sessionManager.sessionItems.append(
                            LiveExerciseSessionItem(
                                plannedItem: newItem,
                                sets: (1...3).map {
                                    LiveSetRow(
                                        setNumber: $0,
                                        weight: chosen.baselineWorkingWeightLbs,
                                        reps: 10,
                                        rir: startRIR,
                                        setType: .working,
                                        isCompleted: false
                                    )
                                }
                            )
                        )
                        sessionManager.startOrUpdateLiveActivity()
                    }
                }
                .alert("Discard Active Workout?", isPresented: $showingDiscardConfirmation) {
                    Button("Discard Workout", role: .destructive) {
                        sessionManager.discardWorkout()
                    }
                    Button("Keep Training", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to discard this session? Your \(completedWorkingSetsCount) completed working sets will not be saved.")
                }
                .alert(
                    sessionManager.reopenedWorkoutLog != nil ? "Save Updated Workout?" : "Finish & Save Workout?",
                    isPresented: $showingFinishConfirmation
                ) {
                    Button("Save & Finish") {
                        sessionManager.saveAndFinishWorkout(modelContext: modelContext)
                    }
                    Button("Keep Training", role: .cancel) {}
                } message: {
                    if completedWorkingSetsCount < totalWorkingSetsCount {
                        Text("You have completed \(completedWorkingSetsCount) of \(totalWorkingSetsCount) working sets. Finish and save this workout anyway? (You can always re-enter it from History later.)")
                    } else {
                        Text("All \(totalWorkingSetsCount) working sets completed! Save this session to your workout history?")
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private func liveWarmupCard(_ warmup: ComputedWarmupPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Targeted Day Warmup (\(warmup.durationMinutes) min)", systemImage: "figure.cooldown")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.yellow)
                Spacer()
                Text(warmup.focusSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ForEach(warmup.drills) { drill in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(drill.name)
                            .font(.caption.weight(.semibold))
                        Text(drill.prescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func liveHeaderBar(plan: RecalculatedWorkoutPlan, activeGym: GymProfile) -> some View {
        VStack(spacing: 8) {
            HStack {
                // Elapsed Clock
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch.fill")
                        .foregroundStyle(.orange)
                    Text(WorkoutTimerManager.formatMMSS(sessionManager.elapsedSessionSeconds))
                        .font(.subheadline.monospacedDigit().weight(.bold))
                    Text("/ \(plan.targetDurationMinutes)m target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Static Gym Location Badge (no mid-workout switching)
                HStack(spacing: 5) {
                    Image(systemName: activeGym.iconName)
                        .foregroundStyle(.orange)
                    Text(activeGym.name)
                        .lineLimit(1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
            }

            // Fixed-height Rest Timer Row (never shifts layout below it)
            HStack {
                if timerManager.isRestTimerRunning {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                    Text("Rest: \(WorkoutTimerManager.formatMMSS(timerManager.restSecondsRemaining))")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.orange)

                    Spacer()

                    Button("-15s") { timerManager.adjustRestTimer(by: -15) }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.bordered)
                    Button("+15s") { timerManager.adjustRestTimer(by: 15) }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.bordered)
                    Button("Skip") { timerManager.stopRestTimer() }
                        .font(.caption.weight(.bold))
                        .tint(.red)
                        .buttonStyle(.bordered)
                } else {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                    Text("Rest Timer Ready")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    ForEach([60, 90, 120], id: \.self) { secs in
                        Button("\(secs)s") {
                            timerManager.startRestTimer(seconds: secs)
                        }
                        .font(.caption2.weight(.bold))
                        .buttonStyle(.bordered)
                    }
                }
            }
            .frame(height: 32)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                timerManager.isRestTimerRunning
                    ? Color.orange.opacity(0.14)
                    : Color(.tertiarySystemGroupedBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func liveExerciseCard(exIdx: Int, item: LiveExerciseSessionItem, activeGym: GymProfile) -> some View {
        let ex = item.plannedItem.resolution.activeExercise
        let sampleWorkingWeight = item.sets.last(where: { $0.setType != .warmup })?.weight ?? item.plannedItem.recommendedWeight
        let plateBreakdown = activeGym.plateBreakdownDescription(forTotalWeight: sampleWorkingWeight, exercise: ex)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let ssBadge = item.plannedItem.supersetBadge {
                            Text(ssBadge)
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                        Text(ex.name)
                            .font(.headline)
                        if item.plannedItem.isProtectedCore {
                            Text("Core")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.mint.opacity(0.2))
                                .foregroundStyle(.mint)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(ex.primaryMuscle.rawValue) · Target \(item.plannedItem.repRangeMin)–\(item.plannedItem.repRangeMax) reps @ \(item.plannedItem.targetRIR) RIR")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let plateDesc = plateBreakdown {
                        HStack(spacing: 4) {
                            Image(systemName: "scalemass.fill")
                                .font(.caption2)
                            Text(plateDesc)
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.orange)
                    }

                    if item.plannedItem.resolution.wasSwapped {
                        Text("🔄 Swapped from \(item.plannedItem.resolution.originalExercise.name) for \(activeGym.name)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                // Exercise History Popup Button
                Button {
                    historyPopupExercise = ex
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("History")
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Set Table Header
            HStack {
                Text("SET")
                    .frame(width: 44, alignment: .leading)
                Text(settings.weightUnit.rawValue.uppercased())
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
                Text("DONE / RIR")
                    .frame(width: 96, alignment: .trailing)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)

            ForEach(Array(item.sets.enumerated()), id: \.element.id) { setIdx, setRow in
                let isWarmup = setRow.setType == .warmup
                let isActualPR = !isWarmup && setRow.isCompleted && PeriodizationEngine.isActualLiftPR(
                    weight: setRow.weight,
                    reps: setRow.reps,
                    for: ex,
                    in: workoutLogs
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(SetType.allCases) { st in
                                Button(st.fullName) {
                                    sessionManager.sessionItems[exIdx].sets[setIdx].setType = st
                                }
                            }
                            Divider()
                            Button("Delete Set", role: .destructive) {
                                sessionManager.sessionItems[exIdx].sets.remove(at: setIdx)
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Text(isWarmup ? "W\(setRow.setNumber)" : "\(setRow.setNumber)\(setRow.setType == .working ? "" : setRow.setType.rawValue)")
                                    .font(.caption.weight(.bold))
                                if isActualPR {
                                    Text("🏆")
                                        .font(.caption2)
                                }
                            }
                            .frame(width: 44, height: 28)
                            .background(isWarmup ? Color.yellow.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(isWarmup ? .yellow : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Button {
                            let w = setRow.weight
                            let str = GymProfile.formatCleanNumber(w)
                            activeNumpadTarget = ActiveNumpadTarget(
                                exIdx: exIdx,
                                setIdx: setIdx,
                                setNumber: setRow.setNumber,
                                field: .weight,
                                initialString: str
                            )
                        } label: {
                            Text(GymProfile.formatCleanNumber(setRow.weight))
                                .font(.subheadline.monospacedDigit().weight(.bold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        Button {
                            activeNumpadTarget = ActiveNumpadTarget(
                                exIdx: exIdx,
                                setIdx: setIdx,
                                setNumber: setRow.setNumber,
                                field: .reps,
                                initialString: "\(setRow.reps)"
                            )
                        } label: {
                            Text("\(setRow.reps)")
                                .font(.subheadline.monospacedDigit().weight(.bold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        Button {
                            sessionManager.handleSetTap(
                                exIdx: exIdx,
                                setIdx: setIdx,
                                plannedTargetRIR: item.plannedItem.targetRIR,
                                restSeconds: item.plannedItem.restSeconds
                            )
                        } label: {
                            if setRow.isCompleted {
                                HStack(spacing: 4) {
                                    Text(
                                        isWarmup
                                            ? "✓ Warmup"
                                            : PeriodizationEngine.formatRIRButtonTitle(
                                                rir: setRow.rir,
                                                targetRIR: item.plannedItem.targetRIR
                                            )
                                    )
                                    .font(.caption.weight(.black))
                                    .monospacedDigit()
                                }
                                .frame(width: 96, height: 32)
                                .background(isWarmup ? Color.yellow.opacity(0.22) : Color.green.opacity(0.22))
                                .foregroundStyle(isWarmup ? .yellow : .green)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "circle")
                                        .font(.subheadline)
                                    Text(isWarmup ? "No Rest" : "Done")
                                        .font(.caption.weight(.semibold))
                                }
                                .frame(width: 96, height: 32)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .foregroundStyle(isWarmup ? .yellow : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Show per-set plate breakdown if warmup weight differs from working weight
                    if isWarmup, let wPlates = activeGym.plateBreakdownDescription(forTotalWeight: setRow.weight, exercise: ex) {
                        Text("Warmup Plates: \(wPlates) · +15s swap (no rest)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 52)
                    } else if isActualPR {
                        Text("🏆 New Actual Lift PR! (\(GymProfile.formatCleanNumber(setRow.weight)) \(settings.weightUnit.rawValue) × \(setRow.reps) reps)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.yellow)
                            .padding(.leading, 52)
                    }
                }
                .padding(.vertical, 2)
                .opacity(setRow.isCompleted ? 0.94 : 1.0)
            }

            Button {
                let workingCount = item.sets.filter { $0.setType != .warmup }.count
                let nextSetNum = workingCount + 1
                let lastWeight = item.sets.last?.weight ?? item.plannedItem.recommendedWeight
                let lastReps = item.sets.last?.reps ?? 10
                let startRIR = PeriodizationEngine.initialTapRIR(for: item.plannedItem.targetRIR)
                sessionManager.sessionItems[exIdx].sets.append(
                    LiveSetRow(
                        setNumber: nextSetNum,
                        weight: lastWeight,
                        reps: lastReps,
                        rir: startRIR,
                        setType: .working,
                        isCompleted: false
                    )
                )
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func liveFinisherCard(_ fin: ComputedFinisherPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(fin.title) (\(fin.effectiveDurationMinutes)m \(fin.format.rawValue))", systemImage: fin.format.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(fin.format.badgeColor)
                Spacer()
                if sessionManager.finisherCompletedResult != nil {
                    Label("Completed", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }

                Button {
                    showingFinisherEditor = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Edit")
                    }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(fin.format.badgeColor.opacity(0.18))
                    .foregroundStyle(fin.format.badgeColor)
                    .clipShape(Capsule())
                }
            }

            ForEach(fin.movements, id: \.self) { m in
                Text("• \(m)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let res = sessionManager.finisherCompletedResult {
                Text("Logged Score: \(res.roundsCompleted) rounds + \(res.extraReps) reps (\(WorkoutTimerManager.formatMMSS(res.durationSeconds)))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            Button {
                showingFinisherModal = true
            } label: {
                HStack {
                    Image(systemName: sessionManager.finisherCompletedResult == nil ? "play.circle.fill" : "arrow.clockwise.circle.fill")
                    Text(sessionManager.finisherCompletedResult == nil ? "Launch \(fin.format.rawValue) Finisher Timer" : "Re-open Finisher Timer")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(fin.format.badgeColor.opacity(0.2))
                .foregroundStyle(fin.format.badgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct LiveExerciseSessionItem: Identifiable {
    let id: UUID = UUID()
    var plannedItem: ComputedPlannedExerciseItem
    var sets: [LiveSetRow]
}

struct LiveSetRow: Identifiable {
    let id: UUID = UUID()
    var setNumber: Int
    var weight: Double
    var reps: Int
    var rir: Int
    var setType: SetType
    var isCompleted: Bool
}

struct FinisherCompletionResult {
    let durationSeconds: Int
    let roundsCompleted: Int
    let extraReps: Int
}

struct ActiveNumpadTarget: Identifiable {
    enum FieldType {
        case weight
        case reps
    }
    let id = UUID()
    let exIdx: Int
    let setIdx: Int
    let setNumber: Int
    let field: FieldType
    let initialString: String
}

struct SetValueNumpadSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let isDecimalAllowed: Bool
    let onCommit: (_ value: Double, _ applyToRemaining: Bool) -> Void

    @State private var inputString: String
    @State private var hasTypedYet: Bool = false
    @State private var applyToRemainingSets: Bool = true

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    init(
        title: String,
        isDecimalAllowed: Bool,
        initialValueString: String,
        onCommit: @escaping (_ value: Double, _ applyToRemaining: Bool) -> Void
    ) {
        self.title = title
        self.isDecimalAllowed = isDecimalAllowed
        _inputString = State(initialValue: initialValueString)
        self.onCommit = onCommit
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // Large Value Display + Simplified Quick Stepper Buttons (±5 / ±2.5 for weight, ±1 for reps)
            HStack(spacing: 8) {
                if isDecimalAllowed {
                    quickStepButton(label: "-5", delta: -5)
                    quickStepButton(label: "-2.5", delta: -2.5)
                } else {
                    quickStepButton(label: "-1", delta: -1)
                }

                Text(inputString.isEmpty ? "0" : inputString)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if isDecimalAllowed {
                    quickStepButton(label: "+2.5", delta: 2.5)
                    quickStepButton(label: "+5", delta: 5)
                } else {
                    quickStepButton(label: "+1", delta: 1)
                }
            }
            .padding(.horizontal, 20)

            // Apply to Remaining Uncompleted Sets Toggle
            Toggle("Apply to remaining uncompleted sets", isOn: $applyToRemainingSets)
                .font(.caption.weight(.semibold))
                .tint(.orange)
                .padding(.horizontal, 20)

            // Numpad Grid
            VStack(spacing: 8) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                handleKeyTap(key)
                            } label: {
                                Text(key == "." && !isDecimalAllowed ? "C" : key)
                                    .font(.title3.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            Button {
                let val = Double(inputString) ?? 0
                onCommit(val, applyToRemainingSets)
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
    }

    private func quickStepButton(label: String, delta: Double) -> some View {
        Button {
            adjustBy(delta)
        } label: {
            Text(label)
                .font(.caption.weight(.black))
                .frame(width: 44, height: 42)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func adjustBy(_ delta: Double) {
        let current = Double(inputString) ?? 0
        let updated = max(0, current + delta)
        hasTypedYet = true
        if !isDecimalAllowed || updated.truncatingRemainder(dividingBy: 1) == 0 {
            inputString = "\(Int(updated))"
        } else {
            inputString = GymProfile.formatCleanNumber(updated)
        }
    }

    private func handleKeyTap(_ key: String) {
        if key == "⌫" {
            if !hasTypedYet {
                inputString = ""
                hasTypedYet = true
            } else if !inputString.isEmpty {
                inputString.removeLast()
            }
            return
        }

        if key == "." {
            if !isDecimalAllowed {
                inputString = ""
                hasTypedYet = true
                return
            }
            if !hasTypedYet {
                inputString = "0."
                hasTypedYet = true
            } else if !inputString.contains(".") {
                inputString.append(".")
            }
            return
        }

        if !hasTypedYet {
            inputString = key
            hasTypedYet = true
        } else if inputString.count < 6 {
            if inputString == "0" {
                inputString = key
            } else {
                inputString.append(key)
            }
        }
    }
}

struct AddExerciseToLiveWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let gym: GymProfile
    let allExercises: [Exercise]
    let onPick: (Exercise) -> Void

    @State private var search: String = ""

    var filtered: [Exercise] {
        allExercises.filter {
            gym.supports($0) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { ex in
                Button {
                    onPick(ex)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name)
                            .font(.subheadline.weight(.semibold))
                        Text("\(ex.primaryMuscle.rawValue) · \(ex.equipmentSummary)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search lifts at \(gym.name)")
            .navigationTitle("Add Lift")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

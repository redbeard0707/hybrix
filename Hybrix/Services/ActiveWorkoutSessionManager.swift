import Foundation
import SwiftUI
import SwiftData
import Observation
import ActivityKit

@Observable
@MainActor
final class ActiveWorkoutSessionManager {
    static let shared = ActiveWorkoutSessionManager()

    var hasActiveSession: Bool = false
    var isPresentingFullScreen: Bool = false

    var plan: RecalculatedWorkoutPlan? = nil
    var mesocycle: Mesocycle? = nil
    var activeGym: GymProfile? = nil
    var sessionItems: [LiveExerciseSessionItem] = []
    var finisherPlan: ComputedFinisherPlan? = nil
    var finisherCompletedResult: FinisherCompletionResult? = nil
    var sessionNotes: String = ""
    var elapsedSessionSeconds: Int = 0
    var reopenedWorkoutLog: WorkoutLog? = nil
    var autoregulationBannerMessage: String? = nil

    private var sessionClockTimer: Timer? = nil
    private var liveActivity: Activity<HybrixWorkoutActivityAttributes>? = nil

    private init() {
        HybrixLiveActivityActionBridge.onCompleteCurrentSet = { [weak self] in
            self?.completeNextPendingSetFromLiveActivity()
        }
    }

    // MARK: - Start New or Reopened Session

    func startNewWorkout(plan: RecalculatedWorkoutPlan, mesocycle: Mesocycle?) {
        stopSessionClock()
        WorkoutTimerManager.shared.stopRestTimer()

        self.plan = plan
        self.mesocycle = mesocycle
        self.activeGym = plan.gym
        self.finisherPlan = plan.includeFinisher ? plan.finisher : nil
        self.finisherCompletedResult = nil
        self.sessionNotes = ""
        self.elapsedSessionSeconds = 0
        self.reopenedWorkoutLog = nil
        self.autoregulationBannerMessage = nil

        var initialItems: [LiveExerciseSessionItem] = []
        for item in plan.activeExercises {
            var setRows: [LiveSetRow] = []

            // 1. Progressive Warm-Up Sets (No Rest Timer)
            let warmupPrescriptions = PeriodizationEngine.generateWarmupPrescriptions(
                for: item.resolution.activeExercise,
                workingWeight: item.recommendedWeight,
                warmupCount: item.warmupSets,
                gym: plan.gym
            )
            for (wIdx, wp) in warmupPrescriptions.enumerated() {
                setRows.append(
                    LiveSetRow(
                        setNumber: wIdx + 1,
                        weight: wp.weight,
                        reps: wp.reps,
                        rir: 4,
                        setType: .warmup,
                        isCompleted: false
                    )
                )
            }

            // 2. Working Sets
            let defaultStartRIR = PeriodizationEngine.initialTapRIR(for: item.targetRIR)
            for s in 1...max(1, item.workingSets) {
                setRows.append(
                    LiveSetRow(
                        setNumber: s,
                        weight: item.recommendedWeight,
                        reps: (item.repRangeMin + item.repRangeMax) / 2,
                        rir: defaultStartRIR,
                        setType: .working,
                        isCompleted: false
                    )
                )
            }

            initialItems.append(
                LiveExerciseSessionItem(
                    plannedItem: item,
                    sets: setRows
                )
            )
        }

        self.sessionItems = initialItems
        self.hasActiveSession = true
        self.isPresentingFullScreen = true
        startSessionClock()
        startOrUpdateLiveActivity()
    }

    /// Rehydrates a completed workout from History so the user can continue or modify it if finished accidentally.
    func reopenCompletedWorkout(
        _ log: WorkoutLog,
        allExercises: [Exercise],
        fallbackGym: GymProfile
    ) {
        stopSessionClock()
        WorkoutTimerManager.shared.stopRestTimer()

        let gym = log.selectedGym ?? fallbackGym
        let meso = log.mesocycle
        let weekProf = meso.map { PeriodizationEngine.weekProfile(for: $0, week: log.weekIndex) }
            ?? WeekPrescriptionProfile(
                weekNumber: log.weekIndex,
                totalWeeks: 4,
                phaseTitle: "Reopened Session",
                phaseSubtitle: "Continuing workout",
                isDeload: false,
                targetRIR: 2,
                targetRPE: 8.0,
                compoundExtraSets: 0,
                setVolumeMultiplier: 1.0,
                loadMultiplierVsWeek1: 1.0
            )

        var restoredItems: [LiveExerciseSessionItem] = []
        var plannedItems: [ComputedPlannedExerciseItem] = []

        for (idx, loggedEx) in log.sortedExercises.enumerated() {
            let activeEx = loggedEx.exercise
                ?? allExercises.first(where: { $0.name == loggedEx.exerciseNameSnapshot })
                ?? allExercises.first!

            let resolution = EquipmentSwapEngine.resolveExercise(
                activeEx,
                for: gym,
                allExercises: allExercises
            )

            let sortedLoggedSets = loggedEx.sortedSets
            let workingCount = max(1, sortedLoggedSets.filter { $0.setType != .warmup }.count)
            let warmupCount = sortedLoggedSets.filter { $0.setType == .warmup }.count
            let sampleWeight = sortedLoggedSets.last?.weight ?? activeEx.baselineWorkingWeightLbs

            let planned = ComputedPlannedExerciseItem(
                id: loggedEx.id,
                slotOrderIndex: idx,
                resolution: resolution,
                tierPriority: activeEx.tierPriority,
                workingSets: workingCount,
                warmupSets: warmupCount,
                repRangeMin: 8,
                repRangeMax: 12,
                targetRIR: weekProf.targetRIR,
                restSeconds: (activeEx.mechanicType == .compound && !activeEx.isCoreExercise)
                    ? UserSettings.shared.defaultCompoundRestSeconds
                    : UserSettings.shared.defaultIsolationRestSeconds,
                recommendedWeight: sampleWeight,
                hasManualPrescriptionOverride: false,
                isProtectedCore: loggedEx.wasAutoInjectedCore || activeEx.isCoreExercise,
                wasAutoInjectedCore: loggedEx.wasAutoInjectedCore,
                wasTrimmedByTimeBudget: false
            )
            plannedItems.append(planned)

            let setRows: [LiveSetRow] = sortedLoggedSets.map { ls in
                LiveSetRow(
                    setNumber: ls.setNumber,
                    weight: ls.weight,
                    reps: ls.reps,
                    rir: ls.rir,
                    setType: ls.setType,
                    isCompleted: ls.isCompleted
                )
            }

            restoredItems.append(
                LiveExerciseSessionItem(
                    plannedItem: planned,
                    sets: setRows
                )
            )
        }

        var restoredFinPlan: ComputedFinisherPlan? = nil
        var restoredFinResult: FinisherCompletionResult? = nil
        if let lf = log.loggedFinisher {
            let mins = max(2, lf.totalDurationSeconds / 60)
            restoredFinPlan = ComputedFinisherPlan(
                title: lf.title,
                format: lf.format,
                programmedDurationMinutes: mins,
                effectiveDurationMinutes: mins,
                workSeconds: 20,
                restSeconds: 10,
                roundsTarget: max(4, lf.roundsCompleted),
                movements: lf.movementsSummary.components(separatedBy: " · ").filter { !$0.isEmpty },
                repSchemes: [],
                wasEquipmentAdjusted: false,
                wasDurationScaledForTimeBudget: false
            )
            if lf.isCompleted {
                restoredFinResult = FinisherCompletionResult(
                    durationSeconds: lf.totalDurationSeconds,
                    roundsCompleted: lf.roundsCompleted,
                    extraReps: lf.extraReps
                )
            }
        }

        let warmup = WarmupGenerator.buildTargetedWarmup(
            for: plannedItems,
            gym: gym,
            isEnabled: false,
            durationMinutes: 0
        )

        let reconstructedPlan = RecalculatedWorkoutPlan(
            dayTemplateName: log.dayTemplateName,
            focusSummary: "Re-entered session from History",
            targetDurationMinutes: log.targetDurationMinutes,
            gym: gym,
            weekProfile: weekProf,
            warmupPlan: warmup,
            activeExercises: plannedItems,
            trimmedExercises: [],
            finisher: restoredFinPlan,
            includeFinisher: restoredFinPlan != nil,
            alwaysIncludeCoreActive: UserSettings.shared.alwaysIncludeCore
        )

        self.plan = reconstructedPlan
        self.mesocycle = meso
        self.activeGym = gym
        self.sessionItems = restoredItems
        self.finisherPlan = restoredFinPlan
        self.finisherCompletedResult = restoredFinResult
        self.sessionNotes = log.notes
        self.elapsedSessionSeconds = log.durationSeconds
        self.reopenedWorkoutLog = log
        self.autoregulationBannerMessage = nil

        self.hasActiveSession = true
        self.isPresentingFullScreen = true
        startSessionClock()
        startOrUpdateLiveActivity()
    }

    // MARK: - Set Completion, Target+1 RIR Cycling & Intra-Workout Autoregulation

    func handleSetTap(
        exIdx: Int,
        setIdx: Int,
        plannedTargetRIR: Int,
        restSeconds: Int
    ) {
        guard sessionItems.indices.contains(exIdx),
              sessionItems[exIdx].sets.indices.contains(setIdx) else { return }

        let setRow = sessionItems[exIdx].sets[setIdx]
        let isWarmup = (setRow.setType == .warmup)
        let startRIR = PeriodizationEngine.initialTapRIR(for: plannedTargetRIR)

        if !setRow.isCompleted {
            // 1st Tap: Mark completed at Target+1 RIR (e.g. 4+ RIR on a 3 RIR week)
            sessionItems[exIdx].sets[setIdx].isCompleted = true
            sessionItems[exIdx].sets[setIdx].rir = isWarmup ? 4 : startRIR

            // Warmup sets NEVER trigger the rest timer!
            if !isWarmup && UserSettings.shared.autoStartRestTimer {
                WorkoutTimerManager.shared.startRestTimer(seconds: restSeconds)
            } else {
                WorkoutTimerManager.shared.triggerHaptic(.medium)
            }

            if !isWarmup {
                evaluateIntraWorkoutAutoregulation(exIdx: exIdx, completedSetIdx: setIdx)
            }
        } else if !isWarmup && setRow.rir > 0 {
            // Subsequent Taps on working sets: drop RIR by 1 down to 0 RIR
            sessionItems[exIdx].sets[setIdx].rir = setRow.rir - 1
            WorkoutTimerManager.shared.triggerHaptic(.light)
            evaluateIntraWorkoutAutoregulation(exIdx: exIdx, completedSetIdx: setIdx)
        } else {
            // At 0 RIR (or tapping a completed warmup set again): reset to uncompleted
            sessionItems[exIdx].sets[setIdx].isCompleted = false
            sessionItems[exIdx].sets[setIdx].rir = isWarmup ? 4 : startRIR
            WorkoutTimerManager.shared.triggerHaptic(.light)
        }

        startOrUpdateLiveActivity()
    }

    /// Completes the next uncompleted set directly from the Lock Screen Live Card or Floating Mini-Bar.
    func completeNextPendingSetFromLiveActivity() {
        for exIdx in sessionItems.indices {
            if let setIdx = sessionItems[exIdx].sets.firstIndex(where: { !$0.isCompleted }) {
                let planned = sessionItems[exIdx].plannedItem
                handleSetTap(
                    exIdx: exIdx,
                    setIdx: setIdx,
                    plannedTargetRIR: planned.targetRIR,
                    restSeconds: planned.restSeconds
                )
                return
            }
        }
    }

    private func evaluateIntraWorkoutAutoregulation(exIdx: Int, completedSetIdx: Int) {
        guard sessionItems.indices.contains(exIdx) else { return }
        let item = sessionItems[exIdx]
        let completedSet = item.sets[completedSetIdx]
        guard completedSet.isCompleted, completedSet.setType != .warmup else { return }

        // Check if there are any remaining uncompleted working sets
        let remainingIndices = item.sets.indices.filter {
            $0 > completedSetIdx && !item.sets[$0].isCompleted && item.sets[$0].setType != .warmup
        }
        guard !remainingIndices.isEmpty else { return }

        if let adjustment = PeriodizationEngine.autoregulateRemainingSets(
            completedSetWeight: completedSet.weight,
            completedSetReps: completedSet.reps,
            completedSetRIR: completedSet.rir,
            repRangeMin: item.plannedItem.repRangeMin,
            repRangeMax: item.plannedItem.repRangeMax,
            targetRIR: item.plannedItem.targetRIR,
            exercise: item.plannedItem.resolution.activeExercise,
            gym: activeGym
        ) {
            let newWeight = max(0, completedSet.weight + adjustment.weightDelta)
            for rIdx in remainingIndices {
                sessionItems[exIdx].sets[rIdx].weight = newWeight
            }
            autoregulationBannerMessage = "\(item.plannedItem.resolution.activeExercise.name): \(adjustment.note)"
        }
    }

    // MARK: - Save / Discard / Minimize

    func minimizeWorkout() {
        isPresentingFullScreen = false
        startOrUpdateLiveActivity()
    }

    func resumeFullScreen() {
        guard hasActiveSession else { return }
        isPresentingFullScreen = true
    }

    func discardWorkout() {
        stopSessionClock()
        WorkoutTimerManager.shared.stopRestTimer()
        endLiveActivity()
        hasActiveSession = false
        isPresentingFullScreen = false
        plan = nil
        reopenedWorkoutLog = nil
        sessionItems = []
    }

    func saveAndFinishWorkout(modelContext: ModelContext) {
        guard let plan = plan, let activeGym = activeGym else { return }
        stopSessionClock()
        WorkoutTimerManager.shared.stopRestTimer()
        endLiveActivity()

        let totalCompletedSets = sessionItems.reduce(0) { $0 + $1.sets.filter { $0.isCompleted && $0.setType != .warmup }.count }
        let totalVol = sessionItems.reduce(0.0) { acc, item in
            acc + item.sets.filter { $0.isCompleted && $0.setType != .warmup }.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        }
        let finDuration = finisherCompletedResult?.durationSeconds ?? ((finisherPlan?.effectiveDurationMinutes ?? 0) * 60)
        let computedCalories = CalorieEstimator.estimateCalories(
            durationSeconds: max(60, elapsedSessionSeconds),
            totalVolumeLbs: totalVol,
            completedSetsCount: max(1, totalCompletedSets),
            finisherDurationSeconds: finDuration,
            finisherFormat: finisherPlan?.format
        )

        if let existingLog = reopenedWorkoutLog {
            // Update reopened workout log in place
            existingLog.durationSeconds = max(60, elapsedSessionSeconds)
            existingLog.caloriesBurned = computedCalories
            existingLog.notes = sessionNotes

            // Replace logged exercises and sets
            for oldEx in existingLog.loggedExercises ?? [] {
                modelContext.delete(oldEx)
            }
            if let oldFin = existingLog.loggedFinisher {
                modelContext.delete(oldFin)
            }

            insertLoggedExercisesAndFinisher(into: existingLog, modelContext: modelContext)
        } else {
            let log = WorkoutLog(
                date: Date(),
                durationSeconds: max(60, elapsedSessionSeconds),
                targetDurationMinutes: plan.targetDurationMinutes,
                mesocycle: mesocycle,
                weekIndex: plan.weekProfile.weekNumber,
                dayTemplateName: plan.dayTemplateName,
                isCustomAdHocWorkout: mesocycle == nil,
                selectedGym: activeGym,
                caloriesBurned: computedCalories,
                notes: sessionNotes
            )
            modelContext.insert(log)
            insertLoggedExercisesAndFinisher(into: log, modelContext: modelContext)

            if let meso = mesocycle {
                meso.advanceToNextWorkout()
            }
        }

        try? modelContext.save()
        hasActiveSession = false
        isPresentingFullScreen = false
        self.plan = nil
        self.reopenedWorkoutLog = nil
        self.sessionItems = []
    }

    private func insertLoggedExercisesAndFinisher(into log: WorkoutLog, modelContext: ModelContext) {
        for (idx, sessionItem) in sessionItems.enumerated() {
            let ex = sessionItem.plannedItem.resolution.activeExercise
            let swappedFrom = sessionItem.plannedItem.resolution.wasSwapped
                ? sessionItem.plannedItem.resolution.originalExercise.name
                : nil
            let loggedEx = LoggedExercise(
                orderIndex: idx,
                exercise: ex,
                swappedFromExerciseName: swappedFrom,
                wasAutoInjectedCore: sessionItem.plannedItem.wasAutoInjectedCore,
                workoutLog: log
            )
            modelContext.insert(loggedEx)

            for s in sessionItem.sets {
                let loggedSet = LoggedSet(
                    setNumber: s.setNumber,
                    weight: s.weight,
                    reps: s.reps,
                    rir: s.rir,
                    setType: s.setType,
                    isCompleted: s.isCompleted,
                    loggedExercise: loggedEx
                )
                modelContext.insert(loggedSet)
            }
        }

        if let fin = finisherPlan {
            let loggedFin = LoggedFinisher(
                title: fin.title,
                format: fin.format,
                totalDurationSeconds: finisherCompletedResult?.durationSeconds ?? (fin.effectiveDurationMinutes * 60),
                roundsCompleted: finisherCompletedResult?.roundsCompleted ?? 0,
                extraReps: finisherCompletedResult?.extraReps ?? 0,
                movementsSummary: fin.movements.joined(separator: " · "),
                isCompleted: finisherCompletedResult != nil,
                workoutLog: log
            )
            modelContext.insert(loggedFin)
        }
    }

    // MARK: - Session Clock & Live Activity State

    private func startSessionClock() {
        sessionClockTimer?.invalidate()
        sessionClockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.elapsedSessionSeconds += 1
                if self.elapsedSessionSeconds % 5 == 0 || WorkoutTimerManager.shared.isRestTimerRunning {
                    self.startOrUpdateLiveActivity()
                }
            }
        }
    }

    private func stopSessionClock() {
        sessionClockTimer?.invalidate()
        sessionClockTimer = nil
    }

    var currentLiveActivityState: HybrixWorkoutActivityAttributes.ContentState {
        let totalSets = sessionItems.reduce(0) { $0 + $1.sets.count }
        let completedSets = sessionItems.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
        let timer = WorkoutTimerManager.shared
        let unit = UserSettings.shared.weightUnit.rawValue

        for item in sessionItems {
            let workingTotal = item.sets.filter { $0.setType != .warmup }.count
            let warmupTotal = item.sets.filter { $0.setType == .warmup }.count

            if let nextSet = item.sets.first(where: { !$0.isCompleted }) {
                let isWarmup = nextSet.setType == .warmup
                let badge = isWarmup
                    ? "Warmup \(nextSet.setNumber)/\(max(1, warmupTotal))"
                    : "Set \(nextSet.setNumber) of \(workingTotal)"
                let wStr = nextSet.weight > 0 ? "\(GymProfile.formatCleanNumber(nextSet.weight)) \(unit)" : "Bodyweight"
                let rirNote = isWarmup ? "No Rest · +15s Plate Swap" : "Target \(item.plannedItem.targetRIR) RIR"

                return HybrixWorkoutActivityAttributes.ContentState(
                    workoutTitle: plan?.dayTemplateName ?? "Workout",
                    gymName: activeGym?.name ?? "Gym",
                    currentExerciseName: item.plannedItem.resolution.activeExercise.name,
                    currentSetBadge: badge,
                    isWarmupSet: isWarmup,
                    prescriptionText: "\(wStr) × \(nextSet.reps) reps · \(rirNote)",
                    targetRIR: item.plannedItem.targetRIR,
                    completedSetsCount: completedSets,
                    totalSetsCount: totalSets,
                    isResting: timer.isRestTimerRunning,
                    restRemainingSeconds: timer.restSecondsRemaining,
                    restEndDate: timer.isRestTimerRunning ? Date().addingTimeInterval(TimeInterval(timer.restSecondsRemaining)) : nil,
                    allSetsCompleted: false
                )
            }
        }

        return HybrixWorkoutActivityAttributes.ContentState(
            workoutTitle: plan?.dayTemplateName ?? "Workout",
            gymName: activeGym?.name ?? "Gym",
            currentExerciseName: "All Lifts Completed",
            currentSetBadge: "Done",
            isWarmupSet: false,
            prescriptionText: "Ready to finish & save workout",
            targetRIR: 0,
            completedSetsCount: completedSets,
            totalSetsCount: totalSets,
            isResting: false,
            restRemainingSeconds: 0,
            restEndDate: nil,
            allSetsCompleted: true
        )
    }

    func startOrUpdateLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let contentState = currentLiveActivityState
        let content = ActivityContent(state: contentState, staleDate: nil)

        if let existing = liveActivity {
            Task {
                await existing.update(content)
            }
        } else {
            let attributes = HybrixWorkoutActivityAttributes(sessionId: UUID().uuidString)
            do {
                liveActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                // Live activity unavailable in current environment
            }
        }
    }

    func endLiveActivity() {
        guard let active = liveActivity else { return }
        let finalState = currentLiveActivityState
        Task {
            await active.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        liveActivity = nil
    }
}

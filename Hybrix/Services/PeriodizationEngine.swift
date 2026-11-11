import Foundation

struct WeekPrescriptionProfile: Identifiable {
    let weekNumber: Int
    let totalWeeks: Int
    let phaseTitle: String
    let phaseSubtitle: String
    let isDeload: Bool
    let targetRIR: Int
    let targetRPE: Double
    let compoundExtraSets: Int
    let setVolumeMultiplier: Double
    let loadMultiplierVsWeek1: Double

    var id: Int { weekNumber }
}

enum PeriodizationEngine {
    static func weekProfile(
        for mesocycle: Mesocycle,
        week: Int? = nil
    ) -> WeekPrescriptionProfile {
        let w = max(1, min(week ?? mesocycle.currentWeek, mesocycle.totalWeeks))
        let total = max(2, mesocycle.totalWeeks)
        let isDeloadWeek = mesocycle.includesDeload && (w == total)

        if isDeloadWeek {
            return WeekPrescriptionProfile(
                weekNumber: w,
                totalWeeks: total,
                phaseTitle: "Deload & Recovery",
                phaseSubtitle: "Cut volume ~45% & keep 4 RIR for supercompensation",
                isDeload: true,
                targetRIR: 4,
                targetRPE: 6.0,
                compoundExtraSets: 0,
                setVolumeMultiplier: 0.55,
                loadMultiplierVsWeek1: 0.85
            )
        }

        let trainingWeeksCount = mesocycle.includesDeload ? max(1, total - 1) : total
        let progressIndex = Double(w - 1) / Double(max(1, trainingWeeksCount - 1))

        switch mesocycle.progressionModel {
        case .linearRIR:
            let rir = max(0, 3 - (w - 1))
            let rpe = min(9.5, 7.0 + Double(w - 1) * 0.8)
            let extraSets = (progressIndex >= 0.5) ? 1 : 0
            let loadMult = 1.0 + (Double(w - 1) * 0.025)

            let phaseName: String = {
                if w == 1 { return "Intro / Baseline" }
                if w == trainingWeeksCount { return "Peak / Overreach" }
                return "Accumulation \(w - 1)"
            }()

            return WeekPrescriptionProfile(
                weekNumber: w,
                totalWeeks: total,
                phaseTitle: phaseName,
                phaseSubtitle: "Target \(rir) RIR (RPE \(String(format: "%.1f", rpe))) · +\(Int((loadMult - 1.0) * 100))% vs Wk 1",
                isDeload: false,
                targetRIR: rir,
                targetRPE: rpe,
                compoundExtraSets: extraSets,
                setVolumeMultiplier: 1.0,
                loadMultiplierVsWeek1: loadMult
            )

        case .volumeAccumulation:
            let rir = max(1, 3 - (w - 1) / 2)
            let extraSets = min(2, w - 1)
            let loadMult = 1.0 + (Double(w - 1) * 0.015)

            return WeekPrescriptionProfile(
                weekNumber: w,
                totalWeeks: total,
                phaseTitle: w == 1 ? "Volume Baseline" : "Volume Ramp +\(extraSets) Set\(extraSets == 1 ? "" : "s")",
                phaseSubtitle: "Target \(rir) RIR · Add working sets on primary lifts",
                isDeload: false,
                targetRIR: rir,
                targetRPE: Double(10 - rir),
                compoundExtraSets: extraSets,
                setVolumeMultiplier: 1.0,
                loadMultiplierVsWeek1: loadMult
            )

        case .wavePercentage:
            // Wave 1: 85% baseline, Wave 2: 90%, Wave 3: 95%, etc.
            let waveMultipliers = [1.0, 1.05, 1.025, 1.075, 1.10, 1.05, 1.12]
            let loadMult = waveMultipliers[min(w - 1, waveMultipliers.count - 1)]
            let rir = (w % 2 == 0) ? 1 : 2

            return WeekPrescriptionProfile(
                weekNumber: w,
                totalWeeks: total,
                phaseTitle: "Wave Week \(w)",
                phaseSubtitle: "Undulating intensity wave (\(Int(loadMult * 100))% baseline)",
                isDeload: false,
                targetRIR: rir,
                targetRPE: Double(10 - rir),
                compoundExtraSets: (w % 2 == 1 && w > 1) ? 1 : 0,
                setVolumeMultiplier: 1.0,
                loadMultiplierVsWeek1: loadMult
            )
        }
    }

    static func prescribedSets(
        for slot: PlannedExerciseSlot,
        exercise: Exercise,
        weekProfile: WeekPrescriptionProfile
    ) -> Int {
        if weekProfile.isDeload {
            return max(2, Int((Double(slot.baseSets) * weekProfile.setVolumeMultiplier).rounded()))
        }
        if exercise.mechanicType == .compound && slot.tierPriority <= .tier2SecondaryCompound {
            return slot.baseSets + weekProfile.compoundExtraSets
        }
        return slot.baseSets
    }

    static func recommendedWeight(
        for exercise: Exercise,
        targetReps: Int,
        repRangeMin: Int? = nil,
        repRangeMax: Int? = nil,
        weekProfile: WeekPrescriptionProfile,
        history: [WorkoutLog],
        gym: GymProfile? = nil,
        settings: UserSettings = .shared
    ) -> Double {
        if exercise.requiredEquipment == [.bodyweight] && exercise.baselineWorkingWeightLbs == 0 {
            return 0
        }

        let minReps = repRangeMin ?? max(1, targetReps - 2)
        let maxReps = repRangeMax ?? (targetReps + 2)
        let effectiveGym = gym ?? GymProfile(name: "Default", availableEquipment: Set(exercise.requiredEquipment))

        // Look up most recent completed working set for this specific exercise
        let previousExercises = history
            .sorted { $0.date > $1.date }
            .flatMap { $0.sortedExercises }
            .filter { $0.exercise?.id == exercise.id || $0.exerciseNameSnapshot == exercise.name }

        if let latestInstance = previousExercises.first {
            let workingSets = latestInstance.sortedSets.filter { $0.isCompleted && $0.setType != .warmup }
            let candidateSets = workingSets.isEmpty ? latestInstance.sortedSets.filter(\.isCompleted) : workingSets

            if let bestSet = candidateSets.max(by: { $0.estimated1RM < $1.estimated1RM }),
               bestSet.weight > 0 {
                // Deload Week: ~85% of previous working weight or 1-2 steps down
                if weekProfile.isDeload {
                    let deloadTarget = bestSet.weight * 0.85
                    if exercise.usesPlates {
                        return max(settings.smallestWeightIncrement, settings.roundWeight(deloadTarget))
                    } else {
                        return effectiveGym.previousProgressionWeight(for: exercise, currentWeight: bestSet.weight, stepCount: 1, settings: settings)
                    }
                }

                // Project target working weight from RIR-aware e1RM
                let e1rm = bestSet.estimated1RM
                let rirAdjustedTargetReps = Double(targetReps + weekProfile.targetRIR)
                let e1rmProjectedWeight = e1rm / (1.0 + rirAdjustedTargetReps / 30.0)

                // Autoregulated Double-Progression + Equipment Intelligence:
                // 1. Hit/exceeded top of rep range with >= 2 RIR in reserve -> Bigger jump (2 increments or 2 weight steps)
                if bestSet.reps >= maxReps && bestSet.rir >= 2 {
                    return effectiveGym.nextProgressionWeight(for: exercise, currentWeight: bestSet.weight, stepCount: 2, settings: settings)
                }

                // 2. Hit top of rep range at 0-1 RIR, OR well inside rep range with extra RIR in reserve -> Standard jump (1 increment / next weight)
                if bestSet.reps >= maxReps || (bestSet.reps >= minReps && bestSet.rir > weekProfile.targetRIR) {
                    return effectiveGym.nextProgressionWeight(for: exercise, currentWeight: bestSet.weight, stepCount: 1, settings: settings)
                }

                // 3. Missed minimum reps at 0 RIR (total failure below rep range) -> Reduce by 1 weight step
                if bestSet.reps < minReps && bestSet.rir == 0 {
                    return effectiveGym.previousProgressionWeight(for: exercise, currentWeight: bestSet.weight, stepCount: 1, settings: settings)
                }

                // 4. Barely hit minimum reps at 0 RIR -> Hold weight to build reps before adding load
                if bestSet.reps <= minReps && bestSet.rir == 0 {
                    return bestSet.weight
                }

                // 5. Default mid-range progression: use e1RM projection if it exceeds current weight
                if e1rmProjectedWeight > bestSet.weight {
                    return effectiveGym.nextProgressionWeight(for: exercise, currentWeight: bestSet.weight, stepCount: 1, settings: settings)
                }
                return bestSet.weight
            }
        }

        // Fallback to exercise baseline scaled by week progression
        let raw = exercise.baselineWorkingWeightLbs * weekProfile.loadMultiplierVsWeek1
        if exercise.usesPlates {
            return max(0, settings.roundWeight(raw))
        } else if exercise.usesKettlebell {
            let sortedKBs = effectiveGym.availableKettlebells.sorted()
            let closest = sortedKBs.min(by: { abs($0 - raw) < abs($1 - raw) }) ?? raw
            return closest
        } else if exercise.usesDumbbell {
            let roundedDB = (raw / 5.0).rounded() * 5.0
            if let maxDB = effectiveGym.availableDumbbellMaxWeight {
                return min(maxDB, roundedDB)
            }
            return roundedDB
        }
        return max(0, settings.roundWeight(raw))
    }

    // MARK: - Target+1 RIR Cycling & Intra-Workout Autoregulation

    static func initialTapRIR(for targetRIR: Int) -> Int {
        return max(3, targetRIR + 1)
    }

    static func formatRIRButtonTitle(rir: Int, targetRIR: Int) -> String {
        let maxStart = initialTapRIR(for: targetRIR)
        if rir >= maxStart && rir > targetRIR {
            return "✓ \(rir)+ RIR"
        }
        return "✓ \(rir) RIR"
    }

    /// Evaluates whether completing `completedSet` should auto-adjust remaining uncompleted working sets in the current exercise.
    static func autoregulateRemainingSets(
        completedSetWeight: Double,
        completedSetReps: Int,
        completedSetRIR: Int,
        repRangeMin: Int,
        repRangeMax: Int,
        targetRIR: Int,
        exercise: Exercise? = nil,
        gym: GymProfile? = nil,
        settings: UserSettings = .shared
    ) -> (weightDelta: Double, note: String)? {
        guard completedSetWeight > 0 else { return nil }
        let easierThreshold = initialTapRIR(for: targetRIR)
        let effectiveGym = gym ?? GymProfile(name: "Default", availableEquipment: Set(exercise?.requiredEquipment ?? []))

        // Early failure below minimum rep range at 0 RIR -> drop remaining sets by 1 weight step
        if completedSetReps < repRangeMin && completedSetRIR == 0 {
            if let ex = exercise {
                let prevWeight = effectiveGym.previousProgressionWeight(for: ex, currentWeight: completedSetWeight, stepCount: 1, settings: settings)
                let delta = prevWeight - completedSetWeight
                return (delta, "Auto-adjusted remaining sets to \(GymProfile.formatCleanNumber(prevWeight)) \(settings.weightUnit.rawValue) after 0 RIR miss")
            } else {
                let increment = max(2.5, settings.smallestWeightIncrement)
                return (-increment, "Auto-adjusted remaining sets -\(GymProfile.formatCleanNumber(increment)) \(settings.weightUnit.rawValue) after 0 RIR miss")
            }
        }

        // Hit top of rep range with easier-than-target RIR -> bump remaining sets to next available weight
        if completedSetReps >= repRangeMax && completedSetRIR >= easierThreshold {
            if let ex = exercise {
                let nextWeight = effectiveGym.nextProgressionWeight(for: ex, currentWeight: completedSetWeight, stepCount: 1, settings: settings)
                let delta = nextWeight - completedSetWeight
                return (delta, "Auto-bumped remaining sets to \(GymProfile.formatCleanNumber(nextWeight)) \(settings.weightUnit.rawValue) (\(completedSetRIR)+ RIR at top reps)")
            } else {
                let increment = max(2.5, settings.smallestWeightIncrement)
                return (increment, "Auto-bumped remaining sets +\(GymProfile.formatCleanNumber(increment)) \(settings.weightUnit.rawValue) (\(completedSetRIR)+ RIR at top reps)")
            }
        }

        return nil
    }

    // MARK: - Progressive Warmup Set Generator (No Rest + 15s Weight Swap)

    static func generateWarmupPrescriptions(
        for exercise: Exercise,
        workingWeight: Double,
        warmupCount: Int,
        gym: GymProfile,
        settings: UserSettings = .shared
    ) -> [(weight: Double, reps: Int)] {
        guard warmupCount > 0, workingWeight > 0 else { return [] }
        let minBarWeight = gym.startingBarResistance(for: exercise)?.weight ?? settings.smallestWeightIncrement

        if warmupCount == 1 {
            let w1 = max(minBarWeight, settings.roundWeight(workingWeight * 0.60))
            return [(weight: min(w1, workingWeight), reps: 6)]
        } else {
            let w1 = max(minBarWeight, settings.roundWeight(workingWeight * 0.50))
            let w2 = max(w1, settings.roundWeight(workingWeight * 0.75))
            return [
                (weight: min(w1, workingWeight), reps: 8),
                (weight: min(w2, workingWeight), reps: 4)
            ]
        }
    }

    // MARK: - Actual Lift PR Evaluation (Weight & Reps, Not e1RM)

    struct HistoricalActualBest {
        let maxWeight: Double
        let maxRepsAtMaxWeight: Int
        let date: Date
        let gymName: String
    }

    static func historicalActualBest(
        for exercise: Exercise,
        in history: [WorkoutLog]
    ) -> HistoricalActualBest? {
        var bestWeight: Double = 0
        var bestRepsAtBestWeight: Int = 0
        var bestDate: Date = Date()
        var bestGym: String = ""

        for log in history {
            for item in log.sortedExercises where (item.exercise?.id == exercise.id || item.exerciseNameSnapshot == exercise.name) {
                let validSets = item.sortedSets.filter { $0.isCompleted && $0.setType != .warmup && $0.weight > 0 && $0.reps > 0 }
                for s in validSets {
                    if s.weight > bestWeight || (s.weight == bestWeight && s.reps > bestRepsAtBestWeight) {
                        bestWeight = s.weight
                        bestRepsAtBestWeight = s.reps
                        bestDate = log.date
                        bestGym = log.selectedGym?.name ?? log.selectedGymNameSnapshot
                    }
                }
            }
        }

        guard bestWeight > 0 else { return nil }
        return HistoricalActualBest(
            maxWeight: bestWeight,
            maxRepsAtMaxWeight: bestRepsAtBestWeight,
            date: bestDate,
            gymName: bestGym
        )
    }

    static func isActualLiftPR(
        weight: Double,
        reps: Int,
        for exercise: Exercise,
        in history: [WorkoutLog]
    ) -> Bool {
        guard weight > 0, reps > 0,
              let best = historicalActualBest(for: exercise, in: history) else {
            return false
        }
        if weight > best.maxWeight {
            return true
        }
        if weight == best.maxWeight && reps > best.maxRepsAtMaxWeight {
            return true
        }
        return false
    }
}

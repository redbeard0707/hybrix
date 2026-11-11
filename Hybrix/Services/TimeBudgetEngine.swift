import Foundation

struct PlannedExercisePrescriptionOverride: Equatable {
    var workingSets: Int?
    var repRangeMin: Int?
    var repRangeMax: Int?
    var restSeconds: Int?
    var targetStartingWeight: Double?
    var customExercise: Exercise?
}

struct ComputedPlannedExerciseItem: Identifiable {
    let id: UUID
    var slotOrderIndex: Int
    var resolution: ResolvedExerciseResolution
    var tierPriority: ExerciseTier
    var workingSets: Int
    var warmupSets: Int
    var repRangeMin: Int
    var repRangeMax: Int
    var targetRIR: Int
    var restSeconds: Int
    var recommendedWeight: Double
    var hasManualPrescriptionOverride: Bool
    var isProtectedCore: Bool
    var wasAutoInjectedCore: Bool
    var wasTrimmedByTimeBudget: Bool
    var supersetGroupId: UUID? = nil
    var supersetBadge: String? = nil

    var estimatedMinutes: Double {
        let setupSecs = 45.0
        // Each warmup set: ~25s execution + 15s weight swap (0s rest)
        let warmupSecs = Double(warmupSets) * (25.0 + 15.0)
        // If bundled into a superset, rest intervals are shared (~45% rest + 15s transition)
        let effectiveRestSecs: Double = supersetGroupId != nil
            ? (Double(restSeconds) * 0.45 + 15.0)
            : Double(restSeconds)
        let workSetSecs = Double(workingSets) * (Double(resolution.activeExercise.averageSecondsPerWorkingSet) + effectiveRestSecs)
        return (setupSecs + warmupSecs + workSetSecs) / 60.0
    }
}

struct PlannedFinisherOverride: Equatable {
    var title: String
    var format: FinisherFormat
    var durationMinutes: Int
    var workSeconds: Int
    var restSeconds: Int
    var roundsTarget: Int
    var movements: [String]
}

struct ComputedFinisherPlan: Identifiable {
    var id: String { "\(title)-\(format.rawValue)-\(effectiveDurationMinutes)" }
    var title: String
    var format: FinisherFormat
    var programmedDurationMinutes: Int
    var effectiveDurationMinutes: Int
    var workSeconds: Int
    var restSeconds: Int
    var roundsTarget: Int
    var movements: [String]
    var repSchemes: [String]
    var hasManualOverride: Bool = false
    var wasEquipmentAdjusted: Bool
    var wasDurationScaledForTimeBudget: Bool
}

struct RecalculatedWorkoutPlan {
    let dayTemplateName: String
    let focusSummary: String
    let targetDurationMinutes: Int
    let gym: GymProfile
    let weekProfile: WeekPrescriptionProfile
    var warmupPlan: ComputedWarmupPlan
    var activeExercises: [ComputedPlannedExerciseItem]
    var trimmedExercises: [ComputedPlannedExerciseItem]
    var finisher: ComputedFinisherPlan?
    let includeFinisher: Bool
    let alwaysIncludeCoreActive: Bool

    var warmupMinutesTotal: Int {
        warmupPlan.isEnabled ? warmupPlan.durationMinutes : 0
    }

    var liftingMinutesTotal: Int {
        Int(activeExercises.filter { !$0.isProtectedCore }.reduce(0.0) { $0 + $1.estimatedMinutes }.rounded())
    }

    var coreMinutesTotal: Int {
        Int(activeExercises.filter { $0.isProtectedCore }.reduce(0.0) { $0 + $1.estimatedMinutes }.rounded())
    }

    var finisherMinutesTotal: Int {
        guard includeFinisher, let fin = finisher else { return 0 }
        return fin.effectiveDurationMinutes + 2
    }

    var totalEstimatedMinutes: Int {
        warmupMinutesTotal + liftingMinutesTotal + coreMinutesTotal + finisherMinutesTotal
    }

    var swappedExercisesCount: Int {
        activeExercises.filter { $0.resolution.wasSwapped }.count
    }

    var supersetPairsCount: Int {
        Set(activeExercises.compactMap(\.supersetGroupId)).count
    }

    var estimatedCaloriesBurned: Int {
        CalorieEstimator.estimatePlannedCalories(for: self)
    }
}

enum TimeBudgetEngine {
    static func buildWorkoutPlan(
        dayTemplate: ProgramDayTemplate,
        mesocycle: Mesocycle,
        gym: GymProfile,
        targetDurationMinutes: Int,
        includeWarmup: Bool = UserSettings.shared.includeTargetedWarmup,
        warmupDurationMinutes: Int = UserSettings.shared.defaultWarmupMinutes,
        includeFinisher: Bool,
        alwaysIncludeCore: Bool,
        allExercises: [Exercise],
        history: [WorkoutLog],
        manualOverrides: [UUID: Exercise] = [:],
        prescriptionOverrides: [UUID: PlannedExercisePrescriptionOverride] = [:],
        finisherOverride: PlannedFinisherOverride? = nil,
        restoredSlotIDs: Set<UUID> = [],
        supersetGroups: [UUID: UUID] = [:],
        customSlotOrder: [UUID] = []
    ) -> RecalculatedWorkoutPlan {
        let weekProfile = PeriodizationEngine.weekProfile(for: mesocycle)
        var usedExerciseIDs = Set<UUID>()
        var allItems: [ComputedPlannedExerciseItem] = []

        for (idx, slot) in dayTemplate.sortedSlots.enumerated() {
            guard var preferred = slot.preferredExercise else { continue }
            let slotOverride = prescriptionOverrides[slot.id]

            // Check if the program has a Preferred Primary Exercise for this movement pattern
            if slot.tierPriority <= .tier2SecondaryCompound,
               let progPrefID = mesocycle.preferredExerciseID(for: preferred.movementPattern),
               !usedExerciseIDs.contains(progPrefID),
               let progPrefEx = allExercises.first(where: { $0.id == progPrefID }) {
                preferred = progPrefEx
            }

            let resolution: ResolvedExerciseResolution
            if let manualChoice = slotOverride?.customExercise ?? manualOverrides[slot.id] {
                let alternatives = EquipmentSwapEngine.rankAlternatives(
                    for: preferred,
                    in: gym,
                    allExercises: allExercises,
                    history: history,
                    excludingIDs: usedExerciseIDs
                )
                resolution = ResolvedExerciseResolution(
                    originalExercise: preferred,
                    activeExercise: manualChoice,
                    wasSwapped: manualChoice.id != preferred.id,
                    swapReason: manualChoice.id != preferred.id ? "Selected for \(gym.name)" : nil,
                    alternatives: alternatives
                )
            } else {
                resolution = EquipmentSwapEngine.resolveExercise(
                    preferred,
                    for: gym,
                    allExercises: allExercises,
                    history: history,
                    excludingIDs: usedExerciseIDs
                )
            }

            usedExerciseIDs.insert(resolution.activeExercise.id)

            let activeEx = resolution.activeExercise
            let isCore = activeEx.isCoreExercise || slot.tierPriority == .tierCore
            let basePrescribedSets = PeriodizationEngine.prescribedSets(
                for: slot,
                exercise: activeEx,
                weekProfile: weekProfile
            )

            let finalSets = slotOverride?.workingSets ?? basePrescribedSets
            let finalRepMin = slotOverride?.repRangeMin ?? slot.repRangeMin
            let finalRepMax = slotOverride?.repRangeMax ?? slot.repRangeMax
            let defaultRestForMechanic = (activeEx.mechanicType == .compound && !isCore)
                ? UserSettings.shared.defaultCompoundRestSeconds
                : UserSettings.shared.defaultIsolationRestSeconds
            let finalRest = slotOverride?.restSeconds ?? defaultRestForMechanic

            let avgReps = (finalRepMin + finalRepMax) / 2
            let autoRecWeight = PeriodizationEngine.recommendedWeight(
                for: activeEx,
                targetReps: avgReps,
                repRangeMin: finalRepMin,
                repRangeMax: finalRepMax,
                weekProfile: weekProfile,
                history: history,
                gym: gym
            )
            let finalWeight = slotOverride?.targetStartingWeight ?? autoRecWeight
            let hasCustomPrescription = slotOverride != nil

            let warmups: Int = {
                guard activeEx.mechanicType == .compound && !isCore && finalWeight > 0 else { return 0 }
                if idx == 0 && finalWeight >= 95 {
                    return 2
                } else if idx <= 1 {
                    return 1
                }
                return 0
            }()

            let item = ComputedPlannedExerciseItem(
                id: slot.id,
                slotOrderIndex: slot.orderIndex,
                resolution: resolution,
                tierPriority: isCore ? .tierCore : slot.tierPriority,
                workingSets: finalSets,
                warmupSets: warmups,
                repRangeMin: finalRepMin,
                repRangeMax: finalRepMax,
                targetRIR: weekProfile.targetRIR,
                restSeconds: finalRest,
                recommendedWeight: finalWeight,
                hasManualPrescriptionOverride: hasCustomPrescription,
                isProtectedCore: isCore && alwaysIncludeCore,
                wasAutoInjectedCore: false,
                wasTrimmedByTimeBudget: false,
                supersetGroupId: supersetGroups[slot.id]
            )
            allItems.append(item)
        }

        // Enforce "Always Include Core" setting
        let hasCoreAlready = allItems.contains { $0.resolution.activeExercise.isCoreExercise || $0.tierPriority == .tierCore }
        if alwaysIncludeCore {
            if hasCoreAlready {
                for idx in allItems.indices where allItems[idx].resolution.activeExercise.isCoreExercise {
                    allItems[idx].isProtectedCore = true
                    allItems[idx].tierPriority = .tierCore
                }
            } else if let injectedCoreRes = EquipmentSwapEngine.selectBestCoreExercise(
                for: gym,
                allExercises: allExercises,
                dayOrderIndex: dayTemplate.orderIndex,
                excludingIDs: usedExerciseIDs
            ) {
                let coreSlotID = UUID(uuidString: "00000000-0000-0000-C08E-\(String(format: "%012d", dayTemplate.orderIndex + 1))") ?? UUID()
                let coreOverride = prescriptionOverrides[coreSlotID]
                let chosenCore = coreOverride?.customExercise ?? manualOverrides[coreSlotID] ?? injectedCoreRes.activeExercise
                let finalRes = ResolvedExerciseResolution(
                    originalExercise: injectedCoreRes.originalExercise,
                    activeExercise: chosenCore,
                    wasSwapped: chosenCore.id != injectedCoreRes.originalExercise.id,
                    swapReason: nil,
                    alternatives: injectedCoreRes.alternatives
                )
                let recWeight = coreOverride?.targetStartingWeight ?? PeriodizationEngine.recommendedWeight(
                    for: chosenCore,
                    targetReps: 12,
                    repRangeMin: 10,
                    repRangeMax: 15,
                    weekProfile: weekProfile,
                    history: history,
                    gym: gym
                )
                let injectedItem = ComputedPlannedExerciseItem(
                    id: coreSlotID,
                    slotOrderIndex: 99,
                    resolution: finalRes,
                    tierPriority: .tierCore,
                    workingSets: coreOverride?.workingSets ?? (weekProfile.isDeload ? 2 : 3),
                    warmupSets: 0,
                    repRangeMin: coreOverride?.repRangeMin ?? 10,
                    repRangeMax: coreOverride?.repRangeMax ?? 15,
                    targetRIR: weekProfile.targetRIR,
                    restSeconds: coreOverride?.restSeconds ?? UserSettings.shared.defaultIsolationRestSeconds,
                    recommendedWeight: recWeight,
                    hasManualPrescriptionOverride: coreOverride != nil,
                    isProtectedCore: true,
                    wasAutoInjectedCore: true,
                    wasTrimmedByTimeBudget: false,
                    supersetGroupId: supersetGroups[coreSlotID]
                )
                allItems.append(injectedItem)
                usedExerciseIDs.insert(chosenCore.id)
            }
        }

        // Compute Finisher Plan with Dynamic Workout-to-Workout Rotation
        let finisherSeed = mesocycle.currentWeek * 17 + dayTemplate.orderIndex * 7 + history.count * 3
        var computedFinisher: ComputedFinisherPlan? = nil
        if let customFin = finisherOverride {
            let (recalcMovements, wasEquipAdjusted) = EquipmentSwapEngine.recalculateFinisherMovements(
                customFin.movements,
                format: customFin.format,
                for: gym,
                variationSeed: nil
            )
            computedFinisher = ComputedFinisherPlan(
                title: customFin.title,
                format: customFin.format,
                programmedDurationMinutes: customFin.durationMinutes,
                effectiveDurationMinutes: customFin.durationMinutes,
                workSeconds: customFin.workSeconds,
                restSeconds: customFin.restSeconds,
                roundsTarget: customFin.roundsTarget,
                movements: recalcMovements,
                repSchemes: [],
                hasManualOverride: true,
                wasEquipmentAdjusted: wasEquipAdjusted,
                wasDurationScaledForTimeBudget: false
            )
        } else if let fin = dayTemplate.finisher {
            let (recalcMovements, wasEquipAdjusted) = EquipmentSwapEngine.recalculateFinisherMovements(
                fin.movementNames,
                format: fin.format,
                for: gym,
                variationSeed: finisherSeed
            )
            var effectiveMins = fin.durationMinutes
            var scaledForBudget = false

            if includeFinisher {
                let maxFinisherMins = max(4, Int((Double(targetDurationMinutes) * 0.26).rounded()))
                if effectiveMins > maxFinisherMins && targetDurationMinutes <= 45 {
                    effectiveMins = max(4, maxFinisherMins)
                    scaledForBudget = true
                }
            }

            computedFinisher = ComputedFinisherPlan(
                title: fin.title,
                format: fin.format,
                programmedDurationMinutes: fin.durationMinutes,
                effectiveDurationMinutes: effectiveMins,
                workSeconds: fin.workSeconds,
                restSeconds: fin.restSeconds,
                roundsTarget: fin.roundsTarget,
                movements: recalcMovements,
                repSchemes: fin.movementRepSchemes,
                hasManualOverride: false,
                wasEquipmentAdjusted: wasEquipAdjusted,
                wasDurationScaledForTimeBudget: scaledForBudget
            )
        }

        // Targeted 3-7 min Warmup Plan
        let clampedWarmupMins = includeWarmup ? max(3, min(7, warmupDurationMinutes)) : 0
        let generalWarmupMins = Double(clampedWarmupMins)
        let finisherAllocationMins = (includeFinisher && computedFinisher != nil)
            ? Double(computedFinisher!.effectiveDurationMinutes + 2)
            : 0.0
        let availableLiftingAndCoreMins = max(12.0, Double(targetDurationMinutes) - generalWarmupMins - finisherAllocationMins)

        if targetDurationMinutes >= 75 {
            let currentSum = allItems.reduce(0.0) { $0 + $1.estimatedMinutes }
            if currentSum + 8.0 < availableLiftingAndCoreMins {
                if let bonusEx = allExercises.first(where: {
                    !usedExerciseIDs.contains($0.id) &&
                    gym.supports($0) &&
                    $0.tierPriority == .tier3Isolation &&
                    !$0.isCoreExercise
                }) {
                    let bonusID = UUID(uuidString: "00000000-0000-0000-B005-\(String(format: "%012d", dayTemplate.orderIndex + 1))") ?? UUID()
                    let bonusOverride = prescriptionOverrides[bonusID]
                    let bonusRes = EquipmentSwapEngine.resolveExercise(
                        bonusOverride?.customExercise ?? bonusEx,
                        for: gym,
                        allExercises: allExercises,
                        history: history,
                        excludingIDs: usedExerciseIDs
                    )
                    let bonusItem = ComputedPlannedExerciseItem(
                        id: bonusID,
                        slotOrderIndex: 90,
                        resolution: bonusRes,
                        tierPriority: .tier3Isolation,
                        workingSets: bonusOverride?.workingSets ?? 3,
                        warmupSets: 0,
                        repRangeMin: bonusOverride?.repRangeMin ?? 12,
                        repRangeMax: bonusOverride?.repRangeMax ?? 15,
                        targetRIR: weekProfile.targetRIR,
                        restSeconds: bonusOverride?.restSeconds ?? UserSettings.shared.defaultIsolationRestSeconds,
                        recommendedWeight: bonusOverride?.targetStartingWeight ?? bonusEx.baselineWorkingWeightLbs,
                        hasManualPrescriptionOverride: bonusOverride != nil,
                        isProtectedCore: false,
                        wasAutoInjectedCore: false,
                        wasTrimmedByTimeBudget: false,
                        supersetGroupId: supersetGroups[bonusID]
                    )
                    allItems.append(bonusItem)
                }
            }
        }

        // Trim or compress sets when over time budget (never drops exercises that are bundled into a Superset!)
        var active = allItems
        var trimmed: [ComputedPlannedExerciseItem] = []

        func currentLiftingAndCoreMinutes() -> Double {
            active.reduce(0.0) { $0 + $1.estimatedMinutes }
        }

        while currentLiftingAndCoreMinutes() > availableLiftingAndCoreMins + 2.5 {
            if let dropIndex = active.indices
                .filter({ idx in
                    let item = active[idx]
                    return !item.isProtectedCore &&
                           !item.hasManualPrescriptionOverride &&
                           item.supersetGroupId == nil &&
                           !restoredSlotIDs.contains(item.id) &&
                           idx > 0
                })
                .max(by: { lhs, rhs in
                    if active[lhs].tierPriority != active[rhs].tierPriority {
                        return active[lhs].tierPriority < active[rhs].tierPriority
                    }
                    return active[lhs].slotOrderIndex < active[rhs].slotOrderIndex
                }) {
                let nonCoreCount = active.filter { !$0.isProtectedCore }.count
                if nonCoreCount <= 2 {
                    break
                }
                var dropped = active.remove(at: dropIndex)
                dropped.wasTrimmedByTimeBudget = true
                trimmed.insert(dropped, at: 0)
            } else {
                break
            }
        }

        if currentLiftingAndCoreMinutes() > availableLiftingAndCoreMins + 2.0 {
            for idx in active.indices.reversed() {
                guard currentLiftingAndCoreMinutes() > availableLiftingAndCoreMins + 1.5 else { break }
                guard !active[idx].hasManualPrescriptionOverride else { continue }
                if active[idx].workingSets > 2 {
                    active[idx].workingSets -= 1
                }
                if active[idx].restSeconds > 60 {
                    active[idx].restSeconds = max(60, active[idx].restSeconds - 15)
                }
            }
        }

        // Apply custom ordering if user reordered slots, otherwise sort normally while keeping superset partners adjacent
        if !customSlotOrder.isEmpty {
            active.sort { lhs, rhs in
                let idxL = customSlotOrder.firstIndex(of: lhs.id) ?? (1000 + lhs.slotOrderIndex)
                let idxR = customSlotOrder.firstIndex(of: rhs.id) ?? (1000 + rhs.slotOrderIndex)
                return idxL < idxR
            }
        } else {
            active.sort { lhs, rhs in
                if lhs.isProtectedCore != rhs.isProtectedCore {
                    return !lhs.isProtectedCore
                }
                return lhs.slotOrderIndex < rhs.slotOrderIndex
            }
            if !supersetGroups.isEmpty {
                active = SupersetAndOrderSheet.clusterSupersetPartnersAdjacently(items: active, groups: supersetGroups)
            }
        }

        // Ensure superset groups only exist on contiguous runs of >= 2 exercises
        let rawGroupMap: [UUID: UUID] = Dictionary(
            uniqueKeysWithValues: active.compactMap { item in
                guard let gid = item.supersetGroupId else { return nil }
                return (item.id, gid)
            }
        )
        let contiguousGroupMap = SupersetAndOrderSheet.sanitizedContiguousGroups(for: active, groups: rawGroupMap)
        for idx in active.indices {
            active[idx].supersetGroupId = contiguousGroupMap[active[idx].id]
        }

        // Assign Superset Badges (A1/A2, B1/B2, etc.)
        var groupLetterIndex = 0
        var assignedLetters: [UUID: Character] = [:]
        var groupMemberCounters: [UUID: Int] = [:]
        let letters = Array("ABCDEFGH")

        for idx in active.indices {
            if let gid = active[idx].supersetGroupId {
                let countInPlan = active.filter { $0.supersetGroupId == gid }.count
                if countInPlan >= 2 {
                    let letter: Character
                    if let existing = assignedLetters[gid] {
                        letter = existing
                    } else {
                        letter = letters[min(groupLetterIndex, letters.count - 1)]
                        assignedLetters[gid] = letter
                        groupLetterIndex += 1
                    }
                    let num = (groupMemberCounters[gid] ?? 0) + 1
                    groupMemberCounters[gid] = num
                    active[idx].supersetBadge = "Superset \(letter)\(num)"
                } else {
                    active[idx].supersetGroupId = nil
                    active[idx].supersetBadge = nil
                }
            }
        }

        let warmupPlan = WarmupGenerator.buildTargetedWarmup(
            for: active,
            gym: gym,
            isEnabled: includeWarmup,
            durationMinutes: clampedWarmupMins
        )

        return RecalculatedWorkoutPlan(
            dayTemplateName: dayTemplate.name,
            focusSummary: dayTemplate.focusSummary,
            targetDurationMinutes: targetDurationMinutes,
            gym: gym,
            weekProfile: weekProfile,
            warmupPlan: warmupPlan,
            activeExercises: active,
            trimmedExercises: trimmed,
            finisher: computedFinisher,
            includeFinisher: includeFinisher,
            alwaysIncludeCoreActive: alwaysIncludeCore
        )
    }

    /// Pairs compatible non-competing or antagonist exercises into supersets (e.g. Push+Pull, Biceps+Triceps, Quad+Hamstring, Isolation+Core).
    static func autoSuggestSupersetGroups(for items: [ComputedPlannedExerciseItem]) -> [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        var pairedIDs = Set<UUID>()

        // Prefer pairing secondary/isolation/core lifts first, then antagonist compounds
        let candidates = items
        for i in candidates.indices {
            let first = candidates[i]
            guard !pairedIDs.contains(first.id) else { continue }

            for j in (i + 1)..<candidates.count {
                let second = candidates[j]
                guard !pairedIDs.contains(second.id) else { continue }

                // Compatible if they target different primary muscles
                if first.resolution.activeExercise.primaryMuscle != second.resolution.activeExercise.primaryMuscle {
                    let groupID = UUID()
                    result[first.id] = groupID
                    result[second.id] = groupID
                    pairedIDs.insert(first.id)
                    pairedIDs.insert(second.id)
                    break
                }
            }
        }
        return result
    }
}

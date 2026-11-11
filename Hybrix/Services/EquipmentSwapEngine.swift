import Foundation

struct ExerciseCandidateMatch: Identifiable {
    let exercise: Exercise
    let score: Int
    let matchReason: String

    var id: UUID { exercise.id }
}

struct ResolvedExerciseResolution {
    let originalExercise: Exercise
    let activeExercise: Exercise
    let wasSwapped: Bool
    let swapReason: String?
    let alternatives: [ExerciseCandidateMatch]
}

enum EquipmentSwapEngine {
    static func resolveExercise(
        _ preferred: Exercise,
        for gym: GymProfile,
        allExercises: [Exercise],
        history: [WorkoutLog] = [],
        excludingIDs: Set<UUID> = []
    ) -> ResolvedExerciseResolution {
        let candidates = rankAlternatives(
            for: preferred,
            in: gym,
            allExercises: allExercises,
            history: history,
            excludingIDs: excludingIDs
        )

        // Check if user saved a permanent preferred swap for this exercise at this gym
        if let savedSwapID = gym.preferredReplacementID(for: preferred.id),
           !excludingIDs.contains(savedSwapID),
           let savedReplacement = allExercises.first(where: { $0.id == savedSwapID }),
           gym.supports(savedReplacement) {
            return ResolvedExerciseResolution(
                originalExercise: preferred,
                activeExercise: savedReplacement,
                wasSwapped: savedReplacement.id != preferred.id,
                swapReason: savedReplacement.id != preferred.id ? "Saved preference at \(gym.name)" : nil,
                alternatives: candidates
            )
        }

        if gym.supports(preferred) {
            return ResolvedExerciseResolution(
                originalExercise: preferred,
                activeExercise: preferred,
                wasSwapped: false,
                swapReason: nil,
                alternatives: candidates
            )
        }

        // Needs equipment swap
        let missingEquip = preferred.requiredEquipment.filter { !gym.availableEquipment.contains($0) }
        let missingDesc: String = {
            if !missingEquip.isEmpty {
                return "Missing \(missingEquip.map(\.rawValue).joined(separator: ", ")) at \(gym.name)"
            }
            if let maxDB = gym.availableDumbbellMaxWeight {
                return "Exceeds \(Int(maxDB)) lb dumbbell cap at \(gym.name)"
            }
            return "Unavailable at \(gym.name)"
        }()

        if let bestMatch = candidates.first {
            return ResolvedExerciseResolution(
                originalExercise: preferred,
                activeExercise: bestMatch.exercise,
                wasSwapped: true,
                swapReason: missingDesc,
                alternatives: candidates
            )
        }

        // Ultimate fallback if nothing matched
        return ResolvedExerciseResolution(
            originalExercise: preferred,
            activeExercise: preferred,
            wasSwapped: false,
            swapReason: missingDesc,
            alternatives: []
        )
    }

    static func rankAlternatives(
        for target: Exercise,
        in gym: GymProfile,
        allExercises: [Exercise],
        history: [WorkoutLog] = [],
        excludingIDs: Set<UUID> = []
    ) -> [ExerciseCandidateMatch] {
        let supported = allExercises.filter { candidate in
            candidate.id != target.id &&
            !excludingIDs.contains(candidate.id) &&
            gym.supports(candidate)
        }

        let performedExerciseIDsAtGym: Set<UUID> = Set(
            history
                .filter { $0.selectedGym?.id == gym.id }
                .flatMap { $0.sortedExercises }
                .compactMap { $0.exercise?.id }
        )

        var matches: [ExerciseCandidateMatch] = []

        for candidate in supported {
            var score = 0
            var reasons: [String] = []

            if candidate.movementPattern == target.movementPattern {
                score += 55
                reasons.append("Same pattern (\(candidate.movementPattern.rawValue))")
            }

            if candidate.primaryMuscle == target.primaryMuscle {
                score += 35
                reasons.append("Same primary muscle (\(candidate.primaryMuscle.rawValue))")
            } else if target.secondaryMuscles.contains(candidate.primaryMuscle) ||
                      candidate.secondaryMuscles.contains(target.primaryMuscle) {
                score += 12
                reasons.append("Shared muscle group")
            }

            if candidate.mechanicType == target.mechanicType {
                score += 15
            }

            if performedExerciseIDsAtGym.contains(candidate.id) {
                score += 10
                reasons.append("Logged at \(gym.name)")
            }

            let sharedSecondary = Set(candidate.secondaryMuscles).intersection(Set(target.secondaryMuscles))
            score += sharedSecondary.count * 4

            if score >= 25 {
                matches.append(
                    ExerciseCandidateMatch(
                        exercise: candidate,
                        score: score,
                        matchReason: reasons.isEmpty ? "Compatible equipment" : reasons.joined(separator: " · ")
                    )
                )
            }
        }

        return matches.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.exercise.name < $1.exercise.name
        }
    }

    static func selectBestCoreExercise(
        for gym: GymProfile,
        allExercises: [Exercise],
        dayOrderIndex: Int = 0,
        excludingIDs: Set<UUID> = []
    ) -> ResolvedExerciseResolution? {
        let validCoreExercises = allExercises.filter { ex in
            ex.isCoreExercise && gym.supports(ex) && !excludingIDs.contains(ex.id)
        }

        guard !validCoreExercises.isEmpty else { return nil }

        // Rotate core patterns across training days (Anti-Extension -> Flexion -> Rotation)
        let preferredPatterns: [MovementPattern] = [.coreAntiExtension, .coreFlexion, .coreRotation]
        let preferredPattern = preferredPatterns[abs(dayOrderIndex) % preferredPatterns.count]

        let chosen = validCoreExercises.first(where: { $0.movementPattern == preferredPattern })
            ?? validCoreExercises.first!

        let otherCoreMatches = validCoreExercises
            .filter { $0.id != chosen.id }
            .map {
                ExerciseCandidateMatch(
                    exercise: $0,
                    score: $0.movementPattern == chosen.movementPattern ? 90 : 75,
                    matchReason: "\($0.movementPattern.rawValue) · \($0.equipmentSummary)"
                )
            }

        return ResolvedExerciseResolution(
            originalExercise: chosen,
            activeExercise: chosen,
            wasSwapped: false,
            swapReason: nil,
            alternatives: otherCoreMatches
        )
    }

    static func recalculateFinisherMovements(
        _ movementNames: [String],
        format: FinisherFormat = .emom,
        for gym: GymProfile,
        variationSeed: Int? = nil
    ) -> (movements: [String], wasAdjusted: Bool) {
        if let seed = variationSeed {
            let rotated = generateDynamicFinisherMovements(
                format: format,
                for: gym,
                stationCount: max(2, movementNames.count),
                variationSeed: seed
            )
            return (rotated, false)
        }

        var adjusted: [String] = []
        var changed = false

        for (idx, item) in movementNames.enumerated() {
            var currentItem = item

            // If EMOM, ensure only ONE single movement per minute with scaled effort (~40–45s work)
            if format == .emom {
                let normalized = normalizeEMOMStation(currentItem, stationIndex: idx)
                if normalized != currentItem {
                    changed = true
                    currentItem = normalized
                }
            }

            let lower = currentItem.lowercased()
            let prefix: String = {
                if format == .emom, currentItem.contains(":") {
                    return (currentItem.components(separatedBy: ":").first ?? "Min \(idx + 1)") + ": "
                }
                return format == .emom ? "Min \(idx + 1): " : ""
            }()

            if (lower.contains("row") && lower.contains("cal")) && !gym.availableEquipment.contains(.rower) {
                changed = true
                if gym.availableEquipment.contains(.assaultBike) {
                    adjusted.append(prefix + (format == .emom ? "15 Cal Assault Bike" : "12 Cal Assault Bike"))
                } else if gym.availableEquipment.contains(.kettlebell) {
                    adjusted.append(prefix + (format == .emom ? "20 Kettlebell Swings" : "15 Kettlebell Swings"))
                } else {
                    adjusted.append(prefix + (format == .emom ? "15 Burpees" : "12 Burpees"))
                }
            } else if lower.contains("assault bike") && !gym.availableEquipment.contains(.assaultBike) {
                changed = true
                if gym.availableEquipment.contains(.rower) {
                    adjusted.append(prefix + "16 Cal Row")
                } else if gym.availableEquipment.contains(.dumbbell) {
                    adjusted.append(prefix + "16 Dumbbell Thrusters")
                } else {
                    adjusted.append(prefix + "15 Burpees")
                }
            } else if lower.contains("kettlebell") && !gym.availableEquipment.contains(.kettlebell) {
                changed = true
                if gym.availableEquipment.contains(.dumbbell) {
                    adjusted.append(currentItem.replacingOccurrences(of: "Kettlebell", with: "Dumbbell"))
                } else {
                    adjusted.append(prefix + "20 Jump Squats")
                }
            } else if lower.contains("box jump") && !gym.availableEquipment.contains(.plyoBox) {
                changed = true
                adjusted.append(prefix + "15 Broad Jumps")
            } else if lower.contains("sled") && !gym.availableEquipment.contains(.sled) {
                changed = true
                adjusted.append(prefix + "20 Walking Lunges")
            } else {
                adjusted.append(currentItem)
            }
        }

        return (adjusted, changed)
    }

    /// Generates varied, equipment-supported conditioning movements so every workout and week rotates fresh stations.
    static func generateDynamicFinisherMovements(
        format: FinisherFormat,
        for gym: GymProfile,
        stationCount: Int = 2,
        variationSeed: Int
    ) -> [String] {
        let equip = gym.availableEquipment

        // Build pool of single-exercise conditioning stations supported by this gym
        var emomPool: [String] = []
        var amrapPool: [String] = []
        var tabataPool: [String] = []

        if equip.contains(.rower) {
            emomPool.append("16 Cal Row")
            amrapPool.append("12 Cal Row")
            tabataPool.append("Max Effort Concept2 Row Sprint")
        }
        if equip.contains(.assaultBike) {
            emomPool.append("15 Cal Assault Bike")
            amrapPool.append("12 Cal Assault Bike")
            tabataPool.append("All-Out Air Bike Sprint")
        }
        if equip.contains(.stationaryBike) {
            emomPool.append("45s High-RPM Stationary Bike Sprint")
            amrapPool.append("20 Cal Stationary Bike")
            tabataPool.append("Stationary Bike Sprint")
        }
        if equip.contains(.stairClimber) {
            emomPool.append("45s Stair Climber Fast Climb")
            amrapPool.append("60 Steps Stair Climber")
        }
        if equip.contains(.kettlebell) {
            emomPool.append("20 Kettlebell Swings")
            emomPool.append("16 Goblet Squats (KB)")
            amrapPool.append("15 Kettlebell Swings")
            amrapPool.append("12 KB Goblet Lunges")
            tabataPool.append("Russian Kettlebell Swings")
        }
        if equip.contains(.dumbbell) {
            emomPool.append("16 Dumbbell Thrusters")
            emomPool.append("16 Alternating DB Snatches")
            emomPool.append("18 Dumbbell Push Press")
            amrapPool.append("10 Dumbbell Thrusters")
            amrapPool.append("12 Alternating DB Snatches")
            tabataPool.append("Dumbbell Push Press")
        }
        if equip.contains(.medicineBall) {
            emomPool.append("18 Medicine Ball Slams")
            emomPool.append("16 Wall Ball Shots")
            amrapPool.append("14 Medicine Ball Slams")
            amrapPool.append("15 Wall Ball Shots")
            tabataPool.append("Medicine Ball Slams")
        }
        if equip.contains(.plyoBox) {
            emomPool.append("14 Box Jumps")
            amrapPool.append("12 Box Jumps")
            tabataPool.append("Box Jump Overs")
        }
        if equip.contains(.sled) {
            emomPool.append("40m Prowler Sled Push")
            amrapPool.append("30m Sled Push")
        }
        if equip.contains(.battleRopes) {
            emomPool.append("40s Battle Rope Waves")
            tabataPool.append("Battle Rope Alternating Waves")
        }
        if equip.contains(.skiErg) {
            emomPool.append("15 Cal SkiErg")
            amrapPool.append("12 Cal SkiErg")
        }
        if equip.contains(.trxSuspension) {
            emomPool.append("18 TRX Jump Squats / Rows")
            amrapPool.append("14 TRX Atomic Push-Ups")
        }

        // Always include high-output bodyweight options for variety
        emomPool.append(contentsOf: ["15 Burpees", "22 Push-Ups", "24 Jumping Lunges", "45s Hardstyle Plank Hold"])
        amrapPool.append(contentsOf: ["12 Burpees", "15 Push-Ups", "20 Mountain Climbers", "16 Alternating Jumping Lunges"])
        tabataPool.append(contentsOf: ["Burpees", "Mountain Climbers", "Jump Squats", "Hollow Body Hold"])

        let positiveSeed = abs(variationSeed)

        switch format {
        case .emom:
            let count = max(2, min(3, stationCount))
            var chosen: [String] = []
            let step = max(1, (positiveSeed % 3) + 1)
            for i in 0..<count {
                let idx = (positiveSeed * 3 + i * step) % emomPool.count
                let candidate = emomPool[idx]
                let label: String
                if count == 2 {
                    label = i == 0 ? "Min 1 (Odd): " : "Min 2 (Even): "
                } else {
                    label = "Min \(i + 1): "
                }
                chosen.append(label + candidate)
            }
            return chosen

        case .amrap:
            var chosen: [String] = []
            for i in 0..<3 {
                let idx = (positiveSeed * 2 + i * 3) % amrapPool.count
                let move = amrapPool[idx]
                if !chosen.contains(move) {
                    chosen.append(move)
                } else {
                    chosen.append(amrapPool[(idx + 1) % amrapPool.count])
                }
            }
            return chosen

        case .tabata:
            let idx1 = (positiveSeed * 2) % tabataPool.count
            let idx2 = (idx1 + 2) % tabataPool.count
            return [tabataPool[idx1], tabataPool[idx2]]

        case .forTime:
            let idx1 = (positiveSeed * 2) % amrapPool.count
            let idx2 = (idx1 + 3) % amrapPool.count
            return ["3 Rounds For Time: \(amrapPool[idx1]) + \(amrapPool[idx2])"]
        }
    }

    /// Ensures any EMOM station string contains strictly ONE exercise for that minute, with rep/calorie count scaled to ~40–45s of work.
    static func normalizeEMOMStation(_ rawStation: String, stationIndex: Int) -> String {
        let prefixParts = rawStation.components(separatedBy: ":")
        let body = (prefixParts.count > 1 ? prefixParts.dropFirst().joined(separator: ":") : rawStation)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let labelPrefix: String = {
            if prefixParts.count > 1 {
                return prefixParts[0].trimmingCharacters(in: .whitespaces) + ": "
            }
            return "Min \(stationIndex + 1): "
        }()

        // If the station combined multiple exercises with "+" or "/", split and pick the primary movement for this minute
        if body.contains("+") || body.contains("/") {
            let parts = body
                .components(separatedBy: CharacterSet(charactersIn: "+/"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            // Pick the movement matching the minute index or the more demanding movement
            let chosenPart = parts.last ?? body
            return labelPrefix + scaleEMOMSingleMovementEffort(chosenPart)
        }

        return labelPrefix + scaleEMOMSingleMovementEffort(body)
    }

    /// Scales a single movement prescription to fill a full 40–45s EMOM minute.
    static func scaleEMOMSingleMovementEffort(_ rawMovement: String) -> String {
        let lower = rawMovement.lowercased()
        if lower.contains("push-up") {
            return "22 Push-Ups"
        } else if lower.contains("thruster") {
            return "16 Dumbbell Thrusters"
        } else if lower.contains("swing") {
            return "20 Kettlebell Swings"
        } else if lower.contains("burpee") {
            return "15 Burpees"
        } else if lower.contains("row") && lower.contains("cal") {
            return "16 Cal Row"
        } else if lower.contains("bike") && lower.contains("cal") {
            return "15 Cal Assault Bike"
        } else if lower.contains("snatch") {
            return "16 Alternating DB Snatches"
        } else if lower.contains("plank") {
            return "45s Hardstyle Plank Hold"
        } else if lower.contains("goblet") {
            return "16 Goblet Squats"
        } else if lower.contains("box jump") {
            return "14 Box Jumps"
        }
        return rawMovement
    }
}

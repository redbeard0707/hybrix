import Foundation
import SwiftData

@Model
final class GymProfile {
    var id: UUID = UUID()
    var name: String = "My Gym"
    var iconName: String = "dumbbell.fill"
    var locationNote: String = ""
    var isDefault: Bool = false
    var isCustom: Bool = true
    var availableEquipmentRaw: [String] = []
    var availableDumbbellMaxWeight: Double? = nil
    var createdAt: Date = Date()

    // Bar & Plate Configuration (with safe primitive defaults for SwiftData migration)
    var availablePlatesCSV: String = "45,35,25,10,5,2.5"
    var availableKettlebellsCSV: String = "9,13,18,26,35,44,53,62,70"
    var barbellWeightLbs: Double = 45.0
    var smithMachineBarWeightLbs: Double = 20.0
    var ezCurlBarWeightLbs: Double = 25.0
    var trapBarWeightLbs: Double = 45.0

    // Saved Per-Gym Preferred Exercise Swaps (Original Exercise UUID -> Replacement Exercise UUID)
    var preferredSwapsJSON: String = "{}"

    @Relationship(deleteRule: .nullify, inverse: \WorkoutLog.selectedGym)
    var workoutLogs: [WorkoutLog]? = []

    static let allStandardPlateOptions: [Double] = [55, 45, 35, 25, 15, 10, 5, 2.5, 1.25]
    static let allStandardKettlebellOptions: [Double] = [
        9, 10, 13, 15, 18, 20, 25, 26, 30, 35, 40, 44, 45, 50, 53, 60, 62, 70, 80, 88, 106
    ]

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "dumbbell.fill",
        locationNote: String = "",
        isDefault: Bool = false,
        isCustom: Bool = true,
        availableEquipment: Set<EquipmentType>,
        availableDumbbellMaxWeight: Double? = nil,
        availablePlates: [Double] = [45, 35, 25, 10, 5, 2.5],
        availableKettlebells: [Double] = [9, 13, 18, 26, 35, 44, 53, 62, 70],
        barbellWeightLbs: Double = 45.0,
        smithMachineBarWeightLbs: Double = 20.0,
        ezCurlBarWeightLbs: Double = 25.0,
        trapBarWeightLbs: Double = 45.0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.locationNote = locationNote
        self.isDefault = isDefault
        self.isCustom = isCustom
        self.availableEquipmentRaw = availableEquipment.map(\.rawValue).sorted()
        self.availableDumbbellMaxWeight = availableDumbbellMaxWeight
        self.availablePlatesCSV = availablePlates.sorted(by: >).map { Self.formatCleanNumber($0) }.joined(separator: ",")
        self.availableKettlebellsCSV = availableKettlebells.sorted().map { Self.formatCleanNumber($0) }.joined(separator: ",")
        self.barbellWeightLbs = barbellWeightLbs
        self.smithMachineBarWeightLbs = smithMachineBarWeightLbs
        self.ezCurlBarWeightLbs = ezCurlBarWeightLbs
        self.trapBarWeightLbs = trapBarWeightLbs
        self.preferredSwapsJSON = "{}"
    }

    var availableEquipment: Set<EquipmentType> {
        get {
            var set = Set(availableEquipmentRaw.compactMap { EquipmentType(rawValue: $0) })
            set.insert(.bodyweight)
            return set
        }
        set {
            var updated = newValue
            updated.insert(.bodyweight)
            availableEquipmentRaw = updated.map(\.rawValue).sorted()
        }
    }

    var availablePlates: [Double] {
        get {
            let parsed = availablePlatesCSV
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                .filter { $0 > 0 }
                .sorted(by: >)
            return parsed.isEmpty ? [45, 35, 25, 10, 5, 2.5] : parsed
        }
        set {
            let uniqueSorted = Array(Set(newValue)).sorted(by: >)
            availablePlatesCSV = uniqueSorted.map { Self.formatCleanNumber($0) }.joined(separator: ",")
        }
    }

    var availableKettlebells: [Double] {
        get {
            let parsed = availableKettlebellsCSV
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                .filter { $0 > 0 }
                .sorted()
            return parsed.isEmpty ? [9, 13, 18, 26, 35, 44, 53, 62, 70] : parsed
        }
        set {
            let uniqueSorted = Array(Set(newValue)).sorted()
            availableKettlebellsCSV = uniqueSorted.map { Self.formatCleanNumber($0) }.joined(separator: ",")
        }
    }

    func nextAvailableKettlebell(above current: Double, stepCount: Int = 1) -> Double {
        let weights = availableKettlebells.sorted()
        guard !weights.isEmpty else { return current + 5.0 }
        let higher = weights.filter { $0 > current + 0.1 }
        guard !higher.isEmpty else { return weights.last ?? current }
        let targetIndex = min(higher.count - 1, max(0, stepCount - 1))
        return higher[targetIndex]
    }

    func previousAvailableKettlebell(below current: Double, stepCount: Int = 1) -> Double {
        let weights = availableKettlebells.sorted()
        guard !weights.isEmpty else { return max(9.0, current - 5.0) }
        let lower = weights.filter { $0 < current - 0.1 }
        guard !lower.isEmpty else { return weights.first ?? current }
        let targetIndex = max(0, lower.count - stepCount)
        return lower[targetIndex]
    }

    func nextAvailableDumbbell(above current: Double, stepCount: Int = 1) -> Double {
        let step = 5.0
        let baseNext = ((current / step).rounded(.down) + Double(stepCount)) * step
        let next = max(current + (current < 15 ? 2.5 : 5.0), baseNext)
        if let maxDB = availableDumbbellMaxWeight {
            return min(maxDB, next)
        }
        return next
    }

    func previousAvailableDumbbell(below current: Double, stepCount: Int = 1) -> Double {
        let step = 5.0
        let basePrev = ((current / step).rounded(.up) - Double(stepCount)) * step
        let prev = min(current - (current <= 15 ? 2.5 : 5.0), basePrev)
        return max(5.0, prev)
    }

    func nextProgressionWeight(
        for exercise: Exercise,
        currentWeight: Double,
        stepCount: Int = 1,
        settings: UserSettings = .shared
    ) -> Double {
        if exercise.usesPlates {
            let inc = max(1.25, settings.smallestWeightIncrement)
            return settings.roundWeight(currentWeight + (inc * Double(stepCount)))
        } else if exercise.usesKettlebell {
            return nextAvailableKettlebell(above: currentWeight, stepCount: stepCount)
        } else if exercise.usesDumbbell {
            return nextAvailableDumbbell(above: currentWeight, stepCount: stepCount)
        } else {
            // Machine / Cable stack: minimum 5 lb step unless user sets larger
            let inc = max(5.0, settings.smallestWeightIncrement)
            return settings.roundWeight(currentWeight + (inc * Double(stepCount)))
        }
    }

    func previousProgressionWeight(
        for exercise: Exercise,
        currentWeight: Double,
        stepCount: Int = 1,
        settings: UserSettings = .shared
    ) -> Double {
        if exercise.usesPlates {
            let inc = max(1.25, settings.smallestWeightIncrement)
            return max(inc, settings.roundWeight(currentWeight - (inc * Double(stepCount))))
        } else if exercise.usesKettlebell {
            return previousAvailableKettlebell(below: currentWeight, stepCount: stepCount)
        } else if exercise.usesDumbbell {
            return previousAvailableDumbbell(below: currentWeight, stepCount: stepCount)
        } else {
            let inc = max(5.0, settings.smallestWeightIncrement)
            return max(inc, settings.roundWeight(currentWeight - (inc * Double(stepCount))))
        }
    }

    var preferredSwapsMap: [String: String] {
        get {
            guard let data = preferredSwapsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                preferredSwapsJSON = str
            }
        }
    }

    func preferredReplacementID(for originalExerciseID: UUID) -> UUID? {
        guard let str = preferredSwapsMap[originalExerciseID.uuidString] else { return nil }
        return UUID(uuidString: str)
    }

    func setPreferredReplacement(_ replacementID: UUID?, for originalExerciseID: UUID) {
        var map = preferredSwapsMap
        if let rep = replacementID, rep != originalExerciseID {
            map[originalExerciseID.uuidString] = rep.uuidString
        } else {
            map.removeValue(forKey: originalExerciseID.uuidString)
        }
        preferredSwapsMap = map
    }

    /// All saved swap preferences as (original → replacement) ID pairs.
    var preferredSwapPairs: [(originalID: UUID, replacementID: UUID)] {
        preferredSwapsMap.compactMap { key, value in
            guard let o = UUID(uuidString: key), let r = UUID(uuidString: value) else { return nil }
            return (o, r)
        }
    }

    func clearAllPreferredReplacements() {
        preferredSwapsJSON = "{}"
    }

    func hasEquipment(_ equipment: [EquipmentType]) -> Bool {
        let available = availableEquipment
        return equipment.allSatisfy { available.contains($0) }
    }

    func supports(_ exercise: Exercise) -> Bool {
        guard hasEquipment(exercise.requiredEquipment) else { return false }
        if exercise.usesFlexibleFreeWeight {
            let anyWeightOptions: Set<EquipmentType> = [
                .weightPlates, .dumbbell, .kettlebell, .medicineBall, .barbell, .ezCurlBar
            ]
            if availableEquipment.isDisjoint(with: anyWeightOptions) {
                return false
            }
        }
        if let maxDB = availableDumbbellMaxWeight,
           exercise.requiredEquipment.contains(.dumbbell),
           let minDBNeeded = exercise.minimumDumbbellWeightRecommended,
           minDBNeeded > maxDB {
            return false
        }
        return true
    }

    // MARK: - Bar & Plate Breakdown Calculator

    func startingBarResistance(for exercise: Exercise) -> (label: String, weight: Double)? {
        let req = Set(exercise.requiredEquipment)
        if req.contains(.smithMachine) {
            return ("Smith Bar", smithMachineBarWeightLbs)
        } else if req.contains(.trapBar) {
            return ("Trap Bar", trapBarWeightLbs)
        } else if req.contains(.ezCurlBar) {
            return ("EZ Bar", ezCurlBarWeightLbs)
        } else if req.contains(.barbell) {
            return ("Bar", barbellWeightLbs)
        } else if req.contains(.hackSquat) || req.contains(.legPress) {
            return ("Sled", 0)
        }
        return nil
    }

    func plateBreakdownDescription(forTotalWeight totalWeight: Double, exercise: Exercise) -> String? {
        guard totalWeight > 0,
              let barInfo = startingBarResistance(for: exercise) else {
            return nil
        }

        let barWeight = barInfo.weight
        if totalWeight <= barWeight {
            return barWeight > 0 ? "\(barInfo.label) only (\(Self.formatCleanNumber(barWeight)) lb)" : nil
        }

        var perSideRemaining = (totalWeight - barWeight) / 2.0
        let plates = availablePlates
        var perSideStack: [String] = []

        for plate in plates where plate > 0 {
            while perSideRemaining + 0.01 >= plate {
                perSideStack.append(Self.formatCleanNumber(plate))
                perSideRemaining -= plate
            }
        }

        let barPrefix = barWeight > 0 ? "\(barInfo.label) \(Self.formatCleanNumber(barWeight)) · " : ""
        if perSideStack.isEmpty {
            return "\(barInfo.label) \(Self.formatCleanNumber(barWeight)) lb"
        }
        return "\(barPrefix)\(perSideStack.joined(separator: " + ")) /side"
    }

    static func formatCleanNumber(_ val: Double) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(val))"
        } else if (val * 10).truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.1f", val)
        } else {
            return String(format: "%.2f", val)
        }
    }
}

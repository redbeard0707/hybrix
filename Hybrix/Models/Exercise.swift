import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var isCustom: Bool = false
    var movementPatternRaw: String = MovementPattern.horizontalPush.rawValue
    var primaryMuscleRaw: String = MuscleGroup.chest.rawValue
    var secondaryMusclesRaw: [String] = []
    var requiredEquipmentRaw: [String] = []
    var mechanicTypeRaw: String = MechanicType.compound.rawValue
    var tierPriorityRaw: Int = ExerciseTier.tier2SecondaryCompound.rawValue
    var averageSecondsPerWorkingSet: Int = 45
    var defaultRestSeconds: Int = 90
    var baselineWorkingWeightLbs: Double = 95
    var minimumDumbbellWeightRecommended: Double? = nil
    var isUnilateral: Bool = false
    var formCues: String = ""
    var defaultFinisherRepScheme: String = "12 reps"

    @Relationship(deleteRule: .nullify, inverse: \PlannedExerciseSlot.preferredExercise)
    var plannedSlots: [PlannedExerciseSlot]? = []

    @Relationship(deleteRule: .nullify, inverse: \LoggedExercise.exercise)
    var loggedInstances: [LoggedExercise]? = []

    init(
        id: UUID = UUID(),
        name: String,
        isCustom: Bool = false,
        movementPattern: MovementPattern,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        requiredEquipment: [EquipmentType] = [.bodyweight],
        mechanicType: MechanicType = .compound,
        tierPriority: ExerciseTier = .tier2SecondaryCompound,
        averageSecondsPerWorkingSet: Int = 45,
        defaultRestSeconds: Int = 90,
        baselineWorkingWeightLbs: Double = 95,
        minimumDumbbellWeightRecommended: Double? = nil,
        isUnilateral: Bool = false,
        formCues: String = "",
        defaultFinisherRepScheme: String = "12 reps"
    ) {
        self.id = id
        self.name = name
        self.isCustom = isCustom
        self.movementPatternRaw = movementPattern.rawValue
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMusclesRaw = secondaryMuscles.map(\.rawValue)
        self.requiredEquipmentRaw = requiredEquipment.map(\.rawValue)
        self.mechanicTypeRaw = mechanicType.rawValue
        self.tierPriorityRaw = tierPriority.rawValue
        self.averageSecondsPerWorkingSet = averageSecondsPerWorkingSet
        self.defaultRestSeconds = defaultRestSeconds
        self.baselineWorkingWeightLbs = baselineWorkingWeightLbs
        self.minimumDumbbellWeightRecommended = minimumDumbbellWeightRecommended
        self.isUnilateral = isUnilateral
        self.formCues = formCues
        self.defaultFinisherRepScheme = defaultFinisherRepScheme
    }

    var movementPattern: MovementPattern {
        get { MovementPattern(rawValue: movementPatternRaw) ?? .horizontalPush }
        set { movementPatternRaw = newValue.rawValue }
    }

    var primaryMuscle: MuscleGroup {
        get { MuscleGroup(rawValue: primaryMuscleRaw) ?? .chest }
        set { primaryMuscleRaw = newValue.rawValue }
    }

    var secondaryMuscles: [MuscleGroup] {
        get { secondaryMusclesRaw.compactMap { MuscleGroup(rawValue: $0) } }
        set { secondaryMusclesRaw = newValue.map(\.rawValue) }
    }

    var requiredEquipment: [EquipmentType] {
        get {
            let items = requiredEquipmentRaw.compactMap { EquipmentType(rawValue: $0) }
            return items.isEmpty ? [.bodyweight] : items
        }
        set { requiredEquipmentRaw = newValue.map(\.rawValue) }
    }

    var mechanicType: MechanicType {
        get { MechanicType(rawValue: mechanicTypeRaw) ?? .compound }
        set { mechanicTypeRaw = newValue.rawValue }
    }

    var tierPriority: ExerciseTier {
        get { ExerciseTier(rawValue: tierPriorityRaw) ?? .tier2SecondaryCompound }
        set { tierPriorityRaw = newValue.rawValue }
    }

    var isCoreExercise: Bool {
        mechanicType == .core || primaryMuscle.isCoreMuscle || movementPattern.isCorePattern
    }

    var usesFlexibleFreeWeight: Bool {
        guard baselineWorkingWeightLbs > 0 else { return false }
        let stationOnlyEquipment: Set<EquipmentType> = [
            .bodyweight, .adjustableBench, .flatBench, .declineBench, .ghdOrRomanChair,
            .pullUpBar, .dipStation, .stabilityBosuBall
        ]
        return requiredEquipment.allSatisfy { stationOnlyEquipment.contains($0) }
    }

    var usesPlates: Bool {
        requiredEquipment.contains(.weightPlates) ||
        requiredEquipment.contains(.barbell) ||
        requiredEquipment.contains(.smithMachine) ||
        requiredEquipment.contains(.trapBar)
    }

    var usesKettlebell: Bool {
        requiredEquipment.contains(.kettlebell) && !usesPlates
    }

    var usesDumbbell: Bool {
        requiredEquipment.contains(.dumbbell) && !usesPlates && !usesKettlebell
    }

    var equipmentSummary: String {
        if usesFlexibleFreeWeight {
            let stations = requiredEquipment.filter { $0 != .bodyweight }.map(\.rawValue)
            if stations.isEmpty {
                return "Any Weight (Plate, DB, or KB)"
            } else {
                return (stations + ["Any Weight (Plate, DB, or KB)"]).joined(separator: " + ")
            }
        }
        return requiredEquipment.map(\.rawValue).joined(separator: " + ")
    }
}

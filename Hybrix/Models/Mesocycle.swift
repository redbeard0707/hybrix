import Foundation
import SwiftData

@Model
final class Mesocycle: Identifiable {
    var id: UUID = UUID()
    var name: String = "Hypertrophy Block"
    var splitTypeRaw: String = SplitType.upperLower.rawValue
    var progressionModelRaw: String = ProgressionModel.linearRIR.rawValue
    var startDate: Date = Date()
    var totalWeeks: Int = 5
    var currentWeek: Int = 1
    var currentDayIndex: Int = 0
    var includesDeload: Bool = true
    var isActive: Bool = true
    var notes: String = ""
    var preferredPrimaryExercisesJSON: String = "{}"

    @Relationship(deleteRule: .cascade, inverse: \ProgramDayTemplate.mesocycle)
    var dayTemplates: [ProgramDayTemplate]? = []

    @Relationship(deleteRule: .nullify, inverse: \WorkoutLog.mesocycle)
    var workoutLogs: [WorkoutLog]? = []

    init(
        id: UUID = UUID(),
        name: String,
        splitType: SplitType,
        progressionModel: ProgressionModel = .linearRIR,
        startDate: Date = Date(),
        totalWeeks: Int = 5,
        currentWeek: Int = 1,
        currentDayIndex: Int = 0,
        includesDeload: Bool = true,
        isActive: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.splitTypeRaw = splitType.rawValue
        self.progressionModelRaw = progressionModel.rawValue
        self.startDate = startDate
        self.totalWeeks = totalWeeks
        self.currentWeek = currentWeek
        self.currentDayIndex = currentDayIndex
        self.includesDeload = includesDeload
        self.isActive = isActive
        self.notes = notes
    }

    var splitType: SplitType {
        get { SplitType(rawValue: splitTypeRaw) ?? .upperLower }
        set { splitTypeRaw = newValue.rawValue }
    }

    var progressionModel: ProgressionModel {
        get { ProgressionModel(rawValue: progressionModelRaw) ?? .linearRIR }
        set { progressionModelRaw = newValue.rawValue }
    }

    var sortedDays: [ProgramDayTemplate] {
        (dayTemplates ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    var activeDayTemplate: ProgramDayTemplate? {
        let days = sortedDays
        guard !days.isEmpty else { return nil }
        let idx = max(0, min(currentDayIndex, days.count - 1))
        return days[idx]
    }

    func advanceToNextWorkout() {
        let days = sortedDays
        guard !days.isEmpty else { return }
        if currentDayIndex + 1 < days.count {
            currentDayIndex += 1
        } else {
            currentDayIndex = 0
            if currentWeek < totalWeeks {
                currentWeek += 1
            }
        }
    }

    func stepBackwardOneWorkout() {
        let days = sortedDays
        guard !days.isEmpty else { return }
        if currentDayIndex > 0 {
            currentDayIndex -= 1
        } else if currentWeek > 1 {
            currentWeek -= 1
            currentDayIndex = max(0, days.count - 1)
        }
    }

    var preferredPrimaryExercisesMap: [String: String] {
        get {
            guard let data = preferredPrimaryExercisesJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                preferredPrimaryExercisesJSON = str
            }
        }
    }

    func preferredExerciseID(for pattern: MovementPattern) -> UUID? {
        guard let str = preferredPrimaryExercisesMap[pattern.rawValue] else { return nil }
        return UUID(uuidString: str)
    }

    func setPreferredExercise(_ exercise: Exercise?, for pattern: MovementPattern) {
        var map = preferredPrimaryExercisesMap
        if let ex = exercise {
            map[pattern.rawValue] = ex.id.uuidString
        } else {
            map.removeValue(forKey: pattern.rawValue)
        }
        preferredPrimaryExercisesMap = map
    }
}

@Model
final class ProgramDayTemplate: Identifiable {
    var id: UUID = UUID()
    var name: String = "Day 1"
    var focusSummary: String = ""
    var orderIndex: Int = 0
    var mesocycle: Mesocycle? = nil

    @Relationship(deleteRule: .cascade, inverse: \PlannedExerciseSlot.dayTemplate)
    var exerciseSlots: [PlannedExerciseSlot]? = []

    @Relationship(deleteRule: .cascade, inverse: \FinisherPrescription.dayTemplate)
    var finisher: FinisherPrescription? = nil

    init(
        id: UUID = UUID(),
        name: String,
        focusSummary: String = "",
        orderIndex: Int = 0,
        mesocycle: Mesocycle? = nil
    ) {
        self.id = id
        self.name = name
        self.focusSummary = focusSummary
        self.orderIndex = orderIndex
        self.mesocycle = mesocycle
    }

    var sortedSlots: [PlannedExerciseSlot] {
        (exerciseSlots ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
}

@Model
final class PlannedExerciseSlot {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var preferredExercise: Exercise? = nil
    var tierPriorityRaw: Int = ExerciseTier.tier2SecondaryCompound.rawValue
    var baseSets: Int = 3
    var repRangeMin: Int = 8
    var repRangeMax: Int = 12
    var baseTargetRIR: Int = 2
    var restSeconds: Int = 90
    var dayTemplate: ProgramDayTemplate? = nil

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        preferredExercise: Exercise?,
        tierPriority: ExerciseTier? = nil,
        baseSets: Int = 3,
        repRangeMin: Int = 8,
        repRangeMax: Int = 12,
        baseTargetRIR: Int = 2,
        restSeconds: Int = 90,
        dayTemplate: ProgramDayTemplate? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.preferredExercise = preferredExercise
        let resolvedTier = tierPriority ?? preferredExercise?.tierPriority ?? .tier2SecondaryCompound
        self.tierPriorityRaw = resolvedTier.rawValue
        self.baseSets = baseSets
        self.repRangeMin = repRangeMin
        self.repRangeMax = repRangeMax
        self.baseTargetRIR = baseTargetRIR
        self.restSeconds = restSeconds
        self.dayTemplate = dayTemplate
    }

    var tierPriority: ExerciseTier {
        get { ExerciseTier(rawValue: tierPriorityRaw) ?? preferredExercise?.tierPriority ?? .tier2SecondaryCompound }
        set { tierPriorityRaw = newValue.rawValue }
    }
}

@Model
final class FinisherPrescription {
    var id: UUID = UUID()
    var title: String = "Conditioning Finisher"
    var formatRaw: String = FinisherFormat.emom.rawValue
    var durationMinutes: Int = 10
    var workSeconds: Int = 20
    var restSeconds: Int = 10
    var roundsTarget: Int = 8
    var movementNames: [String] = []
    var movementRepSchemes: [String] = []
    var dayTemplate: ProgramDayTemplate? = nil

    init(
        id: UUID = UUID(),
        title: String,
        format: FinisherFormat,
        durationMinutes: Int = 10,
        workSeconds: Int = 20,
        restSeconds: Int = 10,
        roundsTarget: Int = 8,
        movementNames: [String] = [],
        movementRepSchemes: [String] = [],
        dayTemplate: ProgramDayTemplate? = nil
    ) {
        self.id = id
        self.title = title
        self.formatRaw = format.rawValue
        self.durationMinutes = durationMinutes
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.roundsTarget = roundsTarget
        self.movementNames = movementNames
        self.movementRepSchemes = movementRepSchemes
        self.dayTemplate = dayTemplate
    }

    var format: FinisherFormat {
        get { FinisherFormat(rawValue: formatRaw) ?? .emom }
        set { formatRaw = newValue.rawValue }
    }
}

import Foundation
import SwiftData

@Model
final class WorkoutLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var durationSeconds: Int = 0
    var targetDurationMinutes: Int = 60
    var mesocycle: Mesocycle? = nil
    var weekIndex: Int = 1
    var dayTemplateName: String = "Workout"
    var isCustomAdHocWorkout: Bool = false
    var selectedGym: GymProfile? = nil
    var selectedGymNameSnapshot: String = ""
    var caloriesBurned: Int = 0
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.workoutLog)
    var loggedExercises: [LoggedExercise]? = []

    @Relationship(deleteRule: .cascade, inverse: \LoggedFinisher.workoutLog)
    var loggedFinisher: LoggedFinisher? = nil

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        durationSeconds: Int = 0,
        targetDurationMinutes: Int = 60,
        mesocycle: Mesocycle? = nil,
        weekIndex: Int = 1,
        dayTemplateName: String,
        isCustomAdHocWorkout: Bool = false,
        selectedGym: GymProfile? = nil,
        caloriesBurned: Int = 0,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
        self.targetDurationMinutes = targetDurationMinutes
        self.mesocycle = mesocycle
        self.weekIndex = weekIndex
        self.dayTemplateName = dayTemplateName
        self.isCustomAdHocWorkout = isCustomAdHocWorkout
        self.selectedGym = selectedGym
        self.selectedGymNameSnapshot = selectedGym?.name ?? "My Gym"
        self.caloriesBurned = caloriesBurned
        self.notes = notes
    }

    var estimatedCaloriesBurned: Int {
        if caloriesBurned > 0 { return caloriesBurned }
        return CalorieEstimator.estimateCalories(for: self)
    }

    var sortedExercises: [LoggedExercise] {
        (loggedExercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    var totalVolumeLbs: Double {
        sortedExercises.reduce(0) { acc, item in
            acc + item.completedVolume
        }
    }

    var totalCompletedSets: Int {
        sortedExercises.reduce(0) { acc, item in
            acc + item.sortedSets.filter(\.isCompleted).count
        }
    }
}

@Model
final class LoggedExercise {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var exercise: Exercise? = nil
    var exerciseNameSnapshot: String = ""
    var swappedFromExerciseName: String? = nil
    var wasAutoInjectedCore: Bool = false
    var workoutLog: WorkoutLog? = nil

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.loggedExercise)
    var sets: [LoggedSet]? = []

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        exercise: Exercise?,
        swappedFromExerciseName: String? = nil,
        wasAutoInjectedCore: Bool = false,
        workoutLog: WorkoutLog? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.exerciseNameSnapshot = exercise?.name ?? "Exercise"
        self.swappedFromExerciseName = swappedFromExerciseName
        self.wasAutoInjectedCore = wasAutoInjectedCore
        self.workoutLog = workoutLog
    }

    var sortedSets: [LoggedSet] {
        (sets ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    var completedVolume: Double {
        sortedSets.filter(\.isCompleted).reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    var bestEstimated1RM: Double {
        sortedSets.filter(\.isCompleted).map(\.estimated1RM).max() ?? 0
    }
}

@Model
final class LoggedSet {
    var id: UUID = UUID()
    var setNumber: Int = 1
    var weight: Double = 0
    var reps: Int = 10
    var rir: Int = 2
    var setTypeRaw: String = SetType.working.rawValue
    var isCompleted: Bool = false
    var loggedExercise: LoggedExercise? = nil

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weight: Double,
        reps: Int,
        rir: Int = 2,
        setType: SetType = .working,
        isCompleted: Bool = false,
        loggedExercise: LoggedExercise? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.rir = rir
        self.setTypeRaw = setType.rawValue
        self.isCompleted = isCompleted
        self.loggedExercise = loggedExercise
    }

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }

    var estimated1RM: Double {
        guard weight > 0, reps > 0 else { return 0 }
        let effectiveRepsToFailure = reps + max(0, min(5, rir))
        if effectiveRepsToFailure <= 1 { return weight }
        return weight * (1.0 + Double(effectiveRepsToFailure) / 30.0)
    }
}

@Model
final class LoggedFinisher {
    var id: UUID = UUID()
    var title: String = "Finisher"
    var formatRaw: String = FinisherFormat.emom.rawValue
    var totalDurationSeconds: Int = 600
    var roundsCompleted: Int = 0
    var extraReps: Int = 0
    var movementsSummary: String = ""
    var isCompleted: Bool = false
    var workoutLog: WorkoutLog? = nil

    init(
        id: UUID = UUID(),
        title: String,
        format: FinisherFormat,
        totalDurationSeconds: Int,
        roundsCompleted: Int = 0,
        extraReps: Int = 0,
        movementsSummary: String = "",
        isCompleted: Bool = false,
        workoutLog: WorkoutLog? = nil
    ) {
        self.id = id
        self.title = title
        self.formatRaw = format.rawValue
        self.totalDurationSeconds = totalDurationSeconds
        self.roundsCompleted = roundsCompleted
        self.extraReps = extraReps
        self.movementsSummary = movementsSummary
        self.isCompleted = isCompleted
        self.workoutLog = workoutLog
    }

    var format: FinisherFormat {
        get { FinisherFormat(rawValue: formatRaw) ?? .emom }
        set { formatRaw = newValue.rawValue }
    }
}

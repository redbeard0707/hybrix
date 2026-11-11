import Foundation
import SwiftUI

enum MuscleVolumeStatus: String {
    case underTarget = "Needs Volume"
    case optimal = "Optimal"
    case highFatigue = "High Fatigue"

    var color: Color {
        switch self {
        case .underTarget: return .blue
        case .optimal: return .green
        case .highFatigue: return .red
        }
    }
}

struct MuscleVolumeBreakdown: Identifiable {
    let muscle: MuscleGroup
    let directSets: Int
    let fractionalSecondarySets: Double

    var id: String { muscle.rawValue }

    var effectiveWeeklySets: Double {
        Double(directSets) + fractionalSecondarySets
    }

    var status: MuscleVolumeStatus {
        let s = effectiveWeeklySets
        if s < 6.0 {
            return .underTarget
        } else if s <= 18.0 {
            return .optimal
        } else {
            return .highFatigue
        }
    }
}

enum VolumeAndFatigueAnalyzer {
    static func analyzeRolling7Days(logs: [WorkoutLog], allExercises: [Exercise]) -> [MuscleVolumeBreakdown] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentLogs = logs.filter { $0.date >= sevenDaysAgo }

        var directMap: [MuscleGroup: Int] = [:]
        var secondaryMap: [MuscleGroup: Double] = [:]
        let exByName = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.name, $0) })

        for log in recentLogs {
            for loggedEx in log.sortedExercises {
                let completedWorkingCount = loggedEx.sortedSets.filter { $0.isCompleted && $0.setType != .warmup }.count
                guard completedWorkingCount > 0 else { continue }

                if let ex = loggedEx.exercise ?? exByName[loggedEx.exerciseNameSnapshot] {
                    directMap[ex.primaryMuscle, default: 0] += completedWorkingCount
                    for sec in ex.secondaryMuscles {
                        secondaryMap[sec, default: 0.0] += Double(completedWorkingCount) * 0.5
                    }
                } else if loggedEx.wasAutoInjectedCore {
                    directMap[.abs, default: 0] += completedWorkingCount
                }
            }
        }

        return MuscleGroup.allCases.map { muscle in
            MuscleVolumeBreakdown(
                muscle: muscle,
                directSets: directMap[muscle, default: 0],
                fractionalSecondarySets: secondaryMap[muscle, default: 0.0]
            )
        }
        .sorted {
            if $0.effectiveWeeklySets != $1.effectiveWeeklySets {
                return $0.effectiveWeeklySets > $1.effectiveWeeklySets
            }
            return $0.muscle.rawValue < $1.muscle.rawValue
        }
    }
}

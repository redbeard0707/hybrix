import Foundation

enum CalorieEstimator {
    /// Calculates estimated calories burned for a completed or planned workout.
    /// Combines MET-based resistance training expenditure, mechanical volume density bonus,
    /// and high-intensity conditioning finisher (EMOM/AMRAP/Tabata) expenditure.
    static func estimateCalories(
        durationSeconds: Int,
        totalVolumeLbs: Double,
        completedSetsCount: Int,
        finisherDurationSeconds: Int,
        finisherFormat: FinisherFormat?,
        bodyweightLbs: Double = UserSettings.shared.userBodyweightLbs
    ) -> Int {
        let weightKg = max(45.0, bodyweightLbs * 0.453592)
        let totalMinutes = max(5.0, Double(durationSeconds) / 60.0)
        let finisherMinutes = min(totalMinutes * 0.5, Double(max(0, finisherDurationSeconds)) / 60.0)
        let liftingMinutes = max(0.0, totalMinutes - finisherMinutes)

        // Vigorous resistance training MET ~ 5.5 (1 MET = 1.05 kcal/kg/hr)
        let liftingMET = 5.2
        let liftingKcalPerMin = (liftingMET * 3.5 * weightKg) / 200.0
        let baseLiftingKcal = liftingMinutes * liftingKcalPerMin

        // Volume & set density bonus (~1.8 kcal per 1,000 lbs moved + 2.2 kcal per working set)
        let volumeBonusKcal = (totalVolumeLbs / 1000.0) * 1.8 + (Double(completedSetsCount) * 2.2)

        // Conditioning Finisher MET (EMOM/AMRAP/Tabata ~ 9.0–10.5 METs)
        let finisherMET: Double = {
            guard let format = finisherFormat else { return 0 }
            switch format {
            case .tabata: return 10.5
            case .amrap, .forTime: return 9.8
            case .emom: return 9.0
            }
        }()
        let finisherKcalPerMin = (finisherMET * 3.5 * weightKg) / 200.0
        let finisherKcal = finisherMinutes * finisherKcalPerMin

        let total = baseLiftingKcal + volumeBonusKcal + finisherKcal
        return max(40, Int(total.rounded()))
    }

    static func estimateCalories(for log: WorkoutLog) -> Int {
        let finSecs = log.loggedFinisher?.totalDurationSeconds ?? 0
        let finFormat = log.loggedFinisher?.format
        return estimateCalories(
            durationSeconds: log.durationSeconds,
            totalVolumeLbs: log.totalVolumeLbs,
            completedSetsCount: log.totalCompletedSets,
            finisherDurationSeconds: finSecs,
            finisherFormat: finFormat
        )
    }

    static func estimatePlannedCalories(for plan: RecalculatedWorkoutPlan) -> Int {
        let setsCount = plan.activeExercises.reduce(0) { $0 + $1.workingSets }
        let estVol = plan.activeExercises.reduce(0.0) { acc, item in
            let avgReps = Double(item.repRangeMin + item.repRangeMax) / 2.0
            return acc + (Double(item.workingSets) * avgReps * max(35.0, item.recommendedWeight))
        }
        let finSecs = (plan.includeFinisher && plan.finisher != nil) ? (plan.finisher!.effectiveDurationMinutes * 60) : 0
        return estimateCalories(
            durationSeconds: plan.totalEstimatedMinutes * 60,
            totalVolumeLbs: estVol,
            completedSetsCount: setsCount,
            finisherDurationSeconds: finSecs,
            finisherFormat: plan.includeFinisher ? plan.finisher?.format : nil
        )
    }
}

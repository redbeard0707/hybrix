import Foundation

struct WarmupDrillItem: Identifiable {
    let id = UUID()
    let name: String
    let prescription: String
    let targetFocus: String
    let durationSeconds: Int
}

struct ComputedWarmupPlan {
    let isEnabled: Bool
    let durationMinutes: Int
    let focusSummary: String
    let drills: [WarmupDrillItem]
}

enum WarmupGenerator {
    static func buildTargetedWarmup(
        for activeExercises: [ComputedPlannedExerciseItem],
        gym: GymProfile,
        isEnabled: Bool,
        durationMinutes: Int = 5
    ) -> ComputedWarmupPlan {
        let clampedMinutes = max(3, min(7, durationMinutes))
        guard isEnabled else {
            return ComputedWarmupPlan(
                isEnabled: false,
                durationMinutes: 0,
                focusSummary: "Warmup disabled",
                drills: []
            )
        }

        let patterns = Set(activeExercises.map { $0.resolution.activeExercise.movementPattern })
        let muscles = Set(activeExercises.map { $0.resolution.activeExercise.primaryMuscle })

        var drills: [WarmupDrillItem] = []

        // 1. General Pulse Raiser (60-90s) adapted to gym equipment
        if gym.availableEquipment.contains(.rower) {
            drills.append(WarmupDrillItem(
                name: "Easy Zone-1 Concept2 Row",
                prescription: "60–90 sec nasal breathing",
                targetFocus: "Core temperature & thoracic blood flow",
                durationSeconds: 75
            ))
        } else if gym.availableEquipment.contains(.assaultBike) {
            drills.append(WarmupDrillItem(
                name: "Easy Spin on Assault / Air Bike",
                prescription: "60–90 sec progressive cadence",
                targetFocus: "Upper + lower joint lubrication",
                durationSeconds: 75
            ))
        } else {
            drills.append(WarmupDrillItem(
                name: "Jumping Jacks + Inchworm Walkouts",
                prescription: "60 sec continuous flow",
                targetFocus: "Total-body pulse raiser & hamstring length",
                durationSeconds: 60
            ))
        }

        // 2. Movement-Specific Mobility & Activation Drills
        let hasUpperPush = patterns.contains(.horizontalPush) || patterns.contains(.inclinePush) || patterns.contains(.verticalPush)
        let hasUpperPull = patterns.contains(.horizontalPull) || patterns.contains(.verticalPull)
        let hasSquatOrLunge = patterns.contains(.squat) || patterns.contains(.unilateralLeg) || muscles.contains(.quads)
        let hasHinge = patterns.contains(.hipHinge) || muscles.contains(.hamstrings) || muscles.contains(.glutes)

        if hasUpperPush || hasUpperPull {
            if gym.availableEquipment.contains(.resistanceBands) {
                drills.append(WarmupDrillItem(
                    name: "Band Pull-Aparts & Shoulder Dislocates",
                    prescription: "15 Pull-Aparts + 10 Pass-Throughs",
                    targetFocus: "Scapular retraction & rotator cuff prep",
                    durationSeconds: 60
                ))
            } else {
                drills.append(WarmupDrillItem(
                    name: "Scapular Push-Ups + Prone Y-T-W Raises",
                    prescription: "10 Scap Push-Ups + 8/8/8 Y-T-W",
                    targetFocus: "Serratus anterior & lower trap activation",
                    durationSeconds: 60
                ))
            }

            drills.append(WarmupDrillItem(
                name: "Quadruped Thoracic Rotations (T-Spine Windmills)",
                prescription: "8 slow reps per side",
                targetFocus: "Thoracic extension & overhead/pressing mobility",
                durationSeconds: 50
            ))
        }

        if hasSquatOrLunge {
            drills.append(WarmupDrillItem(
                name: "World's Greatest Stretch + Pry Goblet Squat Hold",
                prescription: "5/side + 30s deep squat ankle/hip pry",
                targetFocus: "Hip capsule, adductors & ankle dorsiflexion",
                durationSeconds: 65
            ))
        }

        if hasHinge {
            drills.append(WarmupDrillItem(
                name: "Single-Leg Glute Bridge + Bodyweight Good Mornings",
                prescription: "10/side bridges + 12 tempo hinges",
                targetFocus: "Glute firing & posterior chain priming",
                durationSeconds: 60
            ))
        }

        // 3. First Primary Lift Ramp-Up Prep Set
        if let firstCompound = activeExercises.first?.resolution.activeExercise {
            drills.append(WarmupDrillItem(
                name: "\(firstCompound.name) · Empty Bar / Light Ramp Set",
                prescription: "1–2 smooth sets × 8–10 reps @ 50–65% working load",
                targetFocus: "Groove primary movement pattern before working sets",
                durationSeconds: 75
            ))
        }

        // Trim or pad drills to match 3–7 min target
        let maxDrills = clampedMinutes <= 3 ? 3 : (clampedMinutes <= 5 ? 4 : 5)
        let selectedDrills = Array(drills.prefix(maxDrills))

        let focusTags: [String] = [
            (hasUpperPush || hasUpperPull) ? "Shoulders & T-Spine" : nil,
            hasSquatOrLunge ? "Hips & Ankles" : nil,
            hasHinge ? "Glutes & Hamstrings" : nil
        ].compactMap { $0 }

        let summary = focusTags.isEmpty ? "Full Body Dynamic Prep" : focusTags.joined(separator: " · ")

        return ComputedWarmupPlan(
            isEnabled: true,
            durationMinutes: clampedMinutes,
            focusSummary: summary,
            drills: selectedDrills
        )
    }
}

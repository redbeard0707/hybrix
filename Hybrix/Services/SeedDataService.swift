import Foundation
import SwiftData

enum SeedDataService {
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let existingGyms = (try? context.fetch(FetchDescriptor<GymProfile>())) ?? []
        let existingExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingMesocycles = (try? context.fetch(FetchDescriptor<Mesocycle>())) ?? []

        // 1. Seed Gyms (only when no gyms exist yet)
        if existingGyms.isEmpty {
            let commercialGym = GymProfile(
                name: "Commercial Fitness Center",
                iconName: "building.2.fill",
                locationNote: "Full rack, cables, machines, turf & cardio",
                isDefault: true,
                isCustom: false,
                availableEquipment: GymPresetTemplate.fullCommercial.equipmentSet,
                availableDumbbellMaxWeight: 120
            )

            let homeGarageGym = GymProfile(
                name: "Home Garage Gym",
                iconName: "house.fill",
                locationNote: "Power rack, barbell, DBs up to 75 lbs, pull-up bar, rower",
                isDefault: false,
                isCustom: false,
                availableEquipment: GymPresetTemplate.homeGarageRack.equipmentSet,
                availableDumbbellMaxWeight: 75
            )

            let hotelGym = GymProfile(
                name: "Hotel / Travel Gym",
                iconName: "bed.double.fill",
                locationNote: "Dumbbells up to 50 lbs, adjustable bench, dual cable pulley, treadmill",
                isDefault: false,
                isCustom: false,
                availableEquipment: GymPresetTemplate.hotelDumbbells.equipmentSet,
                availableDumbbellMaxWeight: 50
            )

            context.insert(commercialGym)
            context.insert(homeGarageGym)
            context.insert(hotelGym)
            if UserSettings.shared.activeGymProfileId == nil {
                UserSettings.shared.activeGymProfileId = commercialGym.id.uuidString
            }
        }

        // 2. Seed Lift Database (Comprehensive across Movement Patterns & Equipment)
        // Preserves all existing exercises and any custom user additions/modifications (`isCustom == true`).
        var exByName: [String: Exercise] = [:]
        for ex in existingExercises {
            exByName[ex.name] = ex
        }

        func addEx(
            _ name: String,
            pattern: MovementPattern,
            primary: MuscleGroup,
            secondary: [MuscleGroup] = [],
            equip: [EquipmentType],
            mechanic: MechanicType = .compound,
            tier: ExerciseTier = .tier2SecondaryCompound,
            secPerSet: Int = 45,
            rest: Int = 90,
            baseWeight: Double = 95,
            minDB: Double? = nil,
            isUnilateral: Bool = false,
            cues: String = ""
        ) -> Exercise {
            if let existing = exByName[name] {
                if name.contains("Decline") && !existing.requiredEquipment.contains(.declineBench) {
                    existing.requiredEquipment = equip
                }
                return existing
            }
            let ex = Exercise(
                name: name,
                isCustom: false,
                movementPattern: pattern,
                primaryMuscle: primary,
                secondaryMuscles: secondary,
                requiredEquipment: equip,
                mechanicType: mechanic,
                tierPriority: tier,
                averageSecondsPerWorkingSet: secPerSet,
                defaultRestSeconds: rest,
                baselineWorkingWeightLbs: baseWeight,
                minimumDumbbellWeightRecommended: minDB,
                isUnilateral: isUnilateral,
                formCues: cues
            )
            context.insert(ex)
            exByName[name] = ex
            return ex
        }

        // Horizontal Push
        let bbBench = addEx("Barbell Bench Press", pattern: .horizontalPush, primary: .chest, secondary: [.triceps, .frontDelt], equip: [.barbell, .flatBench, .squatRack, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 120, baseWeight: 185, cues: "Retract scapula, slight arch, drive feet into floor.")
        let dbFlatBench = addEx("Dumbbell Flat Bench Press", pattern: .horizontalPush, primary: .chest, secondary: [.triceps, .frontDelt], equip: [.dumbbell, .flatBench], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 105, baseWeight: 70, minDB: 45, cues: "Deep stretch at bottom, controlled press.")
        _ = addEx("Smith Machine Flat Bench Press", pattern: .horizontalPush, primary: .chest, secondary: [.triceps, .frontDelt], equip: [.smithMachine, .flatBench, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 105, baseWeight: 165, cues: "Set bench so bar touches lower sternum; drive elbows in a controlled 45° path.")
        _ = addEx("Machine Chest Press", pattern: .horizontalPush, primary: .chest, secondary: [.triceps, .frontDelt], equip: [.chestPressMachine], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 150, cues: "Keep shoulders pinned back against pad.")
        _ = addEx("Weighted / Deficit Push-Ups", pattern: .horizontalPush, primary: .chest, secondary: [.triceps, .frontDelt, .abs], equip: [.bodyweight], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 75, baseWeight: 0, cues: "Rigid plank line, elbows at 45 degrees.")
        let cableFly = addEx("Cable Chest Fly", pattern: .horizontalPush, primary: .chest, secondary: [.frontDelt], equip: [.dualCablePulley], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 35, cues: "Slight bend in elbows, squeeze pecs together.")
        _ = addEx("Pec Deck Machine Fly", pattern: .horizontalPush, primary: .chest, secondary: [.frontDelt], equip: [.pecDeck], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 115)
        _ = addEx("Dumbbell Chest Fly", pattern: .horizontalPush, primary: .chest, secondary: [.frontDelt], equip: [.dumbbell, .flatBench], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 30)
        _ = addEx("Decline Barbell Bench Press", pattern: .horizontalPush, primary: .chest, secondary: [.triceps, .frontDelt], equip: [.barbell, .declineBench, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 105, baseWeight: 175, cues: "Lock ankles under rollers, lower bar smoothly to lower sternum, press up over lower chest.")
        _ = addEx("Decline Dumbbell Bench Press", pattern: .horizontalPush, primary: .chest, secondary: [.triceps, .frontDelt], equip: [.dumbbell, .declineBench], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 65, minDB: 40, cues: "Secure legs in foot pads, lower dumbbells deep alongside lower chest, press and converge.")
        _ = addEx("Smith Machine Decline Bench Press", pattern: .horizontalPush, primary: .chest, secondary: [.triceps, .frontDelt], equip: [.smithMachine, .declineBench, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 155, cues: "Position decline bench so bar touches lower sternum; press smoothly through fixed plane.")
        _ = addEx("Decline Dumbbell Chest Fly", pattern: .horizontalPush, primary: .chest, secondary: [.frontDelt], equip: [.dumbbell, .declineBench], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 25, cues: "Slight elbow bend, stretch deep across lower chest and squeeze together over lower sternum.")

        // Incline Push
        let inclineDBPress = addEx("Incline Dumbbell Press", pattern: .inclinePush, primary: .upperChest, secondary: [.chest, .frontDelt, .triceps], equip: [.dumbbell, .adjustableBench], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 65, cues: "Set bench to 30 degrees for optimal upper pec line.")
        let inclineBBPress = addEx("Incline Barbell Bench Press", pattern: .inclinePush, primary: .upperChest, secondary: [.chest, .frontDelt, .triceps], equip: [.barbell, .adjustableBench, .squatRack, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 120, baseWeight: 155)
        _ = addEx("Smith Machine Incline Press", pattern: .inclinePush, primary: .upperChest, secondary: [.chest, .triceps], equip: [.smithMachine, .adjustableBench, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 145)
        _ = addEx("Feet-Elevated Pike / Incline Push-Up", pattern: .inclinePush, primary: .upperChest, secondary: [.frontDelt, .triceps], equip: [.bodyweight], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 75, baseWeight: 0)

        // Vertical Push
        let ohp = addEx("Overhead Barbell Press (OHP)", pattern: .verticalPush, primary: .frontDelt, secondary: [.sideDelt, .triceps, .upperChest], equip: [.barbell, .squatRack, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 120, baseWeight: 115, cues: "Squeeze glutes & abs, press bar straight overhead.")
        _ = addEx("Smith Machine Seated Overhead Press", pattern: .verticalPush, primary: .frontDelt, secondary: [.sideDelt, .triceps, .upperChest], equip: [.smithMachine, .adjustableBench, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 105, baseWeight: 115, cues: "Set bench to 75–80° high incline; lower bar to chin/clavicle level without flaring ribs.")
        let seatedDBShoulder = addEx("Seated Dumbbell Shoulder Press", pattern: .verticalPush, primary: .frontDelt, secondary: [.sideDelt, .triceps], equip: [.dumbbell, .adjustableBench], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 50)
        _ = addEx("Machine Shoulder Press", pattern: .verticalPush, primary: .frontDelt, secondary: [.sideDelt, .triceps], equip: [.shoulderPressMachine], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 110)
        _ = addEx("Single-Arm Kettlebell Overhead Press", pattern: .verticalPush, primary: .frontDelt, secondary: [.sideDelt, .triceps, .obliques], equip: [.kettlebell], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 75, baseWeight: 45)

        // Horizontal Pull
        let bbRow = addEx("Barbell Bent-Over Row", pattern: .horizontalPull, primary: .upperBack, secondary: [.lats, .rearDelt, .biceps, .lowerBack], equip: [.barbell, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 120, baseWeight: 165, cues: "Hinge to ~45 degrees, pull toward lower ribs.")
        _ = addEx("Smith Machine Bent-Over Row", pattern: .horizontalPull, primary: .upperBack, secondary: [.lats, .rearDelt, .biceps], equip: [.smithMachine, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 105, baseWeight: 155, cues: "Hinge torso to ~45°, set safety stops just below knee height, pull bar into lower ribs.")
        let chestSupportedRow = addEx("Chest-Supported Machine / Cable Row", pattern: .horizontalPull, primary: .upperBack, secondary: [.lats, .rearDelt, .biceps], equip: [.seatedRowMachine], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 140)
        let dbRow = addEx("Single-Arm Dumbbell Row", pattern: .horizontalPull, primary: .lats, secondary: [.upperBack, .rearDelt, .biceps], equip: [.dumbbell, .flatBench], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 75, cues: "Pull dumbbell in an arc toward your hip pocket.")
        _ = addEx("Gorilla Kettlebell Row", pattern: .horizontalPull, primary: .lats, secondary: [.upperBack, .biceps], equip: [.kettlebell], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 75, baseWeight: 55)
        _ = addEx("Inverted Bodyweight Row", pattern: .horizontalPull, primary: .upperBack, secondary: [.lats, .biceps], equip: [.pullUpBar], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 75, baseWeight: 0)
        _ = addEx("Smith Machine Inverted Australian Row", pattern: .horizontalPull, primary: .upperBack, secondary: [.lats, .biceps, .rearDelt], equip: [.smithMachine], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 75, baseWeight: 0, cues: "Lock Smith bar at hip height, keep body rigid from heels to shoulders, pull chest to bar.")
        _ = addEx("Smith Machine Barbell Shrug", pattern: .horizontalPull, primary: .upperBack, secondary: [.forearms], equip: [.smithMachine, .weightPlates], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 185, cues: "Elevate shoulders straight toward ears with a 1-second pause at peak contraction.")

        // Vertical Pull
        let weightedPullUp = addEx("Pull-Ups (Weighted or Bodyweight)", pattern: .verticalPull, primary: .lats, secondary: [.biceps, .upperBack], equip: [.pullUpBar], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 120, baseWeight: 25, cues: "Drive elbows down to ribs, full hang at bottom.")
        _ = addEx("Assisted Pull-Up Machine", pattern: .verticalPull, primary: .lats, secondary: [.biceps, .upperBack], equip: [.assistedPullUpDip], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 105, baseWeight: 45, cues: "Control the eccentric stretch at the bottom, drive elbows down.")
        _ = addEx("Band-Assisted Pull-Ups", pattern: .verticalPull, primary: .lats, secondary: [.biceps, .upperBack], equip: [.pullUpBar, .resistanceBands], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 105, baseWeight: 0)
        let latPulldown = addEx("Wide-Grip Lat Pulldown", pattern: .verticalPull, primary: .lats, secondary: [.biceps, .upperBack], equip: [.latPulldownMachine], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 140)
        _ = addEx("Half-Kneeling Single-Arm Cable Pulldown", pattern: .verticalPull, primary: .lats, secondary: [.biceps], equip: [.dualCablePulley], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 75, baseWeight: 65)
        _ = addEx("Dumbbell Pullover", pattern: .verticalPull, primary: .lats, secondary: [.chest, .triceps], equip: [.dumbbell, .flatBench], mechanic: .isolation, tier: .tier3Isolation, rest: 75, baseWeight: 55)

        // Squat Pattern
        let bbSquat = addEx("Barbell Back Squat", pattern: .squat, primary: .quads, secondary: [.glutes, .lowerBack, .abs], equip: [.barbell, .squatRack, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 150, baseWeight: 225, cues: "Brace 360 degrees, sit between hips, knees track toes.")
        _ = addEx("Smith Machine Back Squat", pattern: .squat, primary: .quads, secondary: [.glutes, .abs], equip: [.smithMachine, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 120, baseWeight: 185, cues: "Place feet slightly forward of the bar line to stay upright and bias quad knee flexion.")
        let hackSquat = addEx("Machine Hack Squat", pattern: .squat, primary: .quads, secondary: [.glutes], equip: [.hackSquat, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 120, baseWeight: 270)
        _ = addEx("Smith Machine Hack / Feet-Forward Squat", pattern: .squat, primary: .quads, secondary: [.glutes], equip: [.smithMachine, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 105, baseWeight: 155, cues: "Position feet 12–16 inches in front of hips, keep back vertical against the bar path.")
        let legPress = addEx("45° Leg Press", pattern: .squat, primary: .quads, secondary: [.glutes], equip: [.legPress, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 120, baseWeight: 360)
        _ = addEx("Goblet Squat (Dumbbell)", pattern: .squat, primary: .quads, secondary: [.glutes, .abs], equip: [.dumbbell], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 70)
        _ = addEx("Double Kettlebell Front Squat", pattern: .squat, primary: .quads, secondary: [.glutes, .abs, .upperBack], equip: [.kettlebell], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 105, baseWeight: 53)

        // Hip Hinge Pattern
        let rdl = addEx("Barbell Romanian Deadlift (RDL)", pattern: .hipHinge, primary: .hamstrings, secondary: [.glutes, .lowerBack, .forearms], equip: [.barbell, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 120, baseWeight: 205, cues: "Push hips straight back, keep lats tight, feel hamstring stretch.")
        _ = addEx("Smith Machine Romanian Deadlift (RDL)", pattern: .hipHinge, primary: .hamstrings, secondary: [.glutes, .lowerBack], equip: [.smithMachine, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 105, baseWeight: 185, cues: "Stand close to the bar path, push hips straight back until maximal hamstring stretch.")
        let dbRDL = addEx("Dumbbell Romanian Deadlift", pattern: .hipHinge, primary: .hamstrings, secondary: [.glutes, .lowerBack], equip: [.dumbbell], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 75)
        _ = addEx("Trap Bar Deadlift", pattern: .hipHinge, primary: .glutes, secondary: [.quads, .hamstrings, .upperBack], equip: [.trapBar, .weightPlates], mechanic: .compound, tier: .tier1PrimaryCompound, rest: 150, baseWeight: 275)
        _ = addEx("Barbell Hip Thrust", pattern: .hipHinge, primary: .glutes, secondary: [.hamstrings], equip: [.barbell, .flatBench, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 105, baseWeight: 225)
        _ = addEx("Smith Machine Hip Thrust", pattern: .hipHinge, primary: .glutes, secondary: [.hamstrings], equip: [.smithMachine, .flatBench, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 105, baseWeight: 205, cues: "Anchor upper back on bench pad, tuck chin, drive hips to full lockout and squeeze glutes.")
        _ = addEx("Kettlebell Swing (Heavy Hinge)", pattern: .hipHinge, primary: .glutes, secondary: [.hamstrings, .lowerBack], equip: [.kettlebell], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 75, baseWeight: 62)

        // Unilateral Leg
        let bulgarianSplit = addEx("Bulgarian Split Squat (Dumbbell)", pattern: .unilateralLeg, primary: .quads, secondary: [.glutes, .hamstrings], equip: [.dumbbell, .flatBench], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 45, isUnilateral: true, cues: "Slight forward torso lean, lower back knee under control.")
        _ = addEx("Smith Machine Bulgarian Split Squat", pattern: .unilateralLeg, primary: .quads, secondary: [.glutes, .hamstrings], equip: [.smithMachine, .flatBench, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 95, isUnilateral: true, cues: "Fixed bar path eliminates balance limiting factor; control descent for deep quad/glute stretch.")
        _ = addEx("Smith Machine Reverse Lunge", pattern: .unilateralLeg, primary: .glutes, secondary: [.quads, .hamstrings], equip: [.smithMachine, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 105, isUnilateral: true, cues: "Step back into a 90° front knee angle and drive through the front midfoot.")
        _ = addEx("Dumbbell Walking Lunges", pattern: .unilateralLeg, primary: .quads, secondary: [.glutes, .hamstrings], equip: [.dumbbell], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 40)
        _ = addEx("Bodyweight Tempo Split Squat", pattern: .unilateralLeg, primary: .quads, secondary: [.glutes], equip: [.bodyweight], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 60, baseWeight: 0)

        // Knee Extension & Flexion (Leg Isolations)
        let legExt = addEx("Seated Leg Extension", pattern: .kneeExtension, primary: .quads, equip: [.legExtension], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 130, cues: "1-second pause at full contraction.")
        _ = addEx("Sissy Squat / Banded Terminal Knee Extension", pattern: .kneeExtension, primary: .quads, equip: [.bodyweight], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 0)

        let legCurl = addEx("Seated Hamstring Curl", pattern: .kneeFlexion, primary: .hamstrings, equip: [.seatedLegCurl], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 120)
        _ = addEx("Lying Leg Curl", pattern: .kneeFlexion, primary: .hamstrings, equip: [.lyingLegCurl], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 105)
        _ = addEx("Dumbbell Lying Hamstring Curl", pattern: .kneeFlexion, primary: .hamstrings, equip: [.dumbbell, .flatBench], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 40, rest: 60, baseWeight: 40)
        _ = addEx("Nordic / Sliding Floor Hamstring Curl", pattern: .kneeFlexion, primary: .hamstrings, equip: [.bodyweight], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 0)

        // Lateral & Rear Deltoid
        let dbLatRaise = addEx("Dumbbell Lateral Raise", pattern: .lateralDeltoid, primary: .sideDelt, equip: [.dumbbell], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 25, cues: "Lead with elbows slightly forward in scapular plane.")
        let cableLatRaise = addEx("Cable Single-Arm Lateral Raise", pattern: .lateralDeltoid, primary: .sideDelt, equip: [.dualCablePulley], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 20)
        _ = addEx("Smith Machine Upright Row / High Pull", pattern: .lateralDeltoid, primary: .sideDelt, secondary: [.upperBack, .rearDelt], equip: [.smithMachine, .weightPlates], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 75, cues: "Wide shoulder-friendly grip; lead with elbows up to shoulder height.")
        let facePull = addEx("Rope Cable Face Pull", pattern: .rearDeltoid, primary: .rearDelt, secondary: [.upperBack], equip: [.dualCablePulley], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 50)
        _ = addEx("Chest-Supported Rear Delt Dumbbell Fly", pattern: .rearDeltoid, primary: .rearDelt, secondary: [.upperBack], equip: [.dumbbell, .adjustableBench], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 20)
        _ = addEx("Band Pull-Aparts", pattern: .rearDeltoid, primary: .rearDelt, secondary: [.upperBack], equip: [.resistanceBands], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 45, baseWeight: 0)

        // Arms: Biceps & Triceps
        let ezBarCurl = addEx("EZ-Bar Bicep Curl", pattern: .elbowFlexion, primary: .biceps, secondary: [.forearms], equip: [.ezCurlBar, .weightPlates], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 75)
        _ = addEx("Preacher Curl (EZ-Bar or Dumbbell)", pattern: .elbowFlexion, primary: .biceps, secondary: [.forearms], equip: [.preacherBench, .dumbbell], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 35)
        let inclineDBCurl = addEx("Incline Dumbbell Curl", pattern: .elbowFlexion, primary: .biceps, secondary: [.forearms], equip: [.dumbbell, .adjustableBench], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 30)
        _ = addEx("Hammer Dumbbell Curl", pattern: .elbowFlexion, primary: .biceps, secondary: [.forearms], equip: [.dumbbell], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 35)
        _ = addEx("Bayesian Cable Curl", pattern: .elbowFlexion, primary: .biceps, equip: [.dualCablePulley], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 35)

        let cablePushdown = addEx("Cable Tricep Rope Pushdown", pattern: .elbowExtension, primary: .triceps, equip: [.dualCablePulley], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 60)
        let overheadDBTri = addEx("Overhead Dumbbell Tricep Extension", pattern: .elbowExtension, primary: .triceps, equip: [.dumbbell], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 55)
        _ = addEx("EZ-Bar Skullcrushers", pattern: .elbowExtension, primary: .triceps, equip: [.ezCurlBar, .flatBench, .weightPlates], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 75)
        _ = addEx("Decline EZ-Bar Skullcrushers", pattern: .elbowExtension, primary: .triceps, secondary: [.forearms], equip: [.ezCurlBar, .declineBench, .weightPlates], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 65, cues: "Decline bench position increases long-head stretch; keep elbows pointing upward.")
        _ = addEx("Decline Dumbbell Triceps Extension", pattern: .elbowExtension, primary: .triceps, equip: [.dumbbell, .declineBench], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 25, cues: "Lower dumbbells alongside temples for maximum stretch at the bottom.")
        _ = addEx("Smith Machine Close-Grip Bench Press", pattern: .elbowExtension, primary: .triceps, secondary: [.chest, .frontDelt], equip: [.smithMachine, .flatBench, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, secPerSet: 40, rest: 90, baseWeight: 135, cues: "Shoulder-width grip, keep elbows tucked close to torso to maximize triceps loading.")
        _ = addEx("Smith Machine JM Press", pattern: .elbowExtension, primary: .triceps, secondary: [.frontDelt], equip: [.smithMachine, .flatBench, .weightPlates], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 95, cues: "Lower bar toward chin/neck line by hinging at elbows before pressing straight back up.")
        _ = addEx("Weighted Parallel Bar Dips", pattern: .elbowExtension, primary: .triceps, secondary: [.chest, .frontDelt], equip: [.dipStation], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 25)
        _ = addEx("Assisted Dip Machine", pattern: .elbowExtension, primary: .triceps, secondary: [.chest, .frontDelt], equip: [.assistedPullUpDip], mechanic: .compound, tier: .tier2SecondaryCompound, rest: 90, baseWeight: 45, cues: "Lean slightly forward for chest or stay upright for triceps.")

        // Calves
        let machineCalf = addEx("Standing / Seated Calf Raise Machine", pattern: .calves, primary: .calves, equip: [.calfRaiseMachine], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 160)
        _ = addEx("Smith Machine Standing Calf Raise", pattern: .calves, primary: .calves, equip: [.smithMachine, .weightPlates], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 155, cues: "Full pause in the bottom stretch and 1-second hold at peak plantarflexion.")
        _ = addEx("Single-Leg Dumbbell Calf Raise", pattern: .calves, primary: .calves, equip: [.dumbbell], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 50)

        // Core Exercises (Anti-Extension, Flexion, Rotation/Carry)
        let abWheelRollout = addEx("Ab Wheel Rollout", pattern: .coreAntiExtension, primary: .abs, secondary: [.lats], equip: [.abWheel], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0, cues: "Keep pelvis tucked in posterior tilt throughout rollout.")
        _ = addEx("RKC Hardstyle Plank / Hollow Body Hold", pattern: .coreAntiExtension, primary: .abs, secondary: [.obliques], equip: [.bodyweight], mechanic: .core, tier: .tierCore, secPerSet: 45, rest: 60, baseWeight: 0)
        let hangingLegRaise = addEx("Hanging Leg / Knee Raise", pattern: .coreFlexion, primary: .abs, secondary: [.forearms], equip: [.pullUpBar], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0, cues: "Curl pelvis up toward ribs rather than just swinging legs.")
        _ = addEx("Roman Chair / GHD Sit-Up & Knee Raise", pattern: .coreFlexion, primary: .abs, secondary: [.lowerBack], equip: [.ghdOrRomanChair], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0)
        _ = addEx("Sit-Ups", pattern: .coreFlexion, primary: .abs, equip: [.bodyweight], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0, cues: "Anchor feet or keep soles planted; curl torso up under control without yanking neck.")
        _ = addEx("Weighted Sit-Ups", pattern: .coreFlexion, primary: .abs, equip: [.bodyweight], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 25, cues: "Hold any weight (plate, dumbbell, or kettlebell) at chest; control the eccentric descent.")
        _ = addEx("Crunches", pattern: .coreFlexion, primary: .abs, equip: [.bodyweight], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0, cues: "Flex upper spine by curling ribs toward pelvis; pause 1 second at top contraction.")
        _ = addEx("Weighted Crunches", pattern: .coreFlexion, primary: .abs, equip: [.bodyweight], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 25, cues: "Hold any weight (plate, dumbbell, or kettlebell) at upper chest and curl ribs toward pelvis.")
        _ = addEx("Decline Sit-Ups", pattern: .coreFlexion, primary: .abs, equip: [.declineBench], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0, cues: "Lock ankles into decline bench rollers; lower torso with a controlled eccentric.")
        _ = addEx("Weighted Decline Sit-Ups", pattern: .coreFlexion, primary: .abs, equip: [.declineBench], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 25, cues: "Anchor feet on decline bench, hold any weight (plate, dumbbell, or kettlebell) at chest.")
        _ = addEx("Decline Crunches", pattern: .coreFlexion, primary: .abs, equip: [.declineBench], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0, cues: "Keep lower back anchored against decline pad and curl upper spine through short range.")
        _ = addEx("Weighted Decline Crunches", pattern: .coreFlexion, primary: .abs, equip: [.declineBench], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 25, cues: "Anchor feet on decline bench, hold any weight (plate, dumbbell, or kettlebell) and flex upper spine.")
        _ = addEx("Decline Reverse Crunch / Hip Raise", pattern: .coreFlexion, primary: .abs, equip: [.declineBench], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0, cues: "Lie facing uphill holding top bench handles, curl pelvis up toward ribs lifting hips with control.")
        _ = addEx("Decline Russian Twist", pattern: .coreRotation, primary: .obliques, secondary: [.abs], equip: [.declineBench], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 20, cues: "Lock feet into decline rollers, lean torso back 45°, rotate shoulders smoothly side-to-side.")
        _ = addEx("Ab Crunch Machine", pattern: .coreFlexion, primary: .abs, equip: [.abCrunchMachine], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 70)
        let cableCrunch = addEx("Kneeling Rope Cable Crunch", pattern: .coreFlexion, primary: .abs, equip: [.dualCablePulley], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 75)
        _ = addEx("Weighted Deadbug / V-Up", pattern: .coreFlexion, primary: .abs, equip: [.bodyweight], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0)
        let pallofPress = addEx("Cable Pallof Anti-Rotation Press", pattern: .coreRotation, primary: .obliques, secondary: [.abs], equip: [.dualCablePulley], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 35)
        _ = addEx("Single-Arm Suitcase Carry (Dumbbell / KB)", pattern: .coreRotation, primary: .obliques, secondary: [.abs, .forearms, .upperBack], equip: [.dumbbell], mechanic: .core, tier: .tierCore, secPerSet: 45, rest: 60, baseWeight: 65)
        _ = addEx("Russian Twist (Dumbbell / Plate)", pattern: .coreRotation, primary: .obliques, secondary: [.abs], equip: [.bodyweight], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 25)

        // Selectorized Machines, TRX, Medicine Ball, Swiss Ball/BOSU & Landmine
        _ = addEx("Seated Hip Abduction Machine", pattern: .unilateralLeg, primary: .glutes, equip: [.hipAbductorAdductorMachine], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 110)
        _ = addEx("Seated Hip Adduction Machine", pattern: .unilateralLeg, primary: .quads, secondary: [.glutes, .hamstrings], equip: [.hipAbductorAdductorMachine], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 110)
        _ = addEx("Machine Glute Kickback", pattern: .hipHinge, primary: .glutes, secondary: [.hamstrings], equip: [.gluteKickbackMachine], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 90)
        _ = addEx("Multi-Hip Machine Extension & Abduction", pattern: .unilateralLeg, primary: .glutes, equip: [.gluteKickbackMachine], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 70)
        _ = addEx("Seated Machine Back Extension", pattern: .hipHinge, primary: .lowerBack, secondary: [.glutes, .hamstrings], equip: [.backExtensionMachine], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 115)
        _ = addEx("Rotary Torso Machine", pattern: .coreRotation, primary: .obliques, secondary: [.abs], equip: [.rotaryTorsoMachine], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 75)
        _ = addEx("Machine Seated Bicep Curl", pattern: .elbowFlexion, primary: .biceps, secondary: [.forearms], equip: [.bicepCurlMachine], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 65)
        _ = addEx("Machine Seated Tricep Extension", pattern: .elbowExtension, primary: .triceps, equip: [.tricepExtensionMachine], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 70)
        _ = addEx("Selectorized Seated Dip Machine", pattern: .elbowExtension, primary: .triceps, secondary: [.chest, .frontDelt], equip: [.tricepExtensionMachine], mechanic: .compound, tier: .tier2SecondaryCompound, secPerSet: 40, rest: 90, baseWeight: 135)
        _ = addEx("Seated Machine Lateral Raise", pattern: .lateralDeltoid, primary: .sideDelt, equip: [.lateralRaiseMachine], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 55)

        // TRX Suspension Trainer
        _ = addEx("TRX Suspension Inverted Row", pattern: .horizontalPull, primary: .upperBack, secondary: [.lats, .biceps, .rearDelt], equip: [.trxSuspension], mechanic: .compound, tier: .tier2SecondaryCompound, secPerSet: 40, rest: 75, baseWeight: 0)
        _ = addEx("TRX Suspension Chest Press", pattern: .horizontalPush, primary: .chest, secondary: [.triceps, .frontDelt, .abs], equip: [.trxSuspension], mechanic: .compound, tier: .tier2SecondaryCompound, secPerSet: 40, rest: 75, baseWeight: 0)
        _ = addEx("TRX Suspension Rear Delt Y-Fly", pattern: .rearDeltoid, primary: .rearDelt, secondary: [.upperBack, .sideDelt], equip: [.trxSuspension], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 0)
        _ = addEx("TRX Suspension Hamstring Curl", pattern: .kneeFlexion, primary: .hamstrings, secondary: [.glutes, .abs], equip: [.trxSuspension], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 0)
        _ = addEx("TRX Suspension Pike / Fallout", pattern: .coreAntiExtension, primary: .abs, secondary: [.obliques, .frontDelt], equip: [.trxSuspension], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0)

        // Medicine Ball / Wall Ball
        _ = addEx("Medicine Ball Rotational Slam / Throw", pattern: .coreRotation, primary: .obliques, secondary: [.abs, .lats], equip: [.medicineBall], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 20)
        _ = addEx("Medicine Ball Russian Twist", pattern: .coreRotation, primary: .obliques, secondary: [.abs], equip: [.medicineBall], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 16)
        _ = addEx("Wall Ball Squat & Throw", pattern: .squat, primary: .quads, secondary: [.glutes, .frontDelt, .abs], equip: [.medicineBall], mechanic: .compound, tier: .tier2SecondaryCompound, secPerSet: 45, rest: 75, baseWeight: 20)

        // Swiss Ball / BOSU Trainer
        _ = addEx("Swiss Ball Stir-the-Pot Plank", pattern: .coreAntiExtension, primary: .abs, secondary: [.obliques], equip: [.stabilityBosuBall], mechanic: .core, tier: .tierCore, secPerSet: 40, rest: 60, baseWeight: 0)
        _ = addEx("Swiss Ball Hamstring Curl", pattern: .kneeFlexion, primary: .hamstrings, secondary: [.glutes, .abs], equip: [.stabilityBosuBall], mechanic: .isolation, tier: .tier3Isolation, secPerSet: 35, rest: 60, baseWeight: 0)
        _ = addEx("BOSU / Swiss Ball Ab Crunch", pattern: .coreFlexion, primary: .abs, equip: [.stabilityBosuBall], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 0)

        // Landmine Attachment
        _ = addEx("Single-Arm Landmine Press", pattern: .inclinePush, primary: .upperChest, secondary: [.frontDelt, .triceps, .obliques], equip: [.landmine, .barbell, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, secPerSet: 40, rest: 90, baseWeight: 70)
        _ = addEx("Landmine Meadows / T-Bar Row", pattern: .horizontalPull, primary: .lats, secondary: [.upperBack, .rearDelt, .biceps], equip: [.landmine, .barbell, .weightPlates], mechanic: .compound, tier: .tier2SecondaryCompound, secPerSet: 45, rest: 90, baseWeight: 95)
        _ = addEx("Landmine Anti-Rotation Rainbow", pattern: .coreRotation, primary: .obliques, secondary: [.abs, .frontDelt], equip: [.landmine, .barbell, .weightPlates], mechanic: .core, tier: .tierCore, secPerSet: 35, rest: 60, baseWeight: 35)

        // 3. Seed Starter Periodized Mesocycles (Upper/Lower, PPL, Full Body)
        guard existingMesocycles.isEmpty else {
            try? context.save()
            return
        }

        // MESOCYCLE 1: 4-Day Upper / Lower Hypertrophy & Conditioning (ACTIVE DEFAULT)
        let upperLowerMeso = Mesocycle(
            name: "Upper / Lower Hybrid Block",
            splitType: .upperLower,
            progressionModel: .linearRIR,
            startDate: Date(),
            totalWeeks: 5,
            currentWeek: 1,
            currentDayIndex: 0,
            includesDeload: true,
            isActive: true,
            notes: "4 days/wk periodized Upper/Lower split with EMOM & AMRAP conditioning finishers."
        )
        context.insert(upperLowerMeso)

        // Day 1: Upper A (Horizontal Focus)
        let ulDay1 = ProgramDayTemplate(name: "Upper A · Horizontal Strength", focusSummary: "Chest, Lats, Side Delts & Arms", orderIndex: 0, mesocycle: upperLowerMeso)
        context.insert(ulDay1)
        let ul1Slots = [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: bbBench, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 8, restSeconds: 120, dayTemplate: ulDay1),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: bbRow, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 10, restSeconds: 120, dayTemplate: ulDay1),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: inclineDBPress, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 12, restSeconds: 90, dayTemplate: ulDay1),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: latPulldown, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 10, repRangeMax: 12, restSeconds: 90, dayTemplate: ulDay1),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: dbLatRaise, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: ulDay1),
            PlannedExerciseSlot(orderIndex: 5, preferredExercise: cablePushdown, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 10, repRangeMax: 15, restSeconds: 60, dayTemplate: ulDay1)
        ]
        ul1Slots.forEach { context.insert($0) }
        let ul1Finisher = FinisherPrescription(
            title: "Upper Density EMOM 10",
            format: .emom,
            durationMinutes: 10,
            movementNames: ["Min 1 (Odd): 16 Cal Row", "Min 2 (Even): 15 Dumbbell Thrusters"],
            movementRepSchemes: ["~45s effort", "15 reps (~40s)"],
            dayTemplate: ulDay1
        )
        context.insert(ul1Finisher)

        // Day 2: Lower A (Quad Focus)
        let ulDay2 = ProgramDayTemplate(name: "Lower A · Squat & Posterior", focusSummary: "Quads, Hamstrings, Calves & Core", orderIndex: 1, mesocycle: upperLowerMeso)
        context.insert(ulDay2)
        [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: bbSquat, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 5, repRangeMax: 8, restSeconds: 150, dayTemplate: ulDay2),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: dbRDL, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 10, restSeconds: 105, dayTemplate: ulDay2),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: legPress, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 10, repRangeMax: 12, restSeconds: 90, dayTemplate: ulDay2),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: legCurl, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 10, repRangeMax: 15, restSeconds: 60, dayTemplate: ulDay2),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: machineCalf, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: ulDay2),
            PlannedExerciseSlot(orderIndex: 5, preferredExercise: hangingLegRaise, tierPriority: .tierCore, baseSets: 3, repRangeMin: 10, repRangeMax: 15, restSeconds: 60, dayTemplate: ulDay2)
        ].forEach { context.insert($0) }
        context.insert(FinisherPrescription(
            title: "Lower Engine AMRAP 8",
            format: .amrap,
            durationMinutes: 8,
            movementNames: ["15 Kettlebell Swings", "10 Box Jumps", "12 Goblet Squats"],
            movementRepSchemes: ["15 reps", "10 reps", "12 reps"],
            dayTemplate: ulDay2
        ))

        // Day 3: Upper B (Vertical Focus)
        let ulDay3 = ProgramDayTemplate(name: "Upper B · Vertical & Hypertrophy", focusSummary: "Shoulders, Vertical Pull, Chest & Biceps", orderIndex: 2, mesocycle: upperLowerMeso)
        context.insert(ulDay3)
        [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: ohp, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 8, restSeconds: 120, dayTemplate: ulDay3),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: weightedPullUp, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 10, restSeconds: 120, dayTemplate: ulDay3),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: dbFlatBench, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 12, restSeconds: 90, dayTemplate: ulDay3),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: chestSupportedRow, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 10, repRangeMax: 12, restSeconds: 90, dayTemplate: ulDay3),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: facePull, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: ulDay3),
            PlannedExerciseSlot(orderIndex: 5, preferredExercise: ezBarCurl, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 10, repRangeMax: 12, restSeconds: 60, dayTemplate: ulDay3)
        ].forEach { context.insert($0) }
        context.insert(FinisherPrescription(
            title: "Tabata Conditioning Sprints",
            format: .tabata,
            durationMinutes: 4,
            workSeconds: 20,
            restSeconds: 10,
            roundsTarget: 8,
            movementNames: ["Assault Bike All-Out Sprint", "Battle Ropes / Burpees"],
            movementRepSchemes: ["20s Max Effort", "10s Recovery"],
            dayTemplate: ulDay3
        ))

        // Day 4: Lower B (Hinge Focus)
        let ulDay4 = ProgramDayTemplate(name: "Lower B · Hinge & Unilateral", focusSummary: "Hamstrings, Glutes, Single-Leg & Core", orderIndex: 3, mesocycle: upperLowerMeso)
        context.insert(ulDay4)
        [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: rdl, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 8, restSeconds: 135, dayTemplate: ulDay4),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: bulgarianSplit, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 10, restSeconds: 90, dayTemplate: ulDay4),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: hackSquat, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 12, restSeconds: 105, dayTemplate: ulDay4),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: legExt, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: ulDay4),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: abWheelRollout, tierPriority: .tierCore, baseSets: 3, repRangeMin: 10, repRangeMax: 15, restSeconds: 60, dayTemplate: ulDay4)
        ].forEach { context.insert($0) }
        context.insert(FinisherPrescription(
            title: "12-Min Metcon EMOM",
            format: .emom,
            durationMinutes: 12,
            movementNames: ["Min 1: 15 Cal Row", "Min 2: 14 Alternating DB Snatches", "Min 3: 45s Plank Hold"],
            movementRepSchemes: ["15 cals", "14 reps", "45s"],
            dayTemplate: ulDay4
        ))

        // MESOCYCLE 2: Push / Pull / Legs (PPL) 6-Week Block
        let pplMeso = Mesocycle(
            name: "Push / Pull / Legs (PPL) Block",
            splitType: .pushPullLegs,
            progressionModel: .volumeAccumulation,
            totalWeeks: 6,
            currentWeek: 1,
            currentDayIndex: 0,
            includesDeload: true,
            isActive: false,
            notes: "Classic 3-day rotating Push / Pull / Legs split with volume accumulation across weeks."
        )
        context.insert(pplMeso)

        let pushDay = ProgramDayTemplate(name: "Push · Chest, Delts & Triceps", focusSummary: "Pressing strength + delt & tricep volume", orderIndex: 0, mesocycle: pplMeso)
        context.insert(pushDay)
        [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: bbBench, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 8, restSeconds: 120, dayTemplate: pushDay),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: seatedDBShoulder, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 10, restSeconds: 90, dayTemplate: pushDay),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: inclineDBPress, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 12, restSeconds: 90, dayTemplate: pushDay),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: cableFly, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: pushDay),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: cableLatRaise, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: pushDay),
            PlannedExerciseSlot(orderIndex: 5, preferredExercise: overheadDBTri, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 10, repRangeMax: 15, restSeconds: 60, dayTemplate: pushDay)
        ].forEach { context.insert($0) }
        context.insert(FinisherPrescription(
            title: "Push Burnout AMRAP 8",
            format: .amrap,
            durationMinutes: 8,
            movementNames: ["12 Cal Assault Bike", "12 Push-Ups", "15 Band / Cable Tricep Pressdowns"],
            movementRepSchemes: ["12 cal", "12 reps", "15 reps"],
            dayTemplate: pushDay
        ))

        let pullDay = ProgramDayTemplate(name: "Pull · Back, Rear Delts & Biceps", focusSummary: "Vertical & horizontal pulling thickness", orderIndex: 1, mesocycle: pplMeso)
        context.insert(pullDay)
        [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: weightedPullUp, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 10, restSeconds: 120, dayTemplate: pullDay),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: bbRow, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 10, restSeconds: 120, dayTemplate: pullDay),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: dbRow, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 12, restSeconds: 90, dayTemplate: pullDay),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: facePull, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: pullDay),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: inclineDBCurl, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 10, repRangeMax: 12, restSeconds: 60, dayTemplate: pullDay),
            PlannedExerciseSlot(orderIndex: 5, preferredExercise: pallofPress, tierPriority: .tierCore, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: pullDay)
        ].forEach { context.insert($0) }
        context.insert(FinisherPrescription(
            title: "Pull Erg EMOM 10",
            format: .emom,
            durationMinutes: 10,
            movementNames: ["Min 1 (Odd): 16 Cal Row", "Min 2 (Even): 20 Kettlebell Swings"],
            movementRepSchemes: ["16 cal (~45s)", "20 reps (~40s)"],
            dayTemplate: pullDay
        ))

        let legsDay = ProgramDayTemplate(name: "Legs · Quads, Hams & Calves", focusSummary: "Complete lower body hypertrophy", orderIndex: 2, mesocycle: pplMeso)
        context.insert(legsDay)
        [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: bbSquat, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 5, repRangeMax: 8, restSeconds: 150, dayTemplate: legsDay),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: rdl, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 10, restSeconds: 120, dayTemplate: legsDay),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: bulgarianSplit, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 12, restSeconds: 90, dayTemplate: legsDay),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: legExt, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: legsDay),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: legCurl, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: legsDay),
            PlannedExerciseSlot(orderIndex: 5, preferredExercise: machineCalf, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: legsDay)
        ].forEach { context.insert($0) }
        context.insert(FinisherPrescription(
            title: "Legs Sled / Bike Finisher",
            format: .forTime,
            durationMinutes: 8,
            movementNames: ["3 Rounds For Time: 15 Cal Assault Bike + 20 Walking Lunges"],
            movementRepSchemes: ["8:00 Time Cap"],
            dayTemplate: legsDay
        ))

        // MESOCYCLE 3: 3-Day Full Body Athletic Block
        let fullBodyMeso = Mesocycle(
            name: "Full Body Athletic Strength",
            splitType: .fullBody,
            progressionModel: .linearRIR,
            totalWeeks: 4,
            currentWeek: 1,
            currentDayIndex: 0,
            includesDeload: true,
            isActive: false,
            notes: "3 days/wk total-body strength & conditioning block."
        )
        context.insert(fullBodyMeso)

        let fbDay1 = ProgramDayTemplate(name: "Full Body A · Squat & Bench", focusSummary: "Squat, Horizontal Push/Pull & Core", orderIndex: 0, mesocycle: fullBodyMeso)
        context.insert(fbDay1)
        [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: bbSquat, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 5, repRangeMax: 8, restSeconds: 135, dayTemplate: fbDay1),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: bbBench, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 8, restSeconds: 120, dayTemplate: fbDay1),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: dbRow, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 12, restSeconds: 90, dayTemplate: fbDay1),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: legCurl, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 10, repRangeMax: 15, restSeconds: 60, dayTemplate: fbDay1),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: cableCrunch, tierPriority: .tierCore, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: fbDay1)
        ].forEach { context.insert($0) }
        context.insert(FinisherPrescription(
            title: "Full Body EMOM 10",
            format: .emom,
            durationMinutes: 10,
            movementNames: ["Min 1 (Odd): 20 Kettlebell Swings", "Min 2 (Even): 16 Cal Row"],
            movementRepSchemes: ["20 reps (~40s)", "16 cal (~45s)"],
            dayTemplate: fbDay1
        ))

        let fbDay2 = ProgramDayTemplate(name: "Full Body B · Hinge & Overhead", focusSummary: "RDL, Overhead Press, Pull-Ups & Arms", orderIndex: 1, mesocycle: fullBodyMeso)
        context.insert(fbDay2)
        [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: rdl, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 8, restSeconds: 135, dayTemplate: fbDay2),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: ohp, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 8, restSeconds: 120, dayTemplate: fbDay2),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: weightedPullUp, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 10, restSeconds: 120, dayTemplate: fbDay2),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: bulgarianSplit, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 10, restSeconds: 90, dayTemplate: fbDay2),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: ezBarCurl, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 10, repRangeMax: 12, restSeconds: 60, dayTemplate: fbDay2)
        ].forEach { context.insert($0) }
        context.insert(FinisherPrescription(
            title: "Conditioning AMRAP 10",
            format: .amrap,
            durationMinutes: 10,
            movementNames: ["10 DB Thrusters", "12 Cal Assault Bike", "10 Hanging Knee Raises"],
            movementRepSchemes: ["10 reps", "12 cal", "10 reps"],
            dayTemplate: fbDay2
        ))

        let fbDay3 = ProgramDayTemplate(name: "Full Body C · Hypertrophy Mix", focusSummary: "Incline Press, Unilateral Legs, Back & Delts", orderIndex: 2, mesocycle: fullBodyMeso)
        context.insert(fbDay3)
        [
            PlannedExerciseSlot(orderIndex: 0, preferredExercise: legPress, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 12, restSeconds: 120, dayTemplate: fbDay3),
            PlannedExerciseSlot(orderIndex: 1, preferredExercise: inclineBBPress, tierPriority: .tier1PrimaryCompound, baseSets: 3, repRangeMin: 6, repRangeMax: 10, restSeconds: 120, dayTemplate: fbDay3),
            PlannedExerciseSlot(orderIndex: 2, preferredExercise: chestSupportedRow, tierPriority: .tier2SecondaryCompound, baseSets: 3, repRangeMin: 8, repRangeMax: 12, restSeconds: 90, dayTemplate: fbDay3),
            PlannedExerciseSlot(orderIndex: 3, preferredExercise: dbLatRaise, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: fbDay3),
            PlannedExerciseSlot(orderIndex: 4, preferredExercise: cablePushdown, tierPriority: .tier3Isolation, baseSets: 3, repRangeMin: 12, repRangeMax: 15, restSeconds: 60, dayTemplate: fbDay3)
        ].forEach { context.insert($0) }
        context.insert(FinisherPrescription(
            title: "Tabata Rope & Core",
            format: .tabata,
            durationMinutes: 4,
            workSeconds: 20,
            restSeconds: 10,
            roundsTarget: 8,
            movementNames: ["Battle Ropes Alternating Waves", "Hollow Body Hold"],
            movementRepSchemes: ["20s Work", "10s Rest"],
            dayTemplate: fbDay3
        ))

        try? context.save()
    }

    @MainActor
    static func seedSampleWorkoutLogs(context: ModelContext, count: Int = 10) {
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard !allExercises.isEmpty else { return }
        let exByName = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.name, $0) })
        let gyms = (try? context.fetch(FetchDescriptor<GymProfile>())) ?? []
        let defaultGym = gyms.first(where: { $0.isDefault }) ?? gyms.first
        let activeMeso = (try? context.fetch(FetchDescriptor<Mesocycle>()))?.first(where: { $0.isActive })

        let calendar = Calendar.current
        let now = Date()

        struct SampleSetDef {
            let weight: Double
            let reps: Int
            let rir: Int
            let isWarmup: Bool
        }

        struct SampleExDef {
            let name: String
            let sets: [SampleSetDef]
            let wasCore: Bool
        }

        struct SampleWorkoutDef {
            let dayOffset: Int
            let title: String
            let durationSeconds: Int
            let calories: Int
            let exercises: [SampleExDef]
            let finisherTitle: String?
            let finisherFormat: FinisherFormat?
            let finisherSummary: String?
            let notes: String
        }

        let workoutDefs: [SampleWorkoutDef] = [
            SampleWorkoutDef(
                dayOffset: -13,
                title: "Upper A · Horizontal Strength",
                durationSeconds: 3120,
                calories: 445,
                exercises: [
                    SampleExDef(name: "Barbell Bench Press", sets: [
                        SampleSetDef(weight: 135, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 185, reps: 8, rir: 3, isWarmup: false),
                        SampleSetDef(weight: 185, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 185, reps: 7, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Barbell Bent-Over Row", sets: [
                        SampleSetDef(weight: 115, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 155, reps: 8, rir: 3, isWarmup: false),
                        SampleSetDef(weight: 155, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 155, reps: 8, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Incline Dumbbell Press", sets: [
                        SampleSetDef(weight: 60, reps: 10, rir: 3, isWarmup: false),
                        SampleSetDef(weight: 60, reps: 9, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 60, reps: 8, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Dumbbell Lateral Raise", sets: [
                        SampleSetDef(weight: 22.5, reps: 14, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 22.5, reps: 13, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 22.5, reps: 12, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Ab Wheel Rollout", sets: [
                        SampleSetDef(weight: 0, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 10, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 10, rir: 1, isWarmup: false)
                    ], wasCore: true)
                ],
                finisherTitle: "Tabata Sprints & Core",
                finisherFormat: .tabata,
                finisherSummary: "8 Rounds · 20s Work / 10s Rest: Assault Bike + Mountain Climbers",
                notes: "Great first workout of mesocycle. RIR 3 target felt very manageable."
            ),
            SampleWorkoutDef(
                dayOffset: -12,
                title: "Lower A · Quad Focus",
                durationSeconds: 3480,
                calories: 520,
                exercises: [
                    SampleExDef(name: "Barbell Back Squat", sets: [
                        SampleSetDef(weight: 155, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 195, reps: 4, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 225, reps: 8, rir: 3, isWarmup: false),
                        SampleSetDef(weight: 225, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 225, reps: 7, rir: 2, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Barbell Romanian Deadlift (RDL)", sets: [
                        SampleSetDef(weight: 135, reps: 6, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 195, reps: 8, rir: 3, isWarmup: false),
                        SampleSetDef(weight: 195, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 195, reps: 8, rir: 2, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "45° Leg Press", sets: [
                        SampleSetDef(weight: 320, reps: 10, rir: 3, isWarmup: false),
                        SampleSetDef(weight: 320, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 320, reps: 10, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Seated Leg Extension", sets: [
                        SampleSetDef(weight: 120, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 120, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 120, reps: 11, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Hanging Leg / Knee Raise", sets: [
                        SampleSetDef(weight: 0, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 10, rir: 0, isWarmup: false)
                    ], wasCore: true)
                ],
                finisherTitle: "EMOM Leg Burner",
                finisherFormat: .emom,
                finisherSummary: "6 min EMOM · 12 Kettlebell Swings (53 lbs)",
                notes: "Solid leg pump, knee tracking felt smooth on squats."
            ),
            SampleWorkoutDef(
                dayOffset: -10,
                title: "Upper B · Vertical Pull & Push",
                durationSeconds: 3240,
                calories: 460,
                exercises: [
                    SampleExDef(name: "Overhead Barbell Press (OHP)", sets: [
                        SampleSetDef(weight: 75, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 115, reps: 6, rir: 3, isWarmup: false),
                        SampleSetDef(weight: 115, reps: 6, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 115, reps: 5, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Pull-Ups (Weighted or Bodyweight)", sets: [
                        SampleSetDef(weight: 0, reps: 8, rir: 3, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 7, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Single-Arm Dumbbell Row", sets: [
                        SampleSetDef(weight: 70, reps: 9, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 70, reps: 9, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 70, reps: 8, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Cable Tricep Rope Pushdown", sets: [
                        SampleSetDef(weight: 55, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 55, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 55, reps: 10, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Cable Pallof Anti-Rotation Press", sets: [
                        SampleSetDef(weight: 35, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 35, reps: 12, rir: 2, isWarmup: false)
                    ], wasCore: true)
                ],
                finisherTitle: "Rowing Intervals",
                finisherFormat: .forTime,
                finisherSummary: "1000m Row for Time: 3:38 total",
                notes: "OHP overhead lockout was crisp and locked in."
            ),
            SampleWorkoutDef(
                dayOffset: -8,
                title: "Lower B · Posterior Chain",
                durationSeconds: 3360,
                calories: 490,
                exercises: [
                    SampleExDef(name: "Barbell Romanian Deadlift (RDL)", sets: [
                        SampleSetDef(weight: 135, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 200, reps: 8, rir: 3, isWarmup: false),
                        SampleSetDef(weight: 200, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 200, reps: 8, rir: 2, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Bulgarian Split Squat (Dumbbell)", sets: [
                        SampleSetDef(weight: 40, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 40, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 40, reps: 9, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Seated Hamstring Curl", sets: [
                        SampleSetDef(weight: 115, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 115, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 115, reps: 10, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Standing / Seated Calf Raise Machine", sets: [
                        SampleSetDef(weight: 150, reps: 15, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 150, reps: 14, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 150, reps: 12, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Kneeling Rope Cable Crunch", sets: [
                        SampleSetDef(weight: 70, reps: 14, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 70, reps: 12, rir: 1, isWarmup: false)
                    ], wasCore: true)
                ],
                finisherTitle: "Kettlebell AMRAP",
                finisherFormat: .amrap,
                finisherSummary: "7 min AMRAP: 15 Swings + 10 Goblet Squats (5 rounds completed)",
                notes: "Hamstring stretch on RDL felt phenomenal."
            ),
            SampleWorkoutDef(
                dayOffset: -7,
                title: "Upper A · Week 2 Overload",
                durationSeconds: 3180,
                calories: 470,
                exercises: [
                    SampleExDef(name: "Barbell Bench Press", sets: [
                        SampleSetDef(weight: 135, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 165, reps: 4, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 190, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 190, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 190, reps: 7, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Barbell Bent-Over Row", sets: [
                        SampleSetDef(weight: 120, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 160, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 160, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 160, reps: 7, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Incline Dumbbell Press", sets: [
                        SampleSetDef(weight: 65, reps: 9, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 65, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 65, reps: 8, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Cable Single-Arm Lateral Raise", sets: [
                        SampleSetDef(weight: 20, reps: 14, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 20, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 20, reps: 12, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Ab Wheel Rollout", sets: [
                        SampleSetDef(weight: 0, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 11, rir: 1, isWarmup: false)
                    ], wasCore: true)
                ],
                finisherTitle: "Tabata Sprints",
                finisherFormat: .tabata,
                finisherSummary: "8 Rounds · Ski-Erg Max Effort Sprints",
                notes: "Bench weight jumped to 190 lbs smoothly. Rep target met across sets."
            ),
            SampleWorkoutDef(
                dayOffset: -5,
                title: "Lower A · Heavy Squat Overload",
                durationSeconds: 3600,
                calories: 540,
                exercises: [
                    SampleExDef(name: "Barbell Back Squat", sets: [
                        SampleSetDef(weight: 155, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 205, reps: 4, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 235, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 235, reps: 7, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 235, reps: 7, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "45° Leg Press", sets: [
                        SampleSetDef(weight: 340, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 340, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 340, reps: 9, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Seated Leg Extension", sets: [
                        SampleSetDef(weight: 125, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 125, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 125, reps: 10, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Hanging Leg / Knee Raise", sets: [
                        SampleSetDef(weight: 0, reps: 14, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 10, rir: 0, isWarmup: false)
                    ], wasCore: true)
                ],
                finisherTitle: "EMOM Quad Burn",
                finisherFormat: .emom,
                finisherSummary: "6 min EMOM · 15 Wall Ball Squats (20 lbs)",
                notes: "Back squat 235 lbs felt confident. Strong bracing throughout."
            ),
            SampleWorkoutDef(
                dayOffset: -4,
                title: "Push Hypertrophy & Delts",
                durationSeconds: 3000,
                calories: 430,
                exercises: [
                    SampleExDef(name: "Dumbbell Flat Bench Press", sets: [
                        SampleSetDef(weight: 70, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 70, reps: 9, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 70, reps: 8, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Overhead Barbell Press (OHP)", sets: [
                        SampleSetDef(weight: 85, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 120, reps: 6, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 120, reps: 6, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 120, reps: 5, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Dumbbell Lateral Raise", sets: [
                        SampleSetDef(weight: 25, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 25, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 25, reps: 10, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Overhead Dumbbell Tricep Extension", sets: [
                        SampleSetDef(weight: 55, reps: 11, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 55, reps: 10, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 55, reps: 9, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "RKC Hardstyle Plank / Hollow Body Hold", sets: [
                        SampleSetDef(weight: 0, reps: 45, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 40, rir: 0, isWarmup: false)
                    ], wasCore: true)
                ],
                finisherTitle: "Metcon Finisher",
                finisherFormat: .amrap,
                finisherSummary: "6 min AMRAP · 10 Burpees + 15 Push-Ups (4 rounds completed)",
                notes: "OHP PR with 120 lbs for 6 reps clean!"
            ),
            SampleWorkoutDef(
                dayOffset: -3,
                title: "Pull Strength & Biceps",
                durationSeconds: 3180,
                calories: 455,
                exercises: [
                    SampleExDef(name: "Pull-Ups (Weighted or Bodyweight)", sets: [
                        SampleSetDef(weight: 15, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 15, reps: 7, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 15, reps: 6, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Barbell Bent-Over Row", sets: [
                        SampleSetDef(weight: 125, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 165, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 165, reps: 8, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 165, reps: 7, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Wide-Grip Lat Pulldown", sets: [
                        SampleSetDef(weight: 140, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 140, reps: 9, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 140, reps: 8, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "EZ-Bar Bicep Curl", sets: [
                        SampleSetDef(weight: 75, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 75, reps: 9, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 75, reps: 8, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Rope Cable Face Pull", sets: [
                        SampleSetDef(weight: 50, reps: 15, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 50, reps: 14, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 50, reps: 12, rir: 0, isWarmup: false)
                    ], wasCore: false)
                ],
                finisherTitle: "RFT Pull Challenge",
                finisherFormat: .forTime,
                finisherSummary: "5 Rounds: 10 DB Cleans + 200m Rower sprint in 5:12",
                notes: "Weighted pull-up with +15 lbs belt felt strong throughout range."
            ),
            SampleWorkoutDef(
                dayOffset: -2,
                title: "Upper A · Bench PR Session",
                durationSeconds: 3300,
                calories: 475,
                exercises: [
                    SampleExDef(name: "Barbell Bench Press", sets: [
                        SampleSetDef(weight: 135, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 165, reps: 4, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 195, reps: 8, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 195, reps: 7, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 195, reps: 6, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Chest-Supported Machine / Cable Row", sets: [
                        SampleSetDef(weight: 145, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 145, reps: 9, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 145, reps: 8, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Cable Chest Fly", sets: [
                        SampleSetDef(weight: 35, reps: 14, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 35, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 35, reps: 10, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Cable Tricep Rope Pushdown", sets: [
                        SampleSetDef(weight: 60, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 60, reps: 10, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 60, reps: 9, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Ab Wheel Rollout", sets: [
                        SampleSetDef(weight: 0, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 12, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 10, rir: 0, isWarmup: false)
                    ], wasCore: true)
                ],
                finisherTitle: "Tabata Battle Ropes",
                finisherFormat: .tabata,
                finisherSummary: "8 Rounds · 20s Max Slams / 10s Rest",
                notes: "🏆 195 lbs × 8 on Bench Press! New all-time PR."
            ),
            SampleWorkoutDef(
                dayOffset: -1,
                title: "Lower B · Deadlift & Posterior Focus",
                durationSeconds: 3420,
                calories: 510,
                exercises: [
                    SampleExDef(name: "Barbell Romanian Deadlift (RDL)", sets: [
                        SampleSetDef(weight: 135, reps: 8, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 185, reps: 4, rir: 0, isWarmup: true),
                        SampleSetDef(weight: 215, reps: 8, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 215, reps: 7, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 215, reps: 7, rir: 1, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Bulgarian Split Squat (Dumbbell)", sets: [
                        SampleSetDef(weight: 45, reps: 10, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 45, reps: 9, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 45, reps: 8, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Seated Hamstring Curl", sets: [
                        SampleSetDef(weight: 125, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 125, reps: 10, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 125, reps: 10, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Standing / Seated Calf Raise Machine", sets: [
                        SampleSetDef(weight: 160, reps: 15, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 160, reps: 14, rir: 1, isWarmup: false),
                        SampleSetDef(weight: 160, reps: 12, rir: 0, isWarmup: false)
                    ], wasCore: false),
                    SampleExDef(name: "Hanging Leg / Knee Raise", sets: [
                        SampleSetDef(weight: 0, reps: 12, rir: 2, isWarmup: false),
                        SampleSetDef(weight: 0, reps: 11, rir: 1, isWarmup: false)
                    ], wasCore: true)
                ],
                finisherTitle: "EMOM Finisher",
                finisherFormat: .emom,
                finisherSummary: "7 min EMOM · 12 Kettlebell Swings (53 lbs)",
                notes: "RDL 215 lbs feeling super solid through glutes and hamstrings."
            )
        ]

        for def in workoutDefs.prefix(count) {
            let logDate = calendar.date(byAdding: .day, value: def.dayOffset, to: now) ?? now
            let workoutLog = WorkoutLog(
                id: UUID(),
                date: logDate,
                durationSeconds: def.durationSeconds,
                targetDurationMinutes: 60,
                mesocycle: activeMeso,
                weekIndex: (def.dayOffset < -7) ? 1 : 2,
                dayTemplateName: def.title,
                isCustomAdHocWorkout: false,
                selectedGym: defaultGym,
                caloriesBurned: def.calories,
                notes: def.notes
            )
            context.insert(workoutLog)

            for (exIdx, exDef) in def.exercises.enumerated() {
                let resolvedEx = exByName[exDef.name]
                let loggedEx = LoggedExercise(
                    id: UUID(),
                    orderIndex: exIdx,
                    exercise: resolvedEx,
                    swappedFromExerciseName: nil,
                    wasAutoInjectedCore: exDef.wasCore,
                    workoutLog: workoutLog
                )
                if let resolvedEx {
                    loggedEx.exerciseNameSnapshot = resolvedEx.name
                } else {
                    loggedEx.exerciseNameSnapshot = exDef.name
                }
                context.insert(loggedEx)

                for (setIdx, setDef) in exDef.sets.enumerated() {
                    let loggedSet = LoggedSet(
                        id: UUID(),
                        setNumber: setIdx + 1,
                        weight: setDef.weight,
                        reps: setDef.reps,
                        rir: setDef.rir,
                        setType: setDef.isWarmup ? .warmup : .working,
                        isCompleted: true,
                        loggedExercise: loggedEx
                    )
                    context.insert(loggedSet)
                }
            }

            if let finTitle = def.finisherTitle,
               let finFmt = def.finisherFormat,
               let finSum = def.finisherSummary {
                let fin = LoggedFinisher(
                    id: UUID(),
                    title: finTitle,
                    format: finFmt,
                    totalDurationSeconds: 480,
                    roundsCompleted: 6,
                    extraReps: 0,
                    movementsSummary: finSum,
                    isCompleted: true,
                    workoutLog: workoutLog
                )
                context.insert(fin)
            }
        }

        try? context.save()
    }
}

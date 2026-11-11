import Foundation
import SwiftUI

// MARK: - Equipment Type

enum EquipmentCategory: String, Codable, CaseIterable, Identifiable {
    case freeWeights = "Free Weights"
    case racksAndBenches = "Racks & Benches"
    case machinesAndCables = "Machines & Cables"
    case conditioningAndAccessories = "Conditioning & Accessories"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .freeWeights: return "dumbbell.fill"
        case .racksAndBenches: return "square.split.bottomrightquarter.fill"
        case .machinesAndCables: return "gearshape.2.fill"
        case .conditioningAndAccessories: return "figure.run"
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable, Identifiable, Hashable {
    // Free Weights
    case barbell = "Barbell"
    case ezCurlBar = "EZ Curl Bar"
    case trapBar = "Trap / Hex Bar"
    case dumbbell = "Dumbbells"
    case kettlebell = "Kettlebells"
    case weightPlates = "Weight Plates"

    // Racks & Benches
    case squatRack = "Squat / Power Rack"
    case smithMachine = "Smith Machine"
    case landmine = "Landmine Attachment"
    case flatBench = "Flat Bench"
    case adjustableBench = "Adjustable Incline Bench"
    case declineBench = "Decline Bench"
    case preacherBench = "Preacher Curl Bench"
    case pullUpBar = "Pull-Up Bar"
    case dipStation = "Dip Station / Bars"
    case ghdOrRomanChair = "GHD / Roman Chair"

    // Machines & Cables
    case dualCablePulley = "Cable Pulley / Functional Trainer"
    case latPulldownMachine = "Lat Pulldown Machine"
    case seatedRowMachine = "Seated Cable / Chest-Supported Row"
    case legPress = "Leg Press"
    case hackSquat = "Hack Squat"
    case legExtension = "Leg Extension Machine"
    case seatedLegCurl = "Seated Leg Curl Machine"
    case lyingLegCurl = "Lying Leg Curl Machine"
    case hipAbductorAdductorMachine = "Hip Abductor / Adductor Machine"
    case gluteKickbackMachine = "Glute Kickback / Multi-Hip Machine"
    case backExtensionMachine = "Seated Back Extension Machine"
    case pecDeck = "Pec Deck / Rear Delt Fly Machine"
    case chestPressMachine = "Chest Press Machine"
    case shoulderPressMachine = "Shoulder Press Machine"
    case lateralRaiseMachine = "Lateral Raise Machine"
    case bicepCurlMachine = "Bicep Curl Machine"
    case tricepExtensionMachine = "Tricep Extension / Dip Machine"
    case calfRaiseMachine = "Calf Raise Machine"
    case assistedPullUpDip = "Assisted Pull-Up / Dip Machine"
    case abCrunchMachine = "Ab Crunch Machine"
    case rotaryTorsoMachine = "Rotary Torso Machine"

    // Conditioning & Accessories
    case rower = "Rowing Machine (Concept2)"
    case assaultBike = "Air / Assault Bike"
    case stationaryBike = "Stationary Upright / Recumbent Bike"
    case stairClimber = "Stair Climber / StepMill"
    case skiErg = "SkiErg"
    case treadmill = "Treadmill"
    case sled = "Prowler / Turf Sled"
    case plyoBox = "Plyo Box"
    case battleRopes = "Battle Ropes"
    case trxSuspension = "TRX / Suspension Trainer"
    case medicineBall = "Medicine Ball / Wall Ball"
    case stabilityBosuBall = "Swiss Ball / BOSU Trainer"
    case resistanceBands = "Resistance Bands"
    case abWheel = "Ab Wheel"
    case bodyweight = "Bodyweight / Floor"

    var id: String { rawValue }

    var category: EquipmentCategory {
        switch self {
        case .barbell, .ezCurlBar, .trapBar, .dumbbell, .kettlebell, .weightPlates:
            return .freeWeights
        case .squatRack, .smithMachine, .landmine, .flatBench, .adjustableBench, .declineBench, .preacherBench, .pullUpBar, .dipStation, .ghdOrRomanChair:
            return .racksAndBenches
        case .dualCablePulley, .latPulldownMachine, .seatedRowMachine, .legPress, .hackSquat, .legExtension, .seatedLegCurl, .lyingLegCurl, .hipAbductorAdductorMachine, .gluteKickbackMachine, .backExtensionMachine, .pecDeck, .chestPressMachine, .shoulderPressMachine, .lateralRaiseMachine, .bicepCurlMachine, .tricepExtensionMachine, .calfRaiseMachine, .assistedPullUpDip, .abCrunchMachine, .rotaryTorsoMachine:
            return .machinesAndCables
        case .rower, .assaultBike, .stationaryBike, .stairClimber, .skiErg, .treadmill, .sled, .plyoBox, .battleRopes, .trxSuspension, .medicineBall, .stabilityBosuBall, .resistanceBands, .abWheel, .bodyweight:
            return .conditioningAndAccessories
        }
    }

    static func items(for category: EquipmentCategory) -> [EquipmentType] {
        allCases.filter { $0.category == category }
    }
}

// MARK: - Gym Preset Templates

enum GymPresetTemplate: String, CaseIterable, Identifiable {
    case fullCommercial = "Full Commercial Gym"
    case homeGarageRack = "Home Garage (Barbell + Rack + DBs)"
    case hotelDumbbells = "Hotel / Apartment (DBs + Bench + Treadmill)"
    case kettlebellBodyweight = "Minimalist (KB + Pull-Up Bar + Bodyweight)"
    case bodyweightOnly = "Travel / Bodyweight Only"

    var id: String { rawValue }

    var defaultIcon: String {
        switch self {
        case .fullCommercial: return "building.2.fill"
        case .homeGarageRack: return "house.fill"
        case .hotelDumbbells: return "bed.double.fill"
        case .kettlebellBodyweight: return "figure.strengthtraining.functional"
        case .bodyweightOnly: return "airplane"
        }
    }

    var defaultMaxDumbbell: Double? {
        switch self {
        case .fullCommercial: return 120
        case .homeGarageRack: return 80
        case .hotelDumbbells: return 50
        case .kettlebellBodyweight: return nil
        case .bodyweightOnly: return nil
        }
    }

    var equipmentSet: Set<EquipmentType> {
        switch self {
        case .fullCommercial:
            return Set(EquipmentType.allCases)
        case .homeGarageRack:
            return [
                .barbell, .ezCurlBar, .dumbbell, .kettlebell, .weightPlates,
                .squatRack, .flatBench, .adjustableBench, .pullUpBar, .dipStation,
                .rower, .plyoBox, .resistanceBands, .abWheel, .bodyweight
            ]
        case .hotelDumbbells:
            return [
                .dumbbell, .flatBench, .adjustableBench, .dualCablePulley,
                .pullUpBar, .treadmill, .assaultBike, .bodyweight
            ]
        case .kettlebellBodyweight:
            return [
                .kettlebell, .pullUpBar, .dipStation, .resistanceBands, .abWheel, .bodyweight
            ]
        case .bodyweightOnly:
            return [.bodyweight]
        }
    }
}

// MARK: - Movement Pattern & Muscle Group

enum MovementPattern: String, Codable, CaseIterable, Identifiable {
    case horizontalPush = "Horizontal Push"
    case inclinePush = "Incline Push"
    case verticalPush = "Vertical Push"
    case horizontalPull = "Horizontal Pull"
    case verticalPull = "Vertical Pull"
    case squat = "Squat"
    case hipHinge = "Hip Hinge"
    case unilateralLeg = "Single-Leg / Lunge"
    case kneeExtension = "Quad Isolation"
    case kneeFlexion = "Hamstring Curl"
    case elbowFlexion = "Bicep Curl"
    case elbowExtension = "Tricep Extension"
    case lateralDeltoid = "Lateral Raise"
    case rearDeltoid = "Rear Delt / Face Pull"
    case calves = "Calf Raise"
    case coreAntiExtension = "Core Anti-Extension"
    case coreFlexion = "Core Flexion"
    case coreRotation = "Core Rotation / Carry"
    case conditioningFullBody = "Conditioning / Metcon"

    var id: String { rawValue }

    var isCorePattern: Bool {
        switch self {
        case .coreAntiExtension, .coreFlexion, .coreRotation:
            return true
        default:
            return false
        }
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest = "Chest"
    case upperChest = "Upper Chest"
    case lats = "Lats"
    case upperBack = "Upper Back & Traps"
    case frontDelt = "Front Delts"
    case sideDelt = "Side Delts"
    case rearDelt = "Rear Delts"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case forearms = "Forearms"
    case calves = "Calves"
    case abs = "Abs"
    case obliques = "Obliques"
    case lowerBack = "Lower Back"
    case fullBody = "Full Body / Cardio"

    var id: String { rawValue }

    var isCoreMuscle: Bool {
        self == .abs || self == .obliques
    }

    var color: Color {
        switch self {
        case .chest, .upperChest: return .red
        case .lats, .upperBack, .lowerBack: return .blue
        case .frontDelt, .sideDelt, .rearDelt: return .orange
        case .quads, .hamstrings, .glutes, .calves: return .green
        case .biceps, .triceps, .forearms: return .purple
        case .abs, .obliques: return .mint
        case .fullBody: return .yellow
        }
    }
}

// MARK: - Mechanic Type & Priority Tier

enum MechanicType: String, Codable, CaseIterable, Identifiable {
    case compound = "Compound"
    case isolation = "Isolation"
    case core = "Core"
    case conditioning = "Conditioning"

    var id: String { rawValue }
}

enum ExerciseTier: Int, Codable, CaseIterable, Identifiable, Comparable {
    case tier1PrimaryCompound = 1
    case tier2SecondaryCompound = 2
    case tierCore = 3
    case tier3Isolation = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .tier1PrimaryCompound: return "Tier 1 · Primary Compound"
        case .tier2SecondaryCompound: return "Tier 2 · Secondary Compound"
        case .tierCore: return "Core Work"
        case .tier3Isolation: return "Tier 3 · Accessory / Isolation"
        }
    }

    var shortBadge: String {
        switch self {
        case .tier1PrimaryCompound: return "T1 Main"
        case .tier2SecondaryCompound: return "T2 Secondary"
        case .tierCore: return "Core"
        case .tier3Isolation: return "T3 Accessory"
        }
    }

    static func < (lhs: ExerciseTier, rhs: ExerciseTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Periodization & Program Splits

enum SplitType: String, Codable, CaseIterable, Identifiable {
    case fullBody = "Full Body"
    case pushPullLegs = "Push / Pull / Legs (PPL)"
    case upperLower = "Upper / Lower"
    case customSplit = "Custom Split"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .fullBody: return "3–4 days/wk · High frequency, total body stimulus every session"
        case .pushPullLegs: return "3–6 days/wk · Dedicated Push, Pull, and Lower body days"
        case .upperLower: return "4 days/wk · Balanced strength & hypertrophy Upper/Lower rotation"
        case .customSplit: return "Flexible rotation tailored to your custom schedule"
        }
    }

    var icon: String {
        switch self {
        case .fullBody: return "figure.strengthtraining.traditional"
        case .pushPullLegs: return "square.stack.3d.up.fill"
        case .upperLower: return "arrow.up.arrow.down.square.fill"
        case .customSplit: return "slider.horizontal.3"
        }
    }
}

enum ProgressionModel: String, Codable, CaseIterable, Identifiable {
    case linearRIR = "RIR Ramp + Load Progression"
    case volumeAccumulation = "Volume Accumulation (+Sets)"
    case wavePercentage = "Undulating Wave (%1RM)"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .linearRIR:
            return "Starts at 3 RIR (RPE 7) in Week 1 and ramps intensity to 0–1 RIR (+2.5% load/wk) before deload."
        case .volumeAccumulation:
            return "Adds +1 working set to compound lifts in later accumulation weeks, then halves volume on deload."
        case .wavePercentage:
            return "Cycles medium, heavy, and peak %1RM waves across the block before a recovery week."
        }
    }
}

// MARK: - Finishers & Sets

enum FinisherFormat: String, Codable, CaseIterable, Identifiable {
    case emom = "EMOM"
    case amrap = "AMRAP"
    case tabata = "Tabata / Intervals"
    case forTime = "For Time"

    var id: String { rawValue }

    var fullTitle: String {
        switch self {
        case .emom: return "EMOM (Every Minute on the Minute)"
        case .amrap: return "AMRAP (As Many Rounds As Possible)"
        case .tabata: return "Tabata / Work-Rest Intervals"
        case .forTime: return "For Time (Timed Chipper / Rounds)"
        }
    }

    var icon: String {
        switch self {
        case .emom: return "timer"
        case .amrap: return "repeat.circle.fill"
        case .tabata: return "waveform.path.ecg"
        case .forTime: return "flag.checkered"
        }
    }

    var badgeColor: Color {
        switch self {
        case .emom: return .orange
        case .amrap: return .pink
        case .tabata: return .cyan
        case .forTime: return .green
        }
    }
}

enum SetType: String, Codable, CaseIterable, Identifiable {
    case warmup = "W"
    case working = "S"
    case topSet = "T"
    case dropSet = "D"
    case failure = "F"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .warmup: return "Warm-up"
        case .working: return "Working Set"
        case .topSet: return "Top Set"
        case .dropSet: return "Drop Set"
        case .failure: return "To Failure"
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case lbs = "lbs"
    case kg = "kg"

    var id: String { rawValue }
}

enum AppAppearanceMode: String, Codable, CaseIterable, Identifiable {
    case dark = "Dark Mode"
    case light = "Light Mode"
    case system = "System"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

enum HistoryTrendMetric: String, Codable, CaseIterable, Identifiable {
    case exerciseWeight = "Exercise Top Weight"
    case exerciseE1RM = "Exercise Est. 1RM"
    case caloriesBurned = "Calories Burned (kcal)"
    case totalVolume = "Workout Total Volume"

    var id: String { rawValue }

    var requiresExerciseSelection: Bool {
        self == .exerciseWeight || self == .exerciseE1RM
    }
}


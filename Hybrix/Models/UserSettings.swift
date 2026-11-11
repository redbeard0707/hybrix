import Foundation
import Observation

@Observable
final class UserSettings {
    static let shared = UserSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let alwaysIncludeCore = "hybrix.alwaysIncludeCore"
        static let includeTargetedWarmup = "hybrix.includeTargetedWarmup"
        static let defaultWarmupMinutes = "hybrix.defaultWarmupMinutes"
        static let defaultWorkoutDurationMinutes = "hybrix.defaultWorkoutDurationMinutes"
        static let weightUnit = "hybrix.weightUnit"
        static let smallestWeightIncrement = "hybrix.smallestWeightIncrement"
        static let defaultCompoundRestSeconds = "hybrix.defaultCompoundRestSeconds"
        static let defaultIsolationRestSeconds = "hybrix.defaultIsolationRestSeconds"
        static let autoStartRestTimer = "hybrix.autoStartRestTimer"
        static let timerSoundEnabled = "hybrix.timerSoundEnabled"
        static let timerHapticsEnabled = "hybrix.timerHapticsEnabled"
        static let includeFinisherByDefault = "hybrix.includeFinisherByDefault"
        static let activeGymProfileId = "hybrix.activeGymProfileId"
        static let appearanceMode = "hybrix.appearanceMode"
        static let userBodyweightLbs = "hybrix.userBodyweightLbs"
        static let previousMesocycleId = "hybrix.previousMesocycleId"
        static let hasCompletedOnboarding = "hybrix.hasCompletedOnboarding"
    }

    var alwaysIncludeCore: Bool {
        didSet { defaults.set(alwaysIncludeCore, forKey: Keys.alwaysIncludeCore) }
    }

    var includeTargetedWarmup: Bool {
        didSet { defaults.set(includeTargetedWarmup, forKey: Keys.includeTargetedWarmup) }
    }

    var defaultWarmupMinutes: Int {
        didSet { defaults.set(defaultWarmupMinutes, forKey: Keys.defaultWarmupMinutes) }
    }

    var defaultWorkoutDurationMinutes: Int {
        didSet { defaults.set(defaultWorkoutDurationMinutes, forKey: Keys.defaultWorkoutDurationMinutes) }
    }

    var weightUnit: WeightUnit {
        didSet { defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit) }
    }

    var smallestWeightIncrement: Double {
        didSet { defaults.set(smallestWeightIncrement, forKey: Keys.smallestWeightIncrement) }
    }

    var defaultCompoundRestSeconds: Int {
        didSet { defaults.set(defaultCompoundRestSeconds, forKey: Keys.defaultCompoundRestSeconds) }
    }

    var defaultIsolationRestSeconds: Int {
        didSet { defaults.set(defaultIsolationRestSeconds, forKey: Keys.defaultIsolationRestSeconds) }
    }

    var autoStartRestTimer: Bool {
        didSet { defaults.set(autoStartRestTimer, forKey: Keys.autoStartRestTimer) }
    }

    var timerSoundEnabled: Bool {
        didSet { defaults.set(timerSoundEnabled, forKey: Keys.timerSoundEnabled) }
    }

    var timerHapticsEnabled: Bool {
        didSet { defaults.set(timerHapticsEnabled, forKey: Keys.timerHapticsEnabled) }
    }

    var includeFinisherByDefault: Bool {
        didSet { defaults.set(includeFinisherByDefault, forKey: Keys.includeFinisherByDefault) }
    }

    var activeGymProfileId: String? {
        didSet { defaults.set(activeGymProfileId, forKey: Keys.activeGymProfileId) }
    }

    var appearanceMode: AppAppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    var userBodyweightLbs: Double {
        didSet { defaults.set(userBodyweightLbs, forKey: Keys.userBodyweightLbs) }
    }

    var previousMesocycleId: String? {
        didSet { defaults.set(previousMesocycleId, forKey: Keys.previousMesocycleId) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    init() {
        if defaults.object(forKey: Keys.alwaysIncludeCore) == nil {
            defaults.set(true, forKey: Keys.alwaysIncludeCore)
        }
        if defaults.object(forKey: Keys.includeTargetedWarmup) == nil {
            defaults.set(true, forKey: Keys.includeTargetedWarmup)
        }
        if defaults.object(forKey: Keys.defaultWarmupMinutes) == nil {
            defaults.set(5, forKey: Keys.defaultWarmupMinutes)
        }
        if defaults.object(forKey: Keys.defaultWorkoutDurationMinutes) == nil {
            defaults.set(60, forKey: Keys.defaultWorkoutDurationMinutes)
        }
        if defaults.object(forKey: Keys.smallestWeightIncrement) == nil {
            defaults.set(5.0, forKey: Keys.smallestWeightIncrement)
        }
        if defaults.object(forKey: Keys.defaultCompoundRestSeconds) == nil {
            defaults.set(120, forKey: Keys.defaultCompoundRestSeconds)
        }
        if defaults.object(forKey: Keys.defaultIsolationRestSeconds) == nil {
            defaults.set(75, forKey: Keys.defaultIsolationRestSeconds)
        }
        if defaults.object(forKey: Keys.autoStartRestTimer) == nil {
            defaults.set(true, forKey: Keys.autoStartRestTimer)
        }
        if defaults.object(forKey: Keys.timerSoundEnabled) == nil {
            defaults.set(true, forKey: Keys.timerSoundEnabled)
        }
        if defaults.object(forKey: Keys.timerHapticsEnabled) == nil {
            defaults.set(true, forKey: Keys.timerHapticsEnabled)
        }
        if defaults.object(forKey: Keys.includeFinisherByDefault) == nil {
            defaults.set(true, forKey: Keys.includeFinisherByDefault)
        }
        if defaults.object(forKey: Keys.appearanceMode) == nil {
            defaults.set(AppAppearanceMode.dark.rawValue, forKey: Keys.appearanceMode)
        }
        if defaults.object(forKey: Keys.userBodyweightLbs) == nil {
            defaults.set(185.0, forKey: Keys.userBodyweightLbs)
        }

        self.alwaysIncludeCore = defaults.bool(forKey: Keys.alwaysIncludeCore)
        self.includeTargetedWarmup = defaults.bool(forKey: Keys.includeTargetedWarmup)
        self.defaultWarmupMinutes = max(3, min(7, defaults.integer(forKey: Keys.defaultWarmupMinutes)))
        self.defaultWorkoutDurationMinutes = defaults.integer(forKey: Keys.defaultWorkoutDurationMinutes)
        let unitRaw = defaults.string(forKey: Keys.weightUnit) ?? WeightUnit.lbs.rawValue
        self.weightUnit = WeightUnit(rawValue: unitRaw) ?? .lbs
        self.smallestWeightIncrement = defaults.double(forKey: Keys.smallestWeightIncrement)
        self.defaultCompoundRestSeconds = defaults.integer(forKey: Keys.defaultCompoundRestSeconds)
        self.defaultIsolationRestSeconds = defaults.integer(forKey: Keys.defaultIsolationRestSeconds)
        self.autoStartRestTimer = defaults.bool(forKey: Keys.autoStartRestTimer)
        self.timerSoundEnabled = defaults.bool(forKey: Keys.timerSoundEnabled)
        self.timerHapticsEnabled = defaults.bool(forKey: Keys.timerHapticsEnabled)
        self.includeFinisherByDefault = defaults.bool(forKey: Keys.includeFinisherByDefault)
        self.activeGymProfileId = defaults.string(forKey: Keys.activeGymProfileId)
        let modeRaw = defaults.string(forKey: Keys.appearanceMode) ?? AppAppearanceMode.dark.rawValue
        self.appearanceMode = AppAppearanceMode(rawValue: modeRaw) ?? .dark
        let bw = defaults.double(forKey: Keys.userBodyweightLbs)
        self.userBodyweightLbs = bw > 0 ? bw : 185.0
        self.previousMesocycleId = defaults.string(forKey: Keys.previousMesocycleId)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    func roundWeight(_ weight: Double) -> Double {
        let step = max(1.0, smallestWeightIncrement)
        return (weight / step).rounded() * step
    }
}

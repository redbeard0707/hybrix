import Foundation
import Observation
import AudioToolbox
import CoreHaptics
import UIKit

@Observable
final class WorkoutTimerManager {
    static let shared = WorkoutTimerManager()

    // Rest timer state
    var isRestTimerRunning: Bool = false
    var restSecondsRemaining: Int = 0
    var restSecondsTotal: Int = 90

    // Finisher timer state
    var isFinisherRunning: Bool = false
    var finisherElapsedSeconds: Int = 0
    var finisherTotalSeconds: Int = 600
    var finisherFormat: FinisherFormat = .emom
    var tabataWorkSeconds: Int = 20
    var tabataRestSeconds: Int = 10
    var amrapRoundsCompleted: Int = 0
    var amrapExtraReps: Int = 0
    var finisherIsCompleted: Bool = false

    private var restTimer: Timer?
    private var finisherTimer: Timer?

    // MARK: - Rest Timer Controls

    func startRestTimer(seconds: Int) {
        stopRestTimer()
        restSecondsTotal = max(5, seconds)
        restSecondsRemaining = restSecondsTotal
        isRestTimerRunning = true

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.restSecondsRemaining > 1 {
                self.restSecondsRemaining -= 1
                if self.restSecondsRemaining <= 3 {
                    self.playCountdownTick()
                }
            } else {
                self.restSecondsRemaining = 0
                self.isRestTimerRunning = false
                self.restTimer?.invalidate()
                self.playCompletionCue()
            }
        }
    }

    func adjustRestTimer(by deltaSeconds: Int) {
        restSecondsRemaining = max(0, restSecondsRemaining + deltaSeconds)
        restSecondsTotal = max(restSecondsTotal, restSecondsRemaining)
        if restSecondsRemaining == 0 {
            stopRestTimer()
        }
    }

    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerRunning = false
        restSecondsRemaining = 0
    }

    // MARK: - Finisher Timer Controls

    func configureFinisher(
        format: FinisherFormat,
        durationMinutes: Int,
        workSeconds: Int = 20,
        restSeconds: Int = 10,
        roundsTarget: Int = 8
    ) {
        stopFinisher()
        self.finisherFormat = format
        self.tabataWorkSeconds = max(5, workSeconds)
        self.tabataRestSeconds = max(5, restSeconds)
        self.amrapRoundsCompleted = 0
        self.amrapExtraReps = 0
        self.finisherIsCompleted = false
        self.finisherElapsedSeconds = 0

        if format == .tabata {
            self.finisherTotalSeconds = roundsTarget * (self.tabataWorkSeconds + self.tabataRestSeconds)
        } else {
            self.finisherTotalSeconds = max(60, durationMinutes * 60)
        }
    }

    func toggleFinisher() {
        if isFinisherRunning {
            pauseFinisher()
        } else {
            startFinisher()
        }
    }

    func startFinisher() {
        guard !finisherIsCompleted else { return }
        isFinisherRunning = true
        playIntervalTransitionCue()

        finisherTimer?.invalidate()
        finisherTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tickFinisher()
        }
    }

    func pauseFinisher() {
        isFinisherRunning = false
        finisherTimer?.invalidate()
        finisherTimer = nil
    }

    func stopFinisher() {
        pauseFinisher()
        finisherElapsedSeconds = 0
        finisherIsCompleted = false
    }

    private func tickFinisher() {
        if finisherElapsedSeconds + 1 >= finisherTotalSeconds {
            finisherElapsedSeconds = finisherTotalSeconds
            finisherIsCompleted = true
            pauseFinisher()
            playCompletionCue()
            return
        }

        finisherElapsedSeconds += 1
        let remainingTotal = finisherTotalSeconds - finisherElapsedSeconds

        switch finisherFormat {
        case .emom:
            let secInMinute = finisherElapsedSeconds % 60
            let secRemainingInMin = 60 - secInMinute
            if secInMinute == 0 {
                playIntervalTransitionCue()
            } else if secRemainingInMin <= 3 {
                playCountdownTick()
            }

        case .amrap, .forTime:
            if remainingTotal <= 3 {
                playCountdownTick()
            } else if finisherElapsedSeconds % 60 == 0 {
                triggerHaptic(.light)
            }

        case .tabata:
            let cycleLen = max(1, tabataWorkSeconds + tabataRestSeconds)
            let pos = finisherElapsedSeconds % cycleLen
            if pos == 0 || pos == tabataWorkSeconds {
                playIntervalTransitionCue()
            } else if (pos < tabataWorkSeconds && (tabataWorkSeconds - pos) <= 3) ||
                      (pos >= tabataWorkSeconds && (cycleLen - pos) <= 3) {
                playCountdownTick()
            }
        }
    }

    // MARK: - Computed Finisher Display Helpers

    var finisherRemainingSeconds: Int {
        max(0, finisherTotalSeconds - finisherElapsedSeconds)
    }

    var currentEMOMMinuteNumber: Int {
        (finisherElapsedSeconds / 60) + 1
    }

    var totalEMOMMinutes: Int {
        max(1, finisherTotalSeconds / 60)
    }

    var emomSecondsRemainingInMinute: Int {
        let mod = finisherElapsedSeconds % 60
        return 60 - mod
    }

    var tabataCurrentRound: Int {
        let cycle = max(1, tabataWorkSeconds + tabataRestSeconds)
        return (finisherElapsedSeconds / cycle) + 1
    }

    var tabataTotalRounds: Int {
        let cycle = max(1, tabataWorkSeconds + tabataRestSeconds)
        return max(1, finisherTotalSeconds / cycle)
    }

    var tabataIsWorkPhase: Bool {
        let cycle = max(1, tabataWorkSeconds + tabataRestSeconds)
        return (finisherElapsedSeconds % cycle) < tabataWorkSeconds
    }

    var tabataSecondsRemainingInPhase: Int {
        let cycle = max(1, tabataWorkSeconds + tabataRestSeconds)
        let pos = finisherElapsedSeconds % cycle
        if pos < tabataWorkSeconds {
            return tabataWorkSeconds - pos
        } else {
            return cycle - pos
        }
    }

    // MARK: - Audio & Haptics

    private var supportsHaptics: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
        #endif
    }

    func playCountdownTick() {
        if UserSettings.shared.timerSoundEnabled {
            AudioServicesPlaySystemSound(1104)
        }
        triggerHaptic(.light)
    }

    func playIntervalTransitionCue() {
        if UserSettings.shared.timerSoundEnabled {
            AudioServicesPlaySystemSound(1057)
        }
        triggerHaptic(.medium)
    }

    func playCompletionCue() {
        if UserSettings.shared.timerSoundEnabled {
            AudioServicesPlaySystemSound(1005)
        }
        guard UserSettings.shared.timerHapticsEnabled, supportsHaptics else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard UserSettings.shared.timerHapticsEnabled, supportsHaptics else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func formatMMSS(_ totalSeconds: Int) -> String {
        let mins = max(0, totalSeconds) / 60
        let secs = max(0, totalSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

import Foundation
import SwiftUI
import ActivityKit
import AppIntents

enum HybrixLiveActivityActionBridge {
    @MainActor static var onCompleteCurrentSet: (() -> Void)?
}

struct HybrixWorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var workoutTitle: String
        var gymName: String
        var currentExerciseName: String
        var currentSetBadge: String
        var isWarmupSet: Bool
        var prescriptionText: String
        var targetRIR: Int
        var completedSetsCount: Int
        var totalSetsCount: Int
        var isResting: Bool
        var restRemainingSeconds: Int
        var restEndDate: Date?
        var allSetsCompleted: Bool
    }

    var sessionId: String

    static func formatMMSS(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let mins = clamped / 60
        let secs = clamped % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct CompleteCurrentSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Current Set"
    static var description = IntentDescription("Marks the active workout set as completed and starts rest if applicable.")

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            HybrixLiveActivityActionBridge.onCompleteCurrentSet?()
        }
        return .result()
    }
}

/// Reusable Lock Screen "Live Card" view with interactive 'Complete Set' button.
struct HybrixLockScreenLiveCardView: View {
    let state: HybrixWorkoutActivityAttributes.ContentState
    var onCompleteSet: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundStyle(.orange)
                    Text("HYBRIX LIVE · \(state.workoutTitle.uppercased())")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }

                Spacer()

                if state.isResting, state.restRemainingSeconds > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        if let endDate = state.restEndDate, endDate > Date() {
                            Text(timerInterval: Date()...endDate, countsDown: true)
                                .monospacedDigit()
                        } else {
                            Text("Rest \(HybrixWorkoutActivityAttributes.formatMMSS(state.restRemainingSeconds))")
                        }
                    }
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                } else {
                    Text("\(state.completedSetsCount)/\(state.totalSetsCount) Sets")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(state.currentSetBadge)
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(state.isWarmupSet ? Color.yellow.opacity(0.22) : Color.orange.opacity(0.2))
                            .foregroundStyle(state.isWarmupSet ? .yellow : .orange)
                            .clipShape(Capsule())

                        Text(state.currentExerciseName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Text(state.prescriptionText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !state.allSetsCompleted {
                    if let onCompleteSet {
                        Button(action: onCompleteSet) {
                            completeSetButtonLabel
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(intent: CompleteCurrentSetIntent()) {
                            completeSetButtonLabel
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Label("All Sets Done", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var completeSetButtonLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
            Text("Complete Set")
                .font(.caption.weight(.black))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            LinearGradient(
                colors: [.orange, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }
}

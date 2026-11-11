import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

@main
struct HybrixWidgetBundle: WidgetBundle {
    var body: some Widget {
        HybrixWorkoutLiveActivity()
    }
}

struct HybrixWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HybrixWorkoutActivityAttributes.self) { context in
            // Lock Screen / Banner Live Card UI
            HybrixLockScreenLiveCardView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.shield.fill")
                            .foregroundStyle(.orange)
                        Text(context.state.currentSetBadge)
                            .font(.caption.weight(.black))
                            .foregroundStyle(.orange)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isResting, let endDate = context.state.restEndDate, endDate > Date() {
                        Text(timerInterval: Date()...endDate, countsDown: true)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(context.state.completedSetsCount)/\(context.state.totalSetsCount)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.currentExerciseName)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                            Text(context.state.prescriptionText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if !context.state.allSetsCompleted {
                            Button(intent: CompleteCurrentSetIntent()) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Complete Set")
                                        .font(.caption2.weight(.black))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundStyle(.orange)
                    Text(context.state.currentSetBadge)
                        .font(.caption2.weight(.bold))
                }
            } compactTrailing: {
                if context.state.isResting, let endDate = context.state.restEndDate, endDate > Date() {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                        .frame(width: 38)
                } else {
                    Text("\(context.state.completedSetsCount)/\(context.state.totalSetsCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
            } minimal: {
                Image(systemName: "bolt.shield.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}

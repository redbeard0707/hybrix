import SwiftUI

struct FinisherTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var timerManager = WorkoutTimerManager.shared

    @State private var format: FinisherFormat
    @State private var durationMinutes: Int
    @State private var workSeconds: Int
    @State private var restSeconds: Int
    @State private var roundsTarget: Int
    @State private var movements: [String]
    let title: String
    let onComplete: ((FinisherCompletionResult) -> Void)?

    init(
        initialPlan: ComputedFinisherPlan,
        onComplete: ((FinisherCompletionResult) -> Void)?
    ) {
        self.title = initialPlan.title
        _format = State(initialValue: initialPlan.format)
        _durationMinutes = State(initialValue: initialPlan.effectiveDurationMinutes)
        _workSeconds = State(initialValue: initialPlan.workSeconds)
        _restSeconds = State(initialValue: initialPlan.restSeconds)
        _roundsTarget = State(initialValue: initialPlan.roundsTarget)
        _movements = State(initialValue: initialPlan.movements)
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // Format Picker
                    Picker("Format", selection: $format) {
                        ForEach(FinisherFormat.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: format) { _, newValue in
                        timerManager.configureFinisher(
                            format: newValue,
                            durationMinutes: durationMinutes,
                            workSeconds: workSeconds,
                            restSeconds: restSeconds,
                            roundsTarget: roundsTarget
                        )
                    }

                    // Circular Countdown Ring
                    ZStack {
                        Circle()
                            .stroke(Color(.tertiarySystemFill), lineWidth: 18)

                        Circle()
                            .trim(from: 0, to: progressFraction)
                            .stroke(
                                format.badgeColor,
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.35), value: timerManager.finisherElapsedSeconds)

                        VStack(spacing: 6) {
                            Text(statusSubtitle)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(format.badgeColor)

                            Text(primaryClockDisplay)
                                .font(.system(size: 56, weight: .black, design: .rounded))
                                .monospacedDigit()

                            Text("Total Remaining: \(WorkoutTimerManager.formatMMSS(timerManager.finisherRemainingSeconds))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 250, height: 250)
                    .padding(.top, 8)

                    // Duration Adjustment when Paused
                    if !timerManager.isFinisherRunning && timerManager.finisherElapsedSeconds == 0 {
                        HStack(spacing: 16) {
                            if format == .tabata {
                                Stepper("Rounds: \(roundsTarget)", value: $roundsTarget, in: 4...20)
                                    .onChange(of: roundsTarget) { _, newVal in
                                        timerManager.configureFinisher(format: format, durationMinutes: durationMinutes, workSeconds: workSeconds, restSeconds: restSeconds, roundsTarget: newVal)
                                    }
                            } else {
                                Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 2...30)
                                    .onChange(of: durationMinutes) { _, newVal in
                                        timerManager.configureFinisher(format: format, durationMinutes: newVal, workSeconds: workSeconds, restSeconds: restSeconds, roundsTarget: roundsTarget)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Active Station / Movements Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MOVEMENT STATIONS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        ForEach(Array(movements.enumerated()), id: \.offset) { idx, move in
                            let isCurrentEMOMStation = format == .emom &&
                                ((timerManager.currentEMOMMinuteNumber - 1) % max(1, movements.count) == idx)

                            HStack(spacing: 10) {
                                Image(systemName: isCurrentEMOMStation ? "play.circle.fill" : "circle.fill")
                                    .font(isCurrentEMOMStation ? .body : .caption2)
                                    .foregroundStyle(isCurrentEMOMStation ? format.badgeColor : .secondary)

                                Text(move)
                                    .font(.subheadline.weight(isCurrentEMOMStation ? .bold : .regular))
                                Spacer()
                                if isCurrentEMOMStation {
                                    Text("NOW")
                                        .font(.caption2.weight(.heavy))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(format.badgeColor.opacity(0.2))
                                        .foregroundStyle(format.badgeColor)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(10)
                            .background(
                                isCurrentEMOMStation
                                    ? format.badgeColor.opacity(0.12)
                                    : Color(.tertiarySystemGroupedBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // AMRAP / For Time Round Counter
                    if format == .amrap || format == .forTime {
                        HStack(spacing: 14) {
                            Button {
                                timerManager.amrapRoundsCompleted += 1
                                timerManager.triggerHaptic(.heavy)
                            } label: {
                                VStack(spacing: 4) {
                                    Text("+1 ROUND")
                                        .font(.headline.weight(.black))
                                    Text("Completed: \(timerManager.amrapRoundsCompleted) Rounds")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.pink.opacity(0.2))
                                .foregroundStyle(.pink)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Stepper(
                                "+\(timerManager.amrapExtraReps) reps",
                                value: $timerManager.amrapExtraReps,
                                in: 0...100
                            )
                            .font(.caption.weight(.bold))
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // Primary Start / Pause / Reset Controls
                    HStack(spacing: 14) {
                        Button {
                            timerManager.stopFinisher()
                            timerManager.configureFinisher(
                                format: format,
                                durationMinutes: durationMinutes,
                                workSeconds: workSeconds,
                                restSeconds: restSeconds,
                                roundsTarget: roundsTarget
                            )
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            timerManager.toggleFinisher()
                        } label: {
                            Label(
                                timerManager.isFinisherRunning ? "Pause" : "Start Timer",
                                systemImage: timerManager.isFinisherRunning ? "pause.fill" : "play.fill"
                            )
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(format.badgeColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    if let onComplete {
                        Button {
                            timerManager.pauseFinisher()
                            let rounds = format == .emom
                                ? timerManager.currentEMOMMinuteNumber
                                : (format == .tabata ? timerManager.tabataCurrentRound : timerManager.amrapRoundsCompleted)
                            onComplete(
                                FinisherCompletionResult(
                                    durationSeconds: max(60, timerManager.finisherElapsedSeconds),
                                    roundsCompleted: rounds,
                                    extraReps: timerManager.amrapExtraReps
                                )
                            )
                            dismiss()
                        } label: {
                            Label("Log Finisher to Workout", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        timerManager.pauseFinisher()
                        dismiss()
                    }
                }
            }
            .onAppear {
                timerManager.configureFinisher(
                    format: format,
                    durationMinutes: durationMinutes,
                    workSeconds: workSeconds,
                    restSeconds: restSeconds,
                    roundsTarget: roundsTarget
                )
            }
        }
    }

    private var progressFraction: CGFloat {
        switch format {
        case .emom:
            return CGFloat(timerManager.emomSecondsRemainingInMinute) / 60.0
        case .tabata:
            let totalPhase = timerManager.tabataIsWorkPhase ? timerManager.tabataWorkSeconds : timerManager.tabataRestSeconds
            return CGFloat(timerManager.tabataSecondsRemainingInPhase) / CGFloat(max(1, totalPhase))
        case .amrap, .forTime:
            return CGFloat(timerManager.finisherRemainingSeconds) / CGFloat(max(1, timerManager.finisherTotalSeconds))
        }
    }

    private var statusSubtitle: String {
        switch format {
        case .emom:
            return "MINUTE \(timerManager.currentEMOMMinuteNumber) OF \(timerManager.totalEMOMMinutes)"
        case .tabata:
            let phase = timerManager.tabataIsWorkPhase ? "WORK!" : "REST"
            return "ROUND \(timerManager.tabataCurrentRound)/\(timerManager.tabataTotalRounds) · \(phase)"
        case .amrap:
            return "AMRAP · \(timerManager.amrapRoundsCompleted) ROUNDS"
        case .forTime:
            return "FOR TIME CAP"
        }
    }

    private var primaryClockDisplay: String {
        switch format {
        case .emom:
            return String(format: "00:%02d", timerManager.emomSecondsRemainingInMinute)
        case .tabata:
            return String(format: "00:%02d", timerManager.tabataSecondsRemainingInPhase)
        case .amrap:
            return WorkoutTimerManager.formatMMSS(timerManager.finisherRemainingSeconds)
        case .forTime:
            return WorkoutTimerManager.formatMMSS(timerManager.finisherElapsedSeconds)
        }
    }
}

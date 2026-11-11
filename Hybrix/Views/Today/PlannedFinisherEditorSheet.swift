import SwiftUI

struct PlannedFinisherEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentFinisher: ComputedFinisherPlan
    let gym: GymProfile
    let onSave: (PlannedFinisherOverride) -> Void
    let onResetToDefault: () -> Void

    @State private var title: String
    @State private var format: FinisherFormat
    @State private var durationMinutes: Int
    @State private var workSeconds: Int
    @State private var restSeconds: Int
    @State private var roundsTarget: Int
    @State private var stations: [String]
    @State private var newStationText: String = ""

    private var singleExerciseEMOMPresets: [String] {
        var options: [String] = []
        if gym.availableEquipment.contains(.rower) {
            options.append("16 Cal Row")
        }
        if gym.availableEquipment.contains(.assaultBike) {
            options.append("15 Cal Assault Bike")
        }
        if gym.availableEquipment.contains(.stationaryBike) {
            options.append("45s Stationary Bike Sprint")
        }
        if gym.availableEquipment.contains(.stairClimber) {
            options.append("45s Stair Climber Fast Climb")
        }
        if gym.availableEquipment.contains(.medicineBall) {
            options.append("18 Medicine Ball Slams")
            options.append("16 Wall Ball Shots")
        }
        if gym.availableEquipment.contains(.kettlebell) {
            options.append("20 Kettlebell Swings")
            options.append("16 Goblet Squats (KB)")
        }
        if gym.availableEquipment.contains(.dumbbell) {
            options.append("15 Dumbbell Thrusters")
            options.append("16 Alternating DB Snatches")
        }
        if gym.availableEquipment.contains(.plyoBox) {
            options.append("14 Box Jumps")
        }
        if gym.availableEquipment.contains(.sled) {
            options.append("40m Prowler Sled Push")
        }
        options.append(contentsOf: [
            "14 Burpees",
            "20 Push-Ups",
            "45s Hardstyle Plank Hold",
            "24 Jumping Lunges"
        ])
        return options
    }

    init(
        currentFinisher: ComputedFinisherPlan,
        gym: GymProfile,
        onSave: @escaping (PlannedFinisherOverride) -> Void,
        onResetToDefault: @escaping () -> Void
    ) {
        self.currentFinisher = currentFinisher
        self.gym = gym
        self.onSave = onSave
        self.onResetToDefault = onResetToDefault

        _title = State(initialValue: currentFinisher.title)
        _format = State(initialValue: currentFinisher.format)
        _durationMinutes = State(initialValue: currentFinisher.effectiveDurationMinutes)
        _workSeconds = State(initialValue: currentFinisher.workSeconds)
        _restSeconds = State(initialValue: currentFinisher.restSeconds)
        _roundsTarget = State(initialValue: currentFinisher.roundsTarget)
        _stations = State(initialValue: currentFinisher.movements.isEmpty ? ["16 Cal Row", "20 Kettlebell Swings"] : currentFinisher.movements)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Finisher Format & Timing") {
                    TextField("Finisher Title", text: $title)

                    Picker("Format", selection: $format) {
                        ForEach(FinisherFormat.allCases) { f in
                            Text(f.fullTitle).tag(f)
                        }
                    }
                    .onChange(of: format) { _, newFormat in
                        if newFormat == .emom {
                            stations = stations.enumerated().map { idx, st in
                                EquipmentSwapEngine.normalizeEMOMStation(st, stationIndex: idx)
                            }
                        }
                    }

                    if format == .tabata {
                        Stepper("Total Rounds: \(roundsTarget)", value: $roundsTarget, in: 4...20)
                        Stepper("Work Interval: \(workSeconds) sec", value: $workSeconds, in: 10...60, step: 5)
                        Stepper("Rest Interval: \(restSeconds) sec", value: $restSeconds, in: 5...60, step: 5)
                    } else {
                        Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 2...30, step: 1)
                    }

                    if format == .emom {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.circle.fill")
                                .foregroundStyle(.orange)
                            Text("EMOM Rule: 1 exercise per minute (~40–45s work, ~15–20s rest before next beep).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(format == .emom ? "EMOM Minute Stations (1 Exercise Per Minute)" : "Finisher Movements & Reps") {
                    ForEach(Array(stations.enumerated()), id: \.offset) { idx, station in
                        HStack {
                            if format == .emom {
                                Text("Min \(idx + 1)")
                                    .font(.caption2.weight(.heavy))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                            TextField("Movement & Reps", text: Binding(
                                get: { stations[idx] },
                                set: { stations[idx] = $0 }
                            ))
                            .font(.subheadline.weight(.medium))

                            if stations.count > 1 {
                                Button(role: .destructive) {
                                    stations.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField(
                            format == .emom ? "Add minute station (e.g. 15 Burpees)..." : "Add movement...",
                            text: $newStationText
                        )
                        .font(.subheadline)

                        Button {
                            let trimmed = newStationText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            stations.append(trimmed)
                            newStationText = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                        }
                        .disabled(newStationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("1-Tap Add Single-Exercise Stations for \(gym.name)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(singleExerciseEMOMPresets, id: \.self) { preset in
                                Button {
                                    if format == .emom {
                                        stations.append("Min \(stations.count + 1): \(preset)")
                                    } else {
                                        stations.append(preset)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text(preset)
                                    }
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.orange.opacity(0.16))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if currentFinisher.hasManualOverride {
                    Section {
                        Button(role: .destructive) {
                            onResetToDefault()
                            dismiss()
                        } label: {
                            Label("Reset Finisher to Program Default", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .navigationTitle("Edit Finisher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleaned = stations
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        let effectiveMins = format == .tabata
                            ? max(2, Int((Double(roundsTarget * (workSeconds + restSeconds)) / 60.0).rounded()))
                            : durationMinutes
                        onSave(
                            PlannedFinisherOverride(
                                title: title.isEmpty ? "\(format.rawValue) Finisher" : title,
                                format: format,
                                durationMinutes: effectiveMins,
                                workSeconds: workSeconds,
                                restSeconds: restSeconds,
                                roundsTarget: roundsTarget,
                                movements: cleaned.isEmpty ? ["16 Cal Row"] : cleaned
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

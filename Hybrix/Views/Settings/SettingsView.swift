import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gyms: [GymProfile]
    @Query private var exercises: [Exercise]
    @Query private var logs: [WorkoutLog]
    @Query private var mesocycles: [Mesocycle]

    @State private var settings = UserSettings.shared
    @State private var exportedJSON: String = ""
    @State private var showingExportSheet: Bool = false

    // Hidden 10-tap Developer Window trigger on "Private iCloud Sync"
    @State private var iCloudSyncTapCount: Int = 0
    @State private var showingDeveloperSheet: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance & Theme") {
                    Picker("App Theme", selection: $settings.appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle(isOn: $settings.alwaysIncludeCore) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(.mint)
                                Text("Always Include Core in Lift Sessions")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Text("Guarantees an equipment-compatible core movement in every workout session—and protects it from being trimmed when workout time is shortened.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.mint)

                    Toggle(isOn: $settings.includeTargetedWarmup) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include Targeted Day Warmup (3–7 min)")
                                .font(.subheadline.weight(.semibold))
                            Text("Generates mobility & ramp-up drills targeted at today's movement patterns.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.yellow)

                    if settings.includeTargetedWarmup {
                        Stepper(
                            "Warmup Duration: \(settings.defaultWarmupMinutes) min",
                            value: $settings.defaultWarmupMinutes,
                            in: 3...7
                        )
                    }

                    Stepper(
                        "Default Workout Time: \(settings.defaultWorkoutDurationMinutes) min",
                        value: $settings.defaultWorkoutDurationMinutes,
                        in: 25...120,
                        step: 5
                    )

                    Toggle("Include Cardio Finisher by Default", isOn: $settings.includeFinisherByDefault)
                        .tint(.orange)
                } header: {
                    Text("Session Programming & Time Budget")
                }

                Section("Units, Bodyweight & Calorie Calculation") {
                    Picker("Weight Unit", selection: $settings.weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.rawValue.uppercased()).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Weight Rounding Increment", selection: $settings.smallestWeightIncrement) {
                        Text("2.5 \(settings.weightUnit.rawValue)").tag(2.5)
                        Text("5.0 \(settings.weightUnit.rawValue)").tag(5.0)
                    }

                    Stepper(
                        "Your Bodyweight: \(Int(settings.userBodyweightLbs)) lbs",
                        value: $settings.userBodyweightLbs,
                        in: 90...380,
                        step: 5
                    )
                }

                Section("Timers, Audio & Haptics") {
                    Toggle("Auto-Start Rest Timer on Set Completion", isOn: $settings.autoStartRestTimer)
                    Stepper("Compound Rest: \(settings.defaultCompoundRestSeconds)s", value: $settings.defaultCompoundRestSeconds, in: 45...240, step: 15)
                    Stepper("Isolation Rest: \(settings.defaultIsolationRestSeconds)s", value: $settings.defaultIsolationRestSeconds, in: 30...180, step: 15)
                    Toggle("Timer Countdown Beeps", isOn: $settings.timerSoundEnabled)
                    Toggle("Haptic Feedback", isOn: $settings.timerHapticsEnabled)
                }

                Section {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private iCloud Sync (SwiftData + CloudKit)")
                                .font(.subheadline.weight(.semibold))
                            Text("Zero sign-in required. Syncs automatically across your personal Apple ID devices.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Active")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        iCloudSyncTapCount += 1
                        if iCloudSyncTapCount >= 10 {
                            iCloudSyncTapCount = 0
                            WorkoutTimerManager.shared.triggerHaptic(.medium)
                            showingDeveloperSheet = true
                        }
                    }

                    Button {
                        generateBackupJSON()
                        showingExportSheet = true
                    } label: {
                        Label("Export Local History & Gyms Backup (JSON)", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Local Storage & Multi-Device Sync")
                } footer: {
                    Text("Database stats: \(gyms.count) gym profiles · \(exercises.count) lifts · \(logs.count) logged workouts.")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingDeveloperSheet) {
                DeveloperToolsSheet(
                    gyms: gyms,
                    exercises: exercises,
                    logs: logs,
                    mesocycles: mesocycles
                )
            }
            .sheet(isPresented: $showingExportSheet) {
                NavigationStack {
                    ScrollView {
                        Text(exportedJSON)
                            .font(.system(.caption2, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle("JSON Backup Snapshot")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            ShareLink(item: exportedJSON) {
                                Label("Share / Save File", systemImage: "square.and.arrow.up")
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingExportSheet = false }
                        }
                    }
                }
            }
        }
    }

    private func generateBackupJSON() {
        struct BackupPayload: Codable {
            let exportedAt: Date
            let gymsCount: Int
            let gymNames: [String]
            let customExercises: [String]
            let workoutsCompleted: Int
            let totalVolumeLbs: Double
            let totalCaloriesBurned: Int
        }

        let payload = BackupPayload(
            exportedAt: Date(),
            gymsCount: gyms.count,
            gymNames: gyms.map(\.name),
            customExercises: exercises.filter(\.isCustom).map(\.name),
            workoutsCompleted: logs.count,
            totalVolumeLbs: logs.reduce(0) { $0 + $1.totalVolumeLbs },
            totalCaloriesBurned: logs.reduce(0) { $0 + $1.estimatedCaloriesBurned }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload),
           let str = String(data: data, encoding: .utf8) {
            exportedJSON = str
        } else {
            exportedJSON = "{}"
        }
    }
}

// MARK: - Hidden 10-Tap Developer & Testing Window

struct DeveloperToolsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let gyms: [GymProfile]
    let exercises: [Exercise]
    let logs: [WorkoutLog]
    let mesocycles: [Mesocycle]

    @State private var settings = UserSettings.shared
    @State private var showingClearHistoryAlert: Bool = false
    @State private var statusBanner: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                if let banner = statusBanner {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(banner)
                                .font(.caption.weight(.semibold))
                        }
                    }
                }

                Section {
                    Button {
                        SeedDataService.seedSampleWorkoutLogs(context: modelContext, count: 10)
                        statusBanner = "Added 10 sample workouts to History."
                    } label: {
                        Label("Add 10 Test Workouts to History", systemImage: "sparkles.rectangle.stack")
                    }

                    Button(role: .destructive) {
                        showingClearHistoryAlert = true
                    } label: {
                        Label("Clear All Workout Logs (\(logs.count))", systemImage: "trash")
                    }
                    .disabled(logs.isEmpty)
                } header: {
                    Text("Testing & Sample History Data")
                } footer: {
                    Text("Seeds 10 realistic workouts across the past 14 days to test charts, 7-day rolling muscle volume, and PR detection.")
                }

                Section("Startup & Program State") {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            settings.hasCompletedOnboarding = false
                        }
                    } label: {
                        Label("Launch First-Time Startup Setup Wizard", systemImage: "wand.and.stars")
                    }

                    Button {
                        for meso in mesocycles where meso.isActive {
                            meso.startDate = Date()
                            meso.currentWeek = 1
                            meso.currentDayIndex = 0
                        }
                        try? modelContext.save()
                        statusBanner = "Reset active program to Week 1, Day 1 (Today)."
                    } label: {
                        Label("Reset Active Program to Week 1, Day 1", systemImage: "arrow.counterclockwise.circle")
                    }
                }

                Section("Lock Screen Live Activity Card Preview") {
                    HybrixLockScreenLiveCardView(
                        state: ActiveWorkoutSessionManager.shared.hasActiveSession
                            ? ActiveWorkoutSessionManager.shared.currentLiveActivityState
                            : HybrixWorkoutActivityAttributes.ContentState(
                                workoutTitle: "Upper A · Horizontal Strength",
                                gymName: gyms.first?.name ?? "Commercial Gym",
                                currentExerciseName: "Barbell Bench Press",
                                currentSetBadge: "Set 2",
                                isWarmupSet: false,
                                prescriptionText: "195 lbs × 8 reps · Target 2 RIR",
                                targetRIR: 2,
                                completedSetsCount: 3,
                                totalSetsCount: 15,
                                isResting: false,
                                restRemainingSeconds: 0,
                                restEndDate: nil,
                                allSetsCompleted: false
                            ),
                        onCompleteSet: {
                            if ActiveWorkoutSessionManager.shared.hasActiveSession {
                                ActiveWorkoutSessionManager.shared.completeNextPendingSetFromLiveActivity()
                            }
                            statusBanner = "Triggered CompleteCurrentSetIntent action."
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

                Section("Database Diagnostics") {
                    LabeledContent("Gym Profiles", value: "\(gyms.count)")
                    LabeledContent("Total Exercises", value: "\(exercises.count)")
                    LabeledContent("Custom Exercises", value: "\(exercises.filter(\.isCustom).count)")
                    LabeledContent("Mesocycle Programs", value: "\(mesocycles.count)")
                    LabeledContent("Logged Workouts", value: "\(logs.count)")
                }
            }
            .navigationTitle("Developer Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .alert("Clear Workout History?", isPresented: $showingClearHistoryAlert) {
                Button("Delete All (\(logs.count))", role: .destructive) {
                    for log in logs {
                        modelContext.delete(log)
                    }
                    try? modelContext.save()
                    statusBanner = "Cleared all workout logs."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all logged workouts from history.")
            }
        }
    }
}

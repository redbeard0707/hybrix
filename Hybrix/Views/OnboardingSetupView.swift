import SwiftUI
import SwiftData

struct OnboardingSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymProfile.name) private var gyms: [GymProfile]
    @Query(sort: \Mesocycle.name) private var mesocycles: [Mesocycle]

    @State private var settings = UserSettings.shared
    @State private var currentStep: Int = 0

    // Step 2: Gym Selection / Creation
    @State private var useCustomGym: Bool = false
    @State private var selectedGymId: String = ""
    @State private var customGymName: String = "My Primary Gym"
    @State private var customGymPreset: GymPresetTemplate = .fullCommercial
    @State private var customGymMaxDB: Double = 100
    @State private var customBarbellWeight: Double = 45

    // Step 3: Active Program Selection
    @State private var selectedMesocycleId: UUID? = nil

    var onFinish: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Progress Indicator
                headerProgressView

                TabView(selection: $currentStep) {
                    step1ProfileView
                        .tag(0)

                    step2GymSetupView
                        .tag(1)

                    step3ProgramSetupView
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentStep)

                // Bottom Navigation Footer
                footerNavigationBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                SeedDataService.seedIfNeeded(context: modelContext)
                if selectedGymId.isEmpty {
                    selectedGymId = settings.activeGymProfileId ?? gyms.first(where: \.isDefault)?.id.uuidString ?? gyms.first?.id.uuidString ?? ""
                }
                if selectedMesocycleId == nil {
                    selectedMesocycleId = mesocycles.first(where: \.isActive)?.id ?? mesocycles.first?.id
                }
            }
        }
    }

    // MARK: - Header

    private var headerProgressView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    Text("HYBRIX SETUP")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text("Step \(currentStep + 1) of 3")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { idx in
                    Capsule()
                        .fill(idx <= currentStep ? Color.orange : Color(.tertiarySystemFill))
                        .frame(height: 5)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Step 1: Athlete Profile & Session Defaults

    private var step1ProfileView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to Hybrix")
                        .font(.title2.weight(.black))
                    Text("Configure your baseline metrics and workout time budget so Hybrix can calibrate weights, calorie expenditure, and session pacing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Units & Load Rounding") {
                Picker("Weight Unit", selection: $settings.weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.rawValue.uppercased()).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Smallest Weight Jump", selection: $settings.smallestWeightIncrement) {
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

            Section("Session Time Budget & Structure") {
                Stepper(
                    "Default Workout Budget: \(settings.defaultWorkoutDurationMinutes) min",
                    value: $settings.defaultWorkoutDurationMinutes,
                    in: 25...120,
                    step: 5
                )

                Toggle("Always Include Core Movement", isOn: $settings.alwaysIncludeCore)
                    .tint(.mint)

                Toggle("Include Targeted Day Warmup (3–7 min)", isOn: $settings.includeTargetedWarmup)
                    .tint(.yellow)

                Toggle("Include Conditioning Finisher", isOn: $settings.includeFinisherByDefault)
                    .tint(.orange)
            }
        }
    }

    // MARK: - Step 2: Primary Gym Setup

    private var step2GymSetupView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Primary Gym")
                        .font(.title2.weight(.black))
                    Text("Hybrix automatically swaps incompatible exercises and calculates exact plate loadings based on your active gym's equipment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Setup Mode") {
                Picker("Gym Setup", selection: $useCustomGym) {
                    Text("Choose Built-In Gym").tag(false)
                    Text("Create Custom Gym").tag(true)
                }
                .pickerStyle(.segmented)
            }

            if !useCustomGym {
                Section("Select Starting Gym Profile") {
                    ForEach(gyms) { gym in
                        let isSelected = selectedGymId == gym.id.uuidString
                        Button {
                            selectedGymId = gym.id.uuidString
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: gym.iconName)
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(gym.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Text("\(gym.availableEquipment.count) equipment types · DBs up to \(Int(gym.availableDumbbellMaxWeight ?? 100)) lbs")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.orange)
                                } else {
                                    Image(systemName: "circle")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Section("Custom Gym Details") {
                    TextField("Gym Name (e.g. Crosby Wellness Center)", text: $customGymName)

                    Picker("Equipment Template", selection: $customGymPreset) {
                        ForEach(GymPresetTemplate.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }

                    Stepper(
                        "Max Dumbbell: \(Int(customGymMaxDB)) lbs",
                        value: $customGymMaxDB,
                        in: 20...150,
                        step: 5
                    )

                    Picker("Standard Barbell Weight", selection: $customBarbellWeight) {
                        Text("45 lbs (Standard)").tag(45.0)
                        Text("35 lbs (Women's / Lighter)").tag(35.0)
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Active Program Selection

    private var step3ProgramSetupView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Select Starting Program")
                        .font(.title2.weight(.black))
                    Text("Pick your initial periodized mesocycle. You'll begin at Week 1, Day 1 with autoregulated RIR progression.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Available Periodized Blocks") {
                ForEach(mesocycles) { meso in
                    let isSelected = selectedMesocycleId == meso.id
                    Button {
                        selectedMesocycleId = meso.id
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(meso.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.orange)
                                } else {
                                    Image(systemName: "circle")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 8) {
                                Text(meso.splitType.rawValue)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.18))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())

                                Text("\(meso.totalWeeks) Weeks · \(meso.sortedDays.count) Days/Cycle")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            if !meso.notes.isEmpty {
                                Text(meso.notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Footer Navigation

    private var footerNavigationBar: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            Button {
                if currentStep < 2 {
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                HStack {
                    Text(currentStep < 2 ? "Continue" : "Launch Hybrix")
                    Image(systemName: currentStep < 2 ? "chevron.right" : "bolt.fill")
                }
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func completeOnboarding() {
        // 1. Apply Gym selection or custom gym
        if useCustomGym {
            let trimmedName = customGymName.trimmingCharacters(in: .whitespacesAndNewlines)
            let newGym = GymProfile(
                name: trimmedName.isEmpty ? "My Primary Gym" : trimmedName,
                iconName: "dumbbell.fill",
                locationNote: customGymPreset.rawValue,
                isDefault: true,
                isCustom: true,
                availableEquipment: customGymPreset.equipmentSet,
                availableDumbbellMaxWeight: customGymMaxDB,
                barbellWeightLbs: customBarbellWeight
            )
            for g in gyms { g.isDefault = false }
            modelContext.insert(newGym)
            settings.activeGymProfileId = newGym.id.uuidString
        } else if !selectedGymId.isEmpty {
            for g in gyms {
                g.isDefault = (g.id.uuidString == selectedGymId)
            }
            settings.activeGymProfileId = selectedGymId
        }

        // 2. Apply Active Mesocycle starting fresh at Week 1, Day 1
        if let chosenId = selectedMesocycleId {
            for m in mesocycles {
                if m.id == chosenId {
                    m.isActive = true
                    m.startDate = Date()
                    m.currentWeek = 1
                    m.currentDayIndex = 0
                } else {
                    m.isActive = false
                }
            }
        }

        try? modelContext.save()
        settings.hasCompletedOnboarding = true
        onFinish()
    }
}

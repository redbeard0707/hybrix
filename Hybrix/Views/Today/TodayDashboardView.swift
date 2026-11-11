import SwiftUI
import SwiftData

struct TodayDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymProfile.name) private var gyms: [GymProfile]
    @Query(sort: \Mesocycle.startDate, order: .reverse) private var mesocycles: [Mesocycle]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var workoutLogs: [WorkoutLog]

    @State private var settings = UserSettings.shared
    @State private var selectedDurationMinutes: Int = UserSettings.shared.defaultWorkoutDurationMinutes
    @State private var includeWarmupToday: Bool = UserSettings.shared.includeTargetedWarmup
    @State private var warmupMinutesToday: Int = UserSettings.shared.defaultWarmupMinutes
    @State private var includeFinisherToday: Bool = UserSettings.shared.includeFinisherByDefault
    @State private var manualOverrides: [UUID: Exercise] = [:]
    @State private var prescriptionOverrides: [UUID: PlannedExercisePrescriptionOverride] = [:]
    @State private var finisherOverride: PlannedFinisherOverride? = nil
    @State private var restoredSlotIDs: Set<UUID> = []
    @State private var supersetGroups: [UUID: UUID] = [:]
    @State private var customSlotOrder: [UUID] = []

    // Sheets / Popups
    @State private var editingSlotItem: ComputedPlannedExerciseItem? = nil
    @State private var editingFinisherPlan: ComputedFinisherPlan? = nil
    @State private var activeSwapSlotItem: ComputedPlannedExerciseItem? = nil
    @State private var showingSupersetAndOrderSheet: Bool = false
    @State private var showingNewCustomGymSheet: Bool = false
    @State private var showingCustomWorkoutBuilder: Bool = false
    @State private var showingStandaloneFinisher: Bool = false
    @State private var pendingSwapPreferencePrompt: PendingGymSwapPrompt? = nil
    @State private var showingSaveSwapAlert: Bool = false

    private let durationPresets = [30, 45, 60, 75, 90]

    private var activeMesocycle: Mesocycle? {
        mesocycles.first(where: \.isActive) ?? mesocycles.first
    }

    private var activeGym: GymProfile? {
        if let savedId = settings.activeGymProfileId,
           let match = gyms.first(where: { $0.id.uuidString == savedId }) {
            return match
        }
        return gyms.first(where: \.isDefault) ?? gyms.first
    }

    private var recalculatedPlan: RecalculatedWorkoutPlan? {
        guard let meso = activeMesocycle,
              let day = meso.activeDayTemplate,
              let gym = activeGym else {
            return nil
        }
        return TimeBudgetEngine.buildWorkoutPlan(
            dayTemplate: day,
            mesocycle: meso,
            gym: gym,
            targetDurationMinutes: selectedDurationMinutes,
            includeWarmup: includeWarmupToday,
            warmupDurationMinutes: warmupMinutesToday,
            includeFinisher: includeFinisherToday,
            alwaysIncludeCore: settings.alwaysIncludeCore,
            allExercises: allExercises,
            history: workoutLogs,
            manualOverrides: manualOverrides,
            prescriptionOverrides: prescriptionOverrides,
            finisherOverride: finisherOverride,
            restoredSlotIDs: restoredSlotIDs,
            supersetGroups: supersetGroups,
            customSlotOrder: customSlotOrder
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. Gym & Time Budget Control Bar
                    gymAndDurationBar

                    // 2. Active Mesocycle & Week Periodization Banner
                    if let meso = activeMesocycle {
                        mesocycleBanner(meso)
                    }

                    // 3. Time Breakdown, Targeted Warmup, Lifts, Trimmed, Finisher & Start
                    if let plan = recalculatedPlan {
                        timeBudgetSummaryCard(plan)
                        targetedWarmupSection(plan.warmupPlan)
                        plannedExercisesSection(plan)
                        if !plan.trimmedExercises.isEmpty {
                            trimmedExercisesSection(plan)
                        }
                        if let finisher = plan.finisher {
                            finisherCard(finisher, plan: plan)
                        }
                        startWorkoutButton(plan)
                    }

                    // 4. Custom Ad-Hoc Workout & Standalone Finisher Actions
                    secondaryActionsRow
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if selectedDurationMinutes <= 0 {
                    selectedDurationMinutes = settings.defaultWorkoutDurationMinutes
                }
            }
            .sheet(item: $editingSlotItem) { slotItem in
                if let gym = activeGym {
                    PlannedExerciseEditorSheet(
                        slotItem: slotItem,
                        gym: gym,
                        allExercises: allExercises,
                        weightUnit: settings.weightUnit,
                        onSaveOverride: { overrideVal in
                            prescriptionOverrides[slotItem.id] = overrideVal
                        },
                        onResetToDefault: {
                            prescriptionOverrides.removeValue(forKey: slotItem.id)
                            manualOverrides.removeValue(forKey: slotItem.id)
                        }
                    )
                }
            }
            .sheet(item: $editingFinisherPlan) { finPlan in
                if let gym = activeGym {
                    PlannedFinisherEditorSheet(
                        currentFinisher: finPlan,
                        gym: gym,
                        onSave: { newFinOverride in
                            finisherOverride = newFinOverride
                        },
                        onResetToDefault: {
                            finisherOverride = nil
                        }
                    )
                }
            }
            .sheet(item: $activeSwapSlotItem) { slotItem in
                if let gym = activeGym {
                    ExerciseSwapPickerSheet(
                        slotItem: slotItem,
                        gym: gym,
                        allExercises: allExercises
                    ) { chosenExercise in
                        manualOverrides[slotItem.id] = chosenExercise
                        if var existing = prescriptionOverrides[slotItem.id] {
                            existing.customExercise = chosenExercise
                            existing.targetStartingWeight = chosenExercise.baselineWorkingWeightLbs
                            prescriptionOverrides[slotItem.id] = existing
                        }
                        if chosenExercise.id != slotItem.resolution.originalExercise.id {
                            pendingSwapPreferencePrompt = PendingGymSwapPrompt(
                                slotID: slotItem.id,
                                originalExercise: slotItem.resolution.originalExercise,
                                chosenExercise: chosenExercise,
                                gym: gym
                            )
                            showingSaveSwapAlert = true
                        } else if gym.preferredReplacementID(for: chosenExercise.id) != nil {
                            // Switching back to the programmed lift clears the saved preference so it isn't silently re-applied
                            gym.setPreferredReplacement(nil, for: chosenExercise.id)
                            try? modelContext.save()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSupersetAndOrderSheet) {
                if let plan = recalculatedPlan {
                    SupersetAndOrderSheet(
                        initialExercises: plan.activeExercises + plan.trimmedExercises,
                        currentSupersetGroups: supersetGroups,
                        currentCustomOrder: customSlotOrder
                    ) { newGroups, newOrder in
                        supersetGroups = newGroups
                        customSlotOrder = newOrder
                    }
                }
            }
            .sheet(isPresented: $showingNewCustomGymSheet) {
                GymEditorView(gymToEdit: nil) { createdGym in
                    settings.activeGymProfileId = createdGym.id.uuidString
                    manualOverrides.removeAll()
                }
            }
            .sheet(isPresented: $showingCustomWorkoutBuilder) {
                if let gym = activeGym {
                    CustomWorkoutBuilderSheet(
                        initialGym: gym,
                        initialDurationMinutes: selectedDurationMinutes
                    ) { customPlan in
                        ActiveWorkoutSessionManager.shared.startNewWorkout(plan: customPlan, mesocycle: nil)
                    }
                }
            }
            .sheet(isPresented: $showingStandaloneFinisher) {
                FinisherTimerView(
                    initialPlan: recalculatedPlan?.finisher ?? ComputedFinisherPlan(
                        title: "Conditioning EMOM 10",
                        format: .emom,
                        programmedDurationMinutes: 10,
                        effectiveDurationMinutes: 10,
                        workSeconds: 20,
                        restSeconds: 10,
                        roundsTarget: 8,
                        movements: ["Min 1 (Odd): 20 Kettlebell Swings", "Min 2 (Even): 15 Burpees"],
                        repSchemes: ["20 reps (~40s)", "15 reps (~40s)"],
                        wasEquipmentAdjusted: false,
                        wasDurationScaledForTimeBudget: false
                    ),
                    onComplete: nil
                )
            }
            .alert(
                "Save Swap Preference for \(pendingSwapPreferencePrompt?.gym.name ?? "Gym")?",
                isPresented: $showingSaveSwapAlert,
                presenting: pendingSwapPreferencePrompt
            ) { prompt in
                Button("Always Use at \(prompt.gym.name)") {
                    prompt.gym.setPreferredReplacement(prompt.chosenExercise.id, for: prompt.originalExercise.id)
                    try? modelContext.save()
                }
                Button("Just for Today", role: .cancel) {}
            } message: { prompt in
                Text("Would you like to always replace \"\(prompt.originalExercise.name)\" with \"\(prompt.chosenExercise.name)\" whenever you train at \(prompt.gym.name), or keep this as a one-time swap for today?")
            }
        }
    }

    // MARK: - Subviews

    private var gymAndDurationBar: some View {
        HStack(spacing: 8) {
            // Compact Gym Switcher Menu Pill
            Menu {
                Section("Switch Gym for This Workout") {
                    ForEach(gyms) { gym in
                        Button {
                            settings.activeGymProfileId = gym.id.uuidString
                            manualOverrides.removeAll()
                        } label: {
                            Label(
                                "\(gym.name) (\(gym.availableEquipment.count) items)",
                                systemImage: gym.id == activeGym?.id ? "checkmark.circle.fill" : gym.iconName
                            )
                        }
                    }
                }
                Divider()
                Button {
                    showingNewCustomGymSheet = true
                } label: {
                    Label("New Custom Gym Profile...", systemImage: "plus.circle")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: activeGym?.iconName ?? "dumbbell.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ACTIVE GYM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(activeGym?.name ?? "Select Gym")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Target Duration Menu Pill
            Menu {
                Section("Target Workout Duration (Incl. Warmup & Finisher)") {
                    ForEach(durationPresets, id: \.self) { mins in
                        Button {
                            withAnimation {
                                selectedDurationMinutes = mins
                                restoredSlotIDs.removeAll()
                            }
                        } label: {
                            HStack {
                                Text("\(mins) Minutes")
                                if selectedDurationMinutes == mins {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Divider()
                Button("Short 25 Min Express") {
                    withAnimation {
                        selectedDurationMinutes = 25
                        restoredSlotIDs.removeAll()
                    }
                }
                Button("Extended 105 Min Session") {
                    withAnimation {
                        selectedDurationMinutes = 105
                        restoredSlotIDs.removeAll()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TIME BUDGET")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("\(selectedDurationMinutes) min")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Custom Workout "+" Button on Same Row
            Button {
                showingCustomWorkoutBuilder = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 44)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func mesocycleBanner(_ meso: Mesocycle) -> some View {
        let weekProf = PeriodizationEngine.weekProfile(for: meso)
        let days = meso.sortedDays

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(meso.splitType.rawValue.uppercased())
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())

                        if weekProf.isDeload {
                            Text("DELOAD WEEK")
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.mint.opacity(0.2))
                                .foregroundStyle(.mint)
                                .clipShape(Capsule())
                        } else {
                            Text("\(weekProf.targetRIR) RIR TARGET")
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.18))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(meso.name)
                        .font(.headline)

                    Text("Week \(meso.currentWeek) of \(meso.totalWeeks) · \(weekProf.phaseTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Section("Jump to Week in Block") {
                        ForEach(1...meso.totalWeeks, id: \.self) { wk in
                            let wp = PeriodizationEngine.weekProfile(for: meso, week: wk)
                            Button {
                                meso.currentWeek = wk
                            } label: {
                                Label(
                                    "Week \(wk): \(wp.phaseTitle) (\(wp.targetRIR) RIR)",
                                    systemImage: meso.currentWeek == wk ? "checkmark.circle.fill" : "calendar"
                                )
                            }
                        }
                    }
                } label: {
                    Text("Wk \(meso.currentWeek)/\(meso.totalWeeks)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                        let isSelected = idx == meso.currentDayIndex
                        Button {
                            withAnimation(.snappy) {
                                meso.currentDayIndex = idx
                                manualOverrides.removeAll()
                                prescriptionOverrides.removeAll()
                                finisherOverride = nil
                                restoredSlotIDs.removeAll()
                            }
                        } label: {
                            Text(day.name)
                                .font(.caption.weight(isSelected ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isSelected ? Color.orange : Color(.tertiarySystemGroupedBackground))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func timeBudgetSummaryCard(_ plan: RecalculatedWorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    "\(plan.activeExercises.count) Lifts · Est. \(plan.totalEstimatedMinutes)m · ~\(plan.estimatedCaloriesBurned) kcal",
                    systemImage: "flame.fill"
                )
                .font(.subheadline.weight(.semibold))

                Spacer()

                if settings.alwaysIncludeCore {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption2)
                        Text("Core Locked")
                            .font(.caption2.weight(.bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.mint.opacity(0.18))
                    .foregroundStyle(.mint)
                    .clipShape(Capsule())
                }
            }

            // Proportional visual time bar
            GeometryReader { geo in
                let total = max(1.0, Double(plan.totalEstimatedMinutes))
                let warmupRatio = CGFloat(Double(plan.warmupMinutesTotal) / total)
                let liftRatio = CGFloat(Double(plan.liftingMinutesTotal) / total)
                let coreRatio = CGFloat(Double(plan.coreMinutesTotal) / total)
                let finRatio = CGFloat(Double(plan.finisherMinutesTotal) / total)

                HStack(spacing: 3) {
                    if plan.warmupMinutesTotal > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.yellow)
                            .frame(width: max(14, geo.size.width * warmupRatio))
                    }
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: max(20, geo.size.width * liftRatio))
                    if plan.coreMinutesTotal > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.mint)
                            .frame(width: max(14, geo.size.width * coreRatio))
                    }
                    if plan.finisherMinutesTotal > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.pink)
                            .frame(width: max(14, geo.size.width * finRatio))
                    }
                }
            }
            .frame(height: 8)

            HStack(spacing: 12) {
                if plan.warmupMinutesTotal > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(Color.yellow).frame(width: 7, height: 7)
                        Text("Warmup: \(plan.warmupMinutesTotal)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 7, height: 7)
                    Text("Lifts: \(plan.liftingMinutesTotal)m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if plan.coreMinutesTotal > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(Color.mint).frame(width: 7, height: 7)
                        Text("Core: \(plan.coreMinutesTotal)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if plan.finisher != nil {
                    HStack(spacing: 4) {
                        Circle().fill(Color.pink).frame(width: 7, height: 7)
                        Text("Finisher: \(includeFinisherToday ? "\(plan.finisherMinutesTotal)m" : "Off")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if plan.swappedExercisesCount > 0 {
                    Text("🔄 \(plan.swappedExercisesCount) swapped")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func targetedWarmupSection(_ warmup: ComputedWarmupPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("TARGETED DAY WARMUP (3–7 MIN)", systemImage: "figure.cooldown")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)

                Spacer()

                if includeWarmupToday {
                    Menu {
                        ForEach(3...7, id: \.self) { m in
                            Button("\(m) Minutes") {
                                warmupMinutesToday = m
                                settings.defaultWarmupMinutes = m
                            }
                        }
                    } label: {
                        Text("\(warmupMinutesToday) min ▾")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.18))
                            .foregroundStyle(.yellow)
                            .clipShape(Capsule())
                    }
                }

                Toggle("Enable Warmup", isOn: $includeWarmupToday)
                    .labelsHidden()
                    .tint(.yellow)
                    .onChange(of: includeWarmupToday) { _, val in
                        settings.includeTargetedWarmup = val
                    }
            }

            if includeWarmupToday {
                Text("Priming: \(warmup.focusSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(warmup.drills) { drill in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "flame.circle.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(drill.name)
                                    .font(.caption.weight(.semibold))
                                Text("\(drill.prescription) · \(drill.targetFocus)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Warmup disabled for today — full time budget allocated to working sets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func plannedExercisesSection(_ plan: RecalculatedWorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S LIFTING LINEUP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingSupersetAndOrderSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link.circle.fill")
                        Text(plan.supersetPairsCount > 0 ? "Supersets (\(plan.supersetPairsCount)) & Order" : "Supersets & Order")
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.18))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(plan.activeExercises.enumerated()), id: \.element.id) { index, item in
                let ex = item.resolution.activeExercise
                Button {
                    editingSlotItem = item
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .frame(width: 24, height: 24)
                                .background(item.isProtectedCore ? Color.mint.opacity(0.2) : Color.orange.opacity(0.18))
                                .foregroundStyle(item.isProtectedCore ? .mint : .orange)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    if let ssBadge = item.supersetBadge {
                                        Text(ssBadge)
                                            .font(.caption2.weight(.heavy))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.purple.opacity(0.2))
                                            .foregroundStyle(.purple)
                                            .clipShape(Capsule())
                                    }

                                    Text(ex.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)

                                    if item.hasManualPrescriptionOverride {
                                        Text("Edited")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    } else if item.wasAutoInjectedCore {
                                        Text("Auto-Core")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.mint.opacity(0.2))
                                            .foregroundStyle(.mint)
                                            .clipShape(Capsule())
                                    } else {
                                        Text(item.tierPriority.shortBadge)
                                            .font(.caption2.weight(.medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.tertiarySystemGroupedBackground))
                                            .foregroundStyle(.secondary)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text("\(ex.primaryMuscle.rawValue) · \(ex.equipmentSummary)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if item.resolution.wasSwapped {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Swapped from \(item.resolution.originalExercise.name) · \(item.resolution.swapReason ?? "Tap to change")")
                                    }
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.top, 2)
                                }
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                Button {
                                    activeSwapSlotItem = item
                                } label: {
                                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        HStack {
                            Label("\(item.workingSets) sets × \(item.repRangeMin)–\(item.repRangeMax) reps", systemImage: "repeat")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("· \(item.restSeconds)s rest")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if item.recommendedWeight > 0 {
                                Text("\(Int(item.recommendedWeight)) \(settings.weightUnit.rawValue)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.orange)
                            } else {
                                Text("Bodyweight")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            Text("· ~\(Int(item.estimatedMinutes.rounded()))m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func trimmedExercisesSection(_ plan: RecalculatedWorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "scissors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("TRIMMED TO FIT \(plan.targetDurationMinutes)-MIN TIME BUDGET")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingSupersetAndOrderSheet = true
                } label: {
                    Label("Superset Setup", systemImage: "link.badge.plus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.purple)
                }
            }

            ForEach(plan.trimmedExercises) { trimmed in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trimmed.resolution.activeExercise.name)
                            .font(.caption.weight(.semibold))
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Text("\(trimmed.workingSets) sets · ~\(Int(trimmed.estimatedMinutes.rounded())) min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        _ = withAnimation {
                            restoredSlotIDs.insert(trimmed.id)
                        }
                    } label: {
                        Label("Keep Anyway", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func finisherCard(_ finisher: ComputedFinisherPlan, plan: RecalculatedWorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("CONDITIONING FINISHER", systemImage: finisher.format.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(finisher.format.badgeColor)

                Spacer()

                if includeFinisherToday {
                    Button {
                        editingFinisherPlan = finisher
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Edit")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                    }
                    .padding(.trailing, 4)
                }

                Toggle("Include", isOn: $includeFinisherToday)
                    .labelsHidden()
                    .tint(.orange)
            }

            if includeFinisherToday {
                Button {
                    editingFinisherPlan = finisher
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(finisher.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Text("\(finisher.effectiveDurationMinutes) MIN \(finisher.format.rawValue)")
                                        .font(.caption2.weight(.heavy))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(finisher.format.badgeColor.opacity(0.2))
                                        .foregroundStyle(finisher.format.badgeColor)
                                        .clipShape(Capsule())
                                    if finisher.hasManualOverride {
                                        Text("Edited")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text("Tap card to customize format, duration, or minute stations")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                if finisher.wasDurationScaledForTimeBudget {
                                    Text("⏱️ Scaled from \(finisher.programmedDurationMinutes)m → \(finisher.effectiveDurationMinutes)m to fit \(plan.targetDurationMinutes)m total workout time")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Button {
                                showingStandaloneFinisher = true
                            } label: {
                                Label("Timer", systemImage: "play.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(finisher.format.badgeColor.opacity(0.18))
                                    .foregroundStyle(finisher.format.badgeColor)
                                    .clipShape(Capsule())
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(finisher.movements, id: \.self) { move in
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                        .font(.caption2)
                                        .foregroundStyle(finisher.format.badgeColor)
                                    Text(move)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("Finisher skipped for today — extra time reallocated to lifting sets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func startWorkoutButton(_ plan: RecalculatedWorkoutPlan) -> some View {
        Button {
            ActiveWorkoutSessionManager.shared.startNewWorkout(
                plan: plan,
                mesocycle: activeMesocycle
            )
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Start \(plan.dayTemplateName) (\(plan.totalEstimatedMinutes)m · ~\(plan.estimatedCaloriesBurned) kcal)")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
        }
    }

    private var secondaryActionsRow: some View {
        HStack(spacing: 12) {
            Button {
                showingCustomWorkoutBuilder = true
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Build Custom Today")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showingStandaloneFinisher = true
            } label: {
                HStack {
                    Image(systemName: "timer")
                    Text("EMOM / AMRAP Timer")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

extension RecalculatedWorkoutPlan: Identifiable {
    var id: String {
        "\(dayTemplateName)-\(gym.id.uuidString)-\(targetDurationMinutes)"
    }
}

struct PendingGymSwapPrompt {
    let slotID: UUID
    let originalExercise: Exercise
    let chosenExercise: Exercise
    let gym: GymProfile
}

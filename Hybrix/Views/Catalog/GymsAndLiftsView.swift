import SwiftUI
import SwiftData

struct GymsAndLiftsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymProfile.name) private var gyms: [GymProfile]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var selectedSection: Int = 0 // 0 = My Gyms, 1 = Lift Database
    @State private var gymToEdit: GymProfile? = nil
    @State private var exerciseToEdit: Exercise? = nil
    @State private var showingNewGymSheet: Bool = false
    @State private var showingNewExerciseSheet: Bool = false
    @State private var gymToDelete: GymProfile? = nil
    @State private var exerciseToDelete: Exercise? = nil
    @State private var searchText: String = ""
    @State private var selectedRegion: BodyRegion = .all
    @State private var selectedMuscleFilter: MuscleGroup? = nil
    @State private var showOnlyCustomExercises: Bool = false

    private var customExercisesCount: Int {
        exercises.filter(\.isCustom).count
    }

    private var filteredExercises: [Exercise] {
        exercises.filter { ex in
            let matchesCustom = !showOnlyCustomExercises || ex.isCustom
            let matchesRegion: Bool = {
                if selectedRegion == .all { return true }
                if let specific = selectedMuscleFilter {
                    return ex.primaryMuscle == specific
                }
                return selectedRegion.muscleGroups.contains(ex.primaryMuscle)
            }()
            let matchesSearch = searchText.isEmpty ||
                ex.name.localizedCaseInsensitiveContains(searchText) ||
                ex.equipmentSummary.localizedCaseInsensitiveContains(searchText) ||
                ex.movementPattern.rawValue.localizedCaseInsensitiveContains(searchText) ||
                (ex.isCustom && "custom".localizedCaseInsensitiveContains(searchText))
            return matchesCustom && matchesRegion && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Picker("View", selection: $selectedSection) {
                        Text("My Gyms (\(gyms.count))").tag(0)
                        Text("Lift Database (\(exercises.count))").tag(1)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        if selectedSection == 0 {
                            showingNewGymSheet = true
                        } else {
                            showingNewExerciseSheet = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel(selectedSection == 0 ? "New Custom Gym" : "New Lift")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if selectedSection == 0 {
                    gymsListSection
                } else {
                    liftsDatabaseSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewGymSheet) {
                GymEditorView(gymToEdit: nil, onSaved: nil)
            }
            .sheet(item: $gymToEdit) { gym in
                GymEditorView(gymToEdit: gym, onSaved: nil)
            }
            .sheet(isPresented: $showingNewExerciseSheet) {
                ExerciseEditorView(exerciseToEdit: nil)
            }
            .sheet(item: $exerciseToEdit) { ex in
                ExerciseEditorView(exerciseToEdit: ex)
            }
            .confirmationDialog(
                "Delete \"\(gymToDelete?.name ?? "Gym")\"?",
                isPresented: Binding(
                    get: { gymToDelete != nil },
                    set: { if !$0 { gymToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Gym Profile", role: .destructive) {
                    if let gym = gymToDelete {
                        deleteGym(gym)
                    }
                    gymToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    gymToDelete = nil
                }
            } message: {
                Text("All past workouts completed at this gym will remain intact in your history with the gym name preserved.")
            }
            .confirmationDialog(
                "Delete \"\(exerciseToDelete?.name ?? "Custom Lift")\"?",
                isPresented: Binding(
                    get: { exerciseToDelete != nil },
                    set: { if !$0 { exerciseToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Custom Lift", role: .destructive) {
                    if let ex = exerciseToDelete {
                        deleteExercise(ex)
                    }
                    exerciseToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    exerciseToDelete = nil
                }
            } message: {
                Text("All past workouts and set history referencing this exercise will remain intact in your history.")
            }
        }
    }

    private var gymsListSection: some View {
        List {
            Section {
                Button {
                    showingNewGymSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Custom Gym Profile")
                                .font(.subheadline.weight(.bold))
                            Text("Configure exact free weights, racks, machines, cables & cardio available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Saved Gym Profiles (Tap to Edit Equipment)") {
                ForEach(gyms) { gym in
                    Button {
                        gymToEdit = gym
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: gym.iconName)
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .frame(width: 36, height: 36)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(gym.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    if gym.isCustom {
                                        Text("Custom")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.18))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }

                                if !gym.locationNote.isEmpty {
                                    Text(gym.locationNote)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 8) {
                                    Text("\(gym.availableEquipment.count) equipment types")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.orange)
                                    if let maxDB = gym.availableDumbbellMaxWeight {
                                        Text("· Max DB: \(Int(maxDB)) lbs")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if gyms.count > 1 {
                            Button(role: .destructive) {
                                gymToDelete = gym
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .contextMenu {
                        Button {
                            gymToEdit = gym
                        } label: {
                            Label("Edit Gym Profile", systemImage: "pencil")
                        }

                        if gyms.count > 1 {
                            Divider()
                            Button(role: .destructive) {
                                gymToDelete = gym
                            } label: {
                                Label("Delete Gym Profile...", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private enum BodyRegion: String, CaseIterable, Identifiable {
        case all = "All"
        case chest = "Chest"
        case back = "Back"
        case shoulders = "Shoulders"
        case legs = "Legs"
        case arms = "Arms"
        case core = "Core"

        var id: String { rawValue }

        var muscleGroups: [MuscleGroup] {
            switch self {
            case .all:
                return MuscleGroup.allCases
            case .chest:
                return [.chest, .upperChest]
            case .back:
                return [.lats, .upperBack, .lowerBack]
            case .shoulders:
                return [.frontDelt, .sideDelt, .rearDelt]
            case .legs:
                return [.quads, .hamstrings, .glutes, .calves]
            case .arms:
                return [.biceps, .triceps, .forearms]
            case .core:
                return [.abs, .obliques]
            }
        }
    }

    private var liftsDatabaseSection: some View {
        VStack(spacing: 0) {
            // Tier 1: Primary Body Regions + Custom Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            selectedRegion = .all
                            selectedMuscleFilter = nil
                            showOnlyCustomExercises = false
                        }
                    } label: {
                        Text("All")
                            .font(.caption.weight(selectedRegion == .all && !showOnlyCustomExercises ? .bold : .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedRegion == .all && !showOnlyCustomExercises ? Color.orange : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(selectedRegion == .all && !showOnlyCustomExercises ? .white : .primary)
                            .clipShape(Capsule())
                    }

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            showOnlyCustomExercises.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.caption2)
                            Text("Custom (\(customExercisesCount))")
                        }
                        .font(.caption.weight(showOnlyCustomExercises ? .bold : .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(showOnlyCustomExercises ? Color.blue : Color.blue.opacity(0.14))
                        .foregroundStyle(showOnlyCustomExercises ? .white : .blue)
                        .clipShape(Capsule())
                    }

                    ForEach(BodyRegion.allCases.filter { $0 != .all }) { region in
                        let isSel = (selectedRegion == region)
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                if selectedRegion == region {
                                    selectedRegion = .all
                                    selectedMuscleFilter = nil
                                } else {
                                    selectedRegion = region
                                    selectedMuscleFilter = nil
                                }
                            }
                        } label: {
                            Text(region.rawValue)
                                .font(.caption.weight(isSel ? .bold : .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(isSel ? Color.orange : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(isSel ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, selectedRegion != .all ? 4 : 8)
            }

            // Tier 2: Sub-Muscle Filter Chips (revealed when a specific region is selected)
            if selectedRegion != .all {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                selectedMuscleFilter = nil
                            }
                        } label: {
                            Text("All \(selectedRegion.rawValue)")
                                .font(.caption2.weight(selectedMuscleFilter == nil ? .heavy : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedMuscleFilter == nil ? Color.orange.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
                                .foregroundStyle(selectedMuscleFilter == nil ? .orange : .secondary)
                                .clipShape(Capsule())
                        }

                        ForEach(selectedRegion.muscleGroups) { muscle in
                            let isMSelected = (selectedMuscleFilter == muscle)
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                    selectedMuscleFilter = isMSelected ? nil : muscle
                                }
                            } label: {
                                Text(muscle.rawValue)
                                    .font(.caption2.weight(isMSelected ? .heavy : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(isMSelected ? Color.orange.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
                                    .foregroundStyle(isMSelected ? .orange : .secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            List {
                Section {
                    Button {
                        showingNewExerciseSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add Custom Lift to Database")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text("Tagged as Custom and protected from ever being overwritten")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section(showOnlyCustomExercises ? "Custom Lifts (\(filteredExercises.count))" : "Catalog & Custom Lifts (Tap to Modify · \(filteredExercises.count))") {
                    if filteredExercises.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: showOnlyCustomExercises ? "tag.slash" : "magnifyingglass")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text(showOnlyCustomExercises ? "No Custom Lifts Yet" : "No Matching Lifts")
                                .font(.subheadline.weight(.semibold))
                            Text(showOnlyCustomExercises ? "Tap '+' or 'Add Custom Lift to Database' above, or tap any existing lift to customize it." : "Try clearing your search or muscle filter.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(filteredExercises) { ex in
                            Button {
                                exerciseToEdit = ex
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(ex.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)

                                            if ex.isCustom {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "tag.fill")
                                                        .font(.system(size: 8, weight: .bold))
                                                    Text("Custom")
                                                        .font(.caption2.weight(.bold))
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.18))
                                                .foregroundStyle(.blue)
                                                .clipShape(Capsule())
                                            }

                                            Spacer()

                                            Text(ex.tierPriority.shortBadge)
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(ex.isCoreExercise ? Color.mint.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
                                                .foregroundStyle(ex.isCoreExercise ? .mint : .secondary)
                                                .clipShape(Capsule())
                                        }

                                        Text("\(ex.primaryMuscle.rawValue) · \(ex.movementPattern.rawValue)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text("Requires: \(ex.equipmentSummary)")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 3)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if ex.isCustom {
                                    Button(role: .destructive) {
                                        exerciseToDelete = ex
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .contextMenu {
                                Button {
                                    exerciseToEdit = ex
                                } label: {
                                    Label(ex.isCustom ? "Edit Custom Lift" : "Edit Lift", systemImage: "pencil")
                                }

                                if ex.isCustom {
                                    Divider()
                                    Button(role: .destructive) {
                                        exerciseToDelete = ex
                                    } label: {
                                        Label("Delete Custom Lift...", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search lifts, equipment, or 'Custom'...")
        }
    }

    private func deleteGym(_ gym: GymProfile) {
        if UserSettings.shared.activeGymProfileId == gym.id.uuidString {
            let remaining = gyms.first(where: { $0.id != gym.id })
            UserSettings.shared.activeGymProfileId = remaining?.id.uuidString
        }
        modelContext.delete(gym)
        try? modelContext.save()
        WorkoutTimerManager.shared.triggerHaptic(.medium)
    }

    private func deleteExercise(_ ex: Exercise) {
        modelContext.delete(ex)
        try? modelContext.save()
        WorkoutTimerManager.shared.triggerHaptic(.medium)
    }
}

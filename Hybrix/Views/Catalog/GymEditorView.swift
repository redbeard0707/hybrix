import SwiftUI
import SwiftData

struct GymEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let gymToEdit: GymProfile?
    let onSaved: ((GymProfile) -> Void)?

    @State private var name: String = ""
    @State private var iconName: String = "dumbbell.fill"
    @State private var locationNote: String = ""
    @State private var selectedEquipment: Set<EquipmentType> = [.bodyweight, .dumbbell, .flatBench, .adjustableBench]
    @State private var hasMaxDumbbellCap: Bool = false
    @State private var maxDumbbellWeight: Double = 75

    // Bar & Plate inventory state
    @State private var selectedPlates: Set<Double> = [45, 35, 25, 10, 5, 2.5]
    @State private var selectedKettlebells: Set<Double> = [9, 13, 18, 26, 35, 44, 53, 62, 70]
    @State private var barbellWeightLbs: Double = 45
    @State private var smithMachineBarWeightLbs: Double = 20
    @State private var ezCurlBarWeightLbs: Double = 25
    @State private var trapBarWeightLbs: Double = 45

    // Saved exercise swap preferences (staged; committed on Save)
    @Query(sort: \GymProfile.name) private var allGyms: [GymProfile]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var stagedSwapPairs: [(originalID: UUID, replacementID: UUID)] = []
    @State private var swapPreferencesExpanded: Bool = false
    @State private var showingClearAllSwapsConfirm: Bool = false
    @State private var showingDeleteGymConfirm: Bool = false

    private let iconChoices = [
        "dumbbell.fill", "building.2.fill", "house.fill", "bed.double.fill",
        "figure.strengthtraining.traditional", "figure.run", "airplane", "flame.fill"
    ]

    init(gymToEdit: GymProfile?, onSaved: ((GymProfile) -> Void)?) {
        self.gymToEdit = gymToEdit
        self.onSaved = onSaved

        if let g = gymToEdit {
            _name = State(initialValue: g.name)
            _iconName = State(initialValue: g.iconName)
            _locationNote = State(initialValue: g.locationNote)
            _selectedEquipment = State(initialValue: g.availableEquipment)
            _hasMaxDumbbellCap = State(initialValue: g.availableDumbbellMaxWeight != nil)
            _maxDumbbellWeight = State(initialValue: g.availableDumbbellMaxWeight ?? 75)
            _selectedPlates = State(initialValue: Set(g.availablePlates))
            _selectedKettlebells = State(initialValue: Set(g.availableKettlebells))
            _barbellWeightLbs = State(initialValue: g.barbellWeightLbs)
            _smithMachineBarWeightLbs = State(initialValue: g.smithMachineBarWeightLbs)
            _ezCurlBarWeightLbs = State(initialValue: g.ezCurlBarWeightLbs)
            _trapBarWeightLbs = State(initialValue: g.trapBarWeightLbs)
            _stagedSwapPairs = State(initialValue: g.preferredSwapPairs)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Custom Gym Identity") {
                    TextField("Gym Name (e.g., My Garage, Hotel, Gold's)", text: $name)
                    TextField("Notes / Location (optional)", text: $locationNote)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(iconChoices, id: \.self) { icon in
                                Button {
                                    iconName = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(iconName == icon ? Color.orange : Color(.tertiarySystemGroupedBackground))
                                        .foregroundStyle(iconName == icon ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if gymToEdit != nil {
                    savedSwapPreferencesSection
                }

                Section("1-Tap Equipment Presets") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(GymPresetTemplate.allCases) { preset in
                                Button {
                                    selectedEquipment = preset.equipmentSet
                                    iconName = preset.defaultIcon
                                    if name.isEmpty {
                                        name = preset.rawValue
                                    }
                                    if let maxDB = preset.defaultMaxDumbbell {
                                        hasMaxDumbbellCap = true
                                        maxDumbbellWeight = maxDB
                                    } else {
                                        hasMaxDumbbellCap = false
                                    }
                                } label: {
                                    Label(preset.rawValue, systemImage: preset.defaultIcon)
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
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

                if selectedEquipment.contains(.dumbbell) {
                    Section("Dumbbell Weight Cap") {
                        Toggle("Cap Maximum Dumbbell Weight", isOn: $hasMaxDumbbellCap)
                        if hasMaxDumbbellCap {
                            Stepper(
                                "Max Dumbbell: \(Int(maxDumbbellWeight)) lbs",
                                value: $maxDumbbellWeight,
                                in: 20...150,
                                step: 5
                            )
                        }
                    }
                }

                if selectedEquipment.contains(.weightPlates) ||
                   selectedEquipment.contains(.barbell) ||
                   selectedEquipment.contains(.smithMachine) ||
                   selectedEquipment.contains(.ezCurlBar) ||
                   selectedEquipment.contains(.trapBar) {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Available Weight Plates (lbs)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 8)], spacing: 8) {
                                ForEach(GymProfile.allStandardPlateOptions, id: \.self) { plate in
                                    let isSelected = selectedPlates.contains(plate)
                                    Button {
                                        if isSelected && selectedPlates.count > 1 {
                                            selectedPlates.remove(plate)
                                        } else {
                                            selectedPlates.insert(plate)
                                        }
                                    } label: {
                                        Text("\(GymProfile.formatCleanNumber(plate)) lb")
                                            .font(.caption.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(isSelected ? Color.orange : Color(.tertiarySystemGroupedBackground))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        if selectedEquipment.contains(.barbell) {
                            Picker("Standard Barbell Weight", selection: $barbellWeightLbs) {
                                Text("45 lbs (Olympic)").tag(45.0)
                                Text("35 lbs (Women's / Tech)").tag(35.0)
                                Text("25 lbs (Short Bar)").tag(25.0)
                                Text("15 lbs (Technique)").tag(15.0)
                            }
                        }

                        if selectedEquipment.contains(.smithMachine) {
                            Picker("Smith Machine Starting Bar", selection: $smithMachineBarWeightLbs) {
                                Text("0 lbs (Counterbalanced)").tag(0.0)
                                Text("15 lbs").tag(15.0)
                                Text("20 lbs (Standard Smith)").tag(20.0)
                                Text("25 lbs").tag(25.0)
                                Text("30 lbs").tag(30.0)
                                Text("45 lbs (Unbalanced)").tag(45.0)
                            }
                        }

                        if selectedEquipment.contains(.ezCurlBar) {
                            Picker("EZ Curl Bar Weight", selection: $ezCurlBarWeightLbs) {
                                Text("15 lbs").tag(15.0)
                                Text("20 lbs").tag(20.0)
                                Text("25 lbs (Standard)").tag(25.0)
                                Text("30 lbs").tag(30.0)
                            }
                        }

                        if selectedEquipment.contains(.trapBar) {
                            Picker("Trap / Hex Bar Weight", selection: $trapBarWeightLbs) {
                                Text("45 lbs (Standard)").tag(45.0)
                                Text("55 lbs").tag(55.0)
                                Text("60 lbs (Heavy Rackable)").tag(60.0)
                            }
                        }
                    } header: {
                        Label("Bars & Plate Calculator Setup", systemImage: "scalemass.fill")
                    }
                }

                if selectedEquipment.contains(.kettlebell) {
                    Section {
                        HStack(spacing: 8) {
                            Button("Competition (kg)") {
                                selectedKettlebells = [9, 13, 18, 26, 35, 44, 53, 62, 70]
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("5-lb Steps") {
                                selectedKettlebells = [10, 15, 20, 25, 30, 35, 40, 45, 50, 60]
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Spacer()

                            Button("Select All") {
                                selectedKettlebells = Set(GymProfile.allStandardKettlebellOptions)
                            }
                            .font(.caption2)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 62))], spacing: 8) {
                            ForEach(GymProfile.allStandardKettlebellOptions, id: \.self) { kb in
                                let isSelected = selectedKettlebells.contains(kb)
                                Button {
                                    if isSelected {
                                        if selectedKettlebells.count > 1 {
                                            selectedKettlebells.remove(kb)
                                        }
                                    } else {
                                        selectedKettlebells.insert(kb)
                                    }
                                } label: {
                                    Text("\(GymProfile.formatCleanNumber(kb)) lb")
                                        .font(.caption.weight(isSelected ? .bold : .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(isSelected ? Color.orange : Color(.tertiarySystemGroupedBackground))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Label("Available Kettlebell Sizes (\(selectedKettlebells.count))", systemImage: "figure.strengthtraining.functional")
                    } footer: {
                        Text("Kettlebell exercises automatically progress to the next available weight selected above.")
                    }
                }

                ForEach(EquipmentCategory.allCases) { category in
                    Section {
                        ForEach(EquipmentType.items(for: category)) { item in
                            let isOn = selectedEquipment.contains(item)
                            Button {
                                if item == .bodyweight { return }
                                if isOn {
                                    selectedEquipment.remove(item)
                                } else {
                                    selectedEquipment.insert(item)
                                }
                            } label: {
                                HStack {
                                    Text(item.rawValue)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isOn ? .orange : .secondary)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Label(category.rawValue, systemImage: category.icon)
                            Spacer()
                            Button("Select All") {
                                EquipmentType.items(for: category).forEach { selectedEquipment.insert($0) }
                            }
                            .font(.caption2)
                        }
                    }
                }

                if let existing = gymToEdit {
                    Section {
                        if allGyms.count > 1 {
                            Button(role: .destructive) {
                                showingDeleteGymConfirm = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Delete Gym Profile", systemImage: "trash")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                        } else {
                            Text("Cannot delete your only gym profile.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } footer: {
                        if allGyms.count > 1 {
                            Text("Past workout logs referencing \(existing.name) will remain completely intact.")
                        }
                    }
                }
            }
            .navigationTitle(gymToEdit == nil ? "New Custom Gym" : "Edit Gym Profile")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Delete \"\(gymToEdit?.name ?? "Gym")\"?",
                isPresented: $showingDeleteGymConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Gym Profile", role: .destructive) {
                    deleteCurrentGym()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All past workouts completed at this gym will remain intact in your history with the gym name preserved.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGym()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func saveGym() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Custom Gym" : trimmedName
        let dbCap = (selectedEquipment.contains(.dumbbell) && hasMaxDumbbellCap) ? maxDumbbellWeight : nil

        if let existing = gymToEdit {
            existing.name = finalName
            existing.iconName = iconName
            existing.locationNote = locationNote
            existing.availableEquipment = selectedEquipment
            existing.availableDumbbellMaxWeight = dbCap
            existing.availablePlates = Array(selectedPlates)
            existing.availableKettlebells = Array(selectedKettlebells)
            existing.barbellWeightLbs = barbellWeightLbs
            existing.smithMachineBarWeightLbs = smithMachineBarWeightLbs
            existing.ezCurlBarWeightLbs = ezCurlBarWeightLbs
            existing.trapBarWeightLbs = trapBarWeightLbs
            var updatedMap: [String: String] = [:]
            for pair in stagedSwapPairs {
                updatedMap[pair.originalID.uuidString] = pair.replacementID.uuidString
            }
            existing.preferredSwapsMap = updatedMap
            try? modelContext.save()
            onSaved?(existing)
        } else {
            let created = GymProfile(
                name: finalName,
                iconName: iconName,
                locationNote: locationNote,
                isDefault: false,
                isCustom: true,
                availableEquipment: selectedEquipment,
                availableDumbbellMaxWeight: dbCap,
                availablePlates: Array(selectedPlates),
                availableKettlebells: Array(selectedKettlebells),
                barbellWeightLbs: barbellWeightLbs,
                smithMachineBarWeightLbs: smithMachineBarWeightLbs,
                ezCurlBarWeightLbs: ezCurlBarWeightLbs,
                trapBarWeightLbs: trapBarWeightLbs
            )
            modelContext.insert(created)
            try? modelContext.save()
            onSaved?(created)
        }
        dismiss()
    }

    private func deleteCurrentGym() {
        guard let existing = gymToEdit else { return }
        if UserSettings.shared.activeGymProfileId == existing.id.uuidString {
            let remaining = allGyms.first(where: { $0.id != existing.id })
            UserSettings.shared.activeGymProfileId = remaining?.id.uuidString
        }
        modelContext.delete(existing)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Saved Exercise Swap Preferences

    private struct ResolvedSwapRow: Identifiable {
        let originalID: UUID
        let replacementID: UUID
        let original: Exercise?
        let replacement: Exercise?
        var id: UUID { originalID }
        var isStale: Bool { original == nil || replacement == nil }
    }

    private var resolvedSwapRows: [ResolvedSwapRow] {
        stagedSwapPairs.map { pair in
            ResolvedSwapRow(
                originalID: pair.originalID,
                replacementID: pair.replacementID,
                original: allExercises.first(where: { $0.id == pair.originalID }),
                replacement: allExercises.first(where: { $0.id == pair.replacementID })
            )
        }
        .sorted { ($0.original?.name ?? "~") < ($1.original?.name ?? "~") }
    }

    private var savedSwapPreferencesSection: some View {
        Section {
            DisclosureGroup(isExpanded: $swapPreferencesExpanded) {
                if resolvedSwapRows.isEmpty {
                    Text("No saved swaps. When you swap a lift on the Today screen and choose \"Always Use at this gym\", it will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(resolvedSwapRows) { row in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.original?.name ?? "Deleted Exercise")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(row.original == nil ? .secondary : .primary)
                                    .strikethrough(row.original == nil)
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption2)
                                    Text(row.replacement?.name ?? "Deleted Exercise")
                                        .font(.caption.weight(.semibold))
                                        .strikethrough(row.replacement == nil)
                                }
                                .foregroundStyle(.orange)
                                if row.isStale {
                                    Text("Exercise no longer exists — this preference has no effect")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                            Spacer()
                            Button {
                                withAnimation {
                                    stagedSwapPairs.removeAll { $0.originalID == row.originalID }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear swap preference for \(row.original?.name ?? "exercise")")
                        }
                        .padding(.vertical, 2)
                        .swipeActions {
                            Button(role: .destructive) {
                                withAnimation {
                                    stagedSwapPairs.removeAll { $0.originalID == row.originalID }
                                }
                            } label: {
                                Label("Clear", systemImage: "trash")
                            }
                        }
                    }

                    Button(role: .destructive) {
                        showingClearAllSwapsConfirm = true
                    } label: {
                        Label("Clear All Saved Swaps", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                    }
                    .confirmationDialog(
                        "Clear all \(stagedSwapPairs.count) saved swaps for this gym?",
                        isPresented: $showingClearAllSwapsConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Clear All", role: .destructive) {
                            withAnimation { stagedSwapPairs.removeAll() }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.swap")
                        .foregroundStyle(.orange)
                    Text("Saved Exercise Swaps")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(stagedSwapPairs.count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.16))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
        } footer: {
            if gymToEdit.map({ $0.preferredSwapPairs.count != stagedSwapPairs.count }) ?? false {
                Text("Changes to saved swaps apply when you tap Save.")
            }
        }
    }
}

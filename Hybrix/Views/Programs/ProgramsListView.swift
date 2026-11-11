import SwiftUI
import SwiftData

struct ProgramsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Mesocycle.startDate, order: .reverse) private var mesocycles: [Mesocycle]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var settings = UserSettings.shared

    @State private var showingNewMesocycleSheet: Bool = false
    @State private var pendingMesocycleToActivate: Mesocycle? = nil
    @State private var showingSwitchConfirmation: Bool = false
    @State private var editingDayTemplate: ProgramDayTemplate? = nil
    @State private var mesocycleForPreferredLifts: Mesocycle? = nil

    private var activeMesocycle: Mesocycle? {
        mesocycles.first(where: \.isActive) ?? mesocycles.first
    }

    private var previousMesocycle: Mesocycle? {
        guard let prevId = settings.previousMesocycleId,
              let match = mesocycles.first(where: { $0.id.uuidString == prevId }),
              match.id != activeMesocycle?.id else {
            return nil
        }
        return match
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Quick Resume Previous Program Banner (in case of accidental switch)
                    if let prev = previousMesocycle {
                        resumePreviousProgramBanner(prev)
                    }

                    // Active Period Overview
                    if let active = activeMesocycle {
                        activeMesocycleDetailCard(active)
                    }

                    // All Mesocycle Programs (Full Body, PPL, Upper/Lower, Custom)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("AVAILABLE TRAINING PERIODS & SPLITS")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showingNewMesocycleSheet = true
                            } label: {
                                Label("New Block", systemImage: "plus.circle.fill")
                                    .font(.caption.weight(.bold))
                            }
                        }

                        ForEach(mesocycles) { meso in
                            mesocycleRowCard(meso)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewMesocycleSheet) {
                MesocycleBuilderView()
            }
            .sheet(item: $editingDayTemplate) { day in
                ProgramDayEditorSheet(dayTemplate: day, allExercises: allExercises)
            }
            .sheet(item: $mesocycleForPreferredLifts) { meso in
                PreferredPrimaryLiftsSheet(mesocycle: meso, allExercises: allExercises)
            }
            .alert(
                "Switch Active Program?",
                isPresented: $showingSwitchConfirmation,
                presenting: pendingMesocycleToActivate
            ) { target in
                Button("Switch Program") {
                    confirmActivateMesocycle(target)
                }
                Button("Cancel", role: .cancel) {
                    pendingMesocycleToActivate = nil
                }
            } message: { target in
                if let current = activeMesocycle {
                    Text("Switch to \"\(target.name)\" (Week \(target.currentWeek), Day \(target.currentDayIndex + 1))?\n\nYour progress in \"\(current.name)\" (Week \(current.currentWeek) of \(current.totalWeeks), \(current.activeDayTemplate?.name ?? "Day \(current.currentDayIndex + 1)")) will be saved so you can resume where you left off.")
                } else {
                    Text("Activate \"\(target.name)\" at Week \(target.currentWeek) of \(target.totalWeeks)?")
                }
            }
        }
    }

    private func resumePreviousProgramBanner(_ prev: Mesocycle) -> some View {
        let dayName = prev.activeDayTemplate?.name ?? "Day \(prev.currentDayIndex + 1)"
        return HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Previous Program Saved")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                Text("\(prev.name) · Left off at Wk \(prev.currentWeek)/\(prev.totalWeeks) (\(dayName))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                pendingMesocycleToActivate = prev
                showingSwitchConfirmation = true
            } label: {
                Text("Resume")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func activeMesocycleDetailCard(_ meso: Mesocycle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("ACTIVE MESOCYCLE", systemImage: meso.splitType.icon)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.orange)
                Spacer()
                Text(meso.progressionModel.rawValue)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.16))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }

            Text(meso.name)
                .font(.title3.weight(.bold))

            Text(meso.progressionModel.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Preferred Primary Exercises Configuration Button
            Button {
                mesocycleForPreferredLifts = meso
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Set Preferred Primary Lifts for Program")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if !meso.preferredPrimaryExercisesMap.isEmpty {
                        Text("\(meso.preferredPrimaryExercisesMap.count) saved")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Week-by-Week Periodization Timeline
            VStack(alignment: .leading, spacing: 8) {
                Text("WEEK-BY-WEEK PROGRESSION TIMELINE (TAP TO SWITCH WEEK)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                ForEach(1...meso.totalWeeks, id: \.self) { wk in
                    let wp = PeriodizationEngine.weekProfile(for: meso, week: wk)
                    let isCurrent = wk == meso.currentWeek

                    Button {
                        withAnimation {
                            meso.currentWeek = wk
                            try? modelContext.save()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("Wk \(wk)")
                                .font(.caption.weight(.black))
                                .frame(width: 44, height: 28)
                                .background(
                                    isCurrent
                                        ? Color.orange
                                        : (wp.isDeload ? Color.mint.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
                                )
                                .foregroundStyle(isCurrent ? .white : (wp.isDeload ? .mint : .primary))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(wp.phaseTitle)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text(wp.phaseSubtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isCurrent {
                                Text("Active")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(8)
                        .background(
                            isCurrent
                                ? Color.orange.opacity(0.1)
                                : Color(.tertiarySystemGroupedBackground).opacity(0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Text("SPLIT ROTATION (\(meso.sortedDays.count) DAYS · TAP TO EDIT)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(meso.sortedDays) { day in
                Button {
                    editingDayTemplate = day
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(day.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(day.sortedSlots.count) lifts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let fin = day.finisher {
                                Text("+ \(fin.durationMinutes)m \(fin.format.rawValue)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(fin.format.badgeColor)
                            }
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Text(day.sortedSlots.compactMap { $0.preferredExercise?.name }.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func mesocycleRowCard(_ meso: Mesocycle) -> some View {
        let savedDayName = meso.activeDayTemplate?.name ?? "Day \(meso.currentDayIndex + 1)"

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(meso.name)
                        .font(.subheadline.weight(.bold))
                    if meso.isActive {
                        Text("ACTIVE")
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                Text("\(meso.splitType.rawValue) · \(meso.totalWeeks) Weeks · \(meso.progressionModel.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Progress: Week \(meso.currentWeek) of \(meso.totalWeeks) · Next: \(savedDayName)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Spacer()

            if !meso.isActive {
                Button {
                    pendingMesocycleToActivate = meso
                    showingSwitchConfirmation = true
                } label: {
                    Text("Switch")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func confirmActivateMesocycle(_ target: Mesocycle) {
        if let currentActive = activeMesocycle, currentActive.id != target.id {
            settings.previousMesocycleId = currentActive.id.uuidString
        }
        for m in mesocycles {
            m.isActive = (m.id == target.id)
        }
        try? modelContext.save()
        pendingMesocycleToActivate = nil
    }
}

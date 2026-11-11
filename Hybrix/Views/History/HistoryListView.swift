import SwiftUI
import SwiftData
import Charts

struct HistoryChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let value: Double
}

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \GymProfile.name) private var gyms: [GymProfile]
    @State private var settings = UserSettings.shared

    @State private var selectedMetric: HistoryTrendMetric = .exerciseWeight
    @State private var selectedExerciseName: String = ""
    @State private var logToEdit: WorkoutLog? = nil
    @State private var logToDelete: WorkoutLog? = nil
    @State private var showingDeleteAlert: Bool = false
    @State private var showAllMuscleVolumes: Bool = false

    private var loggedExerciseNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for log in logs {
            for item in log.sortedExercises {
                let name = item.exercise?.name ?? item.exerciseNameSnapshot
                if !name.isEmpty && !seen.contains(name) {
                    seen.insert(name)
                    result.append(name)
                }
            }
        }
        return result.sorted()
    }

    private var activeExerciseNameForChart: String {
        if !selectedExerciseName.isEmpty && loggedExerciseNames.contains(selectedExerciseName) {
            return selectedExerciseName
        }
        return loggedExerciseNames.first ?? "Barbell Bench Press"
    }

    private var chartDataPoints: [HistoryChartDataPoint] {
        let chronological = logs.sorted { $0.date < $1.date }

        switch selectedMetric {
        case .caloriesBurned:
            return chronological.map { log in
                HistoryChartDataPoint(
                    date: log.date,
                    label: log.dayTemplateName,
                    value: Double(log.estimatedCaloriesBurned)
                )
            }

        case .totalVolume:
            return chronological.map { log in
                HistoryChartDataPoint(
                    date: log.date,
                    label: log.dayTemplateName,
                    value: log.totalVolumeLbs
                )
            }

        case .exerciseWeight, .exerciseE1RM:
            let targetName = activeExerciseNameForChart
            var points: [HistoryChartDataPoint] = []
            for log in chronological {
                let matchingItems = log.sortedExercises.filter {
                    ($0.exercise?.name ?? $0.exerciseNameSnapshot) == targetName
                }
                let completedSets = matchingItems.flatMap { $0.sortedSets.filter(\.isCompleted) }
                guard !completedSets.isEmpty else { continue }

                let val: Double
                if selectedMetric == .exerciseWeight {
                    val = completedSets.map(\.weight).max() ?? 0
                } else {
                    val = completedSets.map(\.estimated1RM).max() ?? 0
                }

                if val > 0 {
                    points.append(
                        HistoryChartDataPoint(
                            date: log.date,
                            label: targetName,
                            value: val
                        )
                    )
                }
            }
            return points
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary Metrics Row
                    summaryStatsRow

                    // Interactive Trends Graph Card
                    trendsChartCard

                    // 7-Day Muscle Volume & Fatigue Analyzer Card
                    weeklyMuscleVolumeCard

                    if logs.isEmpty {
                        ContentUnavailableView(
                            "No Workouts Logged Yet",
                            systemImage: "dumbbell",
                            description: Text("Complete your first session from the Today tab to track volume, actual PRs, and calories burned.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(logs) { log in
                            workoutLogCard(log)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if selectedExerciseName.isEmpty, let first = loggedExerciseNames.first {
                    selectedExerciseName = first
                }
            }
            .sheet(item: $logToEdit) { log in
                WorkoutLogEditorSheet(log: log)
            }
            .alert(
                "Delete Workout Log?",
                isPresented: $showingDeleteAlert,
                presenting: logToDelete
            ) { target in
                Button("Delete Log", role: .destructive) {
                    if target.id == logs.first?.id, let meso = target.mesocycle {
                        meso.stepBackwardOneWorkout()
                    }
                    modelContext.delete(target)
                    try? modelContext.save()
                    logToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    logToDelete = nil
                }
            } message: { target in
                Text("Delete \"\(target.dayTemplateName)\" from \(target.date.formatted(date: .abbreviated, time: .shortened))? This cannot be undone.")
            }
        }
    }

    private var summaryStatsRow: some View {
        let totalSessions = logs.count
        let totalCalories = logs.reduce(0) { $0 + $1.estimatedCaloriesBurned }
        let totalVolume = Int(logs.reduce(0.0) { $0 + $1.totalVolumeLbs })

        return HStack(spacing: 10) {
            statTile(title: "Workouts", value: "\(totalSessions)", icon: "dumbbell.fill", color: .orange)
            statTile(title: "Calories Burned", value: "\(totalCalories) kcal", icon: "flame.fill", color: .red)
            statTile(title: "Total Volume", value: "\(totalVolume / 1000)k \(settings.weightUnit.rawValue)", icon: "scalemass.fill", color: .blue)
        }
    }

    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var trendsChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PERFORMANCE & CALORIE TRENDS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(selectedMetric.rawValue)
                        .font(.subheadline.weight(.bold))
                }
                Spacer()

                // Metric Selector Menu
                Menu {
                    Picker("Graph Metric", selection: $selectedMetric) {
                        ForEach(HistoryTrendMetric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.xyaxis.line")
                        Text("Metric")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.18))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                }
            }

            // Exercise Selector when viewing Weight or e1RM
            if selectedMetric.requiresExerciseSelection && !loggedExerciseNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(loggedExerciseNames, id: \.self) { exName in
                            let isSel = exName == activeExerciseNameForChart
                            Button {
                                withAnimation {
                                    selectedExerciseName = exName
                                }
                            } label: {
                                Text(exName)
                                    .font(.caption.weight(isSel ? .bold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isSel ? Color.orange : Color(.tertiarySystemGroupedBackground))
                                    .foregroundStyle(isSel ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            if chartDataPoints.isEmpty {
                Text("No logged data points for this selection yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart(chartDataPoints) { pt in
                    AreaMark(
                        x: .value("Date", pt.date),
                        y: .value("Value", pt.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.35), chartColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("Value", pt.value)
                    )
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    PointMark(
                        x: .value("Date", pt.date),
                        y: .value("Value", pt.value)
                    )
                    .foregroundStyle(chartColor)
                    .annotation(position: .top) {
                        Text("\(Int(pt.value))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 185)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var chartColor: Color {
        switch selectedMetric {
        case .exerciseWeight, .exerciseE1RM: return .orange
        case .caloriesBurned: return .red
        case .totalVolume: return .blue
        }
    }

    private var weeklyMuscleVolumeCard: some View {
        let allBreakdowns = VolumeAndFatigueAnalyzer.analyzeRolling7Days(logs: logs, allExercises: allExercises)
        let activeBreakdowns = showAllMuscleVolumes
            ? allBreakdowns
            : Array(allBreakdowns.filter { $0.effectiveWeeklySets > 0 }.prefix(6))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("7-DAY MUSCLE VOLUME & FATIGUE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("Direct sets (1.0) + Secondary sets (0.5) · Target 8–18/wk")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation {
                        showAllMuscleVolumes.toggle()
                    }
                } label: {
                    Text(showAllMuscleVolumes ? "Show Active" : "All Muscles")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }

            if activeBreakdowns.isEmpty {
                Text("No sets logged in the last 7 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activeBreakdowns) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.muscle.rawValue)
                                .font(.caption.weight(.bold))
                            Spacer()
                            Text(String(format: "%.1f sets", item.effectiveWeeklySets))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(item.status.rawValue)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.status.color.opacity(0.18))
                                .foregroundStyle(item.status.color)
                                .clipShape(Capsule())
                        }

                        GeometryReader { geo in
                            let ratio = min(1.0, CGFloat(item.effectiveWeeklySets / 20.0))
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemGroupedBackground))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.status.color)
                                    .frame(width: max(6, geo.size.width * ratio))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func workoutLogCard(_ log: WorkoutLog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(log.dayTemplateName)
                            .font(.headline)
                        if log.isCustomAdHocWorkout {
                            Text("Custom")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        } else {
                            Text("Wk \(log.weekIndex)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(log.date.formatted(date: .abbreviated, time: .shortened)) · 📍 \(log.selectedGym?.name ?? log.selectedGymNameSnapshot)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(max(1, log.durationSeconds / 60)) min")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())

                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                            Text("\(log.estimatedCaloriesBurned) kcal")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.red)
                    }

                    Menu {
                        Button {
                            if let fallbackGym = gyms.first {
                                ActiveWorkoutSessionManager.shared.reopenCompletedWorkout(
                                    log,
                                    allExercises: allExercises,
                                    fallbackGym: fallbackGym
                                )
                            }
                        } label: {
                            Label("Re-Enter Live Workout", systemImage: "arrow.uturn.backward.circle.fill")
                        }

                        Button {
                            logToEdit = log
                        } label: {
                            Label("Edit Sets & Notes", systemImage: "slider.horizontal.3")
                        }

                        Divider()

                        Button(role: .destructive) {
                            logToDelete = log
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Workout Log", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            ForEach(log.sortedExercises) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.exercise?.name ?? item.exerciseNameSnapshot)
                                .font(.subheadline.weight(.medium))
                            if item.wasAutoInjectedCore {
                                Text("Core")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.mint)
                            }
                        }
                        if let swappedFrom = item.swappedFromExerciseName {
                            Text("Swapped from \(swappedFrom)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    let completedSets = item.sortedSets.filter(\.isCompleted)
                    if let topSet = completedSets.max(by: { $0.estimated1RM < $1.estimated1RM }) {
                        Text("\(completedSets.count) sets · Top: \(Int(topSet.weight))×\(topSet.reps) (e1RM \(Int(topSet.estimated1RM)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(item.sortedSets.count) sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let fin = log.loggedFinisher {
                HStack(spacing: 6) {
                    Image(systemName: fin.format.icon)
                        .foregroundStyle(fin.format.badgeColor)
                    Text("\(fin.title): \(fin.roundsCompleted) rounds (\(fin.movementsSummary))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(fin.format.badgeColor)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(fin.format.badgeColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !log.notes.isEmpty {
                Text("\"\(log.notes)\"")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

import SwiftUI

private struct ExerciseCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct SupersetAndOrderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialExercises: [ComputedPlannedExerciseItem]
    let currentSupersetGroups: [UUID: UUID]
    let currentCustomOrder: [UUID]
    let onApply: (_ supersetGroups: [UUID: UUID], _ customOrder: [UUID]) -> Void

    @State private var orderedItems: [ComputedPlannedExerciseItem]
    @State private var supersetGroups: [UUID: UUID]
    @State private var showingAutoSupersetConfirm: Bool = false

    // Press & Hold Drag-and-Drop State
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var draggedItemID: UUID? = nil
    @State private var dragStartLocation: CGPoint = .zero
    @State private var currentDragLocation: CGPoint = .zero
    @State private var activeDropAction: DropAction? = nil

    private enum DropAction: Equatable {
        case bundleOnto(targetID: UUID)
        case moveToIndex(index: Int)
    }

    init(
        initialExercises: [ComputedPlannedExerciseItem],
        currentSupersetGroups: [UUID: UUID],
        currentCustomOrder: [UUID],
        onApply: @escaping (_ supersetGroups: [UUID: UUID], _ customOrder: [UUID]) -> Void
    ) {
        self.initialExercises = initialExercises
        self.currentSupersetGroups = currentSupersetGroups
        self.currentCustomOrder = currentCustomOrder
        self.onApply = onApply

        _orderedItems = State(initialValue: initialExercises)
        _supersetGroups = State(initialValue: Self.sanitizedContiguousGroups(for: initialExercises, groups: currentSupersetGroups))
    }

    private var estimatedMinutesBeforeSupersets: Int {
        let sum = orderedItems.reduce(0.0) { acc, item in
            var copy = item
            copy.supersetGroupId = nil
            return acc + copy.estimatedMinutes
        }
        return Int(sum.rounded())
    }

    private var estimatedMinutesWithSupersets: Int {
        let sum = orderedItems.reduce(0.0) { acc, item in
            var copy = item
            copy.supersetGroupId = supersetGroups[item.id]
            return acc + copy.estimatedMinutes
        }
        return Int(sum.rounded())
    }

    private var minutesSaved: Int {
        max(0, estimatedMinutesBeforeSupersets - estimatedMinutesWithSupersets)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ZStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 14) {
                        headerSummaryCard

                        Text("PRESS & HOLD TO DRAG · DROP ONTO A LIFT TO BUNDLE OR BETWEEN LIFTS TO REORDER")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(orderedItems.enumerated()), id: \.element.id) { idx, item in
                                VStack(spacing: 0) {
                                    // Top insertion line indicator when dragging between items
                                    if activeDropAction == .moveToIndex(index: idx) {
                                        let joinsSuperset = supersetGroupAtInsertionIndex(idx) != nil
                                        dropInsertionIndicator(
                                            positionLabel: joinsSuperset
                                                ? "Insert at #\(idx + 1) · Join Superset"
                                                : "Move to #\(idx + 1)",
                                            isJoiningSuperset: joinsSuperset
                                        )
                                        .padding(.vertical, 6)
                                    }

                                    exerciseCard(for: item, index: idx)
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.preference(
                                                    key: ExerciseCardFramePreferenceKey.self,
                                                    value: [item.id: geo.frame(in: .named("SupersetBoard"))]
                                                )
                                            }
                                        )

                                    // Visual connector if bundled with the next exercise
                                    if isBundledWithNext(at: idx) {
                                        supersetConnectorBar(at: idx)
                                    } else {
                                        Spacer()
                                            .frame(height: 10)
                                    }

                                    // Bottom insertion line indicator after the last item
                                    if idx == orderedItems.count - 1,
                                       activeDropAction == .moveToIndex(index: orderedItems.count) {
                                        dropInsertionIndicator(positionLabel: "Move to #\(orderedItems.count)")
                                            .padding(.vertical, 6)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)

                    // Floating Dragged Card Overlay
                    if let draggedID = draggedItemID,
                       let draggedItem = orderedItems.first(where: { $0.id == draggedID }),
                       let originalFrame = cardFrames[draggedID] {
                        let dy = currentDragLocation.y - dragStartLocation.y
                        let dx = (currentDragLocation.x - dragStartLocation.x) * 0.25
                        floatingDraggedPreview(for: draggedItem)
                            .frame(width: originalFrame.width)
                            .position(
                                x: originalFrame.midX + dx,
                                y: originalFrame.midY + dy
                            )
                            .allowsHitTesting(false)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .coordinateSpace(name: "SupersetBoard")
                .onPreferenceChange(ExerciseCardFramePreferenceKey.self) { frames in
                    cardFrames = frames
                }
            }
            .scrollDisabled(draggedItemID != nil)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Supersets & Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(supersetGroups, orderedItems.map(\.id))
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("Auto-Pair Compatible Supersets?", isPresented: $showingAutoSupersetConfirm) {
                Button("Bundle Supersets") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        let suggested = TimeBudgetEngine.autoSuggestSupersetGroups(for: orderedItems)
                        orderedItems = Self.clusterSupersetPartnersAdjacently(items: orderedItems, groups: suggested)
                        supersetGroups = Self.sanitizedContiguousGroups(for: orderedItems, groups: suggested)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pair non-competing exercises (such as Push + Pull or Isolation + Core) into Supersets to cut rest time and fit more work into your session?")
            }
        }
    }

    // MARK: - Subviews

    private var headerSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Lifting Time: ~\(estimatedMinutesWithSupersets) min")
                        .font(.subheadline.weight(.bold))
                    if minutesSaved > 0 {
                        Text("Saving ~\(minutesSaved) min by sharing rest intervals in supersets")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Press & hold any lift to drag it onto another lift to form a Superset, or drag between lifts to reorder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    showingAutoSupersetConfirm = true
                } label: {
                    Label("Auto-Bundle Supersets", systemImage: "wand.and.stars")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.orange.opacity(0.18))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if !supersetGroups.isEmpty {
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            supersetGroups.removeAll()
                        }
                    } label: {
                        Label("Unbundle All", systemImage: "link.badge.minus")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.red.opacity(0.14))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func exerciseCard(for item: ComputedPlannedExerciseItem, index idx: Int) -> some View {
        let ex = item.resolution.activeExercise
        let badge = computedBadge(for: item.id)
        let isBeingDragged = (draggedItemID == item.id)
        let isBundleDropTarget = (activeDropAction == .bundleOnto(targetID: item.id))
        let isInSuperset = (badge != nil)

        let longPressDrag = LongPressGesture(minimumDuration: 0.16)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("SupersetBoard")))
            .onChanged { value in
                switch value {
                case .first(true):
                    break
                case .second(true, let drag):
                    if draggedItemID == nil {
                        WorkoutTimerManager.shared.triggerHaptic(.medium)
                        let fallbackCenter = cardFrames[item.id].map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero
                        let start = drag?.startLocation ?? fallbackCenter
                        dragStartLocation = start
                        currentDragLocation = drag?.location ?? start
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            draggedItemID = item.id
                        }
                    } else if let drag = drag {
                        currentDragLocation = drag.location
                        updateDropAction(at: drag.location, draggedID: item.id)
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                completeDrop()
            }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Drag Grip Icon + Order Number
                VStack(spacing: 2) {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("#\(idx + 1)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                        Text(ex.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    Text("\(ex.primaryMuscle.rawValue) · \(item.workingSets) sets × \(item.repRangeMin)–\(item.repRangeMax) reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isInSuperset {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            removeSingleItemFromSuperset(item.id)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "link.badge.minus")
                            Text("Unbundle")
                        }
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.14))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if isBundleDropTarget {
                HStack(spacing: 6) {
                    Image(systemName: "link.badge.plus")
                        .font(.caption.weight(.bold))
                    Text("Release to Bundle as Superset with \(ex.name)")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isBundleDropTarget
                        ? Color.purple.opacity(0.16)
                        : Color(.secondarySystemGroupedBackground)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isBundleDropTarget
                        ? Color.purple
                        : (isInSuperset ? Color.purple.opacity(0.45) : Color.clear),
                    lineWidth: isBundleDropTarget ? 2.5 : 1.2
                )
        )
        .opacity(isBeingDragged ? 0.28 : 1.0)
        .scaleEffect(isBundleDropTarget ? 1.02 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .gesture(longPressDrag)
    }

    private func supersetConnectorBar(at idx: Int) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.purple.opacity(0.5))
                .frame(width: 3, height: 18)
                .padding(.leading, 26)

            Image(systemName: "link")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.purple)

            Text("Bundled Superset · Shared Rest")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.purple)

            Spacer()
        }
    }

    private func dropInsertionIndicator(positionLabel: String, isJoiningSuperset: Bool = false) -> some View {
        let accentColor: Color = isJoiningSuperset ? .purple : .orange
        return HStack(spacing: 8) {
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(accentColor)
                .frame(height: 2.5)
            Text(positionLabel)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(accentColor.opacity(0.16))
                .clipShape(Capsule())
            Rectangle()
                .fill(accentColor)
                .frame(height: 2.5)
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)
        }
        .transition(.opacity)
    }

    private func floatingDraggedPreview(for item: ComputedPlannedExerciseItem) -> some View {
        let ex = item.resolution.activeExercise
        let actionSubtitle: String = {
            switch activeDropAction {
            case .bundleOnto(let targetID):
                if let targetName = orderedItems.first(where: { $0.id == targetID })?.resolution.activeExercise.name {
                    return "🔗 Drop to bundle with \(targetName)"
                }
                return "🔗 Drop to bundle into Superset"
            case .moveToIndex(let idx):
                if supersetGroupAtInsertionIndex(idx) != nil {
                    return "🔗 Drop to insert at #\(min(orderedItems.count, max(1, idx))) & join Superset"
                }
                return "↕ Drop to move to position #\(min(orderedItems.count, max(1, idx)))"
            case nil:
                return "Drag onto a lift to bundle, or between lifts to reorder"
            }
        }()

        return HStack(spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(actionSubtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(
                        {
                            if case .bundleOnto = activeDropAction { return Color.purple }
                            return Color.orange
                        }()
                    )
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange, lineWidth: 2)
        )
        .scaleEffect(1.03)
    }

    // MARK: - Drag Hit-Testing & Drop Execution

    private func updateDropAction(at location: CGPoint, draggedID: UUID) {
        var newAction: DropAction? = nil

        for (idx, item) in orderedItems.enumerated() {
            guard let frame = cardFrames[item.id] else { continue }

            // Check if pointer is above the first card
            if idx == 0 && location.y < frame.minY + frame.height * 0.22 {
                newAction = .moveToIndex(index: 0)
                break
            }

            // Check if pointer is inside this card's vertical span
            if location.y >= frame.minY && location.y <= frame.maxY {
                let relativeY = (location.y - frame.minY) / max(1, frame.height)
                if item.id == draggedID {
                    newAction = nil
                } else if relativeY < 0.24 {
                    newAction = .moveToIndex(index: idx)
                } else if relativeY > 0.76 {
                    newAction = .moveToIndex(index: idx + 1)
                } else {
                    newAction = .bundleOnto(targetID: item.id)
                }
                break
            }

            // Check if pointer is in the gap between this card and the next card
            if idx + 1 < orderedItems.count,
               let nextFrame = cardFrames[orderedItems[idx + 1].id],
               location.y > frame.maxY && location.y < nextFrame.minY {
                newAction = .moveToIndex(index: idx + 1)
                break
            }

            // Check if pointer is below the last card
            if idx == orderedItems.count - 1 && location.y > frame.maxY - frame.height * 0.22 {
                newAction = .moveToIndex(index: orderedItems.count)
                break
            }
        }

        if newAction != activeDropAction {
            WorkoutTimerManager.shared.triggerHaptic(.light)
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                activeDropAction = newAction
            }
        }
    }

    private func completeDrop() {
        defer {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                draggedItemID = nil
                activeDropAction = nil
            }
        }

        guard let draggedID = draggedItemID,
              let sourceIdx = orderedItems.firstIndex(where: { $0.id == draggedID }),
              let action = activeDropAction else {
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            switch action {
            case .bundleOnto(let targetID):
                guard targetID != draggedID,
                      orderedItems.contains(where: { $0.id == targetID }) else { return }

                // Remove dragged item from its old superset group first and clean up any orphaned 1-item group
                removeSingleItemFromSuperset(draggedID)

                // Assign shared superset group ID with target
                let sharedGroupID = supersetGroups[targetID] ?? UUID()
                supersetGroups[targetID] = sharedGroupID
                supersetGroups[draggedID] = sharedGroupID

                // Move dragged item right after the last member of targetID's superset group so bundled items stay adjacent
                let draggedItem = orderedItems.remove(at: sourceIdx)
                if let lastGroupMemberIdx = orderedItems.lastIndex(where: { $0.id == targetID || supersetGroups[$0.id] == sharedGroupID }) {
                    orderedItems.insert(draggedItem, at: lastGroupMemberIdx + 1)
                } else {
                    orderedItems.append(draggedItem)
                }
                supersetGroups = Self.sanitizedContiguousGroups(for: orderedItems, groups: supersetGroups)
                WorkoutTimerManager.shared.triggerHaptic(.medium)

            case .moveToIndex(let rawDestIndex):
                let targetSupersetGroupID = supersetGroupAtInsertionIndex(rawDestIndex)

                let item = orderedItems.remove(at: sourceIdx)
                let adjustedIndex = rawDestIndex > sourceIdx ? rawDestIndex - 1 : rawDestIndex
                let clampedIndex = max(0, min(orderedItems.count, adjustedIndex))
                orderedItems.insert(item, at: clampedIndex)

                if let joinGroupID = targetSupersetGroupID {
                    supersetGroups[draggedID] = joinGroupID
                } else {
                    supersetGroups.removeValue(forKey: draggedID)
                }

                supersetGroups = Self.sanitizedContiguousGroups(for: orderedItems, groups: supersetGroups)
                WorkoutTimerManager.shared.triggerHaptic(.medium)
            }
        }
    }

    private func removeSingleItemFromSuperset(_ itemID: UUID) {
        supersetGroups.removeValue(forKey: itemID)
        supersetGroups = Self.sanitizedContiguousGroups(for: orderedItems, groups: supersetGroups)
    }

    private func supersetGroupAtInsertionIndex(_ idx: Int) -> UUID? {
        guard idx > 0 && idx < orderedItems.count else { return nil }
        let prevID = orderedItems[idx - 1].id
        let nextID = orderedItems[idx].id
        guard let gid = supersetGroups[prevID], supersetGroups[nextID] == gid else { return nil }
        return gid
    }

    static func sanitizedContiguousGroups(
        for items: [ComputedPlannedExerciseItem],
        groups: [UUID: UUID]
    ) -> [UUID: UUID] {
        var sanitized: [UUID: UUID] = [:]
        var usedGroupIDs: Set<UUID> = []
        var i = 0

        while i < items.count {
            let itemID = items[i].id
            guard let gid = groups[itemID] else {
                i += 1
                continue
            }

            var j = i + 1
            while j < items.count && groups[items[j].id] == gid {
                j += 1
            }

            let runLength = j - i
            if runLength >= 2 {
                let effectiveGroupID = usedGroupIDs.contains(gid) ? UUID() : gid
                usedGroupIDs.insert(effectiveGroupID)
                for k in i..<j {
                    sanitized[items[k].id] = effectiveGroupID
                }
            }
            i = j
        }

        return sanitized
    }

    static func clusterSupersetPartnersAdjacently(
        items: [ComputedPlannedExerciseItem],
        groups: [UUID: UUID]
    ) -> [ComputedPlannedExerciseItem] {
        var result: [ComputedPlannedExerciseItem] = []
        var placedIDs: Set<UUID> = []

        for item in items {
            guard !placedIDs.contains(item.id) else { continue }
            result.append(item)
            placedIDs.insert(item.id)

            if let gid = groups[item.id] {
                for partner in items where !placedIDs.contains(partner.id) && groups[partner.id] == gid {
                    result.append(partner)
                    placedIDs.insert(partner.id)
                }
            }
        }
        return result
    }

    private func isBundledWithNext(at idx: Int) -> Bool {
        guard idx + 1 < orderedItems.count,
              let gid = supersetGroups[orderedItems[idx].id] else { return false }
        return supersetGroups[orderedItems[idx + 1].id] == gid
    }

    private func computedBadge(for itemID: UUID) -> String? {
        guard let gid = supersetGroups[itemID] else { return nil }
        let members = orderedItems.filter { supersetGroups[$0.id] == gid }
        guard members.count >= 2 else { return nil }

        var uniqueGroups: [UUID] = []
        for it in orderedItems {
            if let g = supersetGroups[it.id],
               orderedItems.filter({ supersetGroups[$0.id] == g }).count >= 2,
               !uniqueGroups.contains(g) {
                uniqueGroups.append(g)
            }
        }
        let letters = Array("ABCDEFGH")
        let groupIdx = uniqueGroups.firstIndex(of: gid) ?? 0
        let letter = letters[min(groupIdx, letters.count - 1)]
        let memberIdx = (members.firstIndex(where: { $0.id == itemID }) ?? 0) + 1
        return "Superset \(letter)\(memberIdx)"
    }
}

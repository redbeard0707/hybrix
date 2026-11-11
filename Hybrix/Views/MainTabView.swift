import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var settings = UserSettings.shared
    @State private var sessionManager = ActiveWorkoutSessionManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayDashboardView()
                    .tabItem {
                        Label("Today", systemImage: "flame.fill")
                    }
                    .tag(0)

                ProgramsListView()
                    .tabItem {
                        Label("Programs", systemImage: "calendar.badge.clock")
                    }
                    .tag(1)

                GymsAndLiftsView()
                    .tabItem {
                        Label("Gyms & Lifts", systemImage: "dumbbell.fill")
                    }
                    .tag(2)

                HistoryListView()
                    .tabItem {
                        Label("History", systemImage: "chart.xyaxis.line")
                    }
                    .tag(3)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(.orange)

            // Minimized Active Workout Floating Live Card above Tab Bar
            if sessionManager.hasActiveSession && !sessionManager.isPresentingFullScreen {
                VStack(spacing: 4) {
                    HybrixLockScreenLiveCardView(
                        state: sessionManager.currentLiveActivityState,
                        onCompleteSet: {
                            sessionManager.completeNextPendingSetFromLiveActivity()
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        sessionManager.resumeFullScreen()
                    }

                    HStack {
                        Image(systemName: "chevron.up.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Workout Minimized (\(WorkoutTimerManager.formatMMSS(sessionManager.elapsedSessionSeconds))) · Tap Card to Expand")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 56)
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .fullScreenCover(isPresented: $sessionManager.isPresentingFullScreen) {
            ActiveWorkoutSheet()
        }
    }
}

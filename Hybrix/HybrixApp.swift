import SwiftUI
import SwiftData

@main
struct HybrixApp: App {
    let modelContainer: ModelContainer
    @State private var showStartupSplash: Bool = true
    @State private var settings = UserSettings.shared

    init() {
        let schema = Schema([
            GymProfile.self,
            Exercise.self,
            Mesocycle.self,
            ProgramDayTemplate.self,
            PlannedExerciseSlot.self,
            FinisherPrescription.self,
            WorkoutLog.self,
            LoggedExercise.self,
            LoggedSet.self,
            LoggedFinisher.self
        ])

        self.modelContainer = Self.makeSafeModelContainer(for: schema)
    }

    private static func makeSafeModelContainer(for schema: Schema) -> ModelContainer {
        #if targetEnvironment(simulator)
        let primaryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [primaryConfig]) {
            return container
        }
        #else
        let cloudConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            return container
        }
        let localFallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [localFallbackConfig]) {
            return container
        }
        #endif

        // Recovery path if on-disk SQLite store encountered a schema migration conflict
        let recoveredStoreURL = URL.applicationSupportDirectory.appending(path: "HybrixStore_v2.store")
        let recoveredConfig = ModelConfiguration(schema: schema, url: recoveredStoreURL, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [recoveredConfig]) {
            return container
        }

        // Last-resort in-memory container so the app never crashes on launch
        let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [inMemoryConfig])
        } catch {
            preconditionFailure("Unable to initialize in-memory SwiftData container: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()

                if !settings.hasCompletedOnboarding && !showStartupSplash {
                    OnboardingSetupView {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            settings.hasCompletedOnboarding = true
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(5)
                }

                if showStartupSplash {
                    HybrixSplashView()
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .task {
                SeedDataService.seedIfNeeded(context: modelContainer.mainContext)
                withAnimation(.easeOut(duration: 0.2)) {
                    showStartupSplash = false
                }
            }
        }
        .modelContainer(modelContainer)
    }
}

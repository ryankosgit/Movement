import SwiftUI
import SwiftData

@main
struct ExerciseApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for:
                WorkoutRoutine.self,
                Exercise.self,
                RoutineTemplate.self,
                ExerciseTemplate.self
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}

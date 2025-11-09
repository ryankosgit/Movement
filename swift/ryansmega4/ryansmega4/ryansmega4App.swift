//
//  ryansmega4App.swift
//  ryansmega4
//
//  Created by ryan . on 11/8/25.
//

import SwiftUI
import SwiftData


struct ryansmega4App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
                    WorkoutRoutine.self,
                    Exercise.self,
                    RoutineTemplate.self, // <-- ADD THIS
                    ExerciseTemplate.self // <-- AND THIS
                ])
    }
}

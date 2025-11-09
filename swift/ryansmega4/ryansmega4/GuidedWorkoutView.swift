import SwiftUI
import CoreMotion
import Combine
import SwiftData

// MARK: - Guided Workout View (REFACTORED)
struct GuidedWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let routine: RoutineTemplate
    @StateObject private var collector = DataCollector()
    @State private var currentExerciseIndex = 0
    @State private var remainingReps: [String: Int] = [:]
    @State private var completedExercises: Set<Int> = []
    @State private var workoutStartTime = Date()
    @State private var showingCompletionAlert = false
    @State private var isWorkoutComplete = false
    
    var currentExercise: ExerciseTemplate? {
        guard currentExerciseIndex < routine.exercises.count else { return nil }
        return routine.exercises.sorted(by: { $0.exerciseType.rawValue < $1.exerciseType.rawValue })[currentExerciseIndex]
    }
    
    var sortedExercises: [ExerciseTemplate] {
        routine.exercises.sorted(by: { $0.exerciseType.rawValue < $1.exerciseType.rawValue })
    }
    
    var totalExercises: Int {
        routine.exercises.count
    }
    
    var completedCount: Int {
        completedExercises.count
    }
    
    var progressPercentage: Double {
        guard totalExercises > 0 else { return 0 }
        return Double(completedCount) / Double(totalExercises)
    }
    
    // ---
    // MARK: - Main Body (Simplified)
    // ---
    var body: some View {
        NavigationStack {
            if !isWorkoutComplete {
                if collector.isClassifying {
                    // Use the helper property
                    workoutInProgressView
                } else {
                    // Use the helper property
                    startScreenView
                }
            } else {
                // Use the helper property
                completionScreenView
            }
        }
        .navigationTitle("Guided Workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(collector.isClassifying)
        .toolbar {
            if collector.isClassifying {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        stopWorkout()
                    }
                }
            }
        }
        .onAppear {
            setupWorkout()
            collector.checkAirPodsConnection()
        }
        .onChange(of: collector.exerciseClassifier.repCounts) { oldValue, newValue in
            updateRemainingReps(oldCounts: oldValue, newCounts: newValue)
        }
    }
    
    // ---
    // MARK: - Helper View Properties
    // ---

    /// 🔥 **Refactored View 1: WORKOUT IN PROGRESS**
    private var workoutInProgressView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress Header
                VStack(spacing: 10) {
                    Text("Exercise \(currentExerciseIndex + 1) of \(totalExercises)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 10)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green)
                                .frame(width: geometry.size.width * progressPercentage, height: 10)
                                .animation(.spring(), value: progressPercentage)
                        }
                    }
                    .frame(height: 10)
                    .padding(.horizontal)
                }
                .padding()
                
                // Current Exercise Display
                if let exercise = currentExercise {
                    VStack(spacing: 20) {
                        // Exercise Name
                        Text(exercise.exerciseType.rawValue.uppercased())
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(exerciseColor(exercise.exerciseType.rawValue))
                        
                        // Reps Counter
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 15)
                                .frame(width: 150, height: 150)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(1 - Double(remainingReps[exercise.exerciseType.rawValue] ?? 0) / Double(exercise.reps)))
                                .stroke(exerciseColor(exercise.exerciseType.rawValue), lineWidth: 15)
                                .frame(width: 150, height: 150)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(), value: remainingReps[exercise.exerciseType.rawValue])
                            
                            VStack(spacing: 5) {
                                Text("\(remainingReps[exercise.exerciseType.rawValue] ?? 0)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                Text("reps left")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Motion Tracker
                        MotionTracker(
                            exercise: collector.exerciseClassifier.currentExercise,
                            p_gx: collector.exerciseClassifier.p_gx_mean,
                            p_gy: collector.exerciseClassifier.p_gy_mean,
                            p_gz: collector.exerciseClassifier.p_gz_mean
                        )
                        .frame(height: 60)
                        .padding(.horizontal, 40)
                        
                        // Current detection
                        Text("Detecting: \(collector.exerciseClassifier.currentExercise.capitalized)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                }
                
                // Upcoming Exercises
                if currentExerciseIndex < sortedExercises.count - 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Up Next")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(Array(sortedExercises.enumerated()), id: \.offset) { index, exercise in
                            if index > currentExerciseIndex {
                                HStack {
                                    Image(systemName: completedExercises.contains(index) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(completedExercises.contains(index) ? .green : .gray)
                                    
                                    Text(exercise.exerciseType.rawValue)
                                        .foregroundColor(completedExercises.contains(index) ? .secondary : .primary)
                                    
                                    Spacer()
                                    
                                    Text("\(exercise.reps) reps")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 5)
                            }
                        }
                    }
                    .padding(.vertical)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(15)
                }
                
                // Skip and Stop Buttons
                HStack(spacing: 20) {
                    Button(action: skipExercise) {
                        Text("Skip Exercise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(15)
                    }
                    
                    Button(action: stopWorkout) {
                        Text("End Workout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(15)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    /// 🔥 **Refactored View 2: START SCREEN**
    private var startScreenView: some View {
        VStack(spacing: 30) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text(routine.name)
                .font(.largeTitle.bold())
            
            // Exercise List Preview
            VStack(alignment: .leading, spacing: 15) {
                Text("Exercises")
                    .font(.headline)
                
                ForEach(sortedExercises) { exercise in
                    HStack {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(exercise.exerciseType.rawValue)
                        
                        Spacer()
                        
                        Text("\(exercise.reps) reps")
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            
            // Sensor Status
            HStack(spacing: 8) {
                Image(systemName: collector.airpodsConnected ? "airpodspro" : "airpodspro.slash")
                    .foregroundColor(collector.airpodsConnected ? .green : .red)
                Text(collector.airpodsConnected ? "AirPods Connected" : "AirPods Not Connected")
                    .font(.caption)
                    .foregroundColor(collector.airpodsConnected ? .green : .red)
                Button(action: { collector.checkAirPodsConnection() }) {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
            }
            
            Button(action: startWorkout) {
                Text("Start Workout")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(20)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    /// 🔥 **Refactored View 3: COMPLETION SCREEN**
    private var completionScreenView: some View {
        WorkoutCompletionView(
            routineName: routine.name,
            duration: Date().timeIntervalSince(workoutStartTime),
            exercisesCompleted: completedCount,
            totalExercises: totalExercises,
            onDismiss: { dismiss() }
        )
    }
    
    // ---
    // MARK: - Private Methods
    // ---
    
    private func setupWorkout() {
        // Initialize remaining reps for each exercise
        for exercise in routine.exercises {
            remainingReps[exercise.exerciseType.rawValue] = exercise.reps
        }
        workoutStartTime = Date()
    }
    
    private func startWorkout() {
        collector.startClassifying()
    }
    
    private func stopWorkout() {
        collector.stopClassifying()
        saveWorkoutToHistory()
        isWorkoutComplete = true
    }
    
    private func skipExercise() {
        moveToNextExercise()
    }
    
    private func updateRemainingReps(oldCounts: [String: Int], newCounts: [String: Int]) {
        guard let currentExercise = currentExercise else { return }
        let exerciseType = currentExercise.exerciseType.rawValue.lowercased()
        
        // Check if the detected exercise matches the current required exercise
        if let newCount = newCounts[exerciseType],
           let oldCount = oldCounts[exerciseType] {
            let repsDone = newCount - oldCount
            if repsDone > 0 {
                // Update remaining reps
                if let remaining = remainingReps[currentExercise.exerciseType.rawValue] {
                    remainingReps[currentExercise.exerciseType.rawValue] = max(0, remaining - repsDone)
                    
                    // Check if exercise is complete
                    if remainingReps[currentExercise.exerciseType.rawValue] == 0 {
                        completeCurrentExercise()
                    }
                }
            }
        }
    }
    
    private func completeCurrentExercise() {
        completedExercises.insert(currentExerciseIndex)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Move to next exercise
        moveToNextExercise()
    }
    
    private func moveToNextExercise() {
        if currentExerciseIndex < sortedExercises.count - 1 {
            currentExerciseIndex += 1
        } else {
            // Workout complete
            stopWorkout()
        }
    }
    
    private func saveWorkoutToHistory() {
        let workout = WorkoutRoutine(date: Date())
        
        // Add completed exercises to the workout
        for (index, exercise) in sortedExercises.enumerated() {
            if completedExercises.contains(index) {
                let completedExercise = Exercise(
                    type: exercise.exerciseType.rawValue,
                    reps: exercise.reps
                )
                workout.exercises.append(completedExercise)
            }
        }
        
        modelContext.insert(workout)
        do {
            try modelContext.save()
        } catch {
            print("Error saving workout: \(error)")
        }
    }
    
    func exerciseColor(_ exercise: String) -> Color {
        switch exercise.lowercased() {
        case "pushup": return .blue
        case "squat": return .green
        case "jumping_jack": return .orange
        default: return .primary
        }
    }
}

// MARK: - Workout Completion View (Unchanged)
struct WorkoutCompletionView: View {
    let routineName: String
    let duration: TimeInterval
    let exercisesCompleted: Int
    let totalExercises: Int
    let onDismiss: () -> Void
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "trophy.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.yellow)
            
            Text("Workout Complete!")
                .font(.largeTitle.bold())
            
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Routine")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(routineName)
                            .font(.headline)
                    }
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formattedDuration)
                            .font(.headline)
                    }
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Exercises Completed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(exercisesCompleted) of \(totalExercises)")
                            .font(.headline)
                    }
                    Spacer()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            
            Spacer()
            
            Button(action: onDismiss) {
                Text("Done")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(20)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Updated ContentView with Guided Workout Option (Unchanged)
extension ContentView {
    func startScreenWithGuidedWorkout() -> some View {
        VStack(spacing: 30) {
            Text("Exercise Classifier")
                .font(.system(size: 36, weight: .bold))
            
            HStack(spacing: 8) {
                Image(systemName: collector.airpodsConnected ? "airpodspro" : "airpodspro.slash")
                    .foregroundColor(collector.airpodsConnected ? .green : .red)
                Text(collector.airpodsConnected ? "AirPods Connected" : "AirPods Not Connected")
                    .font(.caption)
                    .foregroundColor(collector.airpodsConnected ? .green : .red)
                Button(action: { collector.checkAirPodsConnection() }) {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
            }
            
            // Guided Workout Button
            NavigationLink(destination: WorkoutSelectionView()) {
                HStack {
                    Image(systemName: "figure.run.circle")
                    Text("Start Guided Workout")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(20)
            }
            .padding(.horizontal)
            
            NavigationLink(destination: RoutineManagementView()) {
                HStack {
                    Image(systemName: "figure.walk.circle")
                    Text("Build Workout Routines")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(20)
            }
            .padding(.horizontal)
            
            Button(action: { collector.startClassifying() }) {
                VStack(spacing: 10) {
                    Image(systemName: "figure.run").font(.system(size: 60))
                    Text("FREE MODE").font(.system(size: 24, weight: .bold))
                    Text("Real-time exercise detection").font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color.blue)
                .cornerRadius(20)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Workout Selection View (Unchanged)
struct WorkoutSelectionView: View {
    @Query(sort: \RoutineTemplate.name) private var routines: [RoutineTemplate]
    @AppStorage("activeRoutineID") private var activeRoutineID: String?
    
    var activeRoutine: RoutineTemplate? {
        routines.first { $0.id.uuidString == activeRoutineID }
    }
    
    var body: some View {
        List {
            if let active = activeRoutine {
                Section("Active Routine") {
                    NavigationLink(destination: GuidedWorkoutView(routine: active)) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(active.name)
                                    .font(.headline)
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                            Text("\(active.exercises.count) exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            
            Section("All Routines") {
                ForEach(routines) { routine in
                    NavigationLink(destination: GuidedWorkoutView(routine: routine)) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(routine.name)
                                .font(.headline)
                            Text("\(routine.exercises.count) exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .navigationTitle("Select Workout")
        .overlay {
            if routines.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "figure.run",
                    description: Text("Create a workout routine first")
                )
            }
        }
    }
}

// NOTE: I removed the stray "var body: some View {"
// that was at the end of your original file,
// as it was syntactically incorrect.

import SwiftUI
import SwiftData

struct RoutineManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutineTemplate.name) private var routines: [RoutineTemplate]
    @AppStorage("activeRoutineID") private var activeRoutineID: String?
    @State private var showingAddSheet = false

    var body: some View {
        List {
            ForEach(routines) { routine in
                HStack {
                    NavigationLink(destination: EditRoutineView(routine: routine)) {
                        VStack(alignment: .leading) {
                            Text(routine.name)
                                .font(.headline)
                            Text("\(routine.exercises.count) exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if activeRoutineID == routine.id.uuidString {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Button {
                            activeRoutineID = routine.id.uuidString
                        } label: {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .onDelete(perform: deleteRoutines)
        }
        .navigationTitle("Workout Routines")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CreateRoutineView()
        }
        .overlay {
            if routines.isEmpty {
                Text("No routines created.\nTap the '+' button to add one.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func deleteRoutines(at offsets: IndexSet) {
        for index in offsets {
            let routine = routines[index]
            if activeRoutineID == routine.id.uuidString {
                activeRoutineID = nil
            }
            modelContext.delete(routine)
        }
        do {
            try modelContext.save()
        } catch {
            print("Error deleting routine: \(error)")
        }
    }
}

struct CreateRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var routineName = ""
    @State private var exercises: [TempExercise] = []
    @State private var showingAddExercise = false
    
    struct TempExercise: Identifiable {
        let id = UUID()
        let type: ExerciseType
        let reps: Int
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Routine Name") {
                    TextField("e.g., Morning Workout", text: $routineName)
                }
                
                Section("Exercises") {
                    if exercises.isEmpty {
                        Text("No exercises added")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(exercises) { exercise in
                            HStack {
                                Text(exercise.type.rawValue)
                                Spacer()
                                Text("\(exercise.reps) reps")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteExercise)
                    }
                    
                    Button {
                        showingAddExercise = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                    }
                }
            }
            .navigationTitle("New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRoutine()
                    }
                    .disabled(routineName.isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView { type, reps in
                    exercises.append(TempExercise(type: type, reps: reps))
                }
            }
        }
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }
    
    private func saveRoutine() {
        let newRoutine = RoutineTemplate(name: routineName)
        
        for tempExercise in exercises {
            let exercise = ExerciseTemplate(
                exerciseType: tempExercise.type,
                reps: tempExercise.reps
            )
            exercise.routine = newRoutine
            newRoutine.exercises.append(exercise)
        }
        
        modelContext.insert(newRoutine)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving routine: \(error)")
        }
    }
}

struct EditRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var routine: RoutineTemplate
    @State private var showingAddExercise = false

    var body: some View {
        Form {
            Section("Routine Name") {
                TextField("Routine name", text: $routine.name)
            }
            
            Section("Exercises") {
                if routine.exercises.isEmpty {
                    Text("No exercises")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(routine.exercises.sorted(by: { $0.exerciseType.rawValue < $1.exerciseType.rawValue })) { exercise in
                        HStack {
                            Text(exercise.exerciseType.rawValue)
                            Spacer()
                            Text("\(exercise.reps) reps")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteExercise)
                }
                
                Button {
                    showingAddExercise = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Exercise")
                    }
                }
            }
        }
        .navigationTitle("Edit Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    do {
                        try modelContext.save()
                        dismiss()
                    } catch {
                        print("Error saving changes: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView { type, reps in
                let newExercise = ExerciseTemplate(exerciseType: type, reps: reps)
                newExercise.routine = routine
                routine.exercises.append(newExercise)
                do {
                    try modelContext.save()
                } catch {
                    print("Error adding exercise: \(error)")
                }
            }
        }
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        let exercisesToDelete = offsets.map {
            routine.exercises.sorted(by: { $0.exerciseType.rawValue < $1.exerciseType.rawValue })[$0]
        }
        for exercise in exercisesToDelete {
            if let index = routine.exercises.firstIndex(where: { $0.id == exercise.id }) {
                routine.exercises.remove(at: index)
            }
        }
        do {
            try modelContext.save()
        } catch {
            print("Error deleting exercise: \(error)")
        }
    }
}

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    
    var onAdd: (ExerciseType, Int) -> Void
    
    @State private var type: ExerciseType = .pushup
    @State private var reps: Int = 10

    var body: some View {
        NavigationStack {
            Form {
                Picker("Exercise Type", selection: $type) {
                    ForEach(ExerciseType.allCases) { exType in
                        Text(exType.rawValue).tag(exType)
                    }
                }
                
                Stepper("Reps: \(reps)", value: $reps, in: 1...100)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(type, reps)
                        dismiss()
                    }
                }
            }
        }
    }
}

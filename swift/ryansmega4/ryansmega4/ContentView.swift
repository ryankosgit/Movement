import SwiftUI
import CoreMotion
import Combine
import SwiftData


struct WorkoutDetailView: View {
    let routine: WorkoutRoutine
    
    var body: some View {
        List {
            Section(header: Text("Summary")) {
                Text(routine.date, format: .dateTime.day().month().year().hour().minute())
            }
            
            Section(header: Text("Exercises")) {
                ForEach(routine.exercises.sorted(by: { $0.type < $1.type })) { exercise in
                    HStack {
                        Text(exercise.type.capitalized)
                            .font(.headline)
                        Spacer()
                        Text("\(exercise.reps) reps")
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@Model
final class WorkoutRoutine {
    @Attribute(.unique) var id: UUID
    var date: Date
    
    // This tells SwiftData that a routine can have many exercises,
    // and if we delete the routine, it should also delete
    // all the exercises associated with it.
    @Relationship(deleteRule: .cascade, inverse: \Exercise.routine)
    var exercises: [Exercise] = [] // Must be initialized

    init(date: Date, exercises: [Exercise] = []) {
        self.id = UUID()
        self.date = date
        self.exercises = exercises
    }
}

@Model
final class Exercise: Identifiable {
    var id: UUID
    var type: String // "pushup", "squat", etc.
    var reps: Int
    var routine: WorkoutRoutine? // Connects back to the parent routine
    
    init(type: String, reps: Int) {
        self.id = UUID()
        self.type = type
        self.reps = reps
    }
}
enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case pushup = "Pushup"
    case jumping_jack = "Jumping Jack"
    case squat = "Squat"
    
    var id: Self { self }
}

// --- NEW: The template for a single exercise (e.g., "10 Pushups") ---
@Model
final class ExerciseTemplate: Identifiable {
    var id: UUID
    var exerciseType: ExerciseType
    var reps: Int
    var routine: RoutineTemplate?

    
    init(exerciseType: ExerciseType, reps: Int) {
        self.id = UUID()
        self.exerciseType = exerciseType
        self.reps = reps
    }
}

// --- NEW: The template for a full routine (e.g., "Morning Workout") ---
@Model
final class RoutineTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    
    // This tells SwiftData to delete all exercises if the routine is deleted
    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.routine)
    var exercises: [ExerciseTemplate] = []

    init(id: UUID = UUID(), name: String, exercises: [ExerciseTemplate] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

// --- YOUR DATACOLLECTOR CLASS ---
// --- NO CHANGES NEEDED HERE ---
class DataCollector: ObservableObject {
    private let phone = CMMotionManager()
    private let airpods = CMHeadphoneMotionManager()
    
    @Published var isClassifying = false
    @Published var airpodsConnected = false
    
    private var latestPhoneData: (accel: (x: Double, y: Double, z: Double),
                                    gyro: (x: Double, y: Double, z: Double)) = ((0, 0, 0), (0, 0, 0))
    private var latestAirPodsData: (accel: (x: Double, y: Double, z: Double),
                                      gyro: (x: Double, y: Double, z: Double)) = ((0, 0, 0), (0, 0, 0))
    
    let exerciseClassifier = RealtimeExerciseClassifier()
    private var cancellable: AnyCancellable?
    
    init() {
        checkAirPodsConnection()
        
        cancellable = exerciseClassifier.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
    func checkAirPodsConnection() {
        airpodsConnected = airpods.isDeviceMotionAvailable
        print("AirPods available: \(airpodsConnected)")
    }
    
    func startClassifying() {
        print("Starting real-time classification...")
        isClassifying = true
        if !phone.isDeviceMotionAvailable { print("ERROR: Phone motion not available"); return }
        
        if airpods.isDeviceMotionAvailable {
            print("Starting AirPods motion tracking...")
            airpods.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion, let self = self else { return }
                self.latestAirPodsData = (
                    accel: (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z),
                    gyro: (motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
                )
            }
        }
        
        phone.deviceMotionUpdateInterval = 0.02
        phone.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }
            self.latestPhoneData = (
                accel: (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z),
                gyro: (motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
            )
            self.exerciseClassifier.classify(
                phoneAccel: self.latestPhoneData.accel,
                phoneGyro: self.latestPhoneData.gyro,
                airpodsAccel: self.latestAirPodsData.accel,
                airpodsGyro: self.latestAirPodsData.gyro
            )
        }
        print("Real-time classification started")
    }
    
    func stopClassifying() {
        print("Stopping classification...")
        phone.stopDeviceMotionUpdates()
        airpods.stopDeviceMotionUpdates()
        exerciseClassifier.reset()
        isClassifying = false
    }
}

struct ContentView: View {
    @StateObject var collector = DataCollector()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                
                if !collector.isClassifying {
                    // START SCREEN WITH NEW GUIDED WORKOUT OPTION
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
                        
                        // NEW: Guided Workout Button
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
                    
                } else {
                    // FREE MODE CLASSIFICATION SCREEN (unchanged)
                    ScrollView {
                        VStack(spacing: 20) {
                            Text("Exercise Detection - Free Mode")
                                .font(.headline)
                            
                            // Sensor status
                            HStack(spacing: 20) {
                                VStack {
                                    Image(systemName: "iphone").foregroundColor(.green)
                                    Text("Phone").font(.caption)
                                }
                                if collector.airpodsConnected {
                                    VStack {
                                        Image(systemName: "airpodspro").foregroundColor(.green)
                                        Text("AirPods").font(.caption)
                                    }
                                }
                            }
                            
                            // Main exercise display
                            VStack(spacing: 10) {
                                Text(collector.exerciseClassifier.currentExercise.uppercased())
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(exerciseColor(collector.exerciseClassifier.currentExercise))
                                
                                MotionTracker(
                                    exercise: collector.exerciseClassifier.currentExercise,
                                    p_gx: collector.exerciseClassifier.p_gx_mean,
                                    p_gy: collector.exerciseClassifier.p_gy_mean,
                                    p_gz: collector.exerciseClassifier.p_gz_mean
                                )
                                .frame(height: 60)
                                .padding(.horizontal, 40)
                            }
                            .padding(30)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                            
                            // Rep count list
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Total Reps")
                                    .font(.title3.bold())
                                    .padding(.bottom, 5)
                                
                                ForEach(collector.exerciseClassifier.repCounts.sorted(by: { $0.key < $1.key }), id: \.key) { exercise, count in
                                    HStack {
                                        Text(exercise.capitalized)
                                            .font(.body)
                                        Spacer()
                                        Text("\(count)")
                                            .font(.body.bold())
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                            
                            // Live Sensor Data
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Live Sensor Data")
                                    .font(.title3.bold())
                                    .padding(.bottom, 5)
                                
                                // Phone Sensors
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("📱 Phone")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Accel").font(.caption).foregroundColor(.secondary)
                                            SensorRow(label: "X", value: collector.exerciseClassifier.p_ax_mean)
                                            SensorRow(label: "Y", value: collector.exerciseClassifier.p_ay_mean)
                                            SensorRow(label: "Z", value: collector.exerciseClassifier.p_az_mean)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Gyro").font(.caption).foregroundColor(.secondary)
                                            SensorRow(label: "X", value: collector.exerciseClassifier.p_gx_mean)
                                            SensorRow(label: "Y", value: collector.exerciseClassifier.p_gy_mean)
                                            SensorRow(label: "Z", value: collector.exerciseClassifier.p_gz_mean)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(10)
                                
                                // AirPods Sensors
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("🎧 AirPods")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Accel").font(.caption).foregroundColor(.secondary)
                                            SensorRow(label: "X", value: collector.exerciseClassifier.a_ax_mean)
                                            SensorRow(label: "Y", value: collector.exerciseClassifier.a_ay_mean)
                                            SensorRow(label: "Z", value: collector.exerciseClassifier.a_az_mean)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Gyro").font(.caption).foregroundColor(.secondary)
                                            SensorRow(label: "X", value: collector.exerciseClassifier.a_gx_mean)
                                            SensorRow(label: "Y", value: collector.exerciseClassifier.a_gy_mean)
                                            SensorRow(label: "Z", value: collector.exerciseClassifier.a_gz_mean)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.green.opacity(0.05))
                                .cornerRadius(10)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                            
                            // Stop button
                            Button("STOP") {
                                collector.stopClassifying()
                            }
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(15)
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            collector.checkAirPodsConnection()
        }
    }
    
    func exerciseColor(_ exercise: String) -> Color {
        switch exercise.lowercased() {
        case "pushup": return .blue
        case "squat": return .green
        case "jumping_jack": return .orange
        case "rest": return .gray
        default: return .primary
        }
    }
}

struct SensorRow: View {
    let label: String
    let value: Double
    
    var body: some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 15, alignment: .leading)
            Text(String(format: "%.3f", value))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(colorForValue(value))
        }
    }
    
    func colorForValue(_ value: Double) -> Color {
        let absValue = abs(value)
        if absValue > 0.5 { return .red }
        if absValue > 0.2 { return .orange }
        return .primary
    }
}

struct MotionTracker: View {
    let exercise: String
    let p_gx: Double
    let p_gy: Double
    let p_gz: Double
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                Text(movementLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    Circle()
                        .fill(exerciseColor(exercise))
                        .frame(width: 24, height: 24)
                        .shadow(color: exerciseColor(exercise).opacity(0.5), radius: 4)
                        .offset(x: ballPosition(trackWidth: geometry.size.width))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: sensorValue)
                }
                .frame(width: geometry.size.width * 0.8)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    var sensorValue: Double {
        switch exercise.lowercased() {
        case "squat":
            return p_gx
        case "pushup":
            return p_gy
        case "jumping_jack":
            return p_gz
        default:
            return 0.0
        }
    }
    
    var movementLabel: String {
        switch exercise.lowercased() {
        case "squat":
            return sensorValue < -0.2 ? "⬇ Down" : sensorValue > 0.2 ? "⬆ Up" : "—"
        case "pushup":
            return sensorValue > 0.2 ? "⬇ Down" : sensorValue < -0.2 ? "⬆ Up" : "—"
        case "jumping_jack":
            return sensorValue > 0.2 ? "⬅ Out" : sensorValue < -0.2 ? "➡ In" : "—"
        default:
            return "—"
        }
    }
    
    func ballPosition(trackWidth: CGFloat) -> CGFloat {
        let clampedValue = max(-1.0, min(1.0, sensorValue))
        let actualTrackWidth = trackWidth * 0.8
        let normalizedPosition = (clampedValue + 1.0) / 2.0
        let position = normalizedPosition * actualTrackWidth
        let ballRadius: CGFloat = 12
        let offsetPosition = position - ballRadius
        return max(0, min(actualTrackWidth - (ballRadius * 2), offsetPosition))
    }
    
    func exerciseColor(_ exercise: String) -> Color {
        switch exercise.lowercased() {
        case "pushup": return .blue
        case "squat": return .green
        case "jumping_jack": return .orange
        default: return .gray
        }
    }
}

#Preview {
    ContentView()
}

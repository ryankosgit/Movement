import CoreML
import Foundation
import Combine // <-- Import Combine

// 1. Define the states for our state machine
private enum RepState {
    case rest, active
}

class RealtimeExerciseClassifier: ObservableObject {
    @Published var currentExercise: String = "Unknown"
    @Published var confidence: Double = 0.0
    
    // --- NEW PROPERTIES FOR REP COUNTING ---
    
    // 2. Define which exercises to count (must match your model's class names)
    private let countableExercises: Set<String> = ["squat", "pushup", "jumping_jack"]
    
    // 3. A published dictionary to hold the rep counts for the UI
    @Published var repCounts: [String: Int] = [:]
    
    // 4. A private dictionary to track the state for each exercise
    private var exerciseState: [String: RepState] = [:]
    
    // --- END NEW PROPERTIES ---
    
    private var model: ExerciseClassifier_Windowed?
    private var sensorBuffer: [(phone: (ax: Double, ay: Double, az: Double, gx: Double, gy: Double, gz: Double),
                                airpods: (ax: Double, ay: Double, az: Double, gx: Double, gy: Double, gz: Double))] = []
    
    private let windowSize = 75
    private let classifyInterval = 25
    private var sampleCount = 0
    
    init() {
        do {
            let config = MLModelConfiguration()
            model = try ExerciseClassifier_Windowed(configuration: config)
            print("✅ CoreML model loaded successfully")
            
            // 6. Initialize counts and states for countable exercises
            for exercise in countableExercises {
                repCounts[exercise] = 0
                exerciseState[exercise] = .rest
            }
            
        } catch {
            print("❌ Failed to load CoreML model: \(error)")
        }
    }
    
    func classify(phoneAccel: (x: Double, y: Double, z: Double),
                  phoneGyro: (x: Double, y: Double, z: Double),
                  airpodsAccel: (x: Double, y: Double, z: Double),
                  airpodsGyro: (x: Double, y: Double, z: Double)) {
        
        guard let model = model else {
            print("Model not loaded")
            return
        }
        
        // ... (Buffering logic remains exactly the same) ...
        let sample = (
            phone: (phoneAccel.x, phoneAccel.y, phoneAccel.z, phoneGyro.x, phoneGyro.y, phoneGyro.z),
            airpods: (airpodsAccel.x, airpodsAccel.y, airpodsAccel.z, airpodsGyro.x, airpodsGyro.y, airpodsGyro.z)
        )
        sensorBuffer.append(sample)
        if sensorBuffer.count > windowSize {
            sensorBuffer.removeFirst()
        }
        sampleCount += 1
        if sampleCount % classifyInterval != 0 {
            return
        }
        guard sensorBuffer.count >= windowSize else {
            print("Buffering... \(sensorBuffer.count)/\(windowSize)")
            return
        }
        
        let features = extractWindowFeatures()
        
        do {
            let input = ExerciseClassifier_WindowedInput(
                p_ax_mean: features[0], p_ax_std: features[1],
                p_ay_mean: features[2], p_ay_std: features[3],
                p_az_mean: features[4], p_az_std: features[5],
                p_gx_mean: features[6], p_gx_std: features[7],
                p_gy_mean: features[8], p_gy_std: features[9],
                p_gz_mean: features[10], p_gz_std: features[11],
                a_ax_mean: features[12], a_ax_std: features[13],
                a_ay_mean: features[14], a_ay_std: features[15],
                a_az_mean: features[16], a_az_std: features[17],
                a_gx_mean: features[18], a_gx_std: features[19],
                a_gy_mean: features[20], a_gy_std: features[21],
                a_gz_mean: features[22], a_gz_std: features[23]
            )
            
            let prediction = try model.prediction(input: input)
            let predictedExercise = prediction.label
            
            // --- 5. STATE MACHINE LOGIC ---
            // This must be on the main thread since it updates @Published properties
            DispatchQueue.main.async {
                self.currentExercise = predictedExercise
                self.confidence = 0.0
                
                // Loop through all exercises we care about counting
                for exercise in self.countableExercises {
                    // Get the current state for this exercise
                    let currentState = self.exerciseState[exercise, default: .rest]
                    
                    // CASE 1: The model is detecting this exercise RIGHT NOW
                    if predictedExercise == exercise {
                        // If we were previously at rest, we are now "active"
                        // This is the START of a rep
                        if currentState == .rest {
                            self.exerciseState[exercise] = .active
                        }
                    
                    // CASE 2: The model is NOT detecting this exercise
                    } else {
                        // If we were "active", we are now "at rest"
                        // This is the END of a rep. COUNT IT!
                        if currentState == .active {
                            self.exerciseState[exercise] = .rest
                            self.repCounts[exercise, default: 0] += 1
                            print("✅ COUNTED 1 REP for \(exercise). Total: \(self.repCounts[exercise]!)")
                        }
                    }
                }
            }
            // --- END STATE MACHINE LOGIC ---
            
        } catch {
            print("❌ Prediction error: \(error)")
        }
    }
    
    // ... (extractWindowFeatures, mean, std functions are unchanged) ...
    private func extractWindowFeatures() -> [Double] {
        // ... (no changes) ...
        guard sensorBuffer.count >= windowSize else { return Array(repeating: 0.0, count: 24) }
        var features: [Double] = []
        let p_ax_values = sensorBuffer.map { $0.phone.ax }; features.append(mean(p_ax_values)); features.append(std(p_ax_values))
        let p_ay_values = sensorBuffer.map { $0.phone.ay }; features.append(mean(p_ay_values)); features.append(std(p_ay_values))
        let p_az_values = sensorBuffer.map { $0.phone.az }; features.append(mean(p_az_values)); features.append(std(p_az_values))
        let p_gx_values = sensorBuffer.map { $0.phone.gx }; features.append(mean(p_gx_values)); features.append(std(p_gx_values))
        let p_gy_values = sensorBuffer.map { $0.phone.gy }; features.append(mean(p_gy_values)); features.append(std(p_gy_values))
        let p_gz_values = sensorBuffer.map { $0.phone.gz }; features.append(mean(p_gz_values)); features.append(std(p_gz_values))
        let a_ax_values = sensorBuffer.map { $0.airpods.ax }; features.append(mean(a_ax_values)); features.append(std(a_ax_values))
        let a_ay_values = sensorBuffer.map { $0.airpods.ay }; features.append(mean(a_ay_values)); features.append(std(a_ay_values))
        let a_az_values = sensorBuffer.map { $0.airpods.az }; features.append(mean(a_az_values)); features.append(std(a_az_values))
        let a_gx_values = sensorBuffer.map { $0.airpods.gx }; features.append(mean(a_gx_values)); features.append(std(a_gx_values))
        let a_gy_values = sensorBuffer.map { $0.airpods.gy }; features.append(mean(a_gy_values)); features.append(std(a_gy_values))
        let a_gz_values = sensorBuffer.map { $0.airpods.gz }; features.append(mean(a_gz_values)); features.append(std(a_gz_values))
        return features
    }
    private func mean(_ values: [Double]) -> Double { /* ... (no changes) ... */ guard !values.isEmpty else { return 0.0 }; return values.reduce(0.0, +) / Double(values.count) }
    private func std(_ values: [Double]) -> Double { /* ... (no changes) ... */ guard values.count > 1 else { return 0.0 }; let m = mean(values); let variance = values.map { pow($0 - m, 2) }.reduce(0.0, +) / Double(values.count - 1); return sqrt(variance) }

    
    // 6. Update reset() to clear the new properties
    func reset() {
        sensorBuffer.removeAll()
        sampleCount = 0
        currentExercise = "Unknown"
        confidence = 0.0
        
        // Reset counts and states
        for exercise in countableExercises {
            repCounts[exercise] = 0
            exerciseState[exercise] = .rest
        }
        print("Classifier reset. Rep counts zeroed.")
    }
}

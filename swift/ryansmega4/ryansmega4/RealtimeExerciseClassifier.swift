import CoreML
import Foundation
import Combine

private enum RepState {
    case idle
    case goingDown
    case goingUp
}

class RealtimeExerciseClassifier: ObservableObject {
    @Published var currentExercise: String = "rest"
    @Published var repCounts: [String: Int] = [:]
    
    // Published mean sensor values for real-time display
    @Published var p_ax_mean: Double = 0.0
    @Published var p_ay_mean: Double = 0.0
    @Published var p_az_mean: Double = 0.0
    @Published var p_gx_mean: Double = 0.0
    @Published var p_gy_mean: Double = 0.0
    @Published var p_gz_mean: Double = 0.0
    @Published var a_ax_mean: Double = 0.0
    @Published var a_ay_mean: Double = 0.0
    @Published var a_az_mean: Double = 0.0
    @Published var a_gx_mean: Double = 0.0
    @Published var a_gy_mean: Double = 0.0
    @Published var a_gz_mean: Double = 0.0
    
    // Make sure your exercise names here match your model's output
    private let countableExercises: Set<String> = ["squat", "pushup", "jumping_jack"]
    
    private var exerciseState: [String: RepState] = [:]
    
    // Min/Max tracking for each exercise
    private var squatMinMax: [String: (min: Double, max: Double)] = [:]
    private var pushupMinMax: [String: (min: Double, max: Double)] = [:]
    private var jumpingJackMinMax: [String: (min: Double, max: Double)] = [:]
    
    // History tracking for peak detection
    private var p_gz_history: [Double] = []
    private var p_gy_history: [Double] = []
    private var p_gx_history: [Double] = []
    
    // Debouncing - prevent multiple counts for single rep
    private var lastRepTime: [String: Date] = [:]
    private let repCooldown: TimeInterval = 0.1  // Half second between reps
    
    private var model: ExerciseClassifier_Windowed?
    private var sensorBuffer: [(phone: (ax: Double, ay: Double, az: Double, gx: Double, gy: Double, gz: Double),
                                airpods: (ax: Double, ay: Double, az: Double, gx: Double, gy: Double, gz: Double))] = []
    private let windowSize = 75
    private let classifyInterval = 10
    private var sampleCount = 0
    
    init() {
        do {
            let config = MLModelConfiguration()
            model = try ExerciseClassifier_Windowed(configuration: config)
            print("✅ CoreML model loaded successfully")
            
            for exercise in countableExercises {
                repCounts[exercise] = 0
                exerciseState[exercise] = .idle
            }
        } catch {
            print("❌ Failed to load CoreML model: \(error)")
        }
    }
    
    func classify(phoneAccel: (x: Double, y: Double, z: Double),
                  phoneGyro: (x: Double, y: Double, z: Double),
                  airpodsAccel: (x: Double, y: Double, z: Double),
                  airpodsGyro: (x: Double, y: Double, z: Double)) {
        
        guard let model = model else { return }
        
        // ... (Buffering logic is unchanged) ...
        let sample = (
            phone: (phoneAccel.x, phoneAccel.y, phoneAccel.z, phoneGyro.x, phoneGyro.y, phoneGyro.z),
            airpods: (airpodsAccel.x, airpodsAccel.y, airpodsAccel.z, airpodsGyro.x, airpodsGyro.y, airpodsGyro.z)
        )
        sensorBuffer.append(sample)
        if sensorBuffer.count > windowSize { sensorBuffer.removeFirst() }
        sampleCount += 1
        if sampleCount % classifyInterval != 0 { return }
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
            
            DispatchQueue.main.async {
                self.currentExercise = predictedExercise
                
                // Update all mean sensor values for display
                self.p_ax_mean = features[0]
                self.p_ay_mean = features[2]
                self.p_az_mean = features[4]
                self.p_gx_mean = features[6]
                self.p_gy_mean = features[8]
                self.p_gz_mean = features[10]
                self.a_ax_mean = features[12]
                self.a_ay_mean = features[14]
                self.a_az_mean = features[16]
                self.a_gx_mean = features[18]
                self.a_gy_mean = features[20]
                self.a_gz_mean = features[22]
                
                print("\n--- Prediction: \(predictedExercise) ---")
                
                // --- CALL ALL STATE MACHINES ---
                self.handleSquatRep(predicted: predictedExercise, features: features)
                self.handlePushupRep(predicted: predictedExercise, features: features)
                self.handleJumpingJackRep(predicted: predictedExercise, features: features)
            }
            
        } catch {
            print("❌ Prediction error: \(error)")
        }
    }
    
    func reset() {
        sensorBuffer.removeAll()
        sampleCount = 0
        currentExercise = "Unknown"

        
        for exercise in countableExercises {
            repCounts[exercise] = 0
            exerciseState[exercise] = .idle
        }
        
        // Reset min/max tracking
        squatMinMax.removeAll()
        pushupMinMax.removeAll()
        jumpingJackMinMax.removeAll()
        
        // Reset history tracking
        p_gz_history.removeAll()
        p_gy_history.removeAll()
        p_gx_history.removeAll()
        
        // Reset debouncing
        lastRepTime.removeAll()
        
        print("Classifier reset. Rep counts zeroed.")
    }

    //
    // MARK: - Rep Counting State Machines
    //
    
    private func handleSquatRep(predicted: String, features: [Double]) {
        let exerciseName = "squat"
        
        // Reset if doing a different exercise
        let currentState = self.exerciseState[exerciseName, default: .idle]
        if predicted != exerciseName && currentState != .idle {
            self.exerciseState[exerciseName] = .idle
            print("Logger [\(exerciseName.uppercased())]: Resetting to idle (different exercise detected)")
            return
        }
        
        // Update min/max for all sensor values
        updateMinMax(dict: &squatMinMax, key: "p_ax", value: features[0])
        updateMinMax(dict: &squatMinMax, key: "p_ay", value: features[2])
        updateMinMax(dict: &squatMinMax, key: "p_az", value: features[4])
        updateMinMax(dict: &squatMinMax, key: "p_gx", value: features[6])
        updateMinMax(dict: &squatMinMax, key: "p_gy", value: features[8])
        updateMinMax(dict: &squatMinMax, key: "p_gz", value: features[10])
        updateMinMax(dict: &squatMinMax, key: "a_ax", value: features[12])
        updateMinMax(dict: &squatMinMax, key: "a_ay", value: features[14])
        updateMinMax(dict: &squatMinMax, key: "a_az", value: features[16])
        updateMinMax(dict: &squatMinMax, key: "a_gx", value: features[18])
        updateMinMax(dict: &squatMinMax, key: "a_gy", value: features[20])
        updateMinMax(dict: &squatMinMax, key: "a_gz", value: features[22])
        
        if predicted == exerciseName {
            print("--- SQUAT SENSOR DEBUG WITH MIN/MAX ---")
            printSensorWithMinMax(label: "p_ax", value: features[0], dict: squatMinMax, key: "p_ax")
            printSensorWithMinMax(label: "p_ay", value: features[2], dict: squatMinMax, key: "p_ay")
            printSensorWithMinMax(label: "p_az", value: features[4], dict: squatMinMax, key: "p_az")
            printSensorWithMinMax(label: "p_gx", value: features[6], dict: squatMinMax, key: "p_gx")
            printSensorWithMinMax(label: "p_gy", value: features[8], dict: squatMinMax, key: "p_gy")
            printSensorWithMinMax(label: "p_gz", value: features[10], dict: squatMinMax, key: "p_gz")
            printSensorWithMinMax(label: "a_ax", value: features[12], dict: squatMinMax, key: "a_ax")
            printSensorWithMinMax(label: "a_ay", value: features[14], dict: squatMinMax, key: "a_ay")
            printSensorWithMinMax(label: "a_az", value: features[16], dict: squatMinMax, key: "a_az")
            printSensorWithMinMax(label: "a_gx", value: features[18], dict: squatMinMax, key: "a_gx")
            printSensorWithMinMax(label: "a_gy", value: features[20], dict: squatMinMax, key: "a_gy")
            printSensorWithMinMax(label: "a_gz", value: features[22], dict: squatMinMax, key: "a_gz")
            print("---")
        }
        
        let motionTrigger = features[6] // Phone Gyro z
        let downThreshold = -0.8
        let upThreshold = 0.8

        if predicted == exerciseName || currentState != .idle {
            print("Logger [SQUAT]: Status = \(currentState), GyroX-Mean = \(String(format: "%.2f", motionTrigger))")
        }

        if predicted == exerciseName {
            switch currentState {
            case .idle:
                if motionTrigger < downThreshold {
                    self.exerciseState[exerciseName] = .goingDown
                    print("Logger [SQUAT]: STATE CHANGE: idle -> goingDown (Down-stroke)")
                }
            case .goingDown:
                if motionTrigger > upThreshold {
                    self.exerciseState[exerciseName] = .goingUp
                    print("Logger [SQUAT]: STATE CHANGE: goingDown -> goingUp (Up-stroke)")
                }
            case .goingUp:
                if motionTrigger < downThreshold {
                    // Check cooldown to prevent multiple counts
                    let now = Date()
                    let lastTime = self.lastRepTime[exerciseName] ?? Date.distantPast
                    
                    if now.timeIntervalSince(lastTime) > self.repCooldown {
                        self.exerciseState[exerciseName] = .goingDown
                        self.repCounts[exerciseName, default: 0] += 1
                        self.lastRepTime[exerciseName] = now
                        print("Logger [SQUAT]: STATE CHANGE: goingUp -> goingDown (New Rep). +1 REP. Total: \(self.repCounts[exerciseName]!)")
                    } else {
                        print("Logger [SQUAT]: Rep blocked by cooldown (too soon)")
                    }
                }
            }
        } else {
            // --- *** THIS IS THE FIX *** ---
            // Only count and reset if we were on the way UP.
            // If we were .goingDown, we'll hold that state and survive the flicker.
            if currentState == .goingUp {
                self.repCounts[exerciseName, default: 0] += 1
                print("Logger [SQUAT]: STATE CHANGE: goingUp -> idle (Rep Finished). +1 REP. Total: \(self.repCounts[exerciseName]!)")
                self.exerciseState[exerciseName] = .idle
            }
        }
    }
    
    private func handlePushupRep(predicted: String, features: [Double]) {
        let exerciseName = "pushup"
        
        // Reset if doing a different exercise
        let currentState = self.exerciseState[exerciseName, default: .idle]
        if predicted != exerciseName && currentState != .idle {
            self.exerciseState[exerciseName] = .idle
            print("Logger [\(exerciseName.uppercased())]: Resetting to idle (different exercise detected)")
            return
        }
        
        // Update min/max for all sensor values
        updateMinMax(dict: &pushupMinMax, key: "p_ax", value: features[0])
        updateMinMax(dict: &pushupMinMax, key: "p_ay", value: features[2])
        updateMinMax(dict: &pushupMinMax, key: "p_az", value: features[4])
        updateMinMax(dict: &pushupMinMax, key: "p_gx", value: features[6])
        updateMinMax(dict: &pushupMinMax, key: "p_gy", value: features[8])
        updateMinMax(dict: &pushupMinMax, key: "p_gz", value: features[10])
        updateMinMax(dict: &pushupMinMax, key: "a_ax", value: features[12])
        updateMinMax(dict: &pushupMinMax, key: "a_ay", value: features[14])
        updateMinMax(dict: &pushupMinMax, key: "a_az", value: features[16])
        updateMinMax(dict: &pushupMinMax, key: "a_gx", value: features[18])
        updateMinMax(dict: &pushupMinMax, key: "a_gy", value: features[20])
        updateMinMax(dict: &pushupMinMax, key: "a_gz", value: features[22])
        
        if predicted == exerciseName {
            print("--- PUSHUP SENSOR DEBUG WITH MIN/MAX ---")
            printSensorWithMinMax(label: "p_ax", value: features[0], dict: pushupMinMax, key: "p_ax")
            printSensorWithMinMax(label: "p_ay", value: features[2], dict: pushupMinMax, key: "p_ay")
            printSensorWithMinMax(label: "p_az", value: features[4], dict: pushupMinMax, key: "p_az")
            printSensorWithMinMax(label: "p_gx", value: features[6], dict: pushupMinMax, key: "p_gx")
            printSensorWithMinMax(label: "p_gy", value: features[8], dict: pushupMinMax, key: "p_gy")
            printSensorWithMinMax(label: "p_gz", value: features[10], dict: pushupMinMax, key: "p_gz")
            printSensorWithMinMax(label: "a_ax", value: features[12], dict: pushupMinMax, key: "a_ax")
            printSensorWithMinMax(label: "a_ay", value: features[14], dict: pushupMinMax, key: "a_ay")
            printSensorWithMinMax(label: "a_az", value: features[16], dict: pushupMinMax, key: "a_az")
            printSensorWithMinMax(label: "a_gx", value: features[18], dict: pushupMinMax, key: "a_gx")
            printSensorWithMinMax(label: "a_gy", value: features[20], dict: pushupMinMax, key: "a_gy")
            printSensorWithMinMax(label: "a_gz", value: features[22], dict: pushupMinMax, key: "a_gz")
            print("---")
        }
        
        let motionTrigger = features[6] // phone z gyro
        let downThreshold = 0.1 // Lowered from 0.25 for better detection
        let upThreshold = -0.1

        if predicted == exerciseName || currentState != .idle {
            print("Logger [PUSHUP]: Status = \(currentState), p_gy_mean = \(String(format: "%.2f", motionTrigger))")
        }

        if predicted == exerciseName {
            switch currentState {
            case .idle:
                if motionTrigger > downThreshold {
                    self.exerciseState[exerciseName] = .goingDown
                    print("Logger [PUSHUP]: STATE CHANGE: idle -> goingDown (Down-stroke)")
                }
            case .goingDown:
                if motionTrigger < upThreshold {
                    self.exerciseState[exerciseName] = .goingUp
                    print("Logger [PUSHUP]: STATE CHANGE: goingDown -> goingUp (Up-stroke)")
                }
            case .goingUp:
                if motionTrigger > downThreshold {
                    // Check cooldown to prevent multiple counts
                    let now = Date()
                    let lastTime = self.lastRepTime[exerciseName] ?? Date.distantPast
                    
                    if now.timeIntervalSince(lastTime) > self.repCooldown {
                        self.exerciseState[exerciseName] = .goingDown
                        self.repCounts[exerciseName, default: 0] += 1
                        self.lastRepTime[exerciseName] = now
                        print("Logger [PUSHUP]: STATE CHANGE: goingUp -> goingDown (New Rep). +1 REP. Total: \(self.repCounts[exerciseName]!)")
                    } else {
                        print("Logger [PUSHUP]: Rep blocked by cooldown (too soon)")
                    }
                }
            }
        } else {
            // --- *** THIS IS THE FIX *** ---
            // Only count and reset if we were on the way UP.
            // If we were .goingDown, we'll hold that state and survive the flicker.
            if currentState == .goingUp {
                self.repCounts[exerciseName, default: 0] += 1
                print("Logger [PUSHUP]: STATE CHANGE: goingUp -> idle (Rep Finished). +1 REP. Total: \(self.repCounts[exerciseName]!)")
                self.exerciseState[exerciseName] = .idle
            }
        }
    }
    
    private func handleJumpingJackRep(predicted: String, features: [Double]) {
        let exerciseName = "jumping_jack"
        
        // Reset if doing a different exercise
        let currentState = self.exerciseState[exerciseName, default: .idle]
        if predicted != exerciseName && currentState != .idle {
            self.exerciseState[exerciseName] = .idle
            print("Logger [\(exerciseName.uppercased())]: Resetting to idle (different exercise detected)")
            return
        }
        
        // Update min/max for all sensor values
        updateMinMax(dict: &jumpingJackMinMax, key: "p_ax", value: features[0])
        updateMinMax(dict: &jumpingJackMinMax, key: "p_ay", value: features[2])
        updateMinMax(dict: &jumpingJackMinMax, key: "p_az", value: features[4])
        updateMinMax(dict: &jumpingJackMinMax, key: "p_gx", value: features[6])
        updateMinMax(dict: &jumpingJackMinMax, key: "p_gy", value: features[8])
        updateMinMax(dict: &jumpingJackMinMax, key: "p_gz", value: features[10])
        updateMinMax(dict: &jumpingJackMinMax, key: "a_ax", value: features[12])
        updateMinMax(dict: &jumpingJackMinMax, key: "a_ay", value: features[14])
        updateMinMax(dict: &jumpingJackMinMax, key: "a_az", value: features[16])
        updateMinMax(dict: &jumpingJackMinMax, key: "a_gx", value: features[18])
        updateMinMax(dict: &jumpingJackMinMax, key: "a_gy", value: features[20])
        updateMinMax(dict: &jumpingJackMinMax, key: "a_gz", value: features[22])
        
        if predicted == exerciseName {
            print("--- JUMPING JACK SENSOR DEBUG WITH MIN/MAX ---")
            printSensorWithMinMax(label: "p_ax", value: features[0], dict: jumpingJackMinMax, key: "p_ax")
            printSensorWithMinMax(label: "p_ay", value: features[2], dict: jumpingJackMinMax, key: "p_ay")
            printSensorWithMinMax(label: "p_az", value: features[4], dict: jumpingJackMinMax, key: "p_az")
            printSensorWithMinMax(label: "p_gx", value: features[6], dict: jumpingJackMinMax, key: "p_gx")
            printSensorWithMinMax(label: "p_gy", value: features[8], dict: jumpingJackMinMax, key: "p_gy")
            printSensorWithMinMax(label: "p_gz", value: features[10], dict: jumpingJackMinMax, key: "p_gz")
            printSensorWithMinMax(label: "a_ax", value: features[12], dict: jumpingJackMinMax, key: "a_ax")
            printSensorWithMinMax(label: "a_ay", value: features[14], dict: jumpingJackMinMax, key: "a_ay")
            printSensorWithMinMax(label: "a_az", value: features[16], dict: jumpingJackMinMax, key: "a_az")
            printSensorWithMinMax(label: "a_gx", value: features[18], dict: jumpingJackMinMax, key: "a_gx")
            printSensorWithMinMax(label: "a_gy", value: features[20], dict: jumpingJackMinMax, key: "a_gy")
            printSensorWithMinMax(label: "a_gz", value: features[22], dict: jumpingJackMinMax, key: "a_gz")
            print("---")
        }
        
        let motionTrigger = features[6] // Phone Gyro Z
        let downThreshold = 0.1   // "Out" threshold
        let upThreshold = -0.1   // "In" threshold

        if predicted == exerciseName || currentState != .idle {
            print("Logger [JUMPING JACK]: Status = \(currentState), p_gz_Mean = \(String(format: "%.2f", motionTrigger))")
        }

        if predicted == exerciseName {
            switch currentState {
            case .idle:
                if motionTrigger > downThreshold { // "Legs out"
                    self.exerciseState[exerciseName] = .goingDown // "Down" means "out"
                    print("Logger [JUMPING JACK]: STATE CHANGE: idle -> goingDown (Legs Out)")
                }
            case .goingDown:
                if motionTrigger < upThreshold { // "Legs in"
                    self.exerciseState[exerciseName] = .goingUp // "Up" means "in"
                    print("Logger [JUMPING JACK]: STATE CHANGE: goingDown -> goingUp (Legs In)")
                }
            case .goingUp:
                if motionTrigger > downThreshold { // "Legs out" again
                    // Check cooldown to prevent multiple counts
                    let now = Date()
                    let lastTime = self.lastRepTime[exerciseName] ?? Date.distantPast
                    
                    if now.timeIntervalSince(lastTime) > self.repCooldown {
                        self.exerciseState[exerciseName] = .goingDown
                        self.repCounts[exerciseName, default: 0] += 1
                        self.lastRepTime[exerciseName] = now
                        print("Logger [JUMPING JACK]: STATE CHANGE: goingUp -> goingDown (New Rep). +1 REP. Total: \(self.repCounts[exerciseName]!)")
                    } else {
                        print("Logger [JUMPING JACK]: Rep blocked by cooldown (too soon)")
                    }
                }
            }
        } else {
            // --- *** THIS IS THE FIX *** ---
            if currentState == .goingUp {
                self.repCounts[exerciseName, default: 0] += 1
                print("Logger [JUMPING JACK]: STATE CHANGE: goingUp -> idle (Rep Finished). +1 REP. Total: \(self.repCounts[exerciseName]!)")
                self.exerciseState[exerciseName] = .idle
            }
        }
    }

    //
    // MARK: - Helper Functions (Corrected)
    //
    
    private func extractWindowFeatures() -> [Double] {
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
    
    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        return values.reduce(0.0, +) / Double(values.count)
    }
    
    private func std(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        let m = mean(values)
        let variance = values.map { pow($0 - m, 2) }.reduce(0.0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
    
    // MARK: - Min/Max Tracking Helpers
    
    private func updateMinMax(dict: inout [String: (min: Double, max: Double)], key: String, value: Double) {
        if let existing = dict[key] {
            dict[key] = (min: min(existing.min, value), max: max(existing.max, value))
        } else {
            dict[key] = (min: value, max: value)
        }
    }
    
    private func printSensorWithMinMax(label: String, value: Double, dict: [String: (min: Double, max: Double)], key: String) {
        if let minMax = dict[key] {
            let range = minMax.max - minMax.min
            print(String(format: "%@: %.2f [MIN: %.2f, MAX: %.2f, RANGE: %.2f]",
                         label, value, minMax.min, minMax.max, range))
        } else {
            print(String(format: "%@: %.2f [MIN: N/A, MAX: N/A, RANGE: N/A]", label, value))
        }
    }
}

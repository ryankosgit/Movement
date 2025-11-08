import SwiftUI
import CoreMotion
import Combine // <-- ADDED IMPORT

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
    
    // <-- ADDED THIS PROPERTY
    private var cancellable: AnyCancellable?
    
    init() {
        checkAirPodsConnection()
        
        // <-- ADDED THIS SUBSCRIPTION
        // This makes the DataCollector update its view
        // whenever the exerciseClassifier publishes a change.
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
        
        if !phone.isDeviceMotionAvailable {
            print("ERROR: Phone motion not available")
            return
        }
        
        // Start AirPods motion tracking
        if airpods.isDeviceMotionAvailable {
            print("Starting AirPods motion tracking...")
            airpods.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion, let self = self else {
                    if let error = error {
                        print("ERROR: AirPods - \(error)")
                    }
                    return
                }
                
                self.latestAirPodsData = (
                    accel: (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z),
                    gyro: (motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
                )
            }
        }
        
        // Start phone motion tracking
        phone.deviceMotionUpdateInterval = 0.02  // 50 Hz
        phone.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else {
                if let error = error {
                    print("ERROR: Phone - \(error)")
                }
                return
            }
            
            self.latestPhoneData = (
                accel: (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z),
                gyro: (motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
            )
            
            // Classify in real-time
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
        VStack(spacing: 30) {
            
            if !collector.isClassifying {
                // Start screen
                VStack(spacing: 30) {
                    Text("Exercise Classifier")
                        .font(.system(size: 36, weight: .bold))
                    
                    // AirPods connection indicator
                    HStack(spacing: 8) {
                        Image(systemName: collector.airpodsConnected ? "airpodspro" : "airpodspro.slash")
                            .foregroundColor(collector.airpodsConnected ? .green : .red)
                        Text(collector.airpodsConnected ? "AirPods Connected" : "AirPods Not Connected")
                            .font(.caption)
                            .foregroundColor(collector.airpodsConnected ? .green : .red)
                        
                        Button(action: {
                            collector.checkAirPodsConnection()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                    
                    // Start button
                    Button(action: {
                        collector.startClassifying()
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 60))
                            Text("START")
                                .font(.system(size: 24, weight: .bold))
                            Text("Real-time exercise detection")
                                .font(.caption)
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
                // Classification screen
                VStack(spacing: 30) {
                    Text("Exercise Detection")
                        .font(.headline)
                    
                    // Show sensor status
                    HStack(spacing: 20) {
                        VStack {
                            Image(systemName: "iphone")
                                .foregroundColor(.green)
                            Text("Phone")
                                .font(.caption)
                        }
                        
                        if collector.airpodsConnected {
                            VStack {
                                Image(systemName: "airpodspro")
                                    .foregroundColor(.green)
                                Text("AirPods")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Main exercise display
                    VStack(spacing: 10) {
                        Text(collector.exerciseClassifier.currentExercise.uppercased())
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(exerciseColor(collector.exerciseClassifier.currentExercise))
                        
                        // This text now correctly observes the classifier's confidence
                        Text("Confidence: \(Int(collector.exerciseClassifier.confidence * 100))%")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    
                    Spacer()
                    
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
                    .padding()
                }
            }
        }
        .padding()
        .onAppear {
            collector.checkAirPodsConnection()
        }
    }
    
    // Helper function for exercise colors
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

import SwiftUI
import CoreMotion

class DataCollector: ObservableObject {
    private let phone = CMMotionManager()
    private let airpods = CMHeadphoneMotionManager()
    
    @Published var recording = false
    @Published var airpodsConnected = false
    private var data: [[String: Double]] = []
    
    init() {
        checkAirPodsConnection()
    }
    
    func checkAirPodsConnection() {
        airpodsConnected = airpods.isDeviceMotionAvailable
        print("AirPods available: \(airpodsConnected)")
    }
    
    func start() {
        print("Starting recording...")
        data = []
        recording = true
        
        if !phone.isDeviceMotionAvailable {
            print("ERROR: Phone motion not available")
            return
        }
        
        // Store latest AirPods data
        var latestAirPodsData: [String: Double] = [
            "a_ax": 0, "a_ay": 0, "a_az": 0,
            "a_gx": 0, "a_gy": 0, "a_gz": 0
        ]
        
        // Start AirPods if available
        if airpods.isDeviceMotionAvailable {
            print("Starting AirPods motion tracking...")
            airpods.startDeviceMotionUpdates(to: .main) { motion, error in
                guard let motion = motion else {
                    if let error = error {
                        print("ERROR: AirPods - \(error)")
                    }
                    return
                }
                
                // Update latest AirPods values
                latestAirPodsData = [
                    "a_ax": motion.userAcceleration.x,
                    "a_ay": motion.userAcceleration.y,
                    "a_az": motion.userAcceleration.z,
                    "a_gx": motion.rotationRate.x,
                    "a_gy": motion.rotationRate.y,
                    "a_gz": motion.rotationRate.z
                ]
            }
        } else {
            print("AirPods not available - recording phone only")
        }
        
        // Start phone - this drives the data collection
        phone.deviceMotionUpdateInterval = 0.02
        phone.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else {
                if let error = error {
                    print("ERROR: Phone - \(error)")
                }
                return
            }
            
            let t = Date().timeIntervalSince1970
            
            // Create data point with both phone and latest AirPods data
            let dataPoint: [String: Double] = [
                "time": t,
                "p_ax": motion.userAcceleration.x,
                "p_ay": motion.userAcceleration.y,
                "p_az": motion.userAcceleration.z,
                "p_gx": motion.rotationRate.x,
                "p_gy": motion.rotationRate.y,
                "p_gz": motion.rotationRate.z,
                "a_ax": latestAirPodsData["a_ax"] ?? 0,
                "a_ay": latestAirPodsData["a_ay"] ?? 0,
                "a_az": latestAirPodsData["a_az"] ?? 0,
                "a_gx": latestAirPodsData["a_gx"] ?? 0,
                "a_gy": latestAirPodsData["a_gy"] ?? 0,
                "a_gz": latestAirPodsData["a_gz"] ?? 0
            ]
            
            self.data.append(dataPoint)
        }
        
        print("Recording started")
    }
    
    func stopRecording() {
        print("Stopping sensor recording...")
        phone.stopDeviceMotionUpdates()
        airpods.stopDeviceMotionUpdates()
        recording = false
    }
    
    func saveData(label: String, reps: Int) {
        print("Saving data...")
        print("Total samples collected: \(data.count)")
        
        if data.isEmpty {
            print("ERROR: No data collected!")
            return
        }
        
        var csv = "time,p_ax,p_ay,p_az,p_gx,p_gy,p_gz,a_ax,a_ay,a_az,a_gx,a_gy,a_gz,label,reps\n"
        for row in data {
            csv += "\(row["time"] ?? 0),\(row["p_ax"] ?? 0),\(row["p_ay"] ?? 0),\(row["p_az"] ?? 0),"
            csv += "\(row["p_gx"] ?? 0),\(row["p_gy"] ?? 0),\(row["p_gz"] ?? 0),"
            csv += "\(row["a_ax"] ?? 0),\(row["a_ay"] ?? 0),\(row["a_az"] ?? 0),"
            csv += "\(row["a_gx"] ?? 0),\(row["a_gy"] ?? 0),\(row["a_gz"] ?? 0),\(label),\(reps)\n"
        }
        
        let fileName = "\(label)_\(reps)reps_\(Int(Date().timeIntervalSince1970)).csv"
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("ERROR: Cannot access documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        print("Attempting to save to: \(fileURL.path)")
        
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ SUCCESS: File saved to \(fileURL.path)")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                print("✅ File verified to exist!")
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int {
                    print("✅ File size: \(fileSize) bytes")
                }
            }
        } catch {
            print("❌ ERROR saving file: \(error.localizedDescription)")
        }
        
        data = []
    }
}

struct ContentView: View {
    @StateObject var collector = DataCollector()
    @State var exercise = ""
    @State var reps = ""
    @State var showingRepInput = false
    @FocusState private var exerciseFocused: Bool
    @FocusState private var repsFocused: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            if !collector.recording && !showingRepInput {
                // SCREEN 1: Exercise name input
                VStack(spacing: 20) {
                    
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
                    .padding(.bottom, 10)
                    
                    Text("Exercise Name")
                        .font(.headline)
                    
                    TextField("e.g. pushup", text: $exercise)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 24))
                        .multilineTextAlignment(.center)
                        .autocapitalization(.none)
                        .focused($exerciseFocused)
                        .padding()
                    
                    Button("START RECORDING") {
                        print("START pressed, exercise: \(exercise)")
                        if !exercise.isEmpty {
                            exerciseFocused = false
                            collector.start()
                        }
                    }
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(exercise.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(15)
                    .disabled(exercise.isEmpty)
                    .padding()
                }
                
            } else if collector.recording && !showingRepInput {
                // SCREEN 2: Recording
                VStack(spacing: 20) {
                    
                    // Show sensor status while recording
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
                    .padding(.bottom, 10)
                    
                    Text("RECORDING")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text(exercise.uppercased())
                        .font(.system(size: 32))
                    
                    Button("STOP") {
                        print("STOP pressed")
                        collector.stopRecording()
                        showingRepInput = true
                    }
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 200)
                    .background(Color.red)
                    .clipShape(Circle())
                }
                
            } else if !collector.recording && showingRepInput {
                // SCREEN 3: Rep count input
                VStack(spacing: 20) {
                    Text("How many reps?")
                        .font(.headline)
                    
                    TextField("Number of reps", text: $reps)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 32))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($repsFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    repsFocused = false
                                }
                            }
                        }
                        .padding()
                    
                    Spacer()
                    
                    Button("SAVE") {
                        print("SAVE pressed, reps: \(reps)")
                        if let repCount = Int(reps), !exercise.isEmpty {
                            collector.saveData(label: exercise, reps: repCount)
                            
                            // Reset everything
                            repsFocused = false
                            exercise = ""
                            reps = ""
                            showingRepInput = false
                            print("Reset complete")
                        }
                    }
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(reps.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(15)
                    .disabled(reps.isEmpty)
                    .padding()
                }
                .onAppear {
                    repsFocused = true
                }
            }
        }
        .padding()
        .onAppear {
            exerciseFocused = true
            collector.checkAirPodsConnection()
        }
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Heart Rate Display
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "--")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                // Status
                Text(workoutManager.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // API Stats
                if workoutManager.isWorkoutActive {
                    HStack {
                        Label("\(workoutManager.successCount)", systemImage: "checkmark.circle")
                            .foregroundColor(.green)
                        Label("\(workoutManager.failCount)", systemImage: "xmark.circle")
                            .foregroundColor(.red)
                    }
                    .font(.caption2)
                }
                
                // Start/Stop Button
                Button(action: {
                    Task {
                        if workoutManager.isWorkoutActive {
                            await workoutManager.stopWorkout()
                        } else {
                            await workoutManager.startWorkout()
                        }
                    }
                }) {
                    Text(workoutManager.isWorkoutActive ? "Stop" : "Start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(workoutManager.isWorkoutActive ? .red : .green)
                
                // Error Message
                if let error = workoutManager.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .task {
            await workoutManager.requestAuthorization()
        }
    }
}

#Preview {
    ContentView()
}

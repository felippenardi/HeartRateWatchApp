import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Heart Rate Display
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                    
                    Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    
                    Text("BPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Rep Counter
                VStack(spacing: 8) {
                    Text("REPS")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        // Minus Button
                        Button(action: {
                            if workoutManager.reps > 0 {
                                workoutManager.reps -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    workoutManager.reps = 0
                                }
                        )
                        
                        // Rep Count
                        Text("\(workoutManager.reps)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .frame(minWidth: 60)
                        
                        // Plus Button
                        Button(action: {
                            workoutManager.reps += 1
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                
                // Status
                Text(workoutManager.statusMessage)
                    .font(.caption2)
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
                    if workoutManager.isWorkoutActive {
                        workoutManager.stopWorkout()
                    } else {
                        workoutManager.startWorkout()
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
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

#Preview {
    ContentView()
}

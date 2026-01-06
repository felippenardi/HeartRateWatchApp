import Foundation
import HealthKit
import WatchKit

@MainActor
class WorkoutManager: NSObject, ObservableObject {
    
    @Published var heartRate: Double = 0
    @Published var isWorkoutActive: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?
    @Published var successCount: Int = 0
    @Published var failCount: Int = 0
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var sessionId: String = ""
    private let deviceId: String
    private let apiService = APIService()
    
    override init() {
        if let id = UserDefaults.standard.string(forKey: "deviceId") {
            self.deviceId = id
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "deviceId")
            self.deviceId = newId
        }
        super.init()
    }
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit not available"
            return
        }
        
        let types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.workoutType()
        ]
        
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.workoutType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: types)
            isAuthorized = true
            statusMessage = "Ready to start"
        } catch {
            errorMessage = "Authorization failed"
            isAuthorized = false
        }
    }
    
    func startWorkout() async {
        if !isAuthorized {
            await requestAuthorization()
            if !isAuthorized { return }
        }
        
        sessionId = UUID().uuidString
        
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            
            session?.delegate = self
            builder?.delegate = self
            
            let startDate = Date()
            session?.startActivity(with: startDate)
            try await builder?.beginCollection(at: startDate)
            
            startHeartRateQuery()
            
            isWorkoutActive = true
            statusMessage = "Monitoring..."
            successCount = 0
            failCount = 0
        } catch {
            errorMessage = "Failed to start: \(error.localizedDescription)"
        }
    }
    
    func stopWorkout() async {
        stopHeartRateQuery()
        session?.end()
        
        do {
            try await builder?.endCollection(at: Date())
            try await builder?.finishWorkout()
        } catch {
            errorMessage = "Failed to stop"
        }
        
        isWorkoutActive = false
        statusMessage = "Stopped"
        heartRate = 0
        session = nil
        builder = nil
    }
    
    private func startHeartRateQuery() {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
        let deviceId = self.deviceId
        let sessionId = self.sessionId
        
        heartRateQuery = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processSamples(samples, deviceId: deviceId, sessionId: sessionId)
        }
        
        heartRateQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processSamples(samples, deviceId: deviceId, sessionId: sessionId)
        }
        
        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }
    
    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }
    
    private nonisolated func processSamples(_ samples: [HKSample]?, deviceId: String, sessionId: String) {
        guard let samples = samples else { return }
        let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
        guard let sample = quantitySamples.last else { return }
        
        let unit = HKUnit.count().unitDivided(by: .minute())
        let value = sample.quantity.doubleValue(for: unit)
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            let appState = WKApplication.shared().applicationState == .active ? "foreground" : "background"
            self.heartRate = value
            
            let data = HeartRateData(
                heartRate: value,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                deviceId: deviceId,
                sessionType: "monitoring",
                appState: appState,
                sessionId: sessionId
            )
            
            let success = await self.apiService.send(data)
            if success {
                self.successCount += 1
            } else {
                self.failCount += 1
            }
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor [weak self] in
            switch toState {
            case .running: self?.statusMessage = "Active"
            case .ended: self?.isWorkoutActive = false
            default: break
            }
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.errorMessage = error.localizedDescription
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}
}

import Foundation
import HealthKit
import WatchKit
import Combine

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
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                self.errorMessage = "HealthKit not available"
            }
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
        
        healthStore.requestAuthorization(toShare: writeTypes, read: types) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.isAuthorized = true
                    self?.statusMessage = "Ready to start"
                } else {
                    self?.errorMessage = "Authorization failed"
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    func startWorkout() {
        if !isAuthorized {
            requestAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if self?.isAuthorized == true {
                    self?.beginWorkoutSession()
                }
            }
            return
        }
        beginWorkoutSession()
    }
    
    private func beginWorkoutSession() {
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
            builder?.beginCollection(withStart: startDate) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.startHeartRateQuery()
                        self?.isWorkoutActive = true
                        self?.statusMessage = "Monitoring..."
                        self?.successCount = 0
                        self?.failCount = 0
                    } else {
                        self?.errorMessage = "Failed to start collection"
                    }
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to start: \(error.localizedDescription)"
            }
        }
    }
    
    func stopWorkout() {
        stopHeartRateQuery()
        session?.end()
        
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
            self?.builder?.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    self?.isWorkoutActive = false
                    self?.statusMessage = "Stopped"
                    self?.heartRate = 0
                    self?.session = nil
                    self?.builder = nil
                }
            }
        }
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
    
    private func processSamples(_ samples: [HKSample]?, deviceId: String, sessionId: String) {
        guard let samples = samples else { return }
        let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
        guard let sample = quantitySamples.last else { return }
        
        let unit = HKUnit.count().unitDivided(by: .minute())
        let value = sample.quantity.doubleValue(for: unit)
        
        DispatchQueue.main.async { [weak self] in
            self?.heartRate = value
            self?.sendToAPI(heartRate: value, deviceId: deviceId, sessionId: sessionId)
        }
    }
    
    private func sendToAPI(heartRate: Double, deviceId: String, sessionId: String) {
        let appState = WKApplication.shared().applicationState == .active ? "foreground" : "background"
        
        let data = HeartRateData(
            heartRate: heartRate,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            deviceId: deviceId,
            sessionType: "monitoring",
            appState: appState,
            sessionId: sessionId
        )
        
        guard let url = URL(string: "https://applewatchtest.free.beeceptor.com/heartrate") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        do {
            request.httpBody = try JSONEncoder().encode(data)
        } catch {
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    self?.successCount += 1
                } else {
                    self?.failCount += 1
                }
            }
        }.resume()
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async { [weak self] in
            switch toState {
            case .running: self?.statusMessage = "Active"
            case .ended: self?.isWorkoutActive = false
            default: break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = error.localizedDescription
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}
}

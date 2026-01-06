import Foundation

struct HeartRateData: Codable {
    let heartRate: Double
    let timestamp: String
    let deviceId: String
    let sessionType: String
    let appState: String
    let sessionId: String
    
    enum CodingKeys: String, CodingKey {
        case heartRate = "heart_rate"
        case timestamp
        case deviceId = "device_id"
        case sessionType = "session_type"
        case appState = "app_state"
        case sessionId = "session_id"
    }
}

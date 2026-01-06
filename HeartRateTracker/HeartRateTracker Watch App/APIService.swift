import Foundation

actor APIService {
    private let baseURL = "https://applewatchtest.free.beeceptor.com"
    
    func send(_ data: HeartRateData) async -> Bool {
        guard let url = URL(string: "\(baseURL)/heartrate") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        do {
            request.httpBody = try JSONEncoder().encode(data)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            print("API Error: \(error)")
            return false
        }
    }
}

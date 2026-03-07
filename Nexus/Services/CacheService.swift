import Foundation

enum CacheService {
    private static let commsKey = "cached_communications"
    private static let emailsKey = "cached_emails"
    private static let alertsKey = "cached_alerts"
    private static let lastFetchKey = "cached_last_fetch"

    static func saveCommunications(_ comms: [Communication]) {
        save(comms, forKey: commsKey)
    }

    static func loadCommunications() -> [Communication]? {
        load(forKey: commsKey)
    }

    static func saveEmails(_ emails: [EmailMessage]) {
        save(emails, forKey: emailsKey)
    }

    static func loadEmails() -> [EmailMessage]? {
        load(forKey: emailsKey)
    }

    static func saveAlerts(_ alerts: [NexusAlert]) {
        save(alerts, forKey: alertsKey)
    }

    static func loadAlerts() -> [NexusAlert]? {
        load(forKey: alertsKey)
    }

    static func updateLastFetch() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
    }

    static func lastFetchDate() -> Date? {
        let interval = UserDefaults.standard.double(forKey: lastFetchKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private static func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

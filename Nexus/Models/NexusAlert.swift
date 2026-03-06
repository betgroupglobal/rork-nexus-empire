import Foundation

nonisolated enum AlertType: String, Codable, CaseIterable, Identifiable, Sendable {
    case utilisationWarning = "Utilisation"
    case clearScoreDrop = "ClearScore"
    case dormantEntity = "Dormant"
    case newComm = "New Comm"
    case applicationWindow = "Application"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .utilisationWarning: "chart.bar.fill"
        case .clearScoreDrop: "arrow.down.circle.fill"
        case .dormantEntity: "moon.zzz.fill"
        case .newComm: "bell.badge.fill"
        case .applicationWindow: "window.badge.plus"
        }
    }
}

nonisolated enum AlertPriority: String, Codable, Sendable {
    case critical = "Critical"
    case warning = "Warning"
    case info = "Info"
}

struct NexusAlert: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let entityId: UUID?
    let entityName: String?
    var type: AlertType
    var priority: AlertPriority
    var title: String
    var message: String
    var timestamp: Date
    var isRead: Bool
}

import Foundation

nonisolated enum AlertType: String, Codable, CaseIterable, Identifiable, Sendable {
    case stalledApplication = "Stalled App"
    case scoreDrop = "Score Drop"
    case verificationBlock = "Verification"
    case newComm = "New Comm"
    case utilisationSpike = "Utilisation"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stalledApplication: "hourglass"
        case .scoreDrop: "arrow.down.circle.fill"
        case .verificationBlock: "exclamationmark.shield.fill"
        case .newComm: "bell.badge.fill"
        case .utilisationSpike: "chart.bar.fill"
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
    var type: AlertType
    var priority: AlertPriority
    var title: String
    var message: String
    var timestamp: Date
    var isRead: Bool
    var subjectId: String?
    var subjectName: String?
}

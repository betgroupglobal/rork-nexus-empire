import Foundation

nonisolated enum EmailCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case statement = "Statement"
    case approval = "Approval"
    case atoNotice = "ATO Notice"
    case general = "General"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .statement: "doc.text.fill"
        case .approval: "checkmark.seal.fill"
        case .atoNotice: "building.columns.fill"
        case .general: "envelope.fill"
        }
    }
}

struct EmailMessage: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var sender: String
    var senderAddress: String
    var subject: String
    var snippet: String
    var category: EmailCategory
    var timestamp: Date
    var isRead: Bool
    var isFlagged: Bool
    var containsDollarAmount: Bool
    var alias: String
    var accountId: UUID?
}

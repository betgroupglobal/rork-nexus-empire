import Foundation

nonisolated struct CommunicationDTO: Codable, Sendable {
    let id: String
    let entityId: String?
    let entityName: String?
    let type: String
    let sender: String
    let content: String
    let timestamp: String
    let isRead: Bool
    let phoneNumber: String
    let duration: Double?
    let transcription: String?

    func toModel() -> Communication {
        Communication(
            id: UUID(uuidString: id) ?? UUID(),
            type: CommType(rawValue: type) ?? .sms,
            sender: sender,
            content: content,
            timestamp: ISO8601DateFormatter().date(from: timestamp) ?? Date(),
            isRead: isRead,
            phoneNumber: phoneNumber,
            duration: duration,
            transcription: transcription
        )
    }
}

nonisolated struct EmailDTO: Codable, Sendable {
    let id: String
    let entityId: String?
    let entityName: String?
    let sender: String
    let senderAddress: String
    let subject: String
    let snippet: String
    let category: String
    let timestamp: String
    let isRead: Bool
    let isFlagged: Bool
    let containsDollarAmount: Bool
    let alias: String

    func toModel() -> EmailMessage {
        EmailMessage(
            id: UUID(uuidString: id) ?? UUID(),
            sender: sender,
            senderAddress: senderAddress,
            subject: subject,
            snippet: snippet,
            category: EmailCategory(rawValue: category) ?? .general,
            timestamp: ISO8601DateFormatter().date(from: timestamp) ?? Date(),
            isRead: isRead,
            isFlagged: isFlagged,
            containsDollarAmount: containsDollarAmount,
            alias: alias
        )
    }
}

nonisolated struct AlertDTO: Codable, Sendable {
    let id: String
    let entityId: String?
    let entityName: String?
    let type: String
    let priority: String
    let title: String
    let message: String
    let timestamp: String
    let isRead: Bool

    func toModel() -> NexusAlert {
        NexusAlert(
            id: UUID(uuidString: id) ?? UUID(),
            type: AlertType(rawValue: type) ?? .newComm,
            priority: AlertPriority(rawValue: priority) ?? .info,
            title: title,
            message: message,
            timestamp: ISO8601DateFormatter().date(from: timestamp) ?? Date(),
            isRead: isRead
        )
    }
}

nonisolated struct EntityDTO: Codable, Sendable {
    let id: String
    let name: String
    let type: String
    let status: String
    let healthScore: Int
    let creditLimit: Double
    let utilisationPercent: Double
    let monthlyBurn: Double
    let assignedPhone: String
    let assignedEmail: String
    let clearScore: Int
    let lastActivityDate: String
    let isFlagged: Bool
    let notes: String
    let createdDate: String

    func toModel() -> Entity {
        let iso = ISO8601DateFormatter()
        return Entity(
            id: id,
            name: name,
            type: EntityType(rawValue: type) ?? .person,
            status: EntityStatus(rawValue: status) ?? .active,
            healthScore: healthScore,
            creditLimit: creditLimit,
            utilisationPercent: utilisationPercent,
            monthlyBurn: monthlyBurn,
            assignedPhone: assignedPhone,
            assignedEmail: assignedEmail,
            clearScore: clearScore,
            lastActivityDate: iso.date(from: lastActivityDate) ?? Date(),
            isFlagged: isFlagged,
            notes: notes,
            createdDate: iso.date(from: createdDate) ?? Date()
        )
    }
}

nonisolated struct BackendHealthResponse: Codable, Sendable {
    let status: String
    let message: String?
    let version: String?
}

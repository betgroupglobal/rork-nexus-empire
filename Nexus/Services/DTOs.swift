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
            transcription: transcription,
            subjectId: entityId,
            subjectName: entityName
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
        let categoryMap: [String: EmailCategory] = [
            "Statement": .statement,
            "Approval": .approval,
            "Bank Notice": .bankNotice,
            "ATO Notice": .ird,
            "IRD": .ird,
            "General": .general
        ]
        return EmailMessage(
            id: UUID(uuidString: id) ?? UUID(),
            sender: sender,
            senderAddress: senderAddress,
            subject: subject,
            snippet: snippet,
            category: categoryMap[category] ?? .general,
            timestamp: ISO8601DateFormatter().date(from: timestamp) ?? Date(),
            isRead: isRead,
            isFlagged: isFlagged,
            containsDollarAmount: containsDollarAmount,
            alias: alias,
            subjectId: entityId,
            subjectName: entityName
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
        let typeMap: [String: AlertType] = [
            "Stalled App": .stalledApplication,
            "Score Drop": .scoreDrop,
            "Verification": .verificationBlock,
            "New Comm": .newComm,
            "Utilisation": .utilisationSpike,
            "ClearScore": .scoreDrop,
            "Dormant": .stalledApplication,
            "Application": .stalledApplication
        ]
        return NexusAlert(
            id: UUID(uuidString: id) ?? UUID(),
            type: typeMap[type] ?? .newComm,
            priority: AlertPriority(rawValue: priority) ?? .info,
            title: title,
            message: message,
            timestamp: ISO8601DateFormatter().date(from: timestamp) ?? Date(),
            isRead: isRead,
            subjectId: entityId,
            subjectName: entityName
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

    func toModel() -> Subject {
        let iso = ISO8601DateFormatter()
        let statusMap: [String: SubjectStatus] = [
            "Active": .active,
            "Dormant": .pending,
            "At Risk": .atRisk,
            "Archived": .archived,
            "Pending": .pending
        ]
        return Subject(
            id: id,
            name: name,
            type: SubjectType(rawValue: type) ?? .person,
            status: statusMap[status] ?? .active,
            creditScore: min(100, max(0, healthScore)),
            assignedPhone: assignedPhone,
            assignedEmail: assignedEmail,
            lastActivityDate: iso.date(from: lastActivityDate) ?? Date(),
            isFlagged: isFlagged,
            notes: notes,
            createdDate: iso.date(from: createdDate) ?? Date(),
            dateOfBirth: "",
            address: "",
            idNumber: "",
            applications: []
        )
    }
}

nonisolated struct BackendHealthResponse: Codable, Sendable {
    let status: String
    let message: String?
    let version: String?
}

nonisolated struct DashboardResponse: Codable, Sendable {
    let totalFirepower: Double?
    let monthlyBurn: Double?
    let activeCount: Int?
    let totalCount: Int?
    let urgentCount: Int?
    let unreadComms: Int?
    let unreadEmails: Int?
}

nonisolated struct TRPCResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let result: TRPCResult<T>
}

nonisolated struct TRPCResult<T: Decodable & Sendable>: Decodable, Sendable {
    let data: TRPCData<T>
}

nonisolated struct TRPCData<T: Decodable & Sendable>: Decodable, Sendable {
    let json: T
}

nonisolated struct TRPCErrorResponse: Decodable, Sendable {
    let error: TRPCErrorBody
}

nonisolated struct TRPCErrorBody: Decodable, Sendable {
    let message: String?
    let code: Int?
    let data: TRPCErrorData?
}

nonisolated struct TRPCErrorData: Decodable, Sendable {
    let code: String?
    let httpStatus: Int?
    let message: String?
}

nonisolated struct SuccessResponse: Codable, Sendable {
    let success: Bool
}

nonisolated enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case serverError(Int, String)
    case notConfigured

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidURL: "Unable to connect to server"
        case .serverError(_, let message): message
        case .notConfigured: "API not configured"
        }
    }
}

nonisolated struct SuperJSONInput<T: Encodable & Sendable>: Encodable, Sendable {
    let json: T
}

nonisolated struct IDInput: Codable, Sendable {
    let id: String
}

nonisolated struct EmptyInput: Codable, Sendable {}

nonisolated struct SyncMailboxResponse: Codable, Sendable {
    let success: Bool
    let syncedCount: Int
    let message: String
}

nonisolated struct CreateEntityInput: Codable, Sendable {
    let name: String
    let type: String
    let creditLimit: Double
    let assignedPhone: String
    let assignedEmail: String
    let notes: String?
}

nonisolated struct UpdateEntityInput: Codable, Sendable {
    let id: String
    let name: String?
    let type: String?
    let status: String?
    let healthScore: Int?
    let creditLimit: Double?
    let utilisationPercent: Double?
    let monthlyBurn: Double?
    let assignedPhone: String?
    let assignedEmail: String?
    let clearScore: Int?
    let isFlagged: Bool?
    let notes: String?
}

nonisolated struct CommFilterInput: Codable, Sendable {
    let entityId: String?
    let type: String?
}

nonisolated struct EmailFilterInput: Codable, Sendable {
    let entityId: String?
    let category: String?
}

nonisolated struct AlertFilterInput: Codable, Sendable {
    let type: String?
}

nonisolated struct CreateCommInput: Codable, Sendable {
    let entityId: String
    let entityName: String
    let type: String
    let sender: String
    let content: String
    let phoneNumber: String
    let duration: Double?
    let transcription: String?
}

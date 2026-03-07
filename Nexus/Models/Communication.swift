import Foundation

nonisolated enum CommType: String, Codable, CaseIterable, Identifiable, Sendable {
    case sms = "SMS"
    case call = "Call"
    case voicemail = "Voicemail"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sms: "message.fill"
        case .call: "phone.fill"
        case .voicemail: "recordingtape.fill"
        }
    }
}

struct Communication: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var type: CommType
    var sender: String
    var content: String
    var timestamp: Date
    var isRead: Bool
    var phoneNumber: String
    var duration: TimeInterval?
    var transcription: String?
    var subjectId: String?
    var subjectName: String?
}

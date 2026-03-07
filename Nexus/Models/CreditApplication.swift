import Foundation

nonisolated enum ApplicationStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case submitted = "Submitted"
    case inReview = "In Review"
    case approved = "Approved"
    case declined = "Declined"
    case documentsNeeded = "Docs Needed"
    case stalled = "Stalled"

    var id: String { rawValue }

    var isActive: Bool {
        switch self {
        case .submitted, .inReview, .documentsNeeded, .stalled: true
        case .approved, .declined: false
        }
    }

    var icon: String {
        switch self {
        case .submitted: "paperplane.fill"
        case .inReview: "magnifyingglass"
        case .approved: "checkmark.seal.fill"
        case .declined: "xmark.seal.fill"
        case .documentsNeeded: "doc.badge.clock.fill"
        case .stalled: "hourglass"
        }
    }
}

struct CreditApplication: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var bank: String
    var product: String
    var status: ApplicationStatus
    var progressPercent: Int
    var submittedDate: Date
    var lastUpdateDate: Date
    var nextAction: String
    var documents: String

    var isActive: Bool { status.isActive }

    var daysActive: Int {
        Calendar.current.dateComponents([.day], from: submittedDate, to: Date()).day ?? 0
    }
}

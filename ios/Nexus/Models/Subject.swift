import Foundation

nonisolated enum SubjectType: String, Codable, CaseIterable, Identifiable, Sendable {
    case person = "Person"
    case ltd = "Ltd"
    case trust = "Trust"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .person: "person.fill"
        case .ltd: "building.2.fill"
        case .trust: "shield.fill"
        }
    }
}

nonisolated enum SubjectStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active = "Active"
    case pending = "Pending"
    case atRisk = "At Risk"
    case archived = "Archived"

    var id: String { rawValue }
}

struct Subject: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var name: String
    var type: SubjectType
    var status: SubjectStatus
    var creditScore: Int
    var assignedPhone: String
    var assignedEmail: String
    var lastActivityDate: Date
    var isFlagged: Bool
    var notes: String
    var createdDate: Date
    var dateOfBirth: String
    var address: String
    var idNumber: String
    var applications: [CreditApplication]

    var banksApplied: [String] {
        Array(Set(applications.map(\.bank)))
    }

    var overallProgress: Int {
        guard !applications.isEmpty else { return 0 }
        return applications.reduce(0) { $0 + $1.progressPercent } / applications.count
    }

    var activeApplicationCount: Int {
        applications.filter(\.isActive).count
    }
}

import Foundation

nonisolated enum EntityType: String, Codable, CaseIterable, Identifiable, Sendable {
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

nonisolated enum EntityStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active = "Active"
    case dormant = "Dormant"
    case atRisk = "At Risk"
    case archived = "Archived"

    var id: String { rawValue }
}

struct Entity: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var name: String
    var type: EntityType
    var status: EntityStatus
    var healthScore: Int
    var creditLimit: Double
    var utilisationPercent: Double
    var monthlyBurn: Double
    var assignedPhone: String
    var assignedEmail: String
    var clearScore: Int
    var lastActivityDate: Date
    var isFlagged: Bool
    var notes: String
    var createdDate: Date
}

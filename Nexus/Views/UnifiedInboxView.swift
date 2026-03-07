import SwiftUI

nonisolated enum InboxFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case sms = "SMS"
    case calls = "Calls"
    case voicemail = "Voicemail"
    case email = "Email"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: "tray"
        case .sms: "message"
        case .calls: "phone"
        case .voicemail: "recordingtape"
        case .email: "envelope"
        }
    }
}

struct UnifiedInboxView: View {
    let store: NexusStore

    var body: some View {
        Text("Use Comms Citadel or Email Router tabs")
            .foregroundStyle(.secondary)
    }
}

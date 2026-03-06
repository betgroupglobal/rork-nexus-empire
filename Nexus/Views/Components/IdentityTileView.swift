import SwiftUI

struct IdentityTileView: View {
    let entity: NexusEntity
    let store: NexusStore

    private var unreadEmails: Int {
        store.emailsForEntity(entity.id).filter { !$0.isRead }.count
    }

    private var unreadComms: Int {
        store.commsForEntity(entity.id).filter { !$0.isRead }.count
    }

    private var totalUnread: Int {
        unreadEmails + unreadComms
    }

    private var linkedEmail: EmailAccount? {
        guard let accountId = entity.emailAccountId else { return nil }
        return store.emailAccounts.first { $0.id == accountId }
    }

    private var statusColor: Color {
        switch entity.status {
        case .active: .green
        case .dormant: .yellow
        case .atRisk: .red
        case .archived: .gray
        }
    }

    private var typeGradient: [Color] {
        switch entity.type {
        case .person: [Color(red: 0.2, green: 0.4, blue: 0.8), Color(red: 0.3, green: 0.5, blue: 0.9)]
        case .ltd: [Color(red: 0.15, green: 0.3, blue: 0.25), Color(red: 0.2, green: 0.45, blue: 0.35)]
        case .trust: [Color(red: 0.35, green: 0.2, blue: 0.5), Color(red: 0.5, green: 0.3, blue: 0.65)]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: typeGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: entity.type.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if totalUnread > 0 {
                    Text("\(totalUnread)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.red)
                        .clipShape(Capsule())
                }

                if entity.isFlagged {
                    Image(systemName: "flag.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer().frame(height: 12)

            Text(entity.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 4)

            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(entity.status.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer().frame(height: 12)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entity.firepowerAmount, format: .currency(code: "AUD").precision(.fractionLength(0)))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Text("Available")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                HealthRingView(score: entity.healthScore, size: 32, lineWidth: 3)
            }

            if let email = linkedEmail {
                Spacer().frame(height: 10)
                HStack(spacing: 4) {
                    Image(systemName: email.provider.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(email.provider.color)
                    Text(email.emailAddress)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else if !entity.assignedEmail.isEmpty {
                Spacer().frame(height: 10)
                HStack(spacing: 4) {
                    Image(systemName: "envelope")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(entity.assignedEmail)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

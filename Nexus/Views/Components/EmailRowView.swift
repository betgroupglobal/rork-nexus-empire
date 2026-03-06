import SwiftUI

struct EmailRowView: View {
    let email: EmailMessage
    var accountName: String? = nil

    private var categoryColor: Color {
        switch email.category {
        case .statement: .blue
        case .approval: .green
        case .atoNotice: .orange
        case .general: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: email.category.icon)
                    .font(.subheadline)
                    .foregroundStyle(categoryColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(email.sender)
                        .font(.headline)
                        .fontWeight(email.isRead ? .regular : .semibold)
                        .lineLimit(1)

                    Spacer()

                    if email.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Text(email.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(email.subject)
                    .font(.subheadline)
                    .fontWeight(email.isRead ? .regular : .medium)
                    .lineLimit(1)

                Text(email.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(email.category.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(categoryColor.opacity(0.1))
                        .foregroundStyle(categoryColor)
                        .clipShape(Capsule())

                    if email.containsDollarAmount {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }

                    if let accountName {
                        Text(accountName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
            }

            if !email.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

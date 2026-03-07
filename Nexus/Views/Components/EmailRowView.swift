import SwiftUI

struct EmailRowView: View {
    let email: EmailMessage
    let store: NexusStore
    var accountName: String? = nil

    private var categoryColor: Color {
        switch email.category {
        case .statement: .blue
        case .approval: .green
        case .bankNotice: .orange
        case .ird: .purple
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

                    if let name = email.subjectName {
                        subjectTag(name)
                    }

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
                        HStack(spacing: 2) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.caption2)
                            Text("$")
                                .font(.caption2.bold())
                        }
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

    private func subjectTag(_ name: String) -> some View {
        let subject = store.subjects.first { $0.name.localizedStandardContains(name) || name.localizedStandardContains($0.name) }
        let color: Color = {
            guard let s = subject else { return .secondary }
            if s.creditScore >= 80 { return .green }
            if s.creditScore >= 50 { return .yellow }
            return .red
        }()
        return Text(name)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

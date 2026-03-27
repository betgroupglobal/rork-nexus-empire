import SwiftUI

struct AlertRowView: View {
    let alert: NexusAlert

    private var priorityColor: Color {
        switch alert.priority {
        case .critical: .red
        case .warning: .orange
        case .info: .blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(priorityColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: alert.type.icon)
                    .font(.subheadline)
                    .foregroundStyle(priorityColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.title)
                        .font(.headline)
                        .fontWeight(alert.isRead ? .regular : .semibold)
                        .lineLimit(1)

                    Spacer()

                    Text(alert.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(alert.priority.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(priorityColor.opacity(0.12))
                        .foregroundStyle(priorityColor)
                        .clipShape(Capsule())

                    if let name = alert.subjectName {
                        Text(name)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }

            if !alert.isRead {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

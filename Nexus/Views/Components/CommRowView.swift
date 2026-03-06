import SwiftUI

struct CommRowView: View {
    let comm: Communication

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(commTypeColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: comm.type.icon)
                    .font(.subheadline)
                    .foregroundStyle(commTypeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comm.sender)
                        .font(.headline)
                        .fontWeight(comm.isRead ? .regular : .semibold)
                        .lineLimit(1)

                    Spacer()

                    Text(comm.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(comm.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(comm.entityName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    if let duration = comm.duration {
                        Text(formattedDuration(duration))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !comm.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var commTypeColor: Color {
        switch comm.type {
        case .sms: .blue
        case .call: .green
        case .voicemail: .purple
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

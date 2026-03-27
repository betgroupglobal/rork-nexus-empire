import SwiftUI

struct CommRowView: View {
    let comm: Communication
    let store: NexusStore

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

                    if let name = comm.subjectName {
                        subjectBadge(name)
                    }

                    Spacer()

                    Text(comm.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(comm.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if comm.type == .voicemail, let duration = comm.duration {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        Text(formattedDuration(duration))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if comm.transcription != nil {
                            Text("Transcription available")
                                .font(.caption2)
                                .foregroundStyle(.purple.opacity(0.7))
                        }
                    }
                } else if let duration = comm.duration {
                    Text(formattedDuration(duration))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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

    private func subjectBadge(_ name: String) -> some View {
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

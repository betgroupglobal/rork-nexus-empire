import SwiftUI

struct EntityRowView: View {
    let entity: NexusEntity

    private var statusColor: Color {
        switch entity.status {
        case .active: .green
        case .dormant: .yellow
        case .atRisk: .red
        case .archived: .gray
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            HealthRingView(score: entity.healthScore, size: 48, lineWidth: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entity.name)
                        .font(.headline)
                        .lineLimit(1)

                    if entity.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 8) {
                    Label(entity.type.rawValue, systemImage: entity.type.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(entity.status.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(entity.firepowerAmount, format: .currency(code: "AUD").precision(.fractionLength(0)))
                    .font(.subheadline.bold())

                Text("\(entity.utilisationPercent, specifier: "%.0f")% used")
                    .font(.caption2)
                    .foregroundStyle(entity.utilisationPercent > 25 ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

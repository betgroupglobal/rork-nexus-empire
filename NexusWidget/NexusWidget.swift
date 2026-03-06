import WidgetKit
import SwiftUI

nonisolated struct NexusEntry: TimelineEntry {
    let date: Date
    let totalFirepower: Double
    let monthlyBurn: Double
    let urgentCount: Int
    let activeEntities: Int
    let urgentActions: [(String, String)]
}

nonisolated struct NexusProvider: TimelineProvider {
    func placeholder(in context: Context) -> NexusEntry {
        NexusEntry(
            date: .now,
            totalFirepower: 487500,
            monthlyBurn: 312,
            urgentCount: 3,
            activeEntities: 7,
            urgentActions: [
                ("ClearScore Dropping", "Blake Thompson"),
                ("High Utilisation", "Blake Thompson"),
                ("Dormant Entity", "Sarah Chen")
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NexusEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NexusEntry>) -> Void) {
        let shared = UserDefaults(suiteName: "group.app.rork.nexus.shared")
        let firepower = shared?.double(forKey: "totalFirepower") ?? 487500
        let burn = shared?.double(forKey: "monthlyBurn") ?? 312
        let urgent = shared?.integer(forKey: "urgentCount") ?? 3
        let active = shared?.integer(forKey: "activeEntities") ?? 7

        var urgentActions: [(String, String)] = []
        if let data = shared?.data(forKey: "urgentActions"),
           let decoded = try? JSONDecoder().decode([[String]].self, from: data) {
            urgentActions = decoded.map { ($0[0], $0.count > 1 ? $0[1] : "") }
        } else {
            urgentActions = [
                ("ClearScore Dropping", "Blake Thompson"),
                ("High Utilisation", "Blake Thompson"),
                ("Dormant Entity", "Sarah Chen")
            ]
        }

        let entry = NexusEntry(
            date: .now,
            totalFirepower: firepower,
            monthlyBurn: burn,
            urgentCount: urgent,
            activeEntities: active,
            urgentActions: urgentActions
        )

        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct NexusWidgetSmallView: View {
    var entry: NexusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Spacer()
                if entry.urgentCount > 0 {
                    Text("\(entry.urgentCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Text("FIREPOWER")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            Text(formatCurrency(entry.totalFirepower))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)

            HStack(spacing: 4) {
                Text("\(entry.activeEntities) active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct NexusWidgetMediumView: View {
    var entry: NexusEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "bolt.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("NEXUS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }

                Spacer()

                Text("FIREPOWER")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                Text(formatCurrency(entry.totalFirepower))
                    .font(.system(size: 24, weight: .bold))
                    .minimumScaleFactor(0.7)

                HStack(spacing: 10) {
                    Label(formatCurrency(entry.monthlyBurn), systemImage: "flame")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Label("\(entry.activeEntities)", systemImage: "shield.checkered")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("URGENT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    Spacer()
                    if entry.urgentCount > 0 {
                        Text("\(entry.urgentCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red)
                            .clipShape(Capsule())
                    }
                }

                if entry.urgentActions.isEmpty {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All clear")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    ForEach(Array(entry.urgentActions.prefix(3).enumerated()), id: \.offset) { _, action in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.0)
                                .font(.caption2.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(action.1)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct NexusWidget: Widget {
    let kind: String = "NexusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NexusProvider()) { entry in
            NexusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nexus Command")
        .description("Empire pulse — firepower, burn rate, and urgent actions at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NexusWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: NexusEntry

    var body: some View {
        switch family {
        case .systemSmall:
            NexusWidgetSmallView(entry: entry)
        case .systemMedium:
            NexusWidgetMediumView(entry: entry)
        default:
            NexusWidgetSmallView(entry: entry)
        }
    }
}

private func formatCurrency(_ value: Double) -> String {
    if value >= 1_000_000 {
        return "$\(String(format: "%.1fM", value / 1_000_000))"
    } else if value >= 1_000 {
        return "$\(String(format: "%.0fK", value / 1_000))"
    }
    return "$\(String(format: "%.0f", value))"
}

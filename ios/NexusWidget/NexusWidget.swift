import WidgetKit
import SwiftUI

nonisolated struct NexusEntry: TimelineEntry {
    let date: Date
    let currentApplications: Int
    let urgentCount: Int
    let totalSubjects: Int
    let longestActiveSubject: String
    let longestActiveBank: String
    let longestActiveDays: Int
    let urgentActions: [(String, String)]
}

nonisolated struct NexusProvider: TimelineProvider {
    func placeholder(in context: Context) -> NexusEntry {
        NexusEntry(
            date: .now,
            currentApplications: 11,
            urgentCount: 4,
            totalSubjects: 8,
            longestActiveSubject: "Sarah Chen",
            longestActiveBank: "ANZ",
            longestActiveDays: 52,
            urgentActions: [
                ("Application Stalled — 52 Days", "Sarah Chen"),
                ("Score Drop — 32", "Blake Thompson"),
                ("Verification Required", "Pinnacle Trust")
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NexusEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NexusEntry>) -> Void) {
        let shared = UserDefaults(suiteName: "group.app.rork.nexus.shared")
        let apps = shared?.integer(forKey: "currentApplicationsTotal") ?? 11
        let urgent = shared?.integer(forKey: "urgentCount") ?? 4
        let subjects = shared?.integer(forKey: "totalSubjects") ?? 8
        let longestSubject = shared?.string(forKey: "longestActiveSubject") ?? "Sarah Chen"
        let longestBank = shared?.string(forKey: "longestActiveBank") ?? "ANZ"
        let longestDays = shared?.integer(forKey: "longestActiveDays") ?? 52

        var urgentActions: [(String, String)] = []
        if let data = shared?.data(forKey: "urgentActions"),
           let decoded = try? JSONDecoder().decode([[String]].self, from: data) {
            urgentActions = decoded.map { ($0[0], $0.count > 1 ? $0[1] : "") }
        } else {
            urgentActions = [
                ("Application Stalled — 52 Days", "Sarah Chen"),
                ("Score Drop — 32", "Blake Thompson"),
                ("Verification Required", "Pinnacle Trust")
            ]
        }

        let entry = NexusEntry(
            date: .now,
            currentApplications: apps,
            urgentCount: urgent,
            totalSubjects: subjects,
            longestActiveSubject: longestSubject,
            longestActiveBank: longestBank,
            longestActiveDays: longestDays,
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
                Image(systemName: "doc.text.magnifyingglass")
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

            Text("APPLICATIONS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            Text("\(entry.currentApplications)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)

            HStack(spacing: 4) {
                Text("\(entry.totalSubjects) subjects")
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
                    Image(systemName: "shield.checkered")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("NEXUS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }

                Spacer()

                Text("APPLICATIONS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                Text("\(entry.currentApplications)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)

                HStack(spacing: 10) {
                    if entry.longestActiveDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text("\(entry.longestActiveDays)d")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                    }

                    Label("\(entry.totalSubjects)", systemImage: "person.3")
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
        .description("Current applications, urgent actions, and longest active subject at a glance.")
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

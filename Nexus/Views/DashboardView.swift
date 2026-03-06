import SwiftUI

struct DashboardView: View {
    let store: NexusStore
    @State private var appeared: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                commsGlanceRow

                if !store.urgentActions.isEmpty {
                    urgentSection
                }

                recentActivitySection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
        .refreshable {
            await store.refreshData()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5)) { appeared = true }
        }
    }

    private var commsGlanceRow: some View {
        HStack(spacing: 12) {
            glanceTile(
                icon: "envelope.fill",
                color: .teal,
                value: "\(store.unreadEmailCount)",
                label: "Unread Emails"
            )

            glanceTile(
                icon: "message.fill",
                color: .blue,
                value: "\(store.unreadCommsCount)",
                label: "Unread Comms"
            )

            glanceTile(
                icon: "bell.badge.fill",
                color: .red,
                value: "\(store.alerts.filter { !$0.isRead }.count)",
                label: "Alerts"
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.05), value: appeared)
    }

    private func glanceTile(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title3.bold())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var urgentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
                Text("Needs Attention")
                    .font(.subheadline.bold())
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(store.urgentActions.prefix(3))) { alert in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(alert.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(alert.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    if alert.id != store.urgentActions.prefix(3).last?.id {
                        Divider().padding(.leading, 32)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.1), value: appeared)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Activity")
                .font(.subheadline.bold())

            VStack(spacing: 0) {
                let recentComms = store.communications.sorted { $0.timestamp > $1.timestamp }.prefix(5)
                ForEach(Array(recentComms)) { comm in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(commColor(comm.type).opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: comm.type.icon)
                                .font(.caption)
                                .foregroundStyle(commColor(comm.type))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(comm.sender)
                                .font(.subheadline.weight(comm.isRead ? .regular : .semibold))
                                .lineLimit(1)
                            Text(comm.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(comm.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            if !comm.isRead {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)

                    if comm.id != recentComms.last?.id {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.15), value: appeared)
    }

    private func commColor(_ type: CommType) -> Color {
        switch type {
        case .sms: .blue
        case .call: .green
        case .voicemail: .purple
        }
    }
}

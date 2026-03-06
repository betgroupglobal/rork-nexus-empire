import SwiftUI

struct DashboardView: View {
    let store: NexusStore
    @State private var appeared: Bool = false
    @State private var animatedFirepower: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                firepowerCard

                commsGlanceRow

                if !store.urgentActions.isEmpty {
                    urgentSection
                }

                entityHealthStrip
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
            withAnimation(.easeOut(duration: 1.0)) { animatedFirepower = store.totalFirepower }
        }
        .onChange(of: store.totalFirepower) { _, newValue in
            withAnimation(.easeOut(duration: 0.8)) { animatedFirepower = newValue }
        }
    }

    private var firepowerCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Total Firepower")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                Text(animatedFirepower, format: .currency(code: "AUD").precision(.fractionLength(0)))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 0) {
                summaryPill(label: "Burn/mo", value: store.monthlyBurn.formatted(.currency(code: "AUD").precision(.fractionLength(0))))
                Divider().frame(height: 28).background(.white.opacity(0.2))
                summaryPill(label: "Active", value: "\(store.activeEntityCount)")
                Divider().frame(height: 28).background(.white.opacity(0.2))
                summaryPill(label: "Urgent", value: "\(store.urgentActions.count)", highlight: !store.urgentActions.isEmpty)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.10, blue: 0.20), Color(red: 0.10, green: 0.16, blue: 0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.5), value: appeared)
    }

    private func summaryPill(label: String, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(highlight ? .red : .white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
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
                            if let entity = alert.entityName {
                                Text(entity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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

    private var entityHealthStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Entity Health")
                .font(.subheadline.bold())

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(store.entities.filter { $0.status != .archived }) { entity in
                        VStack(spacing: 8) {
                            HealthRingView(score: entity.healthScore, size: 48, lineWidth: 4)

                            Text(entity.name)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .frame(width: 64)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.2), value: appeared)
    }
}

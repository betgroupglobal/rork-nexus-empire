import SwiftUI

struct DashboardView: View {
    let store: NexusStore
    @State private var appeared: Bool = false
    @State private var firepowerAnimated: Double = 0
    @State private var burnAnimated: Double = 0
    @State private var showCompose: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                firepowerHero
                quickStatsRow
                healthOverview

                if !store.urgentActions.isEmpty {
                    urgentSection
                }

                recentActivitySection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.ctConnectionStatus == .connected {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .refreshable {
            await store.refreshData()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
            animateCounters()
        }
        .sheet(isPresented: $showCompose) {
            SMSComposeView(store: store)
        }
    }

    private func animateCounters() {
        withAnimation(.easeOut(duration: 1.2)) {
            firepowerAnimated = store.totalFirepower
            burnAnimated = store.monthlyBurn
        }
    }

    private var firepowerHero: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOTAL FIREPOWER")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)

                    Text(formatCurrency(firepowerAnimated))
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 1.2), value: firepowerAnimated)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, options: .repeating.speed(0.5))

                    if let lastFetch = CacheService.lastFetchDate() {
                        Text(lastFetch, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Divider()

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("BURN RATE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                    }
                    Text(formatCurrency(burnAnimated) + "/mo")
                        .font(.subheadline.bold())
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("HEALTH")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(healthColor(store.overallHealth))
                    }
                    Text("\(Int(store.overallHealth))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(healthColor(store.overallHealth))
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var quickStatsRow: some View {
        HStack(spacing: 10) {
            statCard(
                icon: "envelope.fill",
                color: .teal,
                value: "\(store.unreadEmailCount)",
                label: "Emails"
            )
            statCard(
                icon: "message.fill",
                color: .blue,
                value: "\(store.unreadCommsCount)",
                label: "Messages"
            )
            statCard(
                icon: "bell.badge.fill",
                color: .red,
                value: "\(store.alerts.filter { !$0.isRead }.count)",
                label: "Alerts"
            )
            statCard(
                icon: "phone.connection.fill",
                color: .green,
                value: "\(store.ctDIDs.count)",
                label: "DIDs"
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.08), value: appeared)
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var healthOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .foregroundStyle(.pink)
                    .font(.subheadline)
                Text("Account Health")
                    .font(.subheadline.bold())
                Spacer()
            }

            HStack(spacing: 16) {
                healthRing(
                    label: "Credit",
                    value: store.creditHealth,
                    color: healthColor(store.creditHealth)
                )
                healthRing(
                    label: "Activity",
                    value: store.activityHealth,
                    color: healthColor(store.activityHealth)
                )
                healthRing(
                    label: "Comms",
                    value: store.commsHealth,
                    color: healthColor(store.commsHealth)
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.12), value: appeared)
    }

    private func healthRing(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 6)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: appeared ? value / 100 : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3), value: appeared)

                Text("\(Int(value))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var urgentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
                    .symbolEffect(.bounce, options: .nonRepeating)
                Text("Needs Attention")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(store.urgentActions.count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.red)
                    .clipShape(Capsule())
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
        .animation(.spring(response: 0.5).delay(0.16), value: appeared)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Activity")
                .font(.subheadline.bold())

            VStack(spacing: 0) {
                let recentComms = store.communications.sorted { $0.timestamp > $1.timestamp }.prefix(5)
                if recentComms.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No recent activity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
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
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.2), value: appeared)
    }

    private func commColor(_ type: CommType) -> Color {
        switch type {
        case .sms: .blue
        case .call: .green
        case .voicemail: .purple
        }
    }

    private func healthColor(_ value: Double) -> Color {
        if value >= 80 { return .green }
        if value >= 50 { return .orange }
        return .red
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "$\(String(format: "%.1fM", value / 1_000_000))"
        } else if value >= 1_000 {
            return "$\(String(format: "%.0fK", value / 1_000))"
        }
        return "$\(String(format: "%.0f", value))"
    }
}

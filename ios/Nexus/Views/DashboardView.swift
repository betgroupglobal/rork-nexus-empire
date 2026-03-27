import SwiftUI

struct DashboardView: View {
    let store: NexusStore
    let authVM: AuthViewModel
    @Environment(\.isVoidTheme) private var isVoidTheme
    @State private var appeared: Bool = false
    @State private var appCountAnimated: Int = 0
    @State private var showCompose: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                applicationsHero
                tilesRow
                urgentActionsCard
                quickStatsRow
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(isVoidTheme ? Color.black : Color(.systemGroupedBackground))
        .navigationTitle("War Room")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if store.ctConnectionStatus == .connected {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .refreshable {
            await store.refreshData()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: store.isLoading)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
            animateCounter()
        }
        .sheet(isPresented: $showCompose) {
            SMSComposeView(store: store)
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView(store: store, authVM: authVM)
        }
    }

    private func animateCounter() {
        let target = store.currentApplicationsTotal
        guard target > 0 else { appCountAnimated = 0; return }
        appCountAnimated = 0
        let steps = min(target, 30)
        let interval = 0.8 / Double(steps)
        for i in 1...steps {
            let delay = interval * Double(i)
            let value = Int(Double(target) * (Double(i) / Double(steps)))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.05)) {
                    appCountAnimated = value
                }
            }
        }
    }

    private var applicationsHero: some View {
        VStack(spacing: 12) {
            Text("CURRENT APPLICATIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            Text("\(appCountAnimated)")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text("Live across all subjects")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if store.dataMode == .demo {
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text("Sample Data")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(isVoidTheme ? Color(.systemGray6).opacity(0.12) : Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            store.criticalCount > 0 ? Color.red.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var tilesRow: some View {
        HStack(spacing: 12) {
            longestActiveTile
            urgentCountTile
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.06), value: appeared)
    }

    private var longestActiveTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("LONGEST ACTIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }

            if let longest = store.longestActiveApp {
                Text(longest.subject.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(longest.application.daysActive)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(longest.application.daysActive > 45 ? .red : .primary)
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(longest.application.bank)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No active apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(isVoidTheme ? Color(.systemGray6).opacity(0.12) : Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var urgentCountTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text("URGENT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }

            let total = store.criticalCount + store.warningCount
            Text("\(total)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(total > 0 ? .red : .green)

            HStack(spacing: 8) {
                if store.criticalCount > 0 {
                    badgePill(count: store.criticalCount, color: .red)
                }
                if store.warningCount > 0 {
                    badgePill(count: store.warningCount, color: .yellow)
                }
                if total == 0 {
                    badgePill(count: 0, color: .green, label: "Clear")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(isVoidTheme ? Color(.systemGray6).opacity(0.12) : Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func badgePill(count: Int, color: Color, label: String? = nil) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label ?? "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var urgentActionsCard: some View {
        let actions = (store.urgentActions + store.warningActions).prefix(4)

        return Group {
            if !actions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text("Needs Attention")
                            .font(.subheadline.bold())
                        Spacer()
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(actions)) { alert in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(alert.priority == .critical ? Color.red : Color.yellow)
                                    .frame(width: 6, height: 6)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(alert.title)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    if let name = alert.subjectName {
                                        Text(name)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                Text(alert.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)

                            if alert.id != actions.last?.id {
                                Divider().padding(.leading, 28)
                            }
                        }
                    }
                    .background(isVoidTheme ? Color(.systemGray6).opacity(0.08) : Color(.tertiarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 12))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.5).delay(0.1), value: appeared)
            }
        }
    }

    private var quickStatsRow: some View {
        HStack(spacing: 10) {
            quickStat(icon: "person.3.fill", value: "\(store.subjects.count)", label: "Subjects", color: .blue)
            quickStat(icon: "bubble.left.and.bubble.right.fill", value: "\(store.activeComms24h)", label: "Active 24h", color: .green)
            quickStat(icon: "envelope.badge.fill", value: "\(store.totalUnreadMessages)", label: "Unread", color: .red)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.14), value: appeared)
    }

    private func quickStat(icon: String, value: String, label: String, color: Color) -> some View {
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
        .background(isVoidTheme ? Color(.systemGray6).opacity(0.12) : Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }
}

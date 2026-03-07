import SwiftUI

struct AlertsView: View {
    let store: NexusStore
    @Environment(\.isVoidTheme) private var isVoidTheme
    @State private var selectedType: AlertType? = nil
    @State private var selectedSubject: Subject?
    @State private var selectedAlert: NexusAlert?

    var body: some View {
        List {
            filterSection
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(filteredAlerts) { alert in
                Button {
                    store.markAlertRead(alert)
                    if let subject = store.findRelatedSubject(for: alert) {
                        selectedSubject = subject
                    } else {
                        selectedAlert = alert
                    }
                } label: {
                    AlertRowView(alert: alert)
                }
                .tint(.primary)
                .swipeActions(edge: .trailing) {
                    if !alert.isRead {
                        Button {
                            store.markAlertRead(alert)
                        } label: {
                            Label("Read", systemImage: "envelope.open")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Alert Brain")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        store.markAllAlertsRead()
                    } label: {
                        Label("Mark All Read", systemImage: "envelope.open")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if filteredAlerts.isEmpty {
                ContentUnavailableView("No Alerts", systemImage: "bell.slash", description: Text("All clear — nothing requires your attention"))
            }
        }
        .navigationDestination(item: $selectedSubject) { subject in
            SubjectDetailView(subject: subject, store: store)
        }
        .sheet(item: $selectedAlert) { alert in
            AlertDetailSheet(alert: alert, store: store)
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedType = nil }
                } label: {
                    Text("All")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedType == nil ? .blue : (isVoidTheme ? Color.white.opacity(0.08) : Color(.tertiarySystemGroupedBackground)))
                        .foregroundStyle(selectedType == nil ? .white : .primary)
                        .clipShape(Capsule())
                }

                ForEach(AlertType.allCases) { type in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedType = type }
                    } label: {
                        Label(type.rawValue, systemImage: type.icon)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedType == type ? .blue : (isVoidTheme ? Color.white.opacity(0.08) : Color(.tertiarySystemGroupedBackground)))
                            .foregroundStyle(selectedType == type ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selectedType)
    }

    private var filteredAlerts: [NexusAlert] {
        var result = store.alerts
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        return result.sorted { $0.timestamp > $1.timestamp }
    }
}

struct AlertDetailSheet: View {
    let alert: NexusAlert
    let store: NexusStore
    @Environment(\.dismiss) private var dismiss

    private var priorityColor: Color {
        switch alert.priority {
        case .critical: .red
        case .warning: .orange
        case .info: .blue
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(priorityColor.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: alert.type.icon)
                                .font(.title3)
                                .foregroundStyle(priorityColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.title)
                                .font(.title3.bold())
                            HStack(spacing: 8) {
                                Text(alert.priority.rawValue)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(priorityColor.opacity(0.12))
                                    .foregroundStyle(priorityColor)
                                    .clipShape(Capsule())

                                if let name = alert.subjectName {
                                    Text(name)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    Label(alert.timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text(alert.message)
                        .font(.body)

                    if alert.priority == .critical {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Recommended Actions", systemImage: "lightbulb.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 6) {
                                recommendedAction("Review the affected subject immediately")
                                recommendedAction("Follow up with the bank on stalled applications")
                                recommendedAction("Update documents if verification is pending")
                            }
                        }
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Alert Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private func recommendedAction(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

import SwiftUI

struct AlertsView: View {
    let store: NexusStore
    @State private var selectedType: AlertType? = nil

    var body: some View {
        List {
            filterSection
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(filteredAlerts) { alert in
                Button {
                    store.markAlertRead(alert)
                } label: {
                    AlertRowView(alert: alert)
                }
                .tint(.primary)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Alerts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Mark All Read") {
                        store.markAllAlertsRead()
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
    }

    private var filterSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.snappy) { selectedType = nil }
                } label: {
                    Text("All")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedType == nil ? .blue : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(selectedType == nil ? .white : .primary)
                        .clipShape(Capsule())
                }

                ForEach(AlertType.allCases) { type in
                    Button {
                        withAnimation(.snappy) { selectedType = type }
                    } label: {
                        Label(type.rawValue, systemImage: type.icon)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedType == type ? .blue : Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(selectedType == type ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
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

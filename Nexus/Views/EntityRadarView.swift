import SwiftUI

struct EntityRadarView: View {
    let store: NexusStore
    @State private var searchText: String = ""
    @State private var selectedFilter: EntityFilter = .all
    @State private var selectedEntity: NexusEntity?

    var body: some View {
        List {
            filterChips
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(filteredEntities) { entity in
                NavigationLink(value: entity) {
                    EntityRowView(entity: entity)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.archiveEntity(entity)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        store.toggleEntityFlag(entity)
                    } label: {
                        Label(
                            entity.isFlagged ? "Unflag" : "Flag",
                            systemImage: entity.isFlagged ? "flag.slash" : "flag.fill"
                        )
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search entities...")
        .navigationTitle("Entity Radar")
        .navigationDestination(for: NexusEntity.self) { entity in
            EntityDetailView(store: store, entity: entity)
        }
        .overlay {
            if filteredEntities.isEmpty {
                ContentUnavailableView("No Entities Found", systemImage: "magnifyingglass", description: Text("Try adjusting your search or filters"))
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(EntityFilter.allCases) { filter in
                    Button {
                        withAnimation(.snappy) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if filter != .all {
                                Circle()
                                    .fill(filter.color)
                                    .frame(width: 6, height: 6)
                            }
                            Text(filter.rawValue)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? .blue : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(selectedFilter == filter ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .sensoryFeedback(.selection, trigger: selectedFilter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var filteredEntities: [NexusEntity] {
        var result = store.entities

        switch selectedFilter {
        case .all: break
        case .active: result = result.filter { $0.status == .active }
        case .dormant: result = result.filter { $0.status == .dormant }
        case .atRisk: result = result.filter { $0.status == .atRisk }
        case .flagged: result = result.filter { $0.isFlagged }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.type.rawValue.localizedStandardContains(searchText) ||
                $0.status.rawValue.localizedStandardContains(searchText)
            }
        }

        return result.sorted { $0.healthScore > $1.healthScore }
    }
}

nonisolated enum EntityFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case active = "Active"
    case dormant = "Dormant"
    case atRisk = "At Risk"
    case flagged = "Flagged"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .all: .clear
        case .active: .green
        case .dormant: .yellow
        case .atRisk: .red
        case .flagged: .orange
        }
    }
}

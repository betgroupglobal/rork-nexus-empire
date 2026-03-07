import SwiftUI

struct ContentView: View {
    @State private var authVM = AuthViewModel()
    @State private var store = NexusStore()
    @State private var selectedTab: AppTab = .dashboard
    @AppStorage("appearance") private var appearance: String = "void"

    var body: some View {
        Group {
            if authVM.isAuthenticated {
                mainTabView
            } else {
                LoginView(authVM: authVM)
            }
        }
        .animation(.smooth(duration: 0.4), value: authVM.isAuthenticated)
        .preferredColorScheme(colorScheme)
        .tint(appearance == "void" ? .red : .blue)
        .environment(\.isVoidTheme, appearance == "void")
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("War Room", systemImage: "chart.bar.xaxis", value: .dashboard) {
                NavigationStack {
                    DashboardView(store: store, authVM: authVM)
                }
            }

            Tab("Subjects", systemImage: "person.3.fill", value: .subjects) {
                NavigationStack {
                    SubjectDatabaseView(store: store)
                }
            }

            Tab("Comms", systemImage: "antenna.radiowaves.left.and.right", value: .comms) {
                NavigationStack {
                    CommsView(store: store)
                }
                .badge(store.unreadCommsCount)
            }

            Tab("Email", systemImage: "envelope.badge", value: .email) {
                NavigationStack {
                    EmailInboxView(store: store)
                }
                .badge(store.unreadEmailCount)
            }

            Tab("Alerts", systemImage: "bell.badge", value: .alerts) {
                NavigationStack {
                    AlertsView(store: store)
                }
                .badge(store.alerts.filter { !$0.isRead }.count)
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark", "void": .dark
        default: nil
        }
    }
}

nonisolated enum AppTab: String, Hashable, Sendable {
    case dashboard
    case subjects
    case comms
    case email
    case alerts
}

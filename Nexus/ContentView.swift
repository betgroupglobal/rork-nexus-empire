import SwiftUI

struct ContentView: View {
    @State private var authVM = AuthViewModel()
    @State private var store = NexusStore()
    @State private var selectedTab: AppTab = .dashboard
    @AppStorage("appearance") private var appearance: String = "system"

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
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "chart.bar.xaxis", value: .dashboard) {
                NavigationStack {
                    DashboardView(store: store)
                }
            }

            Tab("Inbox", systemImage: "tray", value: .inbox) {
                NavigationStack {
                    UnifiedInboxView(store: store)
                }
                .badge(store.unreadCommsCount + store.unreadEmailCount)
            }

            Tab("Alerts", systemImage: "bell.badge", value: .alerts) {
                NavigationStack {
                    AlertsView(store: store)
                }
                .badge(store.alerts.filter { !$0.isRead }.count)
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView(store: store, authVM: authVM)
                }
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}

nonisolated enum AppTab: String, Hashable, Sendable {
    case dashboard
    case inbox
    case alerts
    case settings
}

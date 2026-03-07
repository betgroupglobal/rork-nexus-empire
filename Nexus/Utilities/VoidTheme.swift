import SwiftUI

private enum VoidThemeKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isVoidTheme: Bool {
        get { self[VoidThemeKey.self] }
        set { self[VoidThemeKey.self] = newValue }
    }
}

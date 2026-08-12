import SwiftUI

private struct NavigationTabKey: EnvironmentKey {
    static let defaultValue: AppTab = .home
}

extension EnvironmentValues {
    var navigationTab: AppTab {
        get { self[NavigationTabKey.self] }
        set { self[NavigationTabKey.self] = newValue }
    }
}

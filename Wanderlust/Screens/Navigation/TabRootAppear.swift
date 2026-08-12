import SwiftUI

private struct TabRootAppearModifier: ViewModifier {
    let tab: AppTab
    @ObservedObject var router: NavigationRouter
    let perform: () -> Void

    @State private var wasActiveAtRoot = false

    func body(content: Content) -> some View {
        content
            .onAppear { evaluate() }
            .onChange(of: router.selectedTab) { _, _ in evaluate() }
            .onChange(of: router[tab]) { _, _ in evaluate() }
    }

    private func evaluate() {
        let isActiveAtRoot = router.selectedTab == tab && router[tab].isEmpty
        if isActiveAtRoot && !wasActiveAtRoot {
            perform()
        }
        wasActiveAtRoot = isActiveAtRoot
    }
}

extension View {
    func onTabRootAppear(
        _ tab: AppTab,
        router: NavigationRouter,
        perform: @escaping () -> Void
    ) -> some View {
        modifier(TabRootAppearModifier(tab: tab, router: router, perform: perform))
    }
}

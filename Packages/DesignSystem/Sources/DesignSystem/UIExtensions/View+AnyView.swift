import SwiftUI

public extension View {
    func anyView() -> AnyView {
        AnyView(self)
    }
}

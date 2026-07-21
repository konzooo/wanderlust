import SwiftUI

struct CustomBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    var color: Color = .black
    var systemImageName: String = "chevron.left"

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: systemImageName)
                    }
                }
            }
    }
}

public extension View {
    func customBackButton(color: Color = .black, systemImageName: String = "chevron.left") -> some View {
        self.modifier(CustomBackButtonModifier(color: color, systemImageName: systemImageName))
    }
}

import Foundation
import SwiftUI

/// A ViewModifier that injects the DrawerMenu, hides the navigation bar back button, and adds the drawer button to the toolbar.
/// Usage:
/// ```swift
/// .drawerMenu(isOpen: $isDrawerOpen, selected: .home) { row in ... }
/// ```
public struct DrawerToolbarModifier: ViewModifier {
    @Binding var isDrawerOpen: Bool
    var selected: DrawerRow
    var router: DrawerNavigating
    var trailingBarButton: AnyView? = nil
    var isActive: Bool = true
    var buttonBackground: Bool = true

    public func body(content: Content) -> some View {
        ZStack {
            content
                // Hide the back button just when the toolbar is visible
                .navigationBarBackButtonHidden(isActive)
                .toolbar {
                    if isActive {
                        // ----- Drawer Button
                        ToolbarItem(placement: .navigationBarLeading) {
                            drawerButton
                        }
                        
                        // ----- Trailing Button, if present
                        if let trailingBarButton {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                trailingBarButton
                            }
                        }
                    }
                }
            
            DrawerMenu(
                isOpen: $isDrawerOpen,
                selected: selected,
                onSelection: { row in
                    router.processDrawerSelection(row)
                }
            )
        }
    }
    
    private var drawerButton: some View {
        Button(action: { isDrawerOpen.toggle() }) {
            Image("drawer")
                .resizable()
                .scaledToFit()
                .tint(Color.black)
                .frame(width: 24, height: 24)
        }
        .padding(.top, 2)
        .conditional(buttonBackground) { view in
            view
                .padding(.leading, 8)
                .background(.thinMaterial.opacity(0.5), in: Circle())
        }
    }
}

public extension View {
    /// Adds a drawer menu to the view, encapsulating all required logic.
    /// - Parameters:
    ///   - isOpen: Binding to control drawer open/close state
    ///   - selected: The currently selected DrawerRow
    ///   - router: An object conforming to DrawerNavigating to handle navigation
    func drawerToolbar(
        isOpen: Binding<Bool>,
        selected: DrawerRow,
        router: DrawerNavigating,
        trailingButton: AnyView? = nil,
        isActive: Bool = true,
        buttonBackground: Bool = false
    ) -> some View {
        self.modifier(DrawerToolbarModifier(
            isDrawerOpen: isOpen,
            selected: selected,
            router: router,
            trailingBarButton: trailingButton,
            isActive: isActive,
            buttonBackground: buttonBackground
        ))
    }
} 

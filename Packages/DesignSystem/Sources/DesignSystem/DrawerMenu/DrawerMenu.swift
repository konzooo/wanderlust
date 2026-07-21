//
//  NavigationMenu.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 2/7/25.
//

import DesignSystem
import SwiftUI

/// A side drawer menu that slides in from the leading edge, supporting drag-to-open/close and selection.
struct DrawerMenu: View {
    /// Controls whether the drawer is open.
    @Binding var isOpen: Bool
    /// The currently selected row.
    var selected: DrawerRow
    /// Called when a row is selected.
    var onSelection: (DrawerRow) -> Void
    /// The width of the drawer.
    var totalWidth: CGFloat = Constants.drawerWidth
    /// The edge transition for the drawer.
    var edgeTransition: AnyTransition = .move(edge: .leading)
    
    // Internal state and logic
    @StateObject private var viewModel = DrawerMenuViewModel()
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Hot zone for edge drag (always hit testable when drawer is closed)
            Color.clear
                .frame(width: DrawerMenu.Constants.edgeDragWidth)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            viewModel.handleDragChanged(value, isActive: isOpen, width: totalWidth)
                        }
                        .onEnded { value in
                            viewModel.handleDragEnded(value, isActive: isOpen, width: totalWidth, isActiveBinding: $isOpen)
                        }
                )
                .allowsHitTesting(!isOpen && viewModel.dragOffset == 0)

            // The rest of the drawer overlay (only hit testable when open or dragging)
            ZStack(alignment: .bottom) {
                if isOpen || viewModel.dragOffset != 0 {
                    Color.black
                        .opacity(viewModel.overlayOpacity(isActive: isOpen, width: totalWidth))
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.closeDrawer(with: $isOpen)
                        }
                    drawerView
                        .transition(edgeTransition)
                        .background(Color.clear)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
            .animation(Constants.spring, value: isOpen)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.handleDragChanged(value, isActive: isOpen, width: totalWidth)
                    }
                    .onEnded { value in
                        viewModel.handleDragEnded(value, isActive: isOpen, width: totalWidth, isActiveBinding: $isOpen)
                    }
            )
            .allowsHitTesting(isOpen || viewModel.dragOffset != 0)
        }
    }
    
    private var drawerView: some View {
        HStack {
            ZStack {
                Rectangle()
                    .fill(.white)
                    .frame(width: totalWidth)
                    .shadow(color: .green.opacity(0.1), radius: 5, x: 0, y: 3)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(DrawerRow.allCases.filter{ $0 != .none }, id: \.self) { row in
                        RowView(
                            isSelected: selected == row,
                            icon: row.iconName,
                            title: row.title,
                            row: row
                        ) {
                            onSelection(row)
                            viewModel.closeDrawer(with: $isOpen)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 100)
                .frame(width: totalWidth)
                .background(Color.white)
            }
            .padding(.top, 15)
            .offset(x: viewModel.drawerOffset(isActive: isOpen, width: totalWidth))
            Spacer()
        }
        .background(.clear)
    }
}

private extension DrawerMenu {
    /// Constants for drawer configuration
    enum Constants {
        static let drawerWidth: CGFloat = 220
        static let edgeDragWidth: CGFloat = 40
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0.5)
    }
}

/// ViewModel for DrawerMenu encapsulating all gesture and animation logic.
private class DrawerMenuViewModel: ObservableObject {
    @Published var dragOffset: CGFloat = 0
    
    /// Returns the current drawer offset for the animation.
    func drawerOffset(isActive: Bool, width: CGFloat) -> CGFloat {
        dragOffset + (isActive ? 0 : -width)
    }
    /// Returns the overlay opacity based on how open the drawer is.
    func overlayOpacity(isActive: Bool, width: CGFloat) -> Double {
        0.3 * Double((isActive ? 1 : 0) + abs(dragOffset) / width)
    }
    /// Handles the drag gesture's onChanged event.
    func handleDragChanged(_ value: DragGesture.Value, isActive: Bool, width: CGFloat) {
        if isActive || value.startLocation.x < DrawerMenu.Constants.edgeDragWidth {
            let drag = value.translation.width
            if isActive {
                dragOffset = min(0, max(drag, -width))
            } else {
                dragOffset = max(0, min(drag, width))
            }
        }
    }
    /// Handles the drag gesture's onEnded event.
    func handleDragEnded(_ value: DragGesture.Value, isActive: Bool, width: CGFloat, isActiveBinding: Binding<Bool>) {
        let drag = value.translation.width
        let threshold: CGFloat = width / 2
        if isActive {
            if drag < -threshold {
                withAnimation(DrawerMenu.Constants.spring) { isActiveBinding.wrappedValue = false }
            }
        } else {
            if drag > threshold {
                withAnimation(DrawerMenu.Constants.spring) { isActiveBinding.wrappedValue = true }
            }
        }
        withAnimation(DrawerMenu.Constants.spring) { dragOffset = 0 }
    }
    /// Closes the drawer with animation.
    func closeDrawer(with isActive: Binding<Bool>) {
        withAnimation(DrawerMenu.Constants.spring) {
            isActive.wrappedValue = false
            dragOffset = 0
        }
    }
}

extension DrawerMenu {
    func RowView(
        isSelected: Bool,
        icon: String,
        title: String,
        row: DrawerRow,
        hideDivider: Bool = false,
        onTap: @escaping (()->())
    ) -> some View{
        Button{
            onTap()
        } label: {
            HStack(spacing: 10){
                Rectangle()
                    .fill(isSelected ? Color.appTint.opacity(0.4) : .white)
                    .frame(width: 5)
                    .padding(.trailing, 15)
                
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(
                        isSelected ? .appTint : (row == .feedback ? Color.green : Color(UIColor.darkGray))
                    )
                    .frame(width: 24, height: 32)
                
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(
                        isSelected ? .appTint : (row == .feedback ? Color.green : Color(UIColor.darkGray))
                    )
                
                Spacer()
            }
        }
        .frame(height: 50)
        .background(
            isSelected ? Color.appTint.opacity(0.2) : .white
        )
    }
}

#Preview {
    ZStack {
        Color.red
        
        DrawerMenu(isOpen: Binding.constant(false), selected: .none, onSelection: { _ in })
    }
    
}

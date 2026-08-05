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
            VStack(alignment: .leading, spacing: 0) {
                // Branded header
                Text("Wanderlust")
                    .font(.kanit(22))
                    .padding(.leading, 76)
                    .padding(.trailing, 20)
                    .padding(.top, 64)
                    .padding(.bottom, 18)

                Divider().padding(.horizontal, 20)

                VStack(spacing: 4) {
                    ForEach(
                        DrawerRow.allCases.filter {
                            $0 != .none && $0 != .feedback
                        },
                        id: \.self
                    ) { row in
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
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Spacer()

                Divider()
                    .padding(.horizontal, 20)

                VStack(spacing: 0) {
                    RowView(
                        isSelected: selected == .feedback,
                        icon: DrawerRow.feedback.iconName,
                        title: DrawerRow.feedback.title,
                        row: .feedback
                    ) {
                        onSelection(.feedback)
                        viewModel.closeDrawer(with: $isOpen)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .frame(width: totalWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(.systemBackground))
            .ignoresSafeArea()
            .shadow(color: .black.opacity(0.18), radius: 20, x: 6, y: 0)
            .offset(x: viewModel.drawerOffset(isActive: isOpen, width: totalWidth))
            Spacer()
        }
        .background(.clear)
    }
}

private extension DrawerMenu {
    /// Constants for drawer configuration
    enum Constants {
        static let drawerWidth: CGFloat = 280
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
        // "Give us feedback" keeps its green identity regardless of selection;
        // every other row follows the normal selected/unselected tint.
        let tint: Color = row == .feedback ? .green : (isSelected ? .appTint : .primary)

        return Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 26)

                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.appTint.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.red
        
        DrawerMenu(isOpen: Binding.constant(false), selected: .none, onSelection: { _ in })
    }
    
}

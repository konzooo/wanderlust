import SwiftUI

struct FullWidthModifier: ViewModifier {
    var alignment: Alignment

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

public extension View {
    /// Applies a modifier to the view to make it occupy the full available width of its parent container.
    ///
    /// This method uses the internal `FullWidthModifier` to adjust the view's width. It can be particularly useful
    /// when you want a view to stretch across the full width of the screen or its parent view, with the ability
    /// to align its content according to the specified alignment parameter.
    ///
    /// - Parameter alignment: An `Alignment` value that determines the alignment of the content within the full width.
    ///                        The default value is `.leading`, which aligns the content to the leading edge.
    /// - Returns: A view that has been modified to occupy the full available width of its parent container, with
    /// content
    ///            aligned according to the `alignment` parameter.
    func fullWidth(alignment: Alignment = .leading) -> some View {
        modifier(FullWidthModifier(alignment: alignment))
    }
}

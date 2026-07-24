import Combine
import SwiftUI

/// `CardStackWrapper` decorates a plain `CardStack` with **tap‑to‑swipe**
/// gesture support.
///
/// The base `CardStack` already handles drag gestures and external button
/// swipes (via the `manualSwipe` publisher).  What it does **not** offer is the
/// familiar *Tinder‑style* “tap left / tap right” shortcut.  This wrapper
/// implements exactly that, while staying entirely generic over the data set
/// and card content.
///
/// ### How it works
/// 1. The wrapper owns a single `@State` variable, `cardTapSwipe`, which is a
///    `SwipeDirection?`.  `nil` means *no tap‑request pending*.
/// 2. We pass a **binding** of that state (`$cardTapSwipe`) down to the
///    `CardStack`, which in turn forwards it to **only** the *top* `CardView`.
/// 3. An invisible `tapOverlay` sits on top of the front card; it splits the
///    card’s width into two halves:
///    * tap **left** → `cardTapSwipe = .left`
///    * tap **right** → `cardTapSwipe = .right`
/// 4. `CardView` observes the binding change in its `.onChange`, runs the
///    configured swipe animation, and finally resets the binding back to `nil`
///    (see `CardView` implementation for details).
///
/// The wrapper itself doesn’t animate or move anything—it merely injects the
/// gesture and state plumbing required for `CardView` to do its job.
///
/// ### Generic parameters
/// * `Data`    – Collection of domain models.
/// * `ID`      – Stable identifier for each element (used by `ForEach`).
/// * `Content` – View builder that turns a model element into card UI.
///
/// ---
//
//  CardStackWrapper.swift
//
//  Adds tap-to-swipe overlay to CardStack and pipes through undo publisher.
//

import Combine
import SwiftUI

public struct CardStackWrapper<Data, ID, Content>: View
where Data: RandomAccessCollection,
      Data.Index: Hashable,
      ID: Hashable,
      Content: View {

    // Immutable inputs
    let data        : Data
    let id          : KeyPath<Data.Element, ID>
    let direction   : (Double) -> SwipeDirection?
    let onSwipe     : (Data.Element, SwipeDirection) -> Void
    let onEmptyStack: () -> Void
    let manualSwipe : AnyPublisher<SwipeDirection, Never>
    let manualUndo  : AnyPublisher<Void,          Never>
    let isInteractionEnabled: Bool
    let content     : (Data.Element, SwipeDirection?, Bool) -> Content

    // Local tap-to-swipe state
    @State private var cardTapSwipe: SwipeDirection? = nil

    // MARK: Body
    public var body: some View {
        CardStack(
            direction   : direction,
            data        : data,
            id          : id,
            onSwipe     : onSwipe,
            onEmptyStack: onEmptyStack,
            manualSwipe : manualSwipe,
            manualUndo  : manualUndo,
            isInteractionEnabled: isInteractionEnabled,
            cardTapSwipe: $cardTapSwipe,
            content     : contentBuilder
        )
        .onChange(of: cardTapSwipe) { _, _ in /* hook for haptics if wanted */ }
    }

    @ViewBuilder private func contentBuilder(_ element: Data.Element,
                                             _ dir: SwipeDirection?,
                                             _ isTop: Bool) -> some View
    {
        ZStack {
            content(element, dir, isTop)
                .overlay(isTop && isInteractionEnabled ? tapOverlay : nil)
        }
    }

    // Transparent overlay that splits the card into left/right halves
    private var tapOverlay: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(cardTapSwipe == nil)
                .onTapGesture(coordinateSpace: .local) { location in
                    let mid = geo.size.width / 2
                    cardTapSwipe = (location.x < mid) ? .left : .right
                }
        }
    }
}

// MARK: Convenience when Data.Element : Identifiable
public extension CardStackWrapper where Data.Element: Identifiable,
                                      ID == Data.Element.ID {

    init(
        data        : Data,
        direction   : @escaping (Double) -> SwipeDirection?,
        onSwipe     : @escaping (Data.Element, SwipeDirection) -> Void,
        onEmptyStack: @escaping () -> Void,
        manualSwipe : AnyPublisher<SwipeDirection, Never>,
        manualUndo  : AnyPublisher<Void,          Never> = Empty().eraseToAnyPublisher(),
        isInteractionEnabled: Bool = true,
        @ViewBuilder content: @escaping (Data.Element, SwipeDirection?, Bool) -> Content
    ) {
        self.init(data        : data,
                  id          : \Data.Element.id,
                  direction   : direction,
                  onSwipe     : onSwipe,
                  onEmptyStack: onEmptyStack,
                  manualSwipe : manualSwipe,
                  manualUndo  : manualUndo,
                  isInteractionEnabled: isInteractionEnabled,
                  content     : content)
    }
}

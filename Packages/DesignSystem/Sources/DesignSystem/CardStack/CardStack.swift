import Combine
import SwiftUI

/// A generic, Tinder‑style stack of overlaying cards that supports three
/// interaction paths: **drag**, **button‑triggered swipe**, and **tap‑to‑swipe**.
///
/// `CardStack` is *pure view logic* – it does **not** own the data you are
/// presenting.  Instead, you feed it an arbitrary `RandomAccessCollection` and
/// it renders up to `configuration.maxVisibleCards` layers at once.  Whenever
/// the top card is dismissed, the stack merely advances an index and calls the
/// supplied `onSwipe` closure so **your** feature layer can mutate the
/// collection in whatever way makes sense.
///
/// ### Generic parameters
/// * `ID`   – KeyPath used by `ForEach` to identify elements (usually `\.<id>`)
/// * `Data` – The collection that holds your domain model.
/// * `Content` – The *inside* of each card (a `View`).  `CardStack` is agnostic
///               about what this looks like.
///
/// ### Interaction model
/// 1. **Drag** – Implemented in `CardView` and automatically attached to the
///    topmost card.
/// 2. **Manual swipe** – A `AnyPublisher<SwipeDirection, Never>` (typically
///    wired to UI buttons) is handled in `body` via `.onReceive`.
/// 3. **Tap‑to‑swipe** – Provided by the wrapping `CardStackWrapper`, which
///    overlays a transparent `GeometryReader` over the top card and writes
///    `.left` / `.right` into a `@Binding` that the top `CardView` is
///    listening to.
///
/// ### Public callbacks
/// * `onSwipe(element, direction)` – tells your feature logic *which* element
///    the user just dismissed and *where* it went.
/// * `onEmptyStack()` – fires when `currentIndex` runs past
///    `data.endIndex`.  Use this to navigate away / load another page / show a
///    summary.
///
/// ### Configuration via `Environment` (see `CardStackConfiguration`)
/// * `maxVisibleCards` – how many cards are rendered at once.
/// * `swipeThreshold`  – drag distance (as a fraction of min(width, height)).
/// * `cardOffset`      – vertical spacing between stacked cards.
/// * `cardScale`       – how much each card below the top shrinks.
/// * `animation`       – the single `Animation` reused for *all* swipe
///                        operations.
///
/// ---
public struct CardStack<ID: Hashable,
                        Data: RandomAccessCollection,
                        Content: View>: View where Data.Index: Hashable {

    // MARK: Inputs
    private let direction   : (Double) -> SwipeDirection?
    private let data        : Data
    private let id          : KeyPath<Data.Element, ID>
    private let onSwipe     : (Data.Element, SwipeDirection) -> Void
    private let onEmptyStack: () -> Void
    private let content     : (Data.Element, SwipeDirection?, Bool) -> Content
    private let manualSwipe : AnyPublisher<SwipeDirection, Never>
    private let manualUndo  : AnyPublisher<Void,          Never>
    private let isInteractionEnabled: Bool

    // MARK: Environment
    @Environment(\.cardStackConfiguration) private var configuration

    // MARK: State
    @State private var currentIndex: Data.Index
    @Binding private var cardTapSwipe: SwipeDirection?
    @State private var swipeHistory: [SwipeDirection] = []   // last → first
    @State private var undoEdge    : SwipeDirection? = nil   // one-shot flag

    // MARK: Init
    public init(
        direction   : @escaping (Double) -> SwipeDirection?,
        data        : Data,
        id          : KeyPath<Data.Element, ID>,
        onSwipe     : @escaping (Data.Element, SwipeDirection) -> Void,
        onEmptyStack: @escaping () -> Void,
        manualSwipe : AnyPublisher<SwipeDirection, Never> = Empty().eraseToAnyPublisher(),
        manualUndo  : AnyPublisher<Void,          Never> = Empty().eraseToAnyPublisher(),
        isInteractionEnabled: Bool = true,
        cardTapSwipe: Binding<SwipeDirection?>   = .constant(nil),
        @ViewBuilder content: @escaping (Data.Element, SwipeDirection?, Bool) -> Content
    ) {
        self.direction    = direction
        self.data         = data
        self.id           = id
        self.onSwipe      = onSwipe
        self.onEmptyStack = onEmptyStack
        self.content      = content
        self.manualSwipe  = manualSwipe
        self.manualUndo   = manualUndo
        self.isInteractionEnabled = isInteractionEnabled
        self._currentIndex = State(initialValue: data.startIndex)
        self._cardTapSwipe = cardTapSwipe
    }

    // Convenience when Data.Element == ID
    public init(
        direction   : @escaping (Double) -> SwipeDirection?,
        data        : Data,
        onSwipe     : @escaping (Data.Element, SwipeDirection) -> Void,
        onEmptyStack: @escaping () -> Void,
        manualSwipe : AnyPublisher<SwipeDirection, Never> = Empty().eraseToAnyPublisher(),
        manualUndo  : AnyPublisher<Void,          Never> = Empty().eraseToAnyPublisher(),
        isInteractionEnabled: Bool = true,
        @ViewBuilder content: @escaping (Data.Element, SwipeDirection?, Bool) -> Content
    ) where Data.Element: Hashable, ID == Data.Element {
        self.init(direction: direction,
                  data: data,
                  id: \.self,
                  onSwipe: onSwipe,
                  onEmptyStack: onEmptyStack,
                  manualSwipe: manualSwipe,
                  manualUndo: manualUndo,
                  isInteractionEnabled: isInteractionEnabled,
                  content: content)
    }

    // MARK: Body --------------------------------------------------------------
    public var body: some View {
        ZStack {
            // back → front so z-order looks correct
            ForEach(data.indices.reversed(), id: \.self) { index in
                let relative = data.distance(from: currentIndex, to: index)
                if relative >= 0 && relative < configuration.maxVisibleCards {
                    card(index: index, relativeIndex: relative)
                }
            }
        }
        .onReceive(manualSwipe) { dir in
            guard isInteractionEnabled else { return }
            cardTapSwipe = dir
        }
        .onReceive(manualUndo) { _ in
            guard isInteractionEnabled else { return }
            undoLastSwipe()
        }
    }

    // MARK: Helpers -----------------------------------------------------------
    private func card(index: Data.Index, relativeIndex: Int) -> some View {
        CardView(
            direction  : direction,
            isOnTop    : relativeIndex == 0,
            isInteractionEnabled: isInteractionEnabled,
            onSwipe    : { dir in
                handleSwipe(of: data[index], at: index, direction: dir)
            },
            content    : { dir in
                content(data[index], dir, relativeIndex == 0)
                    .offset(y: CGFloat(relativeIndex) * configuration.cardOffset)
                    .scaleEffect(1 - configuration.cardScale * CGFloat(relativeIndex),
                                 anchor: .bottom)
            },
            reentryFrom: relativeIndex == 0 ? undoEdge : nil,
            cardTapSwipe: Binding(
                get: { relativeIndex == 0 ? cardTapSwipe : nil },
                set: { if relativeIndex == 0 { cardTapSwipe = $0 } }
            )
        )
    }

    private func handleSwipe(of element: Data.Element,
                             at index: Data.Index,
                             direction dir: SwipeDirection)
    {
        onSwipe(element, dir)
        currentIndex = data.index(after: index)
        checkEndOfStack()
        swipeHistory.append(dir)
    }

    private func undoLastSwipe() {
        guard currentIndex > data.startIndex,
              let dir = swipeHistory.popLast()
        else { return }

        undoEdge = dir                             // animate this re-insert
        withAnimation(configuration.animation) {
            currentIndex = data.index(before: currentIndex)
        }
        // clear flag after insertion so future inserts pop
        DispatchQueue.main.async { undoEdge = nil }
    }

    private func checkEndOfStack() {
        let i = data.distance(from: data.startIndex, to: currentIndex)
        if i >= data.count { onEmptyStack() }
    }
}

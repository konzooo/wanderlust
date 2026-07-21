import SwiftUI

extension CardStack {
    /// A single, swipe‑able card inside a `CardStack`.
    ///
    /// # Overview
    /// `CardView` is responsible **only** for rendering one card and interpreting
    /// the user / programmatic intent to remove that card from the stack.
    ///
    /// There are **three distinct ways** a card can leave the screen:
    /// 1. **Drag‑to‑swipe** – The user drags the card with their finger. A
    ///    `DragGesture` updates `translationSize` live and, on end, decides if
    ///    the drag was far enough to count as a dismissal.
    /// 2. **Manual swipe** – An external publisher (from the arrow buttons in
    ///    `QuestionnaireScreen`) triggers `CardStack.swipeTopCard(...)`, which in
    ///    turn calls `onSwipe` on the *top* `CardView` **without local
    ///    animation**.
    /// 3. **Tap‑to‑swipe** – The top card is covered by a transparent overlay
    ///    (`CardStackWrapper.tapOverlay`). A tap on the left or right half sets
    ///    `.left` or `.right` into the `cardTapSwipe` binding. `CardView` reacts
    ///    in `onChange` and runs the same removal logic as the drag gesture, but
    ///    **with the spring in `configuration.animation`.**
    ///
    /// # Life‑cycle
    /// 1. On `.onAppear` we record the width in `cardWidth`.
    /// 2. Every frame the card is translated by `translationSize` and rotated up
    ///    to **±30 º** based on the horizontal drag.
    /// 3. After the removal animation, `onSwipe` advances the stack’s index and
    ///    `translationSize` is reset to `.zero` for reuse.
    ///
    /// # Parameters
    /// - `direction`: Maps the **compass‑style** angle of the drag (0 º = up,
    ///   90 º = right, 180 º = down, 270 º = left) to a domain‑specific
    ///   `SwipeDirection`. Return `nil` for *“no direction yet”*.
    /// - `isOnTop`: `true` only for the visually top card; gestures attach only
    ///   there.
    /// - `onSwipe`: Called **once** when the card is dismissed. It fires *before*
    ///   the card’s view leaves the layout so callers can mutate their data
    ///   source in lock‑step with the animation.
    /// - `content`: Builder for the card’s interior. Receives the current swipe
    ///   direction (if any) so the UI can e.g. tint while dragging.
    /// - `cardTapSwipe`: Two‑way binding used to inject swipe directions from a
    ///   simple tap. Only the **top** card listens; lower cards ignore changes.
    ///
    /// # Animation
    /// *Removal* uses `transition` to continue the card’s momentum, offsetting it
    /// two extra card‑widths in the swipe vector. *Reset* (when the drag didn’t
    /// pass the threshold) eases `translationSize` back to `.zero`.
    ///
    /// > Adjust behaviour via `CardStackConfiguration`:
    /// > – `animation` – the base spring,
    /// > – `swipeThreshold` – fraction of card size required to dismiss.
    ///
    /// ---
    struct CardView<ContentView: View>: View {

        // Immutable
        let direction   : (Double) -> SwipeDirection?
        let isOnTop     : Bool
        let onSwipe     : (SwipeDirection) -> Void
        let content     : (SwipeDirection?) -> ContentView
        let reentryFrom : SwipeDirection?
        @Binding var cardTapSwipe: SwipeDirection?

        // Environment
        @Environment(\.cardStackConfiguration) private var configuration

        // State
        @State private var translation: CGSize = .zero
        @State private var cardWidth  : CGFloat = 0

        // MARK: Body
        var body: some View {
            GeometryReader { geo in
                content(swipeDirection(in: geo))
                    .onAppear { cardWidth = geo.size.width }
                    .offset(translation)
                    .rotationEffect(rotation(in: geo))
                    .simultaneousGesture(isOnTop ? dragGesture(in: geo) : nil)
            }
            .transition(customTransition)
            .onChange(of: cardTapSwipe) { _, new in
                guard let dir = new, isOnTop else { return }
                performTapSwipe(dir)
            }
        }

        // MARK: Gesture
        private func dragGesture(in geo: GeometryProxy) -> some Gesture {
            DragGesture()
                .onChanged { value in
                    translation = value.translation
                }
                .onEnded { value in
                    translation = value.translation
                    if let dir = swipeDirection(in: geo) {
                        withAnimation(configuration.animation) {
                            onSwipe(dir)
                        }
                    } else {
                        withAnimation { translation = .zero }
                    }
                }
        }

        // MARK: Swipe helpers
        private func performTapSwipe(_ dir: SwipeDirection) {
            withAnimation(configuration.animation) {
                switch dir {
                case .left:
                    translation = CGSize(width: -cardWidth, height: -150)
                case .right:
                    translation = CGSize(width: +cardWidth, height: -150)
                case .top:
                    // playful "dip" then launch
                    withAnimation(.easeOut(duration: 0.14)) {
                        translation = CGSize(width: 0, height: 20)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        withAnimation(configuration.animation) {
                            translation = CGSize(width: 0,
                                                 height: -(cardWidth * 1.5))
                        }
                    }
                }
            }
            let delay = configuration.animationDuration * 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(configuration.animation) {
                    onSwipe(dir)
                    cardTapSwipe  = nil
//                    translation   = .zero
                }
            }
        }

        private func degree() -> Double {
            var deg = atan2(translation.width, -translation.height) * 180 / .pi
            if deg < 0 { deg += 360 }
            return deg
        }

        private func rotation(in geo: GeometryProxy) -> Angle {
            .degrees(Double(translation.width / geo.size.width) * 30)
        }

        private func swipeDirection(in geo: GeometryProxy) -> SwipeDirection? {
            guard let dir = direction(degree()) else { return nil }
            let thr = min(geo.size.width, geo.size.height) * configuration.swipeThreshold
            let dist = hypot(translation.width, translation.height)
            return dist > thr ? dir : nil
        }

        // MARK: Transition
        private var customTransition: AnyTransition {
            let remove = AnyTransition.offset(x: translation.width * 2,
                                              y: translation.height * 2)

            let insert: AnyTransition
            switch reentryFrom {
            case .left? : insert = .move(edge: .leading)
            case .right?: insert = .move(edge: .trailing)
            case .top?  : insert = .move(edge: .top)
            default     : insert = .identity
            }
            return .asymmetric(insertion: insert, removal: remove)
        }
    }
}

# Navigation Architecture

## Overview

- All navigation is managed by `NavigationRouter`, an `ObservableObject` injected at the app level.
- Screens use `@EnvironmentObject var router: NavigationRouter` to perform navigation actions.
- Navigation state is stored in `router.path` and bound to the app's `NavigationStack`.

## Adding a New Screen

1. Add a new case to the `Destination` enum, with associated state if needed.
2. Add a new method to `NavigationRouter` for semantic navigation (e.g., `goToMyScreen(...)`).
3. Update the navigation destination switch in `HomeScreen` (or your main navigation stack) to handle the new case.
4. (Optional) Add deep link support in `handleDeepLink(_:)` in the router.

## Using the Router in Screens

- Inject the router with `@EnvironmentObject var router: NavigationRouter`.
- Use semantic methods for navigation:

```swift
router.goToFeedback()
router.goToItineraryResult(state)
router.popToRoot()
```

## Deep Linking

- URLs are handled in `WanderlustApp` via `.onOpenURL`.
- Extend `NavigationRouter.handleDeepLink(_:)` to support new routes and parse parameters as needed.
- Example:

```swift
func handleDeepLink(_ url: URL) {
    switch url.path {
    case "/feedback":
        goToFeedback()
    case "/itinerary":
        // Parse query params and navigate
        goToItineraryResult(...)
    default:
        goToUnknown("Unknown deep link: \(url.absoluteString)")
    }
}
```

## AsyncValue Pattern

- Use `AsyncValue<T>` for all async data in stores and views.
- Pass the full async value to child views so they can handle loading, error, and content states.
- Use `.mock` extensions for previews:

```swift
extension AsyncValue where Value == Trip.Suggestions {
    static var mock: AsyncValue<Trip.Suggestions> { .loaded(Trip.Suggestions.mock) }
}
```

## Example: Adding a New Destination

1. In `Destination.swift`:
    ```swift
    case myScreen(MyScreenState)
    ```
2. In `NavigationRouter.swift`:
    ```swift
    func goToMyScreen(_ state: MyScreenState = .init()) {
        path.append(.myScreen(state))
    }
    ```
3. In your navigation destination switch:
    ```swift
    case .myScreen(let state):
        MyScreen(initialState: state)
    ```

---

For more details, see the code comments in `NavigationRouter.swift` and `Destination.swift`. 
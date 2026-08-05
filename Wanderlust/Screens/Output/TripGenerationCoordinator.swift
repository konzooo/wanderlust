import Foundation

/// Owns the in-flight generation work for one trip screen.
///
/// Three separate bugs shared one cause — nobody owned the running tasks:
///
/// - Re-appearing mid-generation fired a **second paid call** for every
///   component, because the only guard was "not loaded yet" and a component
///   that is still loading is, indeed, not loaded.
/// - A retry started a new call without cancelling the old one, so whichever
///   finished last won. A stale response could overwrite a newer one.
/// - Retry re-ran the itinerary only, so a component that failed on its own had
///   no way back except regenerating the whole trip.
///
/// This type is the owner. Every generation goes through ``begin(_:restart:work:)``
/// and every write derived from a result is gated on ``isCurrent(_:attempt:)``.
@MainActor
final class TripGenerationCoordinator {
    private var tasks: [TripComponent: Task<Void, Never>] = [:]
    private var attempts: [TripComponent: Int] = [:]

    init() {}

    /// Whether a run for `component` is currently outstanding.
    func isInFlight(_ component: TripComponent) -> Bool {
        tasks[component] != nil
    }

    /// Starts a run for `component`.
    ///
    /// - Parameter restart: `false` is single-flight — if a run is already
    ///   outstanding this does nothing and returns `nil`. `true` cancels the
    ///   outstanding run first, so an explicit retry always supersedes it.
    /// - Parameter work: receives the attempt number. Pass it back to
    ///   ``isCurrent(_:attempt:)`` before writing anything derived from the
    ///   result; a superseded attempt must write nothing at all.
    /// - Returns: the attempt number, or `nil` when the call was suppressed.
    @discardableResult
    func begin(
        _ component: TripComponent,
        restart: Bool = false,
        work: @escaping @MainActor (_ attempt: Int) async -> Void
    ) -> Int? {
        if let existing = tasks[component] {
            guard restart else { return nil }
            existing.cancel()
        }

        let attempt = (attempts[component] ?? 0) + 1
        attempts[component] = attempt

        // Created before it is stored, but `Task { @MainActor in … }` cannot
        // begin executing until this synchronous scope yields the actor, so the
        // body always observes the assignment below.
        let task = Task { @MainActor [weak self] in
            await work(attempt)
            guard let self, self.attempts[component] == attempt else { return }
            self.tasks[component] = nil
        }
        tasks[component] = task
        return attempt
    }

    /// Whether `attempt` is still the newest run for `component`.
    ///
    /// The single gate a network result must pass before it touches state. A
    /// cancelled task can still be resumed by an `await` that had already
    /// completed, so cancellation alone is not enough — the attempt number is.
    func isCurrent(_ component: TripComponent, attempt: Int) -> Bool {
        attempts[component] == attempt
    }

    /// Cancels everything outstanding. The attempt counters deliberately keep
    /// their values so a late response from a cancelled run still fails
    /// ``isCurrent(_:attempt:)`` if generation is restarted afterwards.
    func cancelAll() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
    }

    deinit {
        // `tasks` is main-actor isolated; capture the values before leaving.
        let outstanding = tasks.values
        for task in outstanding { task.cancel() }
    }
}

import ActivityKit
import DevilKit
import Foundation

/// The Lock Screen activity for a running brew.
///
/// Started once, updated when the step changes or the clock stops, and ended
/// when the brew does. Seven or eight messages across three minutes, because
/// the clock draws itself from the dates and needs none of them.
@MainActor
final class BrewActivity {
  /// The running activities are looked up rather than held.
  ///
  /// `Activity` is not `Sendable`, so carrying one into the task that updates
  /// it is a data race the compiler refuses. Asking `ActivityKit` for it on
  /// the other side costs nothing and never crosses isolation.
  ///
  /// It also clears up after a crash: an app killed mid-brew leaves its
  /// activity on the Lock Screen, and the next `end` finds it.
  private var running: [Activity<BrewAttributes>] {
    Activity<BrewAttributes>.activities
  }

  /// Whether the phone will show one at all.
  ///
  /// Live Activities can be switched off per app in Settings, so this is
  /// checked rather than assumed. A brew is unaffected either way.
  private var isAllowed: Bool {
    ActivityAuthorizationInfo().areActivitiesEnabled
  }

  func start(recipe: Recipe, from start: Date, servings: Int) {
    guard isAllowed, running.isEmpty else { return }
    let attributes = BrewAttributes(
      start: start,
      finish: start.addingTimeInterval(Double(recipe.totalTime.seconds)),
      servings: servings
    )
    let first = recipe.progress(atSeconds: 0)
    do {
      _ = try Activity.request(
        attributes: attributes,
        content: ActivityContent(
          state: state(recipe: recipe, at: first, heldAt: nil),
          staleDate: nil
        )
      )
    } catch {
      // A brew is not worth abandoning over a Lock Screen widget, and the
      // console is the only place to say so.
      print("[Devil] could not start the live activity: \(error)")
    }
  }

  func update(recipe: Recipe, at progress: BrewProgress, heldAt: Double?) {
    let content = ActivityContent(
      state: state(recipe: recipe, at: progress, heldAt: heldAt),
      staleDate: nil
    )
    Task {
      for activity in Activity<BrewAttributes>.activities {
        await activity.update(content)
      }
    }
  }

  /// Ends it now rather than letting it linger on the Lock Screen.
  func end() {
    Task {
      for activity in Activity<BrewAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }

  private func state(
    recipe: Recipe,
    at progress: BrewProgress,
    heldAt: Double?
  ) -> BrewAttributes.ContentState {
    BrewAttributes.ContentState(
      stepTitle: progress.step.title,
      instruction: recipe.instructions(for: progress.step).joined(separator: ", "),
      switchIsOpen: progress.step.switchPosition == .open,
      heldAtSeconds: heldAt
    )
  }
}

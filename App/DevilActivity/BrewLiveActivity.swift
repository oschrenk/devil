import ActivityKit
import SwiftUI
import WidgetKit

/// The brew, on the Lock Screen and in the Dynamic Island.
///
/// Everything here is drawn from what the app last sent plus a clock the
/// system runs itself, so a brew can sit on the Lock Screen for three minutes
/// while the app sends seven updates.
struct BrewLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BrewAttributes.self) { context in
      LockScreenView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          BrewClock(context: context)
            .font(.title2.monospacedDigit())
            .fontWeight(.semibold)
        }
        DynamicIslandExpandedRegion(.trailing) {
          SwitchLabel(isOpen: context.state.switchIsOpen)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 2) {
            Text(context.state.stepTitle)
              .font(.headline)
            Text(context.state.instruction)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        Image(systemName: "cup.and.saucer.fill")
      } compactTrailing: {
        // The clock and the switch are the two things worth a glance
        // mid-pour, and the compact form has room for about that much.
        BrewClock(context: context)
          .font(.caption.monospacedDigit())
      } minimal: {
        Image(systemName: context.state.switchIsOpen ? "arrow.up.circle" : "arrow.down.circle")
      }
      .keylineTint(.orange)
    }
  }
}

private struct LockScreenView: View {
  let context: ActivityViewContext<BrewAttributes>

  var body: some View {
    // The clock leads, at roughly twice the size of anything else. The
    // region is about 160 points tall and cannot be made bigger, so what
    // reads at arm's length has to win the space rather than share it.
    HStack(alignment: .center, spacing: 16) {
      BrewClock(context: context)
        .font(.system(size: 44, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .minimumScaleFactor(0.7)
        .lineLimit(1)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(context.state.stepTitle)
            .font(.headline)
            .lineLimit(1)
          SwitchLabel(isOpen: context.state.switchIsOpen)
        }
        Text(context.state.instruction)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
  }
}

/// The clock, run by the system rather than by the app.
private struct BrewClock: View {
  let context: ActivityViewContext<BrewAttributes>

  var body: some View {
    if let held = context.state.heldAtSeconds {
      // A stopped clock cannot be drawn from a date range that keeps moving.
      Text(BrewTimeText.of(seconds: held))
        .foregroundStyle(.orange)
    } else {
      Text(
        timerInterval: context.attributes.start ... context.attributes.finish,
        pauseTime: nil,
        countsDown: false
      )
    }
  }
}

private struct SwitchLabel: View {
  let isOpen: Bool

  var body: some View {
    // The word alone. An icon and a word at caption size in a strip this
    // short is two things to read where one will do.
    Text(isOpen ? "open" : "closed")
      .font(.caption.weight(.semibold))
      .foregroundStyle(isOpen ? .green : .orange)
  }
}

/// `m:ss`, spelled out here because the widget shows a held clock as text.
enum BrewTimeText {
  static func of(seconds: Double) -> String {
    let whole = Int(max(0, seconds))
    return "\(whole / 60):\(whole % 60 < 10 ? "0" : "")\(whole % 60)"
  }
}

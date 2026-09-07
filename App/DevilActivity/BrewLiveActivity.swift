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
        .activityBackgroundTint(.black.opacity(0.35))
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
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text(context.state.stepTitle)
          .font(.headline)
        Text(context.state.instruction)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 4) {
        BrewClock(context: context)
          .font(.title.monospacedDigit())
          .fontWeight(.semibold)
        SwitchLabel(isOpen: context.state.switchIsOpen)
      }
    }
    .padding()
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
    Label(
      isOpen ? "Open" : "Closed",
      systemImage: isOpen ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    )
    .font(.caption)
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

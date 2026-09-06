---
project: devil
assignee: oliver
created: 2026-09-06
state: done:completed
rank: 7000
requires:
  - DEVIL-04
closed: 2026-09-06
outcome: >
  Done.
  Pressing start now gives three seconds before 0:00.
  The clock shows 0:03, 0:02, 0:01 in red, then turns black and counts up.

  Red only during the lead-in, because that is the one time the number means
  "not yet" rather than "how long it has been".
  Both run in the same m:ss shape so the digits do not jump at the turn.
  The step card already shows the bloom during the lead-in, which is the point:
  you read what to do while you get the kettle over the bed.

  Countdown.remaining lives in DevilKit and is tested rather than eyeballed.
  Each number holds for a full second, so 0:03 is on screen as long as 0:02 is.
  Rounding the other way would have given a two second head start while
  claiming three.

  Two things were fixed alongside.

  The instruction bullets sat low against their text.
  They were SF Symbols, and firstTextBaseline puts an image's bottom edge on
  the baseline, so a small dot hangs below the words.
  A text glyph carries the font's own metrics and lines up without help.

  Pressing start twice in quick succession dropped the brew in progress.
  The second press built a new RunningBrew, which changed the cover's identity
  mid-animation and left it dismissed.
  The button now ignores a press while a brew is running.
  Only the simulator automation ever hit this, but it was a real way to lose a
  brew.
---

# DEVIL-07: a Head Start Before 0:00

A brew begins when water touches coffee, so the clock has to be running before you pour.
Pressing start and pouring at the same instant is not something two hands do.

## Definition of Ready

- **Problem** the clock starts the instant you press the button.
  0:00 is already behind you by the time the kettle reaches the bed.
  Every pour then runs late against a schedule built on exact timings.
- **Goal** three seconds between the press and 0:00, counted down on screen, with the first step already showing.
- **Scope** the lead-in and how the clock reads during it.
  Not audio, and not a settable length.
- **Consumers** `App/Devil/TimerView.swift` and the start button in `App/Devil/ContentView.swift`
- **Baseline** `RunningBrew.start` is the moment of the press, and `TimerView` counts up from it
- **Open** no open decisions
- **Undo** revert the commit

## Definition of Done

- `swift test` passes
- A test asserts each countdown number holds for a full second
- A test asserts a gap that has passed reads 0 rather than a negative
- `task run`, press start, and the clock reads a red 0:03 before a black 0:00
- The bloom step is on screen throughout the countdown
- `task lint` reports 0 violations

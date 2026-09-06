---
project: devil
assignee: oliver
created: 2026-09-06
state: done:completed
rank: 5000
closed: 2026-09-06
outcome: >
  Done.
  The grind is a recorded value now, not a property of the paper.

  Filter keeps a defaultGrind, and BrewSettings carries the setting in force.
  Picking a paper moves the grind to that paper's number, and the stepper takes
  it from there in clicks of 0.1.
  A test asserts that a grind set by hand changes the grind and nothing else:
  same kettle fill, same beakers, same schedule, same delivered blend.

  Two smaller changes went with it.
  The kettle stepper moves in whole degrees, because that is the accuracy the
  kettle holds and half a degree was a false precision.
  The ratio reads 1 : 16.6 with a vinculum over the six.
  It is 50/3 exactly, since the dose and the water are both linear in the same
  term and it cancels, so 16.7 was rounding a number that does not need it.
  Format.grind also keeps the decimal on a whole setting, because 8.0 and 8 are
  different clicks on the grinder.

  Verified on the simulator: the grind row steps, and switching the filter to
  Abaca moved it from 7.9 to 7.5.
---

# DEVIL-05: Record and Adjust the Grind

The grind setting is tracking data, not an input to any calculation.
Make it something you can dial in and write down.

## Definition of Ready

- **Problem** `Filter` defines the grind, so each paper has exactly one setting and a dial-in has nowhere to go.
  Nothing computes from the grind, yet it is the one number in the model that cannot move.
- **Goal** the grind is a setting you can move, starting from whatever the current paper usually wants.
- **Scope** the grind setting, the kettle temperature step, and how the ratio reads.
  Not the brew arithmetic, which none of these touch.
- **Consumers** `Sources/DevilKit/Filter.swift`, `Recipe.grindSetting`, and the grind row in `App/Devil/ContentView.swift`
- **Baseline** `Recipe.grindSetting` returns the filter's string, and the row shows it without a control
- **Open** no open decisions
- **Undo** revert the commit

## Definition of Done

- `swift test` passes
- A test asserts an unset grind starts at the filter's default, 7.9 for Hario and 7.5 for Abaca
- A test asserts a grind set by hand overrides the filter and changes nothing else about the brew
- A test asserts `8.0` keeps its decimal and `1 : 16.6` carries the vinculum
- `task run` and step the grind
- Switch the filter, and watch the grind move to the new default
- `task lint` reports 0 violations

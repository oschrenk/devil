---
project: devil
assignee: oliver
created: 2026-09-06
state: done:completed
rank: 6000
closed: 2026-09-06
outcome: >
  Done.
  The preheat is three amounts rather than one total, because only one of them
  scales.

  The cone takes 150 ml, the vessel 50 ml, and each cup 50 ml.
  The cone and the vessel are warmed in one pass, poured through the Switch
  with the filter in place and into the server below, which is how it was
  always done; splitting them only separates the arithmetic.
  The cup is the part that grows with the people.

  That gives the number to act on before anything else is on: Recipe.tapToBoil,
  the preheat plus the brew's tap portion plus the slack.
  400 ml for one person, 512.5 for two.
  It is the first row of the preheat section on screen, and a footer says where
  it comes from so it can be checked rather than trusted.

  The recipe copies said 300 ml of preheat, 200 through the brewer and 100 into
  the cup, and a 450 ml single fill.
  Both now say 250 ml and 400 ml, split three ways.
  The change is the cup: 50 ml rather than 100.

  A compile error slipped through on the way, because task test builds DevilKit
  only and task lint does not compile at all.
  Nothing catches an app-target break except task build, and grepping its
  output for "Build Succeeded" hid the failure rather than reporting it.
---

# DEVIL-06: Preheat Plan Drives the Kettle Fill

The preheat was a pair of hardcoded numbers with no way to say how many cups to warm.
It also decides how much water goes in the kettle, which is the first thing you do.

## Definition of Ready

- **Problem** `Preheat` stores `throughBrewer` and `intoCup` as fixed amounts.
  Nothing scales with the people, and you cannot skip a warm-up you do not need.
  The kettle fill is a number you work out on paper each morning.
- **Goal** the cup, the vessel and the cone each take an amount.
  The cup part scales with servings, and the app shows the single figure to boil.
- **Scope** the preheat plan, the kettle fill it implies, and the controls for all three amounts.
  Not the preheat temperature, because altitude caps it at 96 °C.
- **Consumers** `Sources/DevilKit/Recipe.swift`, `Recipe+Scaling.swift`, `App/Devil/ContentView.swift`, and the preheat sections of both recipe copies
- **Baseline** `Preheat(temperature: 96, throughBrewer: 200, intoCup: 100)`, a flat 300 ml
- **Open** no open decisions
- **Undo** revert the commit, and restore the two recipe copies from git and from the backup in the scratchpad

## Definition of Done

- `swift test` passes
- A test asserts one serving preheats 250 ml, split 150 cone, 50 vessel, 50 cup
- A test asserts only the cup part grows, across one to five servings
- A test asserts the kettle fill is 400 ml for one and 512.5 ml for two
- A test asserts setting an amount to zero takes it out of the fill and changes nothing else
- `task run` shows a Boil row of 400 ml with a footer that adds up
- `RECIPE.md` and the vault copy both say 250 ml of preheat and a 400 ml single fill

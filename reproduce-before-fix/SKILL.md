---
name: reproduce-before-fix
description: Reproduce a reported bug headlessly through the repo's own check harness before changing any code, then leave the probe behind as an assertion. Use when a user reports a symptom from any rendered surface, the running app or a generated document, spreadsheet or export ("it doesn't replace X", "the dialog appears every time", "regenerate still does not show the sub-items", "did you change anything?"), when they repeat a symptom you thought you fixed, before telling them a fix works, when a fix is about to be written from reading source alone, and when a green test suite disagrees with what the user just saw.
---

# Reproduce before fix

A symptom reported through the UI is a claim about behaviour. Reading the source produces a theory about behaviour. The two agree often enough to be dangerous: the theory explains the symptom the user named and misses the ones they did not.

Print the real value first.

## The cycle

**1. Find the harness.** The repo almost certainly has a runner that executes its own modules headlessly, and it is rarely `npm test`. Look for `checks/`, `scripts/`, `tools/`, a `*.sh` next to the code it exercises. Find it once and write down where it is, because the next session will hunt for it again.

**2. Point it at a probe.** Copy the runner, swap its entry module for a scratch file, and have that file call the real functions with the real input shape and print what comes back. No assertions yet. You are looking at output, not confirming a guess.

Copy the runner rather than editing it. A modified runner that gets committed is a worse outcome than the bug.

**3. Read what printed.** This is the step that pays. The theory you arrived with explains one symptom; the output routinely shows two more, and one of them is usually the reason your first fix would not have held.

**4. Fix, then promote the probe.** Every defect the probe exposed becomes a permanent assertion, phrased as the behaviour that was wrong. Then delete the probe. A probe deleted with its insight means the next regression is found by a user again.

**5. Check the assertions that were already green.** A defect that shipped under a passing suite means some existing assertion encodes the broken behaviour as correct. Find it and rewrite it. If nothing failed when you introduced the fix, you have not yet found that assertion.

## Why the suite did not catch it

Two recurring reasons, both worth checking before trusting a green run:

- **The fixture was invented.** Someone wrote the input by hand instead of copying the shape the system stores. The check then certifies the invented case forever. See `grill-me` on fixtures.
- **The check tests the pure layer.** Serialization, DOM conversion, editors and persistence usually sit behind a service call the headless runner cannot make, so the part that actually broke was never in scope. Say so out loud rather than reporting the suite as coverage it does not provide.
- **The probe rendered a different surface.** One feature is often printed by more than one renderer: a list and a body, a preview and an export, a screen and the document it generates. Identify which one produced the thing the user photographed before you probe anything, and prove the fix against that one. Reproducing on a sibling surface that already worked proves nothing, and "it works" said about it buys a round trip and a second report of the same bug.

## What this is not

Not a substitute for the user's own run. The probe proves the unit misbehaves; only the real app proves the fix reaches them. Ask for the console line that discriminates between your remaining theories — one specific line beats another round of reading.

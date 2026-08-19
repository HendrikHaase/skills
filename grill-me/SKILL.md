---
name: grill-me
description: Grill the user relentlessly about a plan, decision, or idea before acting on it. Use on any 'grill' trigger phrase, when the user says to ask if you are unsure, and whenever you are about to decide scope, approach, or tradeoffs that are the user's call rather than yours. Ask before building, not after.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet.

Ask with the **AskUserQuestion** tool, one question per call, so the user answers by picking an option. Never put the question in unstructured prose instead. Where the tool does not exist (headless runs, subagent contexts), fall back to one numbered question per turn with the same parts: the tradeoff, the numbered options, your recommendation marked.

Build each question like this:

- `header`: the decision in 12 characters or less ("Auth method", "Storage").
- `question`: the full question, ending in a question mark. Include the tradeoff, not just the choice.
- `options`: 2 to 4 real, mutually exclusive candidates. Put your recommendation **first** and append `(Recommended)` to its label. Each needs a `description` saying what happens if it is picked. Never write an "Other" option; the tool adds one.
- `multiSelect: true` when the choices can legitimately combine (which checks to run, which surfaces to cover). Otherwise leave it false.
- `preview`: use it when the options are concrete artifacts the user should compare by eye (layouts, code shapes, schemas, config). Single-select only.

Work the frontier one question at a time, in dependency order, and let each answer land before the next call. Batch only when several frontier questions are genuinely independent and small; then put up to 4 in a single call. A question whose answer depends on another question still open belongs to a _later_ round, not this one.

Each answer reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier after every answer. When the user picks "Other" or adds notes, treat that as a new branch and re-derive the frontier from it.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch an `Explore` agent in the background to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

Facts you feed into a question carry their provenance. Bound every sweep (a per-target `timeout`, or a background agent) and say so when one gets cut short: partial counts presented as a full scan turn a guess into false authority.

An answer can assert a fact about the tools or the environment ("gitignored files never get added, so this option is fine"). Test the claim before you design around it. If it is false, say so, show what you ran, and reopen that branch: the premise was part of the answer.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

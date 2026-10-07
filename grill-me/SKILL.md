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

Seed the tree from the runtime substrate as well as from the brief. A tree grown only from what the thing _does_ generates feature branches and misses the ground it stands on, so the user ends up raising the load-bearing question themselves. For anything that deploys, one of those branches is **which paths are reachable from outside versus merely present on disk** — where secrets and code sit relative to whatever the server treats as its root. Structural unreachability beats a configured refusal every time: a file outside the served tree cannot be served by a misread rule, and access rules turn out to be read in places you did not predict.

Seed it from **decisions already shipped nearby**, too. Plan files, a previous work item's state doc, and the comments left by the last change in that area record choices someone made on purpose, and a new absolute rule from the user ("never X") routinely collides with one of them. Do not silently honour the new rule or silently keep the old one: put the collision up as its own question, naming what the earlier decision bought. The user is the only one who can say which of the two survives.

An option that **deletes a surface** carries a question the diff will not ask. Removing a tab, a panel, or a warning block orphans two kinds of state, and they are not equally harmless: state that loses its only writer is dead code, while state that loses its only display goes on being written and read by nobody. The second is an availability regression dressed as cleanup, because the condition it reported still happens and now reports nowhere. Name both in the option's `description`, separately, before the user picks.

And for any option that writes state **after an async boundary** — a save, a navigation, a server response — ask which object receives the write and what orders it against that boundary. An option that looks safe because it "reuses the path that already works" may be relying on a human click sitting between the two, and a click is an undeclared synchronization primitive: the moment the flow becomes automatic, the write lands somewhere nothing will read.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch an `Explore` agent in the background to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

A question about **which case the work is in** is a fact, not a decision, and the user's own example decides it. When they name a concrete one (an entity id, a record, a ticket, a screenshot), run that example through the branching condition before you write the options. Reading the source tells you what the branches are; only the data tells you which one their example takes. Get this backwards and `(Recommended)` launders an unmeasured guess into the user's pick, they approve it, and the work lands on the branch their data never reaches. The label is a claim that you checked.

This holds for systems you cannot currently reach, not just the ones you can. When a fact lives on a host, panel, or account you have no credential for, the frontier item is **access**, not the fact: ask once for the credential, then go and measure. A list of facts handed back to the user ("which PHP version, is this setting honoured, what does that variable say") is a list you would have answered yourself an hour later with a login — and the user knows it.

"I cannot reach it" is itself a fact, and an untested one is usually wrong. Prove the unreachability before you design around it: the repo's own configuration is where access hides. Connection strings, tunnel and host URLs, environment files and local settings overrides routinely name a dev database or a dev API that answers from here even when the user's `localhost` does not. Read those, try the connection, and ask only for what is genuinely missing (often just a token). Re-run the check when a later debugging round needs it: an unreachability that was true during planning is not evidence about now, and a question built on it hands the user a risk decision that did not have to exist.

Facts you feed into a question carry their provenance. Bound every sweep (a per-target `timeout`, or a background agent) and say so when one gets cut short: partial counts presented as a full scan turn a guess into false authority.

Existence claims are asymmetric, and the user answers as though yours are settled. One hit proves a thing exists. Nothing proves it absent — a layered codebase hides the same concept in client enums, model enums, generated VO libs, and seeds, and finding it missing from one layer says only that. So never report an absence as definitive: name the layers you searched ("not in the client enum or the seeds"), and treat a user's "don't we already have X?" as evidence you searched the wrong layer, not as a question already answered.

An answer can assert a fact about the tools or the environment ("gitignored files never get added, so this option is fine"). Test the claim before you design around it. If it is false, say so, show what you ran, and reopen that branch: the premise was part of the answer.

A change to a path that already ships carries two branches the user should not have to remember. How is it turned off — a flag, a config switch, or a structural no-op that makes the feature inert when unused? And what proves the existing path still behaves identically when it is off? Ask both before the frontier counts as empty; they are design decisions, and discovering them after the interview closes reopens work the interview existed to prevent.

A decision that asserts a gate ("spike this before building") or an invariant ("existing behaviour must not change") is not settled until it names the check that fails when it is violated. Prose commitments decay: the gate gets skipped because the build is going well, and the invariant gets broken three edits later by something that looked unrelated. Name the assertion, the blocking checklist entry, or the user's explicit waiver — and note that tests written for the new code do not cover either one.

A check is not named until its **fixture is the shape the system actually stores**. Invent the input and the check certifies the invented case: it goes green, it stays green, and the real shape walks straight past it. Copy a fixture from a sibling assertion in the same file, or from real data. A new fixture noticeably tidier than the ones around it is a smell worth resolving before the frontier closes, because the surrounding ones are usually untidy for a reason somebody already learned.

A blanket test double is the same failure wearing different clothes. A stub that returns `undefined` for every lookup, or echoes back what it was handed, makes a new assertion green without the code under test ever running. So does asserting a value the fixture itself supplies. The only proof that an assertion is attached to anything is breaking the source it covers and watching it fail. Do that once per new assertion, restore, and say in the report that you did; a check nobody has seen fail is a check nobody has evidence for.

"Fail" means that assertion fails. A crash, an unhandled rejection or a compile error also turns the run red, and proves only that the harness noticed something. So mutate the value the assertion names (make the branch return the wrong result), not the control flow around it (replacing a `catch` with a rethrow tests that a catch exists). A mutation that does not end in the expected assertion error has not been seen to fail.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

The no-prose rule outlives the interview. Decisions surface later too — parked for a phase that hasn't started, or created by something you learn while building — and the temptation is to raise them as a closing paragraph in a status report, where they die quietly. When a parked decision's work becomes the current work and it is still unanswered, ask it again through the tool. Silence is not consent for your recommendation; it usually means the question was never read.

Ship the option the user picked, and only that one. A pick routinely leaves a usability gap right next to it, and folding a fix for the gap in beside the chosen work is not thoroughness: it is a second decision they never made, arriving without a question. Raise it through the tool instead. The cost is not only the undo. A change that looks cosmetic in the UI can reach whatever else reads the same stored state, so the unrequested extra lands somewhere the user was not looking.

Watch your own drafts for the tell. "One deliberate simplification", "a gap against what we agreed", "say the word if you'd rather", "worth your call" — a sentence like that at the bottom of a status report is a question you decided instead of asking, dressed as a footnote. It is the same decision either way; filing it as a simplification just moves it past the point where the user could have chosen. When one appears in a draft, take it out of the report and put it through the tool before the work lands, not after.

Debugging is where this fails, because a fix that unblocks the user feels like execution rather than design. Here is the test that does not care what phase you are in: **any change to what gets persisted, stored, or billed is a frontier question**, however small the diff. A one-word flag that changes the format or size of every row written from now on outranks every cosmetic question you are already asking, and it is worth less to the user as a closing "one consequence worth knowing" than as an option they got to refuse.

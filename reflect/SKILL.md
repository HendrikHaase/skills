---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

## When to invoke

- The user said "reflect" or "/reflect".
- A complex task (5+ tool calls) just landed cleanly and the recipe is worth keeping.
- The agent hit dead ends, found the working path, and the path generalizes.
- The user corrected the agent's approach mid-task.
- A non-trivial workflow emerged that isn't captured anywhere.

Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## Process

### 1. Locate the active transcript

The parent finds its own transcript file before fanning out. Claude Code stores one directory per project under `~/.claude/projects/`, named after the working directory with every non-alphanumeric character replaced by `-`, holding one `<session-id>.jsonl` per session. Stay inside the current project's directory. Globbing across `~/.claude/projects/*/` crosses project boundaries and reads private sessions from unrelated repos.

```bash
ls -t ~/.claude/projects/"$(pwd | sed 's|[^a-zA-Z0-9]|-|g')"/*.jsonl | head -5
```

Subagent turns live in the same file, marked `"isSidechain": true`.

For each candidate, read the first JSONL line and check that `message.content[0].text` contains the conversation's opening user prompt. Take the matching path. If no path resolves, write a tight digest of the session and pass that instead.

### 2. Spawn three reviewers in parallel

One message, three `Agent` calls, `subagent_type: general-purpose`, `run_in_background: false`, explicit `model` on each. Reviewers need the full tool set for context lookups (tickets, chat threads, observability traces referenced in the transcript), so do not use the read-only `Explore` type. The prompt forbids file writes; the parent applies edits.

| Lens | `model` | Prompt template |
|---|---|---|
| Judgment | `opus` | `references/judgment-reviewer.md` |
| Tooling | `sonnet` | `references/tooling-reviewer.md` |
| Divergent | `fable` | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in the `Agent` response body.

### 3. Synthesize

One `Agent` call, `subagent_type: general-purpose`, `model: opus`, `run_in_background: false`. The synthesizer spot-verifies citations, so it needs the full tool set. Use `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. The synthesizer returns a structured Accepted / Rejected / Backlog list.

### 4. Structural enforcement check

Sanity-check the synthesizer's Accepted list. For any item that would be enforced more reliably by a lint rule, script, hook, metadata flag, or runtime check, move it from Accepted to Backlog. A lesson encoded in structure holds; a lesson written as prose in a skill only holds when the next agent reads it. The synthesizer already applies this criterion; this is a final pass before edits land.

### 5. Apply

Before applying any Accepted edit, present the synthesizer's full Accepted/Rejected/Backlog output to the user and wait for explicit approval. The user picks which subset to apply and may redirect routings. Skill changes affect every future agent in the org; do not auto-apply.

Backlog items are not skill edits. List them in the summary; only file them to a tracker if the user asks.

Skills live in `~/.claude/skills/<name>/SKILL.md`, the project's `.claude/skills/`, or a plugin directory under `~/.claude/plugins/`. Edit the file that the transcript shows was actually loaded, and apply the edit at that path. A directory in the working tree can hold a checkout of the same skills repo and still be a different file: same content, same remote, no effect on what loads. Resolve the load path first, then re-read the edited file there before declaring done.

For each approved Accepted item, follow the Routing field:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): apply it.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): draft it, show the diff, apply after the user confirms.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): rewrite the frontmatter `description` so it names the trigger phrases and situations from this transcript. Description drives model invocation; the body does not.
- `new skill: <kebab-name>`: create `<name>/SKILL.md` with frontmatter (`name` matching the directory, `description`), a short body, and reference files only if the body would otherwise exceed roughly 100 lines.
- `update config: <path>`: the learning is that a standing claim is false, not that a skill is thin. Correct the CLAUDE.md line, memory file, or setting that says it. A config that mis-routes work reaches every future session, and no skill edit fixes it.

Every touched SKILL.md must still parse: `---` fence on line 1, `name` matching its directory, non-empty `description`.

### 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog (structural enforcement, not skill text): `<item>`. One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.

---
name: back-to-dev
description: "Put every repo in the session back on its default branch, up to date, with merged feature branches gone, ready for the next work item. Use on 'back to dev', 'reset the repos', 'branches back to dev', 'pull latest everywhere', 'clean up the branches', or 'get ready for the next work item'. Hands off to work-on once the repos are clean."
---

# Back to dev

The bookend to `work-on`. That skill opens a unit of work; this one closes it.

## Run it

One call, all repos, in parallel:

```bash
bash ~/.claude/skills/back-to-dev/back-to-dev.sh <repo>...
```

Do not run the git commands yourself, one repo at a time. The git work takes about ten seconds for six repos; a tool call per step per repo takes minutes, and that is the whole reason this script exists.

## Which repos

The repo list is the session's working directories, primary and additional, as the environment block names them. Type those paths literally.

Never discover them. No `ls`, no `find`, no `/workspace/*/`, no sibling scan, no `.code-workspace` file. The parent directory holds seventy git repos that belong to other projects, and touching one of them is the failure this skill exists to avoid. Switching an unrelated repo's branch or deleting its merged branch is not recoverable from here.

If the working directories are not in front of you, ask which repos. Do not guess and do not widen.

The script refuses to help you guess: it rejects anything that is not a repo root and any list longer than ten, and exits before it touches a thing. Its first output line echoes the repos it acted on, so check that against what you meant.

## What it does per repo

`fetch --prune`, resolve the default branch from `origin/HEAD` (falling back to dev, develop, main, master), switch to it, fast-forward it, and delete every local branch that is provably an ancestor of `origin/<default>`.

Three refusals are deliberate, so read a note as a finding rather than a failure to retry:

- No fast-forward when the local default has commits of its own. Show them, do not merge.
- No `branch -D`. An unmerged branch means the work is not where you think it is.
- No stash, no `checkout --`, no clean. A dirty tree rides along on `switch`, and a `switch` that a dirty file blocks is reported, not forced.

### When the user wants the refused ones gone anyway

Doing it by hand is fine. Doing it to a lower standard than the script is not, and that is the easy mistake: the script's bar is "provably an ancestor of `origin/<default>`", and a hand-rolled check usually degrades to "a remote branch of that name exists", which proves nothing about the local tip.

The user approves the **inventory you show them**, not the action. So the inventory has to be right before the question is asked, per branch and across every repo:

```bash
git rev-list --count origin/<default>..<branch>   # 0 => already on the default branch
git rev-list --count origin/<branch>..<branch>    # 0 => the remote has this exact tip
```

A remote name that exists is not a remote copy of *this* tip. Anything that fails both counts still has commits living only on your disk, so either prove the content reached the default branch another way (a squash merge, a cherry-pick) and say which, or leave it alone and name it. Count stashes the same way, across all repos, before quoting a number. If a claim in the inventory turns out to be wrong after the user has approved it, say so plainly: they agreed to a fact, and the fact was yours.

## Read the report

Columns: repo, branch, head, deleted, dirty_real, dirty_crlf, staged, untracked. Lines starting `!` need a decision.

`dirty_real` and `dirty_crlf` are counted apart on purpose. "38 modified files" and "3 modified files plus 35 with only line-ending churn" lead to different decisions, and these repos on WSL produce a lot of churn.

Relay the table, then name what needs a call: a branch that would not fast-forward, an unmerged branch left alone, a remote branch still on the server (its PR was not set to delete the source; offer, never delete someone's remote ref unasked).

Offer the remote-branch cleanup once per session. An offer the user passes over is declined: on later runs, list the session's leftover remote branches in one line with no question. Read the script's full output before relaying it; never pipe its `!` lines away to make the report shorter.

Close by asking for the next work item, or invoke `work-on` if the user already named one.

## Changing the script

`bash ~/.claude/skills/back-to-dev/test.sh` builds throwaway repos and asserts the report. Run it after any edit.

---
name: commit
description: Use when the user asks to commit ("commit this", "commit and push", "check this in") or when changes are being staged for a git commit. Covers what gets staged, the checks that block a commit, and the message format. Does not push and never starts a commit on its own.
---

# Commit

One complete commit that reverts cleanly and hides nothing.

Commit only when the user asks. Never commit because a task finished, tests went green, or the worktree looks like a good stopping point. Stop at the commit: pushing happens only on request, and pull requests belong to `azure-devops:pull-request`.

## 1. Read the worktree

```bash
git status --short
git diff --stat HEAD
```

Read this before staging anything. Everything below depends on knowing what is actually there.

## 2. Gate on surprises

Stage with `git add -A`. That is what makes the commit complete: files edited by hand outside this session land too, and ignored files never do. The cost is that anything else lying around lands as well, so check the status output first.

Stop and ask when it shows:

- Untracked files nobody mentioned and this session did not create.
- Secret-shaped names: `.env*`, `*.pat`, `pat.txt`, `*key*`, `*.pem`, `id_rsa*`, `*.pfx`, `credentials*`, `*.publishsettings`.
- Binaries or anything over roughly 1 MB.

Offer three ways out: ignore it, commit it anyway, or leave it out of this commit. Write the `.gitignore` line only if the user picks that. A repo without a `.gitignore` filters nothing, so expect this gate to fire there on every commit until one exists.

## 3. Stops that block the commit

**Secrets in the staged diff.** After staging, before committing:

```bash
git diff --cached -U0 | grep -nEi '(password|passwd|secret|token|api[_-]?key|bearer |connectionstring|private[_-]key|BEGIN [A-Z ]*PRIVATE KEY)[^a-z]{0,3}[:=]'
```

A hit means unstage and report, not commit. A secret that reaches the remote has to be rotated, and reverting the commit does not rotate it.

**Committing on a shared branch.** If `git rev-parse --abbrev-ref HEAD` is `main`, `master`, `dev`, or `develop`, do not commit there. Propose `feature/<slug-from-the-staged-diff>` and commit there once the user confirms. If the user names a work item instead, hand off to `work-on` and commit on the branch it creates. `git switch -c` carries staged changes across, so nothing is lost.

This stop is deliberate on personal and single-author repos too, and the owner has confirmed it. Propose the branch. Do not propose dropping `main` from the list.

**Rewriting published history.** Never `--no-verify`, never force-push, never amend or rebase a commit that already exists on the remote. Check with `git branch -r --contains <sha>` when unsure. Amending a local-only commit is fine.

Build and test failures do not block a commit. Broken work still deserves a checkpoint.

## 4. Message

```
41243: register CS_Master_Meeting_Orga_Setup in masterdata admin

<body: why, only when the diff does not already say it>

Co-Authored-By: <the trailer the harness specifies>
```

- Subject: lowercase, imperative, 72 characters or less, no trailing period.
- Id prefix: the work-item id from the current branch name, matched as `^[Tt]?([0-9]{3,})[-_]` or `^(feature|bug|task|fix|hotfix)/[Tt]?([0-9]{3,})[-_]`. No match means no prefix. Never invent an id and never lift digits out of a branch like `dev_haase_2026_2`.
- Body: only when the reason is not obvious from the diff. Say why, not what.
- Match the repo's voice: `git log --format=%s -10` before writing the subject.

## 5. Commit and report

```bash
git add -A && git commit -m "<subject>" -m "<body>" -m "<trailer>"
```

Report the short sha, the subject, and the file count. If the gate left anything out, say what and why.

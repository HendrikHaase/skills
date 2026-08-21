---
name: work-on
description: Use when the user starts a unit of work, whether or not they name a work item: "work on #41243", "start work item 41243", "new branch for the rate limiting", "let's do 40581", and equally the moment an agreed plan turns into building — "lets get to it", "go ahead", "do it", "start implementing", or any first code edit while sitting on dev/main/master. Creates or resumes the branch that carries the work, before the edits land, so later commits and pull requests inherit it.
---

# Work on

Turn a work-item id into the branch you work on. The branch name carries the id, which is how `commit` later prefixes messages without remembering anything.

The id comes from the user. Never guess one, never pick one off the board.

## 1. An existing branch wins

```bash
git fetch --prune
git branch -a --list "*<id>*"
```

A match means switch to it and stop. Resuming an item days later must not create a second branch for it.

## 2. Branch from a fresh base

```bash
git symbolic-ref --quiet --short refs/remotes/origin/HEAD
```

That prints `origin/<default>`. If it is unset, take the first of `origin/dev`, `origin/develop`, `origin/main`, `origin/master` that exists.

```bash
git switch --no-track -c feature/<id>-<slug> origin/<default>
```

`--no-track` goes before `-c`. After it, git reads it as the branch name and dies with `fatal: only one reference expected`.

`--no-track` is the whole point of this line. Without it the new branch tracks `origin/dev`, and every later push — bare `git push`, VS Code's Sync — sends the feature work straight to the shared branch. A branch with no upstream cannot do that; the first push has to name where it goes.

Uncommitted changes come along with the switch. Say so rather than stashing anything.

Pair it with this, once per machine, so the first push publishes the feature branch instead of erroring:

```bash
git config --global push.autoSetupRemote true
```

Then `git push` on an upstreamless branch creates `origin/<same-name>` and tracks it. If it is not set, the first push is `git push -u origin feature/<id>-<slug>`.

## 3. Name it

`feature/<id>-<slug>`, where the slug is the work-item title: lowercase, every non-alphanumeric run collapsed to a single `-`, trimmed to about 40 characters.

`41243` titled "Register CS_Master_Meeting_Orga_Setup in masterdata admin" becomes `feature/41243-register-cs-master-meeting-orga-setup`.

Read the title with:

```bash
az boards work-item show --id <id> --query 'fields."System.Title"' -o tsv
```

Resolve the org and credential through the `azure-devops:work-item-connection` skill before that call. If the title cannot be read, branch as `feature/<id>` and carry on.

## 4. Move the board

Hand the state change and assignment to the `azure-devops:work-items` skill: one step forward only, assigned to the signed-in user. It knows the process template's state names and the forward-only rule. Never set a terminal state.

A failure here is worth one line of output, not a stop. The branch is the deliverable.

## 5. Repos with no Azure DevOps remote

If `git remote get-url origin` does not point at `dev.azure.com` or `visualstudio.com`, skip every step above that talks to ADO. Slug the user's own phrasing instead: "work on rate limiting" becomes `feature/rate-limiting`, branched from the fetched default. No id in the branch means `commit` writes an unprefixed subject, which is correct there.

## Report

The branch, what it was based on, and either the work-item title and its new state or a note that this repo has no work items.

---
name: work-on
description: Use when the user starts a unit of work, whether or not they name a work item: "work on #41243", "start work item 41243", "new branch for the rate limiting", "let's do 40581", and equally the moment an agreed plan turns into building — "lets get to it", "go ahead", "do it", "start implementing", or any first code edit while sitting on dev/main/master. Creates or resumes the branch that carries the work, before the edits land, so later commits and pull requests inherit it. Always start with a /grill-me after getting a good picture of what the work is about.
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

Read the title through the `azure-devops:work-items` skill, which goes over the REST API with the PAT. Do not reach for `az boards` first: plenty of environments have no `az` at all, and the failure is a bare `command not found` that reads like a broken skill rather than a missing binary.

```bash
# work-items/wi.sh, or the same call by hand
curl -s -u ":$PAT" "https://dev.azure.com/<org>/_apis/wit/workitems/<id>?api-version=7.0"
```

Resolve the org and credential through the `azure-devops:work-item-connection` skill before that call. If the title cannot be read, branch as `feature/<id>` and carry on.

## 4. Leave the board alone

Read the work item for its title, description, repro steps and attachments, which is what it is for, and stop there. Do not change `System.State` and do not assign it. Hendrik runs the board himself: a merged task stays In Progress until staging verifies it, so the state says nothing about where the work is, and moving it produces confident nonsense.

Decide what is done from the repos (branches, merge commits) instead. Linking the work item to a PR at creation time is not a state change and stays fine.

## 5. One branch per repository

The branch belongs to a repository, not to the session. A change that spans repos needs this skill run again in the second one, **before the first edit lands there** — otherwise that repo gets edited on its shared branch by default, and nobody notices until commit time, when the work is already sitting on `dev`.

Same id, same slug convention, so the two branches read as one change and `commit` prefixes both the same way. Check with `git branch --show-current` in the repo you are about to touch, not the one you started in.

## 6. Repos with no Azure DevOps remote

If `git remote get-url origin` does not point at `dev.azure.com` or `visualstudio.com`, skip every step above that talks to ADO. Slug the user's own phrasing instead: "work on rate limiting" becomes `feature/rate-limiting`, branched from the fetched default. No id in the branch means `commit` writes an unprefixed subject, which is correct there.

## Report

The branch, what it was based on, and either the work-item title or a note that this repo has no work items.

When the repos are still carrying the last item's branches, `back-to-dev` resets them first.

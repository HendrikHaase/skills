#!/usr/bin/env bash
# One pass over every repo: fetch, switch to default, ff-only pull, drop provably merged branches.
# All repos in parallel; one tool call instead of six per repo.
# Usage: back-to-dev.sh <repo-dir>...
set -u
[ $# -gt 0 ] || { echo "usage: back-to-dev.sh <repo-dir>..." >&2; exit 2; }

# Preflight. These repos are the session's working directories, named literally.
# A glob over the parent directory sweeps in unrelated repos, so refuse the shapes that look like one.
MAX_REPOS=10   # ponytail: a flat cap, not a config knob. Raise it here if a session ever needs more.
if [ $# -gt $MAX_REPOS ]; then
  echo "refusing $# repos (cap $MAX_REPOS). Pass the session's working directories, not a glob over their parent." >&2
  exit 2
fi
bad=0
for d in "$@"; do
  if [ ! -d "$d" ]; then echo "not a directory: $d" >&2; bad=1
  elif ! git -C "$d" rev-parse --git-dir >/dev/null 2>&1; then echo "not a git repo: $d" >&2; bad=1
  elif [ "$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)" != "$(cd "$d" && pwd -P)" ]; then
    echo "not a repo root: $d" >&2; bad=1
  fi
done
[ $bad -eq 0 ] || { echo "nothing touched." >&2; exit 2; }
printf 'repos: %s\n' "$*"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

one() {
  local d=$1 out=$2 err="${2%/*}/err.${1##*/}"
  g() { git -C "$d" -c advice.diverging=false "$@"; }
  local def cur ahead deleted=() unmerged=() notes=()

  g fetch --prune -q 2>>"$err" || notes+=("fetch failed")

  def=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  def=${def#origin/}
  if [ -z "$def" ]; then
    for c in dev develop main master; do
      g show-ref --quiet "refs/remotes/origin/$c" && { def=$c; break; }
    done
  fi
  [ -n "$def" ] || { echo "REPO	$(basename "$d")	NO-DEFAULT-BRANCH" >"$out"; return; }

  cur=$(g symbolic-ref --quiet --short HEAD 2>/dev/null || echo DETACHED)
  if [ "$cur" != "$def" ]; then
    g switch -q "$def" 2>>"$err" || notes+=("switch to $def failed, still on $cur")
  fi
  cur=$(g symbolic-ref --quiet --short HEAD 2>/dev/null || echo DETACHED)

  if [ "$cur" = "$def" ]; then
    g merge --ff-only -q "origin/$def" 2>>"$err" \
      || notes+=("$def will not fast-forward, local commits: $(g log --oneline "origin/$def..$def" | tr '\n' ';')")
    ahead=$(g rev-list --count "origin/$def..$def")
    [ "$ahead" = 0 ] || notes+=("$def is $ahead commit(s) ahead of origin, unpushed")
  fi

  # provably merged into the fetched remote ref, not the local one
  while read -r b; do
    [ -z "$b" ] && continue
    [ "$b" = "$def" ] && continue
    if g merge-base --is-ancestor "$b" "origin/$def" 2>/dev/null; then
      g branch -q -d "$b" 2>>"$err" && deleted+=("$b") || notes+=("could not delete $b")
    else
      unmerged+=("$b")
    fi
  done < <(g for-each-ref --format='%(refname:short)' refs/heads)

  while read -r r; do
    [ -z "$r" ] && continue
    notes+=("remote branch still on server: $r")
  done < <(g for-each-ref --format='%(refname:short)' --merged "origin/$def" refs/remotes/origin \
           | grep -vx -e "origin/$def" -e origin -e origin/HEAD)

  local real churn staged untracked
  # --numstat, not --name-only: name-only still lists a file whose only diff is CR churn
  real=$(g diff --ignore-cr-at-eol --numstat | wc -l)
  churn=$(( $(g diff --numstat | wc -l) - real ))
  staged=$(g diff --cached --name-only | wc -l)
  untracked=$(g ls-files --others --exclude-standard | wc -l)

  {
    printf 'REPO\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(basename "$d")" "$cur" "$(g log -1 --format='%h %s' | cut -c1-60)" \
      "${deleted[*]:-none}" "$real" "$churn" "$staged" "$untracked"
    for n in "${unmerged[@]}"; do printf 'NOTE\t%s\tunmerged branch kept: %s\n' "$(basename "$d")" "$n"; done
    for n in "${notes[@]}"; do printf 'NOTE\t%s\t%s\n' "$(basename "$d")" "$n"; done
  } >>"$out"
}

i=0
for d in "$@"; do
  printf -v n '%03d' "$i"   # outside a subshell: $((i++)) in one would never increment here
  one "$d" "$tmp/$n" &
  i=$((i+1))
done
wait

echo "repo	branch	head	deleted	dirty_real	dirty_crlf	staged	untracked"
cat "$tmp"/[0-9][0-9][0-9] 2>/dev/null | grep '^REPO' | cut -f2-
cat "$tmp"/[0-9][0-9][0-9] 2>/dev/null | grep '^NOTE' | cut -f2- | sed 's/^/! /'
for f in "$tmp"/err.*; do [ -s "$f" ] || continue; echo "--- git stderr: ${f##*/err.} ---"; cat "$f"; done
exit 0

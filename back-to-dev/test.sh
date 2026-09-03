#!/usr/bin/env bash
# Runnable check for back-to-dev.sh: builds four throwaway repos and asserts the report.
# Usage: bash test.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT
cd "$S"
git init -q --bare origin.git
git clone -q origin.git seed 2>/dev/null; cd seed
git config user.email t@t; git config user.name t
echo a > a.txt; git add .; git commit -qm init; git branch -m dev; git push -qu origin dev
git switch -qc feature/merged; printf 'x\r\ny\r\n' > crlf.txt; git add .; git commit -qm crlf
git push -q origin feature/merged
git switch -q dev; git merge -q --no-ff -m merge feature/merged; git push -q origin dev
git switch -qc feature/unmerged; echo c > c.txt; git add .; git commit -qm c
git switch -q dev
printf 'x\ny\n' > crlf.txt; echo more >> a.txt        # 1 real change + 1 CR-only change
cd "$S"
git clone -q -b dev origin.git ahead; cd ahead
git config user.email t@t; git config user.name t
echo local > local.txt; git add .; git commit -qm "local only"
cd "$S"

out=$(bash "$here/back-to-dev.sh" "$S/seed" "$S/ahead")
echo "$out"
fail() { echo "FAIL: $1" >&2; exit 1; }
grep -q $'^seed\tdev\t.*\tfeature/merged\t1\t1\t0\t0' <<<"$out" || fail "seed row: merged branch deleted, 1 real + 1 CR-churn file"
grep -q 'unmerged branch kept: feature/unmerged' <<<"$out" || fail "unmerged branch must be kept and reported"
grep -q 'remote branch still on server: origin/feature/merged' <<<"$out" || fail "merged remote branch must be reported"
grep -q 'ahead.*ahead of origin, unpushed' <<<"$out" || fail "unpushed local commit must be reported"
[ -d "$S/seed/.git/refs/heads" ] && git -C "$S/seed" show-ref --quiet refs/heads/feature/unmerged || fail "unmerged branch was deleted"

# guards: a wrong repo set must be refused before anything is touched
guard() { if bash "$here/back-to-dev.sh" "$@" >/dev/null 2>&1; then fail "guard let through: $*"; fi; }
guard "$S"                          # a parent directory, not a repo
guard "$S/seed/.git"                # inside a repo, not its root
guard "$S/nope"                     # missing
guard $(for i in $(seq 11); do echo "$S/seed"; done)   # longer than the cap
git -C "$S/ahead" rev-parse --abbrev-ref HEAD | grep -qx dev || fail "guard run altered a repo"

echo "OK"

#!/usr/bin/env bash
# Builds the repos the ship-task evals run against. Each fixture is <out>/<name>/ with a
# bare origin.git and a work/ clone in a state ship-task must refuse to ship from.
# Usage: ./make-fixtures.sh <out-dir>
# Check nothing was pushed or merged: (cd <name> && ../snapshot.sh) | diff - <name>.before
set -euo pipefail
out=${1:?usage: make-fixtures.sh <out-dir>}
mkdir -p "$out" && cd "$out"
out=$(pwd)
g() { git -c user.name=fixture -c user.email=fixture@example.com "$@"; }

cat > snapshot.sh <<'SNAP'
#!/usr/bin/env bash
# Run from a fixture dir: origin refs, plus the work clone's branch, HEAD and status.
git -C origin.git for-each-ref --format='%(refname) %(objectname)'
git -C work symbolic-ref -q HEAD || echo detached
git -C work rev-parse HEAD
git -C work status --porcelain
git -C work branch --format='%(refname:short)'
SNAP
chmod +x snapshot.sh

make_base() { # <name>: origin with one commit on main, cloned into work/
  mkdir -p "$1" && cd "$1"
  git init -q --bare -b main origin.git
  git clone -q origin.git work 2>/dev/null
  cd work
  printf '# demo\n' > README.md
  printf 'Preflight: true\n' > CLAUDE.md
  g add -A && g commit -qm "chore: init" && git push -q origin main
}

# on-base-dirty: on main itself, with an uncommitted edit. Must stop (branch is the base).
(make_base on-base-dirty; echo "change" >> README.md)
# detached: HEAD detached at a new commit. Must stop (detached HEAD).
(make_base detached; git checkout -q --detach; echo x > a.txt; g add a.txt; g commit -qm "feat: a")
# nothing-to-ship: feature branch with no commits ahead of origin/main. Must stop.
(make_base nothing-to-ship; git checkout -q -b feat/empty)
# feature-dirty: feature branch with one commit and an uncommitted change. Must stop (dirty tree).
(make_base feature-dirty; git checkout -q -b feat/x; echo x > x.txt; g add x.txt; g commit -qm "feat: x"; echo y >> x.txt)

for f in on-base-dirty detached nothing-to-ship feature-dirty; do (cd "$f" && ../snapshot.sh) > "$f.before"; done
echo "fixtures in $out"

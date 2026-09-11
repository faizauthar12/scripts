#!/usr/bin/env bash
# Syntax-checks every shell/zsh file in the repo. Run manually before
# committing, or wire in once via:
#   git config core.hooksPath scripts-hooks && ln -s ../../check.sh scripts-hooks/pre-commit
# (opt-in — core.hooksPath isn't versioned by git itself, so this script is
# the thing that gets committed; the hook wiring is a one-time local step.)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

status=0

echo "==> bash -n"
while IFS= read -r -d '' f; do
  bash -n "$f" && echo "  ok: $f" || { echo "  FAIL: $f" >&2; status=1; }
done < <(find . -name '*.sh' -not -path './.git/*' -print0)

echo "==> zsh -n"
for f in zsh/.zshenv zsh/.zprofile; do
  zsh -n "$f" && echo "  ok: $f" || { echo "  FAIL: $f" >&2; status=1; }
done

exit $status

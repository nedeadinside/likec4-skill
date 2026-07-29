#!/usr/bin/env bash
# Moves the pin to a new LikeC4 version: rewrites scripts/likec4-version, then
# any leftover mention of the old number in the docs, then runs the full check.
#
#   scripts/bump-pin.sh 1.60.0     bump and verify
#   scripts/bump-pin.sh            bump to whatever npm calls latest
#
# Exits 0 only if the skill still checks out on the new version, so CI can use
# the exit code to decide between "open a PR" and "open an issue".
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
VERSION_FILE="$HERE/scripts/likec4-version"

old="$(tr -d '[:space:]' < "$VERSION_FILE")"
new="${1:-$(npm view likec4 version)}"
[ -n "$new" ] || { echo "could not determine the new version"; exit 2; }

if [ "$old" = "$new" ]; then
  echo "already pinned to ${new}"
  exit 0
fi

echo "bumping ${old} -> ${new}"
printf '%s\n' "$new" > "$VERSION_FILE"

# The skill itself never spells the version out — it points at this file — but
# repo-level docs do (the README badge), and a stray literal could always creep
# back into a reference. Rewrite any that exist, then prove the new version.
mapfile -t files < <(
  grep -rl --fixed-strings "$old" \
    --include='*.md' "$HERE" "$REPO/README.md" 2>/dev/null |
    grep -v '/scripts/snippet-fixtures.md$' | sort -u
)
for f in "${files[@]}"; do
  sed -i "s/${old//./\\.}/${new}/g" "$f"
  echo "  updated $(realpath --relative-to="$REPO" "$f")"
done

echo
"$HERE/scripts/check.sh"

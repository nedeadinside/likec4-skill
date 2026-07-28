#!/usr/bin/env bash
# Validates every template in this skill with the PINNED LikeC4 version.
# Run after any edit to templates/ or before bumping the pin.
#
# Upgrade procedure: change LIKEC4_VERSION below (single source of truth),
# run this script; if it exits 0, commit the bump and update the version
# mentioned in references/setup-and-validation.md and SKILL.md.
set -u

LIKEC4_VERSION="1.59.2"
# Floor, measured: < 1.52.0 has no `format` (unknown command exits 0, so the
# format gate silently passes); 1.52.0 exits 0 on an invalid model. An older
# installed CLI is therefore ignored in favour of the pin.
LIKEC4_MIN="1.53.0"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

# `--version` may also print an "Update available" banner; keep the semver line.
installed="$(likec4 --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | tail -1)"
if [ -n "$installed" ] &&
   [ "$(printf '%s\n%s\n' "$installed" "$LIKEC4_MIN" | sort -V | head -1)" = "$LIKEC4_MIN" ]; then
  echo "using installed likec4 ${installed} (min ${LIKEC4_MIN})"
  LIKEC4=(likec4)
else
  [ -n "$installed" ] && echo "installed likec4 ${installed} < ${LIKEC4_MIN}, using pin"
  LIKEC4=(npx -y "likec4@${LIKEC4_VERSION}")
fi

run_likec4() {
  "${LIKEC4[@]}" "$@"
}

fail=0
for dir in "$HERE"/templates/*/; do
  name="$(basename "$dir")"

  echo "== validating templates/${name} =="
  if run_likec4 validate "$dir"; then
    echo "OK: validate ${name}"
  else
    echo "FAIL: validate ${name}"
    fail=1
  fi

  # Templates are what the model copies verbatim, so they must already be in
  # canonical form: --check is read-only and exits 1 on any drift.
  echo "== format --check templates/${name} =="
  if run_likec4 format "$dir" --check; then
    echo "OK: format ${name}"
  else
    echo "FAIL: format ${name} (run: likec4 format ${dir})"
    fail=1
  fi
done

exit "$fail"

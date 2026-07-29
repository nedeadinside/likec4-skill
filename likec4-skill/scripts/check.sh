#!/usr/bin/env bash
# Validates this skill against the PINNED LikeC4 version
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
LIKEC4_VERSION="$(tr -d '[:space:]' < "$HERE/scripts/likec4-version")"
[ -n "$LIKEC4_VERSION" ] || { echo "scripts/likec4-version is empty"; exit 2; }
echo "pinned likec4: ${LIKEC4_VERSION}"

run_likec4() {
  npx -y "likec4@${LIKEC4_VERSION}" "$@"
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

  echo "== format --check templates/${name} =="
  if run_likec4 format "$dir" --check; then
    echo "OK: format ${name}"
  else
    echo "FAIL: format ${name} (run: likec4 format ${dir})"
    fail=1
  fi
done

echo "== validating documentation snippets =="
if "$HERE/scripts/check-snippets.sh" "$LIKEC4_VERSION"; then
  echo "OK: snippets"
else
  echo "FAIL: snippets"
  fail=1
fi

exit "$fail"

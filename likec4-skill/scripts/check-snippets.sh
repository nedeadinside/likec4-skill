#!/usr/bin/env bash
# Compiles every ```likec4 block in SKILL.md and references/**/*.md with the
# PINNED LikeC4 version. A snippet that ships in this skill is a snippet the
# model will copy, so it has to be real syntax, not plausible syntax.
#
# Usage: check-snippets.sh [version]     (default: scripts/likec4-version)
#
# Each block becomes a LikeC4 project under a temp workspace, and each workspace
# is validated in ONE CLI run (multi-project mode).
#
# Info-string modifiers on the fence:
#   ```likec4                       standalone project — must validate
#   ```likec4 fixture=NAME          inserted at the %% marker of fixture NAME
#   ```likec4 group=NAME            merged with every other group=NAME block in
#                                   the skill into one project — worked examples
#                                   that span several files
#   ```likec4 group=NAME project=P  same, but the group is a multi-project
#                                   workspace and this block is project P —
#                                   for `import { … } from 'P'`
#   ```likec4 invalid               intentionally broken — must FAIL to validate
#
# Fixtures and group preludes live in scripts/snippet-fixtures.md: the
# surrounding model a doc fragment needs, kept out of the docs themselves.
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
LIKEC4_VERSION="${1:-$(tr -d '[:space:]' < "$HERE/scripts/likec4-version")}"
[ -n "$LIKEC4_VERSION" ] || { echo "no likec4 version given and scripts/likec4-version is empty"; exit 2; }

WORK="${TMPDIR:-/tmp}/likec4-snippets.$$"
trap '[ -n "${KEEP_SNIPPET_WORKDIR:-}" ] && echo "workdir kept: $WORK" || rm -rf "$WORK"' EXIT

LIKEC4=(npx -y "likec4@${LIKEC4_VERSION}")

mkdir -p "$WORK/valid" "$WORK/invalid"

find "$HERE" -name '*.md' -not -path '*/node_modules/*' \
     -not -name 'snippet-fixtures.md' -print0 |
  sort -z |
  xargs -0 awk -v work="$WORK" -v root="$HERE" '
  function emit(ws, proj, key, txt, origin,   dir) {
    if (!((ws "/" key) in projdir)) {
      dir = work "/" ws "/" (proj != "" ? proj : sprintf("p%03d", ++seq))
      system("mkdir -p \"" dir "\"")
      printf "{\"name\":\"%s\"}\n", (proj != "" ? proj : sprintf("p%03d", seq)) > (dir "/likec4.config.json")
      close(dir "/likec4.config.json")
      projdir[ws "/" key] = dir
      print dir "\t" origin >> (work "/manifest")
      close(work "/manifest")
    }
    dir = projdir[ws "/" key]
    printf "%s\n", txt >> (dir "/main.c4")
    close(dir "/main.c4")
  }

  function here(  rel) { rel = FILENAME; sub("^" root "/", "", rel); return rel ":" startline }

  function label() {
    if (grpname == "") return here()
    return "group " grpname (projname != "" ? "/" projname : "") " (first block " here() ")"
  }

  function flush(  n, parts, txt) {
    txt = block
    if (fixname != "") {
      n = split(fixtures[fixname], parts, "%%")
      if (n != 2) {
        print "check-snippets: unknown fixture \"" fixname "\" (or no %% marker) at " here() > "/dev/stderr"
        exit 2
      }
      txt = parts[1] txt parts[2]
    }
    emit(workspace, projname, groupkey, txt, label())
    block = ""
  }

  # <!-- likec4-fixture: NAME ... -->   surrounding model, %% marks the hole
  /^<!--[ \t]*likec4-fixture:/ {
    cname = $0; sub(/^<!--[ \t]*likec4-fixture:[ \t]*/, "", cname); sub(/[ \t]*$/, "", cname)
    incomment = "fixture"; fixtures[cname] = ""; next
  }
  # <!-- likec4-prelude: GROUP ... -->  extra sources for a cross-file group
  /^<!--[ \t]*likec4-prelude:/ {
    cname = $0; sub(/^<!--[ \t]*likec4-prelude:[ \t]*/, "", cname); sub(/[ \t]*$/, "", cname)
    incomment = "prelude"; prelude[cname] = ""; next
  }
  incomment != "" && /^-->[ \t]*$/ {
    if (incomment == "prelude") {
      startline = FNR; grpname = cname; projname = ""; workspace = "valid"
      emit("valid", "", "g#" cname, prelude[cname], "group " cname " prelude (" here() ")")
    }
    incomment = ""; next
  }
  incomment != "" {
    if (incomment == "fixture") fixtures[cname] = fixtures[cname] $0 "\n"
    else prelude[cname] = prelude[cname] $0 "\n"
    next
  }

  !inblock && /^[ \t]*```likec4/ {
    inblock = 1; startline = FNR; block = ""
    fixname = ""; grpname = ""; projname = ""; workspace = "valid"
    info = $0; sub(/^[ \t]*```likec4[ \t]*/, "", info)
    groupkey = FILENAME ":" FNR                       # standalone unless grouped
    if (info ~ /(^|[ \t])invalid([ \t]|$)/) workspace = "invalid"
    if (match(info, /fixture=[A-Za-z0-9_-]+/))
      fixname = substr(info, RSTART + 8, RLENGTH - 8)
    if (match(info, /group=[A-Za-z0-9_-]+/)) {
      grpname = substr(info, RSTART + 6, RLENGTH - 6)
      groupkey = "g#" grpname
    }
    if (match(info, /project=[A-Za-z0-9_-]+/)) {
      projname = substr(info, RSTART + 8, RLENGTH - 8)
      if (grpname == "") {
        print "check-snippets: project= needs group= at " here() > "/dev/stderr"
        exit 2
      }
      workspace = "mp-" grpname                       # its own multi-project workspace
      groupkey = "mp#" grpname "#" projname
    }
    next
  }
  inblock && /^[ \t]*```[ \t]*$/ { inblock = 0; flush(); next }
  inblock { block = block $0 "\n"; next }
' "$HERE/scripts/snippet-fixtures.md" || exit 2

[ -f "$WORK/manifest" ] || { echo "check-snippets: no likec4 blocks found"; exit 2; }

where() { awk -F'\t' -v d="$1" '$1 == d { print $2; exit }' "$WORK/manifest"; }

broken_in() {
  NO_COLOR=1 "${LIKEC4[@]}" validate --no-layout "$1" 2>&1 |
    sed -n 's#.*Invalid \('"$1"'/[A-Za-z0-9_-]*\)/main\.c4.*#\1#p' | sort -u
}

count_projects() { find "$1" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort; }

fail=0
n_valid=$(count_projects "$WORK/valid" | wc -l)
n_invalid=$(count_projects "$WORK/invalid" | wc -l)
n_mp=$(find "$WORK" -maxdepth 1 -mindepth 1 -type d -name 'mp-*' | wc -l)
echo "== compiling ${n_valid} snippet(s), ${n_mp} multi-project group(s), ${n_invalid} negative example(s) =="

for ws in "$WORK/valid" $(find "$WORK" -maxdepth 1 -mindepth 1 -type d -name 'mp-*' | sort); do
  [ -n "$(ls -A "$ws" 2>/dev/null)" ] || continue
  broken="$(broken_in "$ws")"
  [ -n "$broken" ] || continue
  fail=1
  echo "FAIL: these documented snippets do not compile:"
  for d in $broken; do echo "  - $(where "$d")"; done
  echo "--- validator output ---"
  NO_COLOR=1 "${LIKEC4[@]}" validate --no-layout "$ws" 2>&1 |
    grep -E 'Invalid|Line [0-9]+:' |
    sed "s#$ws/\([A-Za-z0-9_-]*\)/main.c4#\1#"
done
[ "$fail" -eq 0 ] && echo "OK: all $((n_valid + n_mp)) snippet project(s) compile"

if [ "$n_invalid" -gt 0 ]; then
  really_broken=" $(broken_in "$WORK/invalid" | tr '\n' ' ')"
  ok=1
  for d in $(count_projects "$WORK/invalid"); do
    case "$really_broken" in
      *" $d "*) ;;
      *) fail=1; ok=0; echo "FAIL: $(where "$d") is marked \`\`\`likec4 invalid but compiles fine" ;;
    esac
  done
  [ "$ok" -eq 1 ] && echo "OK: all ${n_invalid} negative examples still rejected"
fi

exit "$fail"

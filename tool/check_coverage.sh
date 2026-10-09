#!/usr/bin/env sh
# Coverage ratchet: line coverage of lib/ must not drop below the committed
# baseline in tool/coverage_baseline.txt.
#
#   tool/check_coverage.sh [lcov ...]            check (CI gate)
#   tool/check_coverage.sh [lcov ...] --update   raise the baseline to the
#                                                current value (never lowers)
#
# Several lcov files (unit + integration runs) are MERGED: a line counts as
# covered when any run executed it. Default input: coverage/lcov.info plus
# coverage/lcov.integration.info when present.
#
# Excluded: generated code (*.g.dart) and pure declarations whose "lines" are
# never meaningfully executed — the l10n string table (one getter per line,
# counted only when a test happens to render that string) and the Drift table
# definitions (schema DSL). They measure which strings/columns a test touched,
# not which logic ran.
#
# A small tolerance absorbs run-to-run noise (async paths hit or not by
# timing). When coverage goes up, raise the baseline in the same commit.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
cd "$repo_root"

baseline_file=tool/coverage_baseline.txt
tolerance=0.10
mode=check
files=""
for arg in "$@"; do
  case "$arg" in
    --update) mode=update ;;
    *) files="$files $arg" ;;
  esac
done
if [ -z "$files" ]; then
  files=coverage/lcov.info
  [ -f coverage/lcov.integration.info ] && files="$files coverage/lcov.integration.info"
fi
for f in $files; do
  [ -f "$f" ] || { echo "coverage file not found: $f (run: flutter test --coverage)" >&2; exit 1; }
done

# shellcheck disable=SC2086
summary=$(awk -F'[:,]' '
  /^SF:/ {
    f = substr($0, 4)
    i = index(f, "lib/"); if (i > 1 && substr(f, i - 1, 1) != "/") i = 0
    f = (substr(f, 1, 4) == "lib/") ? f : (i > 0 ? substr(f, i) : "")
    keep = (f != "" && f !~ /\.g\.dart$/ && f != "lib/l10n/app_strings.dart" && f != "lib/database/tables.dart")
    next
  }
  /^DA:/ && keep {
    k = f SUBSEP $2
    seen[k] = 1
    if ($3 + 0 > 0) hit[k] = 1
  }
  END {
    for (k in seen) lf++
    for (k in hit) lh++
    if (lf == 0) printf "0.00 0/0"; else printf "%.2f %d/%d", 100 * lh / lf, lh, lf
  }
' $files)
current=${summary%% *}
lines=${summary#* }

baseline=$(tr -d '[:space:]' < "$baseline_file")
echo "Line coverage (lib/, merged:$files): ${current}% (${lines}); baseline ${baseline}%"

if [ "$mode" = update ]; then
  if awk -v c="$current" -v b="$baseline" 'BEGIN { exit !(c > b) }'; then
    printf '%s\n' "$current" > "$baseline_file"
    echo "Baseline raised to ${current}%"
  else
    echo "Baseline unchanged (current is not above it)"
  fi
  exit 0
fi

if awk -v c="$current" -v b="$baseline" -v t="$tolerance" 'BEGIN { exit !(c + t < b) }'; then
  echo "::error::Coverage dropped to ${current}% (baseline ${baseline}%, tolerance ${tolerance}). Add tests for the new code." >&2
  exit 1
fi
if awk -v c="$current" -v b="$baseline" -v t="$tolerance" 'BEGIN { exit !(c > b + t) }'; then
  echo "Coverage is above the baseline: raise it with 'tool/check_coverage.sh$files --update' and commit tool/coverage_baseline.txt."
fi

#!/usr/bin/env sh
# Coverage ratchet: line coverage of lib/ (generated *.g.dart excluded) from a
# `flutter test --coverage` lcov file must not drop below the committed
# baseline in tool/coverage_baseline.txt.
#
#   tool/check_coverage.sh [lcov.info]          check (CI gate)
#   tool/check_coverage.sh [lcov.info] --update raise the baseline to the
#                                               current value (never lowers it)
#
# A small tolerance absorbs run-to-run noise (async code paths hit or not by
# timing); anything beyond it fails. When coverage goes up, raise the
# baseline in the same commit so the gain is locked in.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
cd "$repo_root"

lcov=${1:-coverage/lcov.info}
mode=${2:-check}
baseline_file=tool/coverage_baseline.txt
tolerance=0.10

if [ ! -f "$lcov" ]; then
  echo "coverage file not found: $lcov (run: flutter test --coverage)" >&2
  exit 1
fi

# LF/LH summed over lib/ source files that are not generated.
current=$(awk -F: '
  /^SF:/ { f = substr($0, 4); keep = (f ~ /(^|\/)lib\// && f !~ /\.g\.dart$/) }
  /^LF:/ && keep { lf += $2 }
  /^LH:/ && keep { lh += $2 }
  END { if (lf == 0) { print "0.00" } else { printf "%.2f", 100 * lh / lf } }
' "$lcov")
lines=$(awk -F: '
  /^SF:/ { f = substr($0, 4); keep = (f ~ /(^|\/)lib\// && f !~ /\.g\.dart$/) }
  /^LF:/ && keep { lf += $2 } /^LH:/ && keep { lh += $2 }
  END { printf "%d/%d", lh, lf }
' "$lcov")

baseline=$(tr -d '[:space:]' < "$baseline_file")
echo "Line coverage (lib/, generated excluded): ${current}% (${lines}); baseline ${baseline}%"

if [ "$mode" = "--update" ]; then
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
  echo "Coverage is above the baseline: raise it with 'tool/check_coverage.sh $lcov --update' and commit tool/coverage_baseline.txt."
fi

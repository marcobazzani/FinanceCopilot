#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./do-release.sh --version v0.10.1 --title "Short description" [options]

Required:
  --version VERSION     Release version, with or without a leading v.
  --title TEXT          Short description used in the GitHub release title.

Options:
  --merge-pr NUMBER     Merge this pull request into main before tagging.
  --notes-file PATH     Use this file as GitHub release notes.
  --cleanup-cmd CMD     Pre-release cleanup command to run on develop.
  --skip-cleanup        Skip the cleanup hook when none is configured.
  --no-sync-develop     Skip the post-release merge from main back to develop.
  --dry-run             Print the commands without changing git/GitHub state.
  -h, --help            Show this help.

Environment:
  PRE_RELEASE_CLEANUP_CMD  Default cleanup command if --cleanup-cmd is absent.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

run() {
  echo "+ $*"
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi
  "$@"
}

run_shell() {
  echo "+ bash -lc $1"
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi
  bash -lc "$1"
}

version=""
title=""
merge_pr=""
notes_file=""
cleanup_cmd="${PRE_RELEASE_CLEANUP_CMD:-}"
skip_cleanup=false
sync_develop=true
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --title)
      title="${2:-}"
      shift 2
      ;;
    --merge-pr)
      merge_pr="${2:-}"
      shift 2
      ;;
    --notes-file)
      notes_file="${2:-}"
      shift 2
      ;;
    --cleanup-cmd)
      cleanup_cmd="${2:-}"
      shift 2
      ;;
    --skip-cleanup)
      skip_cleanup=true
      shift
      ;;
    --no-sync-develop)
      sync_develop=false
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$version" ]] || { usage; die "Missing --version"; }
[[ -n "$title" ]] || { usage; die "Missing --title"; }

if [[ "$version" != v* ]]; then
  version="v$version"
fi

[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version must look like vX.Y.Z"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "Run this from inside the FinanceCopilot repo"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
  die "Working tree is not clean"
fi

if git show-ref --tags --quiet --verify "refs/tags/$version"; then
  die "Tag $version already exists locally"
fi

run git fetch origin --tags --prune --force

if [[ -n "$merge_pr" ]]; then
  pr_state="$(gh pr view "$merge_pr" --json state --jq .state)"
  case "$pr_state" in
    MERGED)
      echo "PR #$merge_pr is already merged."
      ;;
    CLOSED)
      die "PR #$merge_pr is closed and not merged"
      ;;
    OPEN)
      run gh pr merge "$merge_pr" --merge
      ;;
    *)
      die "Unexpected PR state for #$merge_pr: $pr_state"
      ;;
  esac
fi

if [[ "$skip_cleanup" == false && -n "$cleanup_cmd" ]]; then
  run git checkout develop
  run git pull --ff-only origin develop
  run_shell "$cleanup_cmd"
elif [[ "$skip_cleanup" == false ]]; then
  echo "WARNING: no cleanup command configured; continuing without running the pre-release hook."
fi

run git checkout main
run git pull --ff-only origin main

develop_ci="$(gh run list --branch develop --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || true)"
if [[ -z "$develop_ci" ]]; then
  die "Could not determine the latest develop workflow result"
fi
develop_ci="$(printf '%s' "$develop_ci" | tr '[:upper:]' '[:lower:]')"
if [[ "$develop_ci" != success ]]; then
  die "Latest develop workflow did not pass: $develop_ci"
fi

tmp_notes="$(mktemp)"
trap 'rm -f "$tmp_notes"' EXIT

previous_tag="$(git describe --tags --abbrev=0 --match 'v*' HEAD^ 2>/dev/null || true)"
repo_slug="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

if [[ -n "$notes_file" ]]; then
  cp "$notes_file" "$tmp_notes"
else
  {
    echo "$version -- $title"
    echo
    if [[ -n "$previous_tag" ]]; then
      echo "Changes since $previous_tag:"
      git log --oneline "${previous_tag}..HEAD"
    else
      echo "Changes:"
      git log --oneline HEAD
    fi
    if [[ -n "$merge_pr" ]]; then
      echo
      echo "Merged PR #$merge_pr: https://github.com/$repo_slug/pull/$merge_pr"
    fi
  } >"$tmp_notes"
fi

run git tag -a "$version" -m "$version -- $title"
run git push origin "$version"
run gh release create "$version" --title "$version -- $title" --notes-file "$tmp_notes"

run_id=""
for _ in $(seq 1 60); do
  run_id="$(gh run list --branch "$version" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
  if [[ -n "$run_id" ]]; then
    break
  fi
  sleep 10
done

if [[ -n "$run_id" ]]; then
  run gh run watch "$run_id" --exit-status
else
  echo "WARNING: no GitHub Actions run appeared for tag $version within the timeout."
fi

if [[ "$sync_develop" == true ]]; then
  run git checkout develop
  run git merge --no-ff main -m "Merge main $version into develop"
  run git push origin develop
  run git checkout main
fi

echo "Release $version complete."

#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
cd "$repo_root"

expected_version=$(tr -d '[:space:]' < .flutter-version)

if ! flutter_version_output=$(flutter --version 2>&1); then
  printf '%s\n' "$flutter_version_output" >&2
  exit 1
fi

actual_version=$(printf '%s\n' "$flutter_version_output" | awk '/^Flutter / { print $2; exit }')

if [ "$actual_version" != "$expected_version" ]; then
  printf 'Expected Flutter %s from .flutter-version, got %s.\n' "$expected_version" "${actual_version:-unknown}" >&2
  printf 'Use the pinned Flutter SDK before running dart format.\n' >&2
  exit 1
fi

dart format --output=none --set-exit-if-changed lib test integration_test

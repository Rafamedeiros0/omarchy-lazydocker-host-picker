#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

command -v go >/dev/null 2>&1 || {
  echo 'Go is required to check the plugin sources.' >&2
  exit 1
}
command -v gofmt >/dev/null 2>&1 || {
  echo 'gofmt is required to check the plugin sources.' >&2
  exit 1
}
command -v node >/dev/null 2>&1 || {
  echo 'Node.js is required to test the host configuration model.' >&2
  exit 1
}

mapfile -d '' go_files < <(find "$repo_dir/plugin" -type f -name '*.go' -print0 | sort -z)
if ((${#go_files[@]} == 0)); then
  echo 'No Go files found under plugin/.' >&2
  exit 1
fi

unformatted="$(gofmt -l "${go_files[@]}")"
if [[ -n "$unformatted" ]]; then
  printf 'Go files need formatting; run gofmt -w on:\n%s\n' "$unformatted" >&2
  exit 1
fi

cd "$repo_dir"
GO111MODULE=off go test ./plugin/...
GO111MODULE=off go vet ./plugin/...
node tests/host-config-model.test.cjs

mapfile -d '' shell_files < <(
  find "$repo_dir/plugin" "$repo_dir/scripts" -type f -name '*.sh' -print0 | sort -z
)
shell_files+=(
  "$repo_dir/plugin/docker-ssh-proxy-launcher"
  "$repo_dir/plugin/lazydocker-picker-shortcut"
)
for shell_file in "${shell_files[@]}"; do
  bash -n "$shell_file"
done

printf 'Go tests, vet, formatting, and shell syntax checks passed.\n'

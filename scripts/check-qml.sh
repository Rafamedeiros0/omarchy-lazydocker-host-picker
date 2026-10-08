#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

if [[ -n "${QT6_QML_TOOLS_DIR:-}" ]]; then
  qmllint_bin="$QT6_QML_TOOLS_DIR/qmllint"
  qmlformat_bin="$QT6_QML_TOOLS_DIR/qmlformat"
elif [[ -x /usr/lib/qt6/bin/qmllint && -x /usr/lib/qt6/bin/qmlformat ]]; then
  qmllint_bin=/usr/lib/qt6/bin/qmllint
  qmlformat_bin=/usr/lib/qt6/bin/qmlformat
else
  qmllint_bin="$(command -v qmllint || true)"
  qmlformat_bin="$(command -v qmlformat || true)"
fi

for tool in "$qmllint_bin" "$qmlformat_bin"; do
  if [[ ! -x "$tool" ]]; then
    printf 'Missing Qt 6 QML tool: %s. Set QT6_QML_TOOLS_DIR if needed.\n' "$tool" >&2
    exit 1
  fi
  if ! "$tool" --version 2>&1 | grep -Eq '(^|[[:space:]])6\.'; then
    printf '%s is not a Qt 6 tool. Set QT6_QML_TOOLS_DIR to the Qt 6 tools directory.\n' "$tool" >&2
    exit 1
  fi
done

mapfile -d '' qml_files < <(find plugin -type f -name '*.qml' -print0 | sort -z)
if ((${#qml_files[@]} == 0)); then
  printf 'No QML files found under plugin/.\n' >&2
  exit 1
fi

printf 'Linting %d QML files...\n' "${#qml_files[@]}"
lint_args=()
if [[ -n "${QML_IMPORT_PATHS:-}" ]]; then
  IFS=: read -r -a import_paths <<< "$QML_IMPORT_PATHS"
  for import_path in "${import_paths[@]}"; do
    [[ -n "$import_path" ]] && lint_args+=(-I "$import_path")
  done
fi
"$qmllint_bin" "${lint_args[@]}" "${qml_files[@]}"

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
format_failed=0

printf 'Checking QML formatting...\n'
for index in "${!qml_files[@]}"; do
  file="${qml_files[$index]}"
  formatted_file="$temp_dir/$index.qml"
  "$qmlformat_bin" "$file" > "$formatted_file"
  if ! cmp -s "$file" "$formatted_file"; then
    diff -u --label "$file" "$file" --label "qmlformat output" "$formatted_file" || true
    format_failed=1
  fi
done

if ((format_failed)); then
  printf '\nQML formatting differs. Run %s -i on the affected files.\n' "$qmlformat_bin" >&2
  exit 1
fi

printf 'QML lint and formatting checks passed.\n'

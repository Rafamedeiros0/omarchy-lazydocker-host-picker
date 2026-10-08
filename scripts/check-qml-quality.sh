#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
quality_image=lazydocker-host-picker-qml-quality:arch-20260913
# Pin Omarchy's QML type context to an immutable commit.
omarchy_commit=1554a522ccd641a603d94aae28c495ce30afa428
inside_quality_container="${QML_QUALITY_IN_CONTAINER:-0}"
require_pinned_omarchy="${OMARCHY_REQUIRE_PINNED:-0}"
commons_dir=""

if [[ "$inside_quality_container" != 1 ]] && command -v docker >/dev/null && docker info >/dev/null 2>&1; then
  docker build --quiet \
    --file "$repo_dir/scripts/qml-quality.Dockerfile" \
    --tag "$quality_image" \
    "$repo_dir/scripts"
  exec docker run --rm \
    --volume "$repo_dir:/workspace" \
    --volume lazydocker-host-picker-omarchy-cache:/root/.cache/lazydocker-host-picker \
    --workdir /workspace \
    --env QML_QUALITY_IN_CONTAINER=1 \
    "$quality_image" bash scripts/check-qml-quality.sh
fi

if [[ "$inside_quality_container" != 1 ]]; then
  echo 'Docker daemon unavailable; running with local Qt tools and Omarchy types.' >&2
fi

if [[ "$inside_quality_container" == 1 ]]; then
  if [[ ! -f /etc/arch-release ]]; then
    echo 'The pinned QML quality container must run on Arch Linux.' >&2
    exit 1
  fi
  require_pinned_omarchy=1
fi

if [[ "$require_pinned_omarchy" != 1 ]]; then
  if [[ -n "${OMARCHY_QML_COMMONS_DIR:-}" ]]; then
    commons_dir="$OMARCHY_QML_COMMONS_DIR"
  elif [[ -n "${OMARCHY_PATH:-}" && -d "$OMARCHY_PATH/shell/Commons" ]]; then
    commons_dir="$OMARCHY_PATH/shell/Commons"
  elif [[ -d /usr/share/omarchy/shell/Commons ]]; then
    commons_dir=/usr/share/omarchy/shell/Commons
  fi
fi

if [[ -z "$commons_dir" ]]; then
  command -v git >/dev/null || {
    echo 'Git is required to load Omarchy QML type information.' >&2
    exit 1
  }

  cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/lazydocker-host-picker"
  omarchy_checkout="$cache_root/omarchy-${omarchy_commit:0:7}"
  mkdir -p "$cache_root"

  if [[ ! -d "$omarchy_checkout/.git" ]]; then
    if [[ -e "$omarchy_checkout" ]]; then
      echo "Omarchy cache path exists but is not a Git checkout: $omarchy_checkout" >&2
      exit 1
    fi

    git init -q "$omarchy_checkout"
    git -C "$omarchy_checkout" remote add origin https://github.com/omacom/omarchy.git
    git -C "$omarchy_checkout" fetch --depth 1 origin "$omarchy_commit"
    git -C "$omarchy_checkout" checkout --detach FETCH_HEAD
  fi

  actual_commit="$(git -C "$omarchy_checkout" rev-parse HEAD)"
  if [[ "$actual_commit" != "$omarchy_commit" ]]; then
    echo "Expected Omarchy commit $omarchy_commit, got $actual_commit" >&2
    echo "Update the pinned commit in scripts/check-qml-quality.sh after reviewing the new type context." >&2
    exit 1
  fi

  commons_dir="$omarchy_checkout/shell/Commons"
fi

if [[ ! -d "$commons_dir" ]]; then
  echo "Omarchy QML Commons module not found: $commons_dir" >&2
  exit 1
fi

import_root="$(mktemp -d "${TMPDIR:-/tmp}/lazydocker-picker-qml-imports.XXXXXX")"
trap 'rm -rf "$import_root"' EXIT
mkdir -p "$import_root/qs"
ln -s "$commons_dir" "$import_root/qs/Commons"

export QML_IMPORT_PATHS="$import_root${QML_IMPORT_PATHS:+:$QML_IMPORT_PATHS}"
"$repo_dir/scripts/check-qml.sh"

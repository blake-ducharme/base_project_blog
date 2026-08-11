#!/usr/bin/env bash
set -euo pipefail

# Sync Vite build output to DreamHost ONLY.
# Application code is deployed via git pull on the server — not this script.
#
# Usage:
#   ./rsync.sh              # npm ci + npm run build, then rsync public/build/
#   ./rsync.sh --dry-run
#   ./rsync.sh --no-build
#   SKIP_BUILD=1 ./rsync.sh
#
# Remotes (first match wins):
#   1) exported env: REMOTE_USER / REMOTE_HOST / REMOTE_PATH
#   2) values in local .env (same keys)
#   3) placeholders (script warns)
#
# REMOTE_PATH = site root on Dreamhost (same as the git checkout).
# This script syncs only:  local public/build/  →  remote $REMOTE_PATH/public/build/

ROOT="$(cd "$(dirname "$0")" && pwd)"

env_get() {
  local key="$1"
  local file="${ROOT}/.env"
  [[ -f "$file" ]] || return 0
  local line
  line="$(grep -E "^${key}=" "$file" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 0
  local value="${line#*=}"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s' "$value"
}

if [[ -z "${REMOTE_USER:-}" ]]; then
  REMOTE_USER="$(env_get REMOTE_USER)"
fi
if [[ -z "${REMOTE_HOST:-}" ]]; then
  REMOTE_HOST="$(env_get REMOTE_HOST)"
fi
if [[ -z "${REMOTE_PATH:-}" ]]; then
  REMOTE_PATH="$(env_get REMOTE_PATH)"
fi

REMOTE_USER="${REMOTE_USER:-your-dreamhost-user}"
REMOTE_HOST="${REMOTE_HOST:-your-domain.com}"
REMOTE_PATH="${REMOTE_PATH:-/home/your-dreamhost-user/your-site}"
REMOTE_BUILD="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/public/build/"

DRY_RUN=0
DO_BUILD=1

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n)
      DRY_RUN=1
      ;;
    --no-build)
      DO_BUILD=0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: $0 [--dry-run] [--no-build]" >&2
      exit 1
      ;;
  esac
done

if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
  DO_BUILD=0
fi

if [[ "$REMOTE_USER" == "your-dreamhost-user" || "$REMOTE_HOST" == "your-domain.com" ]]; then
  echo "WARNING: Using placeholder REMOTE_* values." >&2
  echo "Set REMOTE_USER, REMOTE_HOST, and REMOTE_PATH in .env (or export them) before a real deploy." >&2
  echo "" >&2
fi

cd "$ROOT"

if [[ "$DO_BUILD" -eq 1 ]]; then
  echo "==> Building frontend assets (npm)…"
  npm ci
  npm run build
fi

if [[ ! -d "${ROOT}/public/build" ]]; then
  echo "ERROR: ${ROOT}/public/build does not exist. Run a build first (omit --no-build)." >&2
  exit 1
fi

RSYNC_OPTS=(-avz --delete --human-readable)
if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_OPTS+=(--dry-run)
fi

echo "==> Rsync Vite build → ${REMOTE_BUILD}"
echo "    (app code is NOT synced — use git pull on Dreamhost)"
rsync "${RSYNC_OPTS[@]}" \
  "${ROOT}/public/build/" \
  "${REMOTE_BUILD}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "==> Dry run complete (no files changed)."
  exit 0
fi

echo "==> Frontend assets synced."
echo "App code / PHP deps on Dreamhost (when needed) — use PHP 8.4 CLI (not bare php):"
echo "  cd ${REMOTE_PATH}"
echo "  git pull"
echo "  /usr/local/php84/bin/php composer.phar install --no-dev --optimize-autoloader"
echo "  /usr/local/php84/bin/php artisan migrate --force"
echo "  /usr/local/php84/bin/php artisan storage:link"
echo "  /usr/local/php84/bin/php artisan config:cache"
echo "  /usr/local/php84/bin/php artisan route:cache"
echo "  /usr/local/php84/bin/php artisan view:cache"
echo "(Remote .env is never touched by this script. Panel domain PHP should also be 8.4.)"

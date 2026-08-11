#!/usr/bin/env bash
set -euo pipefail

# Deploy this site to DreamHost via rsync.
# Build frontend assets locally, then sync. On the server use composer.phar
# (this script never installs Composer deps remotely and never overwrites .env).
#
# Usage:
#   ./rsync.sh              # deploy
#   ./rsync.sh --dry-run    # preview changes
#   ./rsync.sh --no-build
#   SKIP_BUILD=1 ./rsync.sh
#
# Remotes (first match wins):
#   1) already-exported env: REMOTE_USER / REMOTE_HOST / REMOTE_PATH
#   2) values in local .env (same keys)
#   3) placeholders (script warns)

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Read KEY from .env without sourcing the whole file (avoids breaking on special chars).
env_get() {
  local key="$1"
  local file="${ROOT}/.env"
  [[ -f "$file" ]] || return 0
  local line
  line="$(grep -E "^${key}=" "$file" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 0
  local value="${line#*=}"
  # Strip optional surrounding quotes
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
REMOTE="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"

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
  echo "==> Building frontend assets…"
  npm ci
  npm run build
fi

RSYNC_OPTS=(-avz --delete --human-readable)
if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_OPTS+=(--dry-run)
fi

echo "==> Rsync to ${REMOTE}"
rsync "${RSYNC_OPTS[@]}" \
  --exclude '.git/' \
  --exclude '.gitignore' \
  --exclude '.env' \
  --exclude '.env.*' \
  --exclude '.DS_Store' \
  --exclude 'node_modules/' \
  --exclude 'vendor/' \
  --exclude 'Homestead.json' \
  --exclude 'Homestead.yaml' \
  --exclude 'auth.json' \
  --exclude 'phpunit.xml' \
  --exclude 'tests/' \
  --exclude 'storage/logs/*' \
  --exclude 'storage/framework/cache/*' \
  --exclude 'storage/framework/sessions/*' \
  --exclude 'storage/framework/views/*' \
  --exclude 'storage/pail/' \
  --exclude 'public/hot' \
  --exclude 'public/storage' \
  --exclude '.phpunit.result.cache' \
  --exclude '.phpunit.cache/' \
  --exclude '.idea/' \
  --exclude '.vscode/' \
  --exclude '.fleet/' \
  --exclude '.nova/' \
  --exclude '.zed/' \
  --exclude 'rsync.sh' \
  --exclude 'bin/setup.sh' \
  --exclude 'bin/ui.sh' \
  --exclude 'bin/dbngin.sh' \
  "$ROOT/" \
  "$REMOTE/"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "==> Dry run complete (no files changed)."
  exit 0
fi

echo "==> Deployed."
echo "On the Dreamhost server you may still need:"
echo "  cd ${REMOTE_PATH}"
echo "  php composer.phar install --no-dev --optimize-autoloader"
echo "  php artisan migrate --force"
echo "  php artisan storage:link"
echo "  php artisan config:cache && php artisan route:cache && php artisan view:cache"
echo "(Keep the remote .env in place — this script never overwrites it.)"
echo "Enable Gumlet in production .env when ready (GUMLET_ENABLED=true)."

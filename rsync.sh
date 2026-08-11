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
# Per-site remotes (override defaults):
#   REMOTE_USER=myuser REMOTE_HOST=example.com REMOTE_PATH=/home/myuser/site ./rsync.sh

ROOT="$(cd "$(dirname "$0")" && pwd)"
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
  echo "Set REMOTE_USER, REMOTE_HOST, and REMOTE_PATH for this site before a real deploy." >&2
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

#!/usr/bin/env bash
set -euo pipefail

# Local bootstrap for this Laravel + Twill blog starter (Herd + DBngin).
# Usage:
#   ./bin/setup.sh
#   ./bin/setup.sh --no-admin
#   ./bin/setup.sh --no-seed

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE_NAME="$(basename "$ROOT")"
APP_URL="http://${SITE_NAME}.test"

DO_SEED=1
DO_ADMIN=1

for arg in "$@"; do
  case "$arg" in
    --no-seed)
      DO_SEED=0
      ;;
    --no-admin)
      DO_ADMIN=0
      ;;
    -h|--help)
      echo "Usage: $0 [--no-seed] [--no-admin]"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: $0 [--no-seed] [--no-admin]" >&2
      exit 1
      ;;
  esac
done

cd "$ROOT"

echo "==> Site folder: ${SITE_NAME}"
echo "==> Herd URL:    ${APP_URL}"
echo ""
echo "IMPORTANT: Use DBngin MySQL on 127.0.0.1:3306 (root / empty password)."
echo "Stop other local MySQL instances (e.g. Herd MySQL) so they do not steal that port."
echo ""

if ! command -v mysql >/dev/null 2>&1; then
  echo "ERROR: mysql client not found on PATH. Install mysql-client or add DBngin's client to PATH." >&2
  exit 1
fi

if ! mysql -h 127.0.0.1 -P 3306 -u root -e "SELECT 1" >/dev/null 2>&1; then
  echo "ERROR: Cannot connect to MySQL at 127.0.0.1:3306 as root (empty password)." >&2
  echo "Start your DBngin MySQL instance and retry." >&2
  exit 1
fi

echo "==> Composer install"
composer install

if [[ ! -f .env ]]; then
  echo "==> Copying .env.example → .env"
  cp .env.example .env
fi

# Stamp folder-derived values (portable sed for macOS/BSD).
set_env() {
  local key="$1"
  local value="$2"
  # Escape sed replacement specials: \ & |
  local escaped="${value//\\/\\\\}"
  escaped="${escaped//&/\\&}"
  escaped="${escaped//|/\\|}"
  if grep -q "^${key}=" .env; then
    sed -i.bak "s|^${key}=.*|${key}=${escaped}|" .env
  else
    printf '%s=%s\n' "$key" "$value" >> .env
  fi
}

set_env "APP_NAME" "\"${SITE_NAME}\""
set_env "APP_URL" "${APP_URL}"
set_env "TWILL_ADMIN_APP_URL" "${APP_URL}"
set_env "DB_DATABASE" "${SITE_NAME}"
set_env "DB_HOST" "127.0.0.1"
set_env "DB_PORT" "3306"
set_env "DB_USERNAME" "root"
set_env "DB_PASSWORD" ""
set_env "GUMLET_ENABLED" "false"

rm -f .env.bak

echo "==> Creating database \`${SITE_NAME}\` if needed"
mysql -h 127.0.0.1 -P 3306 -u root -e "CREATE DATABASE IF NOT EXISTS \`${SITE_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

if ! grep -q '^APP_KEY=base64:' .env; then
  echo "==> Generating APP_KEY"
  php artisan key:generate
fi

echo "==> Migrate"
php artisan migrate --force

echo "==> npm install + build"
npm install
npm run build

echo "==> storage:link"
php artisan storage:link || true

if [[ "$DO_SEED" -eq 1 ]]; then
  echo "==> Seed homepage"
  php artisan db:seed --force
fi

if [[ "$DO_ADMIN" -eq 1 ]]; then
  if [[ -t 0 ]]; then
    echo ""
    read -r -p "Create a Twill superadmin now? [Y/n] " reply
    reply="${reply:-Y}"
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      php artisan twill:superadmin
    else
      echo "Skipped. Later: php artisan twill:superadmin"
    fi
  else
    echo "==> Non-interactive shell: skip twill:superadmin (run manually later)"
  fi
fi

echo ""
echo "==> Setup complete."
echo "    Site:  ${APP_URL}"
echo "    Admin: ${APP_URL}/admin"
echo "    Gumlet is off locally (GUMLET_ENABLED=false)."

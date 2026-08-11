#!/usr/bin/env bash
set -euo pipefail

# Local bootstrap for this Laravel + Twill blog starter (Herd + DBngin).
# All PHP/Composer calls go through Herd (`herd php` / `herd composer`).
#
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

# shellcheck source=dbngin.sh
source "$(cd "$(dirname "$0")" && pwd)/dbngin.sh"

herd_require() {
  if ! command -v herd >/dev/null 2>&1; then
    echo "ERROR: Laravel Herd CLI not found on PATH." >&2
    echo "Install Herd and ensure its bin dir is on PATH, then retry." >&2
    exit 1
  fi
  echo "==> Using Herd PHP: $(herd php -r 'echo PHP_VERSION;')"
  echo "    ($(command -v herd))"
}

# Run Artisan via Herd's PHP (never bare `php`).
herd_artisan() {
  herd php artisan "$@"
}

echo "==> Site folder: ${SITE_NAME}"
echo "==> Herd URL:    ${APP_URL}"
echo ""

herd_require

echo ""
echo "DBngin: stop all MySQL services, ensure a service named \"${SITE_NAME}\" exists,"
echo "create it if needed, then start only that service on 127.0.0.1:3306 (root / empty password)."
echo "Also stop any non-DBngin MySQL that might bind 3306 (e.g. Herd MySQL)."
echo ""

if ! command -v mysql >/dev/null 2>&1; then
  echo "ERROR: mysql client not found on PATH. Install mysql-client or add DBngin's client to PATH." >&2
  exit 1
fi

dbngin_prepare_for_site "$SITE_NAME"

echo "==> herd composer install"
herd composer install

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
  echo "==> Generating APP_KEY (herd php artisan)"
  herd_artisan key:generate
fi

echo "==> Migrate (herd php artisan)"
herd_artisan migrate --force

echo "==> npm install + build"
npm install
npm run build

echo "==> storage:link (herd php artisan)"
herd_artisan storage:link || true

if [[ "$DO_SEED" -eq 1 ]]; then
  echo "==> Seed homepage (herd php artisan)"
  herd_artisan db:seed --force
fi

echo "==> Register site with Herd (link)"
# Sites under BD_PROJECTS are not in Herd's parked paths (~/Herd only).
# Link matches how bd_shop / other Developer sites are registered.
if herd links 2>/dev/null | grep -q "${SITE_NAME}"; then
  echo "    Already linked: ${SITE_NAME}"
else
  herd link "${SITE_NAME}"
fi

if [[ "$DO_ADMIN" -eq 1 ]]; then
  if [[ -t 0 ]]; then
    echo ""
    read -r -p "Create a Twill superadmin now? [Y/n] " reply
    reply="${reply:-Y}"
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      herd_artisan twill:superadmin
    else
      echo "Skipped. Later: herd php artisan twill:superadmin"
    fi
  else
    echo "==> Non-interactive shell: skip twill:superadmin (run: herd php artisan twill:superadmin)"
  fi
fi

echo ""
echo "==> Setup complete."
echo "    Site:  ${APP_URL}"
echo "    Admin: ${APP_URL}/admin"
echo "    Herd:  linked as ${SITE_NAME} (check Sites / herd links)"
echo "    PHP:   always use \`herd php artisan …\` / \`herd composer …\` for this project"
echo "    Gumlet is off locally (GUMLET_ENABLED=false)."

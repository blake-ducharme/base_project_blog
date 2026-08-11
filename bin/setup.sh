#!/usr/bin/env bash
set -euo pipefail

# Local bootstrap for this Laravel + Twill blog starter (Herd + DBngin).
# All PHP/Composer calls go through Herd (`herd php` / `herd composer`).
#
# Usage:
#   ./bin/setup.sh
#   ./bin/setup.sh --no-admin
#   ./bin/setup.sh --no-seed
#   ./bin/setup.sh --instructions   # reprint reference card only

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_NAME="$(basename "$ROOT")"
APP_URL="http://${SITE_NAME}.test"

# shellcheck source=ui.sh
source "${BIN_DIR}/ui.sh"
# shellcheck source=dbngin.sh
source "${BIN_DIR}/dbngin.sh"

DO_SEED=1
DO_ADMIN=1
INSTRUCTIONS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --no-seed)
      DO_SEED=0
      ;;
    --no-admin)
      DO_ADMIN=0
      ;;
    --instructions|--ref|--reference)
      INSTRUCTIONS_ONLY=1
      ;;
    -h|--help)
      echo "Usage: $0 [--no-seed] [--no-admin] [--instructions]"
      exit 0
      ;;
    *)
      ui_err "Unknown option: $arg"
      echo "Usage: $0 [--no-seed] [--no-admin] [--instructions]" >&2
      exit 1
      ;;
  esac
done

cd "$ROOT"

if [[ "$INSTRUCTIONS_ONLY" -eq 1 ]]; then
  ui_print_site_reference "$SITE_NAME" "$ROOT" "$APP_URL"
  exit 0
fi

herd_require() {
  if ! command -v herd >/dev/null 2>&1; then
    ui_err "Laravel Herd CLI not found on PATH."
    ui_info "Install Herd and ensure its bin dir is on PATH, then retry."
    exit 1
  fi
  ui_step "Using Herd PHP: $(herd php -r 'echo PHP_VERSION;')"
  ui_info "$(command -v herd)"
}

# Run Artisan via Herd's PHP (never bare `php`).
herd_artisan() {
  herd php artisan "$@"
}

ui_step "Site folder: ${SITE_NAME}"
ui_step "Herd URL:    ${APP_URL}"
echo ""

herd_require

echo ""
ui_warn "DBngin will stop all MySQL services, ensure \"${SITE_NAME}\" exists, then start only that service."
ui_info "Also stop any non-DBngin MySQL that might bind 3306 (e.g. Herd MySQL)."
echo ""

if ! command -v mysql >/dev/null 2>&1; then
  ui_err "mysql client not found on PATH. Install mysql-client or add DBngin's client to PATH."
  exit 1
fi

dbngin_prepare_for_site "$SITE_NAME"

ui_step "Running: herd composer install"
ui_cmd "herd composer install"
herd composer install

if [[ ! -f .env ]]; then
  ui_step "Copying .env.example → .env"
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

ui_step "Creating database \`${SITE_NAME}\` if needed"
mysql -h 127.0.0.1 -P 3306 -u root -e "CREATE DATABASE IF NOT EXISTS \`${SITE_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

if ! grep -q '^APP_KEY=base64:' .env; then
  ui_step "Generating APP_KEY"
  ui_cmd "herd php artisan key:generate"
  herd_artisan key:generate
fi

ui_step "Migrate"
ui_cmd "herd php artisan migrate --force"
herd_artisan migrate --force

ui_step "npm install + build"
ui_cmd "npm install && npm run build"
npm install
npm run build

ui_step "storage:link"
ui_cmd "herd php artisan storage:link"
herd_artisan storage:link || true

if [[ "$DO_SEED" -eq 1 ]]; then
  ui_step "Seed homepage"
  ui_cmd "herd php artisan db:seed --force"
  herd_artisan db:seed --force
fi

ui_step "Register site with Herd (link)"
# Sites under BD_PROJECTS are not in Herd's parked paths (~/Herd only).
if herd links 2>/dev/null | grep -q "${SITE_NAME}"; then
  ui_info "Already linked: ${SITE_NAME}"
else
  ui_cmd "herd link ${SITE_NAME}"
  herd link "${SITE_NAME}"
fi

if [[ "$DO_ADMIN" -eq 1 ]]; then
  if [[ -t 0 ]]; then
    echo ""
    read -r -p "Create a Twill superadmin now? [Y/n] " reply
    reply="${reply:-Y}"
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      ui_cmd "herd php artisan twill:superadmin"
      herd_artisan twill:superadmin
    else
      ui_info "Skipped. Later:"
      ui_cmd "herd php artisan twill:superadmin"
    fi
  else
    ui_step "Non-interactive shell: skip twill:superadmin"
    ui_cmd "herd php artisan twill:superadmin"
  fi
fi

ui_print_site_reference "$SITE_NAME" "$ROOT" "$APP_URL"

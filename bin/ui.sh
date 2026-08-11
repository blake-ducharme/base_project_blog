#!/usr/bin/env bash
# Terminal UI helpers for setup / launcher scripts.
# Distinguish labels (cyan) from copy-paste commands (yellow).
# Disable with NO_COLOR=1 or when stdout is not a TTY.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  UI_RESET=$'\033[0m'
  UI_BOLD=$'\033[1m'
  UI_DIM=$'\033[2m'
  UI_RED=$'\033[31m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
  UI_CYAN=$'\033[36m'
else
  UI_RESET=''
  UI_BOLD=''
  UI_DIM=''
  UI_RED=''
  UI_GREEN=''
  UI_YELLOW=''
  UI_CYAN=''
fi

ui_step() {
  # Section / status label
  printf '%s==>%s %s%s%s\n' "$UI_CYAN$UI_BOLD" "$UI_RESET" "$UI_BOLD" "$*" "$UI_RESET"
}

ui_ok() {
  printf '%s==>%s %s%s%s\n' "$UI_GREEN$UI_BOLD" "$UI_RESET" "$UI_GREEN" "$*" "$UI_RESET"
}

ui_warn() {
  printf '%s==>%s %s%s%s\n' "$UI_YELLOW$UI_BOLD" "$UI_RESET" "$UI_YELLOW" "$*" "$UI_RESET" >&2
}

ui_err() {
  printf '%sERROR:%s %s\n' "$UI_RED$UI_BOLD" "$UI_RESET" "$*" >&2
}

ui_info() {
  # Secondary information under a step
  printf '    %s%s%s\n' "$UI_DIM" "$*" "$UI_RESET"
}

ui_label() {
  # "Key: value" row — key dim, value bold
  local key="$1"
  local value="$2"
  printf '    %s%-8s%s %s%s%s\n' "$UI_DIM" "$key" "$UI_RESET" "$UI_BOLD" "$value" "$UI_RESET"
}

ui_cmd() {
  # Copy-pasteable command
  printf '    %s%s%s\n' "$UI_YELLOW" "$*" "$UI_RESET"
}

# Shared end-of-setup / re-run reference card.
# Args: site_name, project_path, app_url
ui_print_site_reference() {
  local site_name="$1"
  local project_path="$2"
  local app_url="$3"

  echo ""
  ui_ok "Setup complete."
  ui_label "Site:" "$app_url"
  ui_label "Admin:" "${app_url}/admin"
  ui_label "Herd:" "linked as ${site_name} (check Sites / herd links)"
  ui_label "Path:" "$project_path"
  ui_info "Gumlet is off locally (GUMLET_ENABLED=false)."
  echo ""
  ui_step "Handy commands (Herd PHP)"
  ui_cmd "cd ${project_path}"
  ui_cmd "herd php artisan twill:superadmin"
  ui_cmd "herd php artisan migrate"
  ui_cmd "herd php artisan db:seed --class=HomePageSeeder"
  ui_cmd "herd composer install"
  ui_cmd "npm run dev"
  echo ""
}

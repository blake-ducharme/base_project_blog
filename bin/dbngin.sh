#!/usr/bin/env bash
# DBngin helpers for setup.sh — stop/create/start a per-project MySQL service.
# DBngin has no official CLI; we drive its launchd plists + DBEngines.plist.
#
# Usage (sourced): source bin/dbngin.sh
#   dbngin_prepare_for_site "my-site-folder-name"

DBNGIN_SUPPORT="${HOME}/Library/Application Support/com.tinyapp.DBngin"
DBNGIN_ENGINES_PLIST="${DBNGIN_SUPPORT}/Data/DBEngines.plist"
DBNGIN_MYSQL_ROOT="${DBNGIN_SUPPORT}/Engines/mysql"
DBNGIN_SHARED_MYSQL="/Users/Shared/DBngin/mysql"

dbngin_gui_domain() {
  echo "gui/$(id -u)"
}

dbngin_require() {
  if [[ ! -f "$DBNGIN_ENGINES_PLIST" ]]; then
    echo "ERROR: DBngin not found (missing ${DBNGIN_ENGINES_PLIST})." >&2
    echo "Install DBngin from https://dbngin.com and create at least one MySQL service once." >&2
    exit 1
  fi
  if [[ ! -d "$DBNGIN_SHARED_MYSQL" ]]; then
    echo "ERROR: DBngin MySQL binaries missing under ${DBNGIN_SHARED_MYSQL}." >&2
    exit 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required to manage DBngin plists." >&2
    exit 1
  fi
}

# Print preferred MySQL basedir (latest version dir under Shared).
dbngin_default_basedir() {
  python3 - <<'PY'
import os
from pathlib import Path
root = Path("/Users/Shared/DBngin/mysql")
dirs = sorted([p for p in root.iterdir() if p.is_dir()], key=lambda p: p.name, reverse=True)
if not dirs:
    raise SystemExit("no mysql binaries")
print(dirs[0])
PY
}

dbngin_stop_all() {
  local domain label
  domain="$(dbngin_gui_domain)"
  echo "==> Stopping all DBngin MySQL services…" >&2

  # Boot out any loaded DBngin mysqld agents.
  while IFS= read -r label; do
    [[ -z "$label" ]] && continue
    echo "    bootout ${label}" >&2
    launchctl bootout "${domain}/${label}" 2>/dev/null || true
  done < <(launchctl print "$domain" 2>/dev/null | sed -n 's/.*"\(com\.tinyapp\.DBngin\.mysqld-[^"]*\)".*/\1/p' | sort -u)

  # Also try every known engine plist path (covers agents not listed above).
  if [[ -d "$DBNGIN_MYSQL_ROOT" ]]; then
    local plist
    for plist in "$DBNGIN_MYSQL_ROOT"/*/com.tinyapp.DBngin.mysqld-*.plist; do
      [[ -f "$plist" ]] || continue
      label="$(basename "$plist" .plist)"
      launchctl bootout "${domain}/${label}" 2>/dev/null || true
    done
  fi

  # Mark all stopped in DBngin registry (UI sync).
  python3 - <<'PY'
import plistlib
from pathlib import Path
path = Path.home() / "Library/Application Support/com.tinyapp.DBngin/Data/DBEngines.plist"
engines = plistlib.loads(path.read_bytes())
changed = False
for e in engines:
    if e.get("Type") == "MySQL" and e.get("Status") != "stopped":
        e["Status"] = "stopped"
        changed = True
if changed:
    path.write_bytes(plistlib.dumps(engines, fmt=plistlib.FMT_XML))
PY

  # Wait for port 3306 to free.
  local i
  for i in {1..30}; do
    if ! nc -z 127.0.0.1 3306 2>/dev/null; then
      rm -f /tmp/mysql_3306.sock /tmp/mysqlx.sock 2>/dev/null || true
      return 0
    fi
    sleep 0.5
  done
  echo "ERROR: Port 3306 still in use after stopping DBngin services." >&2
  lsof -nP -iTCP:3306 -sTCP:LISTEN >&2 || true
  exit 1
}

# Echo UUID of engine named $1, or empty.
dbngin_find_uuid_by_name() {
  local name="$1"
  python3 - "$name" <<'PY'
import plistlib, sys
from pathlib import Path
name = sys.argv[1]
path = Path.home() / "Library/Application Support/com.tinyapp.DBngin/Data/DBEngines.plist"
engines = plistlib.loads(path.read_bytes())
for e in engines:
    if e.get("Type") == "MySQL" and e.get("Name") == name:
        print(e["ID"])
        break
PY
}

dbngin_write_launchd_plist() {
  local uuid="$1"
  local basedir="$2"
  local datadir="$3"
  local plist="${datadir}/com.tinyapp.DBngin.mysqld-${uuid}.plist"
  local label="com.tinyapp.DBngin.mysqld-${uuid}"

  cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Disabled</key>
	<false/>
	<key>ExitTimeOut</key>
	<integer>600</integer>
	<key>GroupName</key>
	<string>_mysql</string>
	<key>KeepAlive</key>
	<true/>
	<key>Label</key>
	<string>${label}</string>
	<key>LaunchOnlyOnce</key>
	<false/>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>Program</key>
	<string>${basedir}/bin/mysqld</string>
	<key>ProgramArguments</key>
	<array>
		<string>${basedir}/bin/mysqld</string>
		<string>--disable-log-bin</string>
		<string>--socket=/tmp/mysql_3306.sock</string>
		<string>--user=_mysql</string>
		<string>--port=3306</string>
		<string>--basedir=${basedir}</string>
		<string>--datadir=${datadir}</string>
		<string>--plugin-dir=${basedir}/lib/plugin</string>
		<string>--log-error=${datadir}/mysqld.local.err</string>
		<string>--pid-file=${datadir}/mysql.pid</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>SessionCreate</key>
	<true/>
	<key>UserName</key>
	<string>_mysql</string>
	<key>WorkingDirectory</key>
	<string>${datadir}</string>
</dict>
</plist>
EOF
  echo "$plist"
}

dbngin_create_service() {
  local name="$1"
  local uuid basedir datadir version source
  uuid="$(uuidgen)"
  basedir="$(dbngin_default_basedir)"
  datadir="${DBNGIN_MYSQL_ROOT}/${uuid}"
  version="$(basename "$basedir")"
  source="https://files.dbngin.com/binaries/mysql/${version}.zip"

  echo "==> Creating DBngin MySQL service \"${name}\" (${uuid})" >&2
  mkdir -p "$datadir"

  echo "    Initializing empty datadir…" >&2
  "${basedir}/bin/mysqld" \
    --initialize-insecure \
    --basedir="$basedir" \
    --datadir="$datadir" \
    --user="$(whoami)" \
    >/dev/null

  dbngin_write_launchd_plist "$uuid" "$basedir" "$datadir" >/dev/null

  python3 - "$name" "$uuid" "$basedir" "$datadir" "$version" "$source" <<'PY'
import plistlib, sys
from pathlib import Path
name, uuid, basedir, datadir, version, source = sys.argv[1:7]
path = Path.home() / "Library/Application Support/com.tinyapp.DBngin/Data/DBEngines.plist"
engines = plistlib.loads(path.read_bytes())
engines.append({
    "AutoStartup": False,
    "Binaries": basedir,
    "ConfigPath": "Select a file...",
    "DBPath": datadir,
    "DisableBinLog": True,
    "ID": uuid,
    "LogPath": datadir,
    "Name": name,
    "Pid": datadir,
    "Port": "3306",
    "SocketPath": "",
    "Source": source,
    "Status": "stopped",
    "Type": "MySQL",
    "Version": version,
})
path.write_bytes(plistlib.dumps(engines, fmt=plistlib.FMT_XML))
print(uuid)
PY
}

dbngin_start_uuid() {
  local uuid="$1"
  local domain label plist datadir
  domain="$(dbngin_gui_domain)"
  label="com.tinyapp.DBngin.mysqld-${uuid}"
  datadir="${DBNGIN_MYSQL_ROOT}/${uuid}"
  plist="${datadir}/com.tinyapp.DBngin.mysqld-${uuid}.plist"

  if [[ ! -f "$plist" ]]; then
    echo "ERROR: Missing launchd plist: ${plist}" >&2
    exit 1
  fi

  echo "==> Starting DBngin service ${uuid}" >&2
  # Ensure not already loaded.
  launchctl bootout "${domain}/${label}" 2>/dev/null || true
  launchctl bootstrap "$domain" "$plist"
  launchctl enable "${domain}/${label}" 2>/dev/null || true
  launchctl kickstart -k "${domain}/${label}" 2>/dev/null || true

  python3 - "$uuid" <<'PY'
import plistlib, sys
from pathlib import Path
uuid = sys.argv[1]
path = Path.home() / "Library/Application Support/com.tinyapp.DBngin/Data/DBEngines.plist"
engines = plistlib.loads(path.read_bytes())
for e in engines:
    if e.get("ID") == uuid:
        e["Status"] = "running"
    elif e.get("Type") == "MySQL":
        e["Status"] = "stopped"
path.write_bytes(plistlib.dumps(engines, fmt=plistlib.FMT_XML))
PY
}

dbngin_wait_mysql() {
  local i
  echo "==> Waiting for MySQL on 127.0.0.1:3306…" >&2
  for i in {1..60}; do
    if mysql -h 127.0.0.1 -P 3306 -u root -e "SELECT 1" >/dev/null 2>&1; then
      echo "    MySQL is ready." >&2
      return 0
    fi
    sleep 0.5
  done
  echo "ERROR: MySQL did not become ready on 127.0.0.1:3306." >&2
  echo "Check DBngin UI and the service error log under:" >&2
  echo "  ${DBNGIN_MYSQL_ROOT}/<uuid>/mysqld.local.err" >&2
  exit 1
}

# Stop all services; create site-named service if missing; start only that service.
dbngin_prepare_for_site() {
  local site_name="$1"
  local uuid

  dbngin_require
  dbngin_stop_all

  uuid="$(dbngin_find_uuid_by_name "$site_name")"
  if [[ -z "$uuid" ]]; then
    uuid="$(dbngin_create_service "$site_name")"
  else
    echo "==> Reusing DBngin MySQL service \"${site_name}\" (${uuid})" >&2
  fi

  dbngin_start_uuid "$uuid"
  dbngin_wait_mysql
}

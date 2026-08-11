# BaseProject (blog starter)

Laravel + Twill CMS starter for local development with **Herd** and **DBngin**. No ecommerce / Stripe — that lives in the parallel shop starter.

## Stack

- PHP 8.4 locally via **Laravel Herd** (match Dreamhost to 8.4 — see deploy section)
- Twill CMS 3.5
- MySQL (DBngin locally)
- Tailwind CSS v4, Alpine.js, Barba.js
- Optional Gumlet image CDN (off locally)

## PHP / Composer (Herd only)

Local CLI must use Herd — do **not** rely on bare `php` / Homebrew PHP:

```bash
herd php -v
herd php artisan …
herd composer …
```

`bin/setup.sh` and `new-twill-blog` already call `herd php` and `herd composer`.

## Herd without the UI (CLI)

Herd does **not** start/stop individual sites like Apache vhosts. While Herd’s services are running, every **linked** (or parked) folder is already available at `http://{folder}.test`.

### 1. Start / stop the Herd stack (nginx + PHP-FPM)

```bash
herd start              # start Herd services
herd stop               # stop Herd services
herd restart            # restart all
herd restart nginx      # optional: one service
herd restart php
```

### 2. Register / remove a site (hosts)

Sites under `BD_PROJECTS` are **not** in Herd’s parked path (`~/Herd/` only). They must be **linked** (same pattern as `bd_shop`). `bin/setup.sh` runs `herd link` for you.

```bash
cd ~/Developer/BD_PROJECTS/my-client-blog
herd link my-client-blog      # add → http://my-client-blog.test
herd unlink my-client-blog    # remove from Herd

herd sites                    # list all sites
herd links                    # linked sites only
herd parked                   # sites under parked paths (~/Herd)
herd open my-client-blog      # open in browser
```

If a site is missing from the Herd UI / Sites list after setup:

```bash
cd ~/Developer/BD_PROJECTS/muratrecevik
herd link muratrecevik
herd links   # confirm
```

### 3. MySQL is DBngin (not Herd)

Local MySQL is managed by **DBngin**, separate from Herd start/stop. See [DBngin](#dbngin) below. Do not rely on Herd’s MySQL for this starter.

## New site (recommended)

From `~/Developer/BD_PROJECTS`:

```bash
./new-twill-blog my-client-blog
# optional: GH_OWNER=blake-ducharme GH_VISIBILITY=private ./new-twill-blog my-client-blog
# local only (no GitHub): ./new-twill-blog my-client-blog --skip-github
```

This:

1. Clones the [base_project_blog](https://github.com/blake-ducharme/base_project_blog) **starter**
2. Creates a **new GitHub repo** `blake-ducharme/my-client-blog` (via `gh`), renames the starter remote to `starter`, sets `origin` to the new repo, and pushes
3. Runs `bin/setup.sh` (Herd PHP, DBngin, `herd link`)

The **folder name** becomes:

- Herd URL: `http://my-client-blog.test`
- DBngin MySQL service + Laravel schema: `my-client-blog`
- GitHub repo name (default owner `blake-ducharme`)

Requires [GitHub CLI](https://cli.github.com/) (`gh auth login`).

### DBngin

`bin/setup.sh` manages DBngin for you (DBngin has no official CLI; the script drives its launchd services):

1. **Stops all** DBngin MySQL services (so nothing else owns `3306`)
2. **Ensures** a MySQL service named like the project folder exists (creates an empty one if missing)
3. **Starts only that** service
4. Creates the Laravel schema (`DB_DATABASE` = folder name) if needed, then migrates

Defaults: `127.0.0.1:3306`, user `root`, empty password.

Do **not** manually start `PeterDB` / `bd_shop` / etc. for a new site — let setup create/start the project-named service so migrations never land on another project’s server.

Also stop any **non-DBngin** MySQL that might bind `3306` (e.g. Herd MySQL).

You can still Start/Stop services in the DBngin app if needed; only **one** MySQL on port `3306` should run at a time.

## Existing clone / manual setup

```bash
cd /path/to/your-site-folder   # folder name = Herd host
./bin/setup.sh
# ./bin/setup.sh --no-admin
# ./bin/setup.sh --no-seed
# ./bin/setup.sh --instructions   # reprint URLs + Herd commands
```

If you run `./new-twill-blog existing-folder` again, it does **not** re-clone; it reprints the same reference card.

Or step by step (**Herd PHP**):

```bash
herd composer install
cp .env.example .env
# edit APP_URL / DB_* or let setup.sh stamp them from the folder name
herd php artisan key:generate
herd php artisan migrate
npm install
npm run build
herd php artisan storage:link
herd php artisan db:seed
herd php artisan twill:superadmin
herd link "$(basename "$PWD")"
```

Admin is at `/admin`.

## Database seeding

`HomePageSeeder` is idempotent — re-running reuses the existing `home` page and refreshes Homepage settings.

```bash
herd php artisan db:seed
# or
herd php artisan db:seed --class=HomePageSeeder
```

## Gumlet (image CDN)

Front-end Twill media can be delivered through Gumlet. CMS thumbnails always use the origin host. Keep Gumlet **disabled** locally.

**Local (default in `.env.example`):**

```env
GUMLET_ENABLED=false
GUMLET_HOSTNAME=https://your-subdomain.gumlet.io
GUMLET_ORIGIN_BASE_URL=https://your-production-host.com
GUMLET_URL_MODE=path
# MEDIA_URL=https://your-production-host.com/storage
```

**Production:**

```env
GUMLET_ENABLED=true
GUMLET_HOSTNAME=https://your-subdomain.gumlet.io
GUMLET_ORIGIN_BASE_URL=https://your-production-host.com
GUMLET_URL_MODE=path
```

Create a Gumlet **Web Folders** source whose Base URL matches `GUMLET_ORIGIN_BASE_URL`. Prefer `path` mode so `/storage/…` maps 1:1 onto the Gumlet host. After changing env on the server: `/usr/local/php84/bin/php artisan config:cache`.

## Deploy to Dreamhost

**Split deploy model:**

| What | How |
|------|-----|
| App code (PHP, views, config, …) | Push to the site’s **GitHub** repo → on Dreamhost **`git pull`** |
| PHP dependencies | On Dreamhost: **`/usr/local/php84/bin/php composer.phar install …`** (PHAR on server, not in this repo) |
| Frontend build (`public/build/`) | Build on your Mac → **`./rsync.sh`** (assets only; `public/build` is gitignored) |

Do **not** rsync the whole project. Dreamhost’s checkout is the git repo; rsync only refreshes Vite output.

### PHP version (Herd 8.4 ↔ Dreamhost 8.4)

Local Herd uses **PHP 8.4**, so `composer.lock` often requires packages with `php >=8.4.1`. Production should match.

1. **Panel:** set the domain to **PHP 8.4** (web).
2. **SSH:** do **not** rely on bare `php` — the shell default is often older even when the panel shows 8.3/8.4. Always call **8.4** explicitly:

```bash
/usr/local/php84/bin/php -v
```

Optional — make the shell default to 8.4 (`~/.bash_profile`):

```bash
export PATH=/usr/local/php84/bin:$PATH
# then: source ~/.bash_profile && php -v
```

#### If the panel change to 8.4 fails and reverts

DreamHost runs a quick compatibility check; on failure you see something like **“PHP Change Unsuccessful… reverted”**. Common causes:

- Domain docroot is **not** the Laravel `public/` folder (or the domain folder still has old/WordPress/other PHP)
- Leftover incompatible scripts in the domain directory
- Choosing “Revert to previous PHP version” when the check fails (default)

**Diagnose on SSH** (from the site root, adjust paths):

```bash
# Does 8.4 CLI exist?
/usr/local/php84/bin/php -v

# Boot Laravel on 8.4 — should print the app name, not a fatal error
cd /path/to/site
/usr/local/php84/bin/php artisan --version
```

Also confirm in the panel that the domain points at `…/your-site/public`.

Retry the panel upgrade; if it still reverts, you can force 8.4 via `.htaccess` in **`public/`** (DreamHost docs):

```apache
AddHandler fcgid-script .php
FCGIWrapper "/dh/cgi-system/php84.cgi" .php
```

See: [Change the PHP version of a site](https://help.dreamhost.com/hc/en-us/articles/214895317-Change-the-PHP-version-of-a-site) and [PHP upgrade failure troubleshooting](https://help.dreamhost.com/hc/en-us/articles/360001402163-PHP-upgrade-failure-troubleshooting).

#### Composer: “require a PHP version >= 8.4.1”

That message means **`composer.lock` was built on PHP 8.4**. Installing with 8.2/8.3 CLI will fail (or warn). Fix by either:

- **A (preferred):** run Composer with 8.4 and get the **web** vhost onto 8.4 (panel or `.htaccess` above), or  
- **B (stay on 8.3):** regenerate the lock on your Mac for 8.3, commit, push, then install on the server with `php83`:

```bash
# on Mac (in the site repo)
herd composer config platform.php 8.3.30
herd composer update
git add composer.json composer.lock && git commit -m "Target PHP 8.3 for Dreamhost" && git push

# on Dreamhost
git pull
/usr/local/php83/bin/php composer.phar install --no-dev --optimize-autoloader
```

Do **not** rely on `--ignore-platform-reqs` long-term if the web PHP is still 8.3 — some packages truly need 8.4 at runtime.

### `composer.phar` (server only)

Not committed. Install once on Dreamhost (home or site dir), using PHP 8.4:

```bash
curl -sS https://getcomposer.org/installer | /usr/local/php84/bin/php
# leaves composer.phar in the current directory
```

### Production `.env` (required — never committed / never rsynced)

On Dreamhost, create `.env` in the site root (copy from `.env.example`, then edit). At minimum:

```env
APP_NAME="Your Site"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://dev.recevik.com

APP_KEY=
# generate on the server (see below) — MissingAppKeyException means this is empty

TWILL_ADMIN_APP_URL=https://dev.recevik.com
TWILL_ADMIN_APP_PATH=admin

DB_CONNECTION=mysql
DB_HOST=…
DB_DATABASE=…
DB_USERNAME=…
DB_PASSWORD=…
```

Generate the key **on the server** (do not copy a local key unless you intend to):

```bash
cd /path/to/site
/usr/local/php84/bin/php artisan key:generate
/usr/local/php84/bin/php artisan config:clear
/usr/local/php84/bin/php artisan config:cache
```

`key:generate` writes `APP_KEY=base64:…` into `.env`. If you already ran `config:cache` with an empty key, **`config:clear` then `config:cache` again** after generating.

### 1. Code (GitHub → Dreamhost)

```bash
# on your Mac (Herd PHP 8.4)
cd ~/Developer/BD_PROJECTS/my-client-blog
git push

# on Dreamhost (SSH) — first time:
#   git clone https://github.com/blake-ducharme/my-client-blog.git /path/to/site
#   cp .env.example .env   # then edit production values
#   /usr/local/php84/bin/php artisan key:generate

cd /path/to/site
git pull
/usr/local/php84/bin/php composer.phar install --no-dev --optimize-autoloader
# if APP_KEY is empty in .env:
# /usr/local/php84/bin/php artisan key:generate
/usr/local/php84/bin/php artisan migrate --force
/usr/local/php84/bin/php artisan storage:link
/usr/local/php84/bin/php artisan config:clear
/usr/local/php84/bin/php artisan config:cache
/usr/local/php84/bin/php artisan route:cache
/usr/local/php84/bin/php artisan view:cache
```

### First-time only: Home page seed + Twill admin

On a **new** production database (after migrate), seed the Home page and create a superadmin. Do **not** re-run this on every deploy.

```bash
cd /path/to/site
/usr/local/php84/bin/php artisan db:seed --force --class=HomePageSeeder
/usr/local/php84/bin/php artisan twill:superadmin
```

That creates a published **Home** page, selects it under **Settings → Homepage**, and prompts for the first `/admin` user.

### 2. Frontend assets (`./rsync.sh`)

Put targets in the **local** `.env` (gitignored; never sent to the server):

```env
REMOTE_USER=your-dreamhost-user
REMOTE_HOST=your-domain.com
REMOTE_PATH=/home/your-dreamhost-user/your-site
```

`REMOTE_PATH` is the site root (same directory as the git checkout). The script syncs:

`local public/build/` → `remote $REMOTE_PATH/public/build/`

```bash
./rsync.sh           # npm ci + npm run build, then rsync public/build/
./rsync.sh --dry-run
./rsync.sh --no-build
```

Optional: `export REMOTE_USER=…` still overrides `.env` for one-off runs.

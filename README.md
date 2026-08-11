# BaseProject (blog starter)

Laravel + Twill CMS starter for local development with **Herd** and **DBngin**. No ecommerce / Stripe — that lives in the parallel shop starter.

## Stack

- PHP 8.3+ / Laravel 12 (local PHP via **Laravel Herd**)
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
```

This clones [base_project_blog](https://github.com/blake-ducharme/base_project_blog) into `my-client-blog` and runs `bin/setup.sh`. The **folder name** becomes:

- Herd URL: `http://my-client-blog.test` (registered with `herd link`)
- DBngin MySQL service + Laravel schema: `my-client-blog`

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

Create a Gumlet **Web Folders** source whose Base URL matches `GUMLET_ORIGIN_BASE_URL`. Prefer `path` mode so `/storage/…` maps 1:1 onto the Gumlet host. After changing env on the server: `php artisan config:cache` (Dreamhost PHP, not Herd).

## Deploy to Dreamhost

Build assets on your Mac, then rsync. On the server, install PHP deps with **`composer.phar`** (not a global `composer` binary).

Put deploy targets in the **local** `.env` (gitignored; never rsynced to the server):

```env
REMOTE_USER=your-dreamhost-user
REMOTE_HOST=your-domain.com
REMOTE_PATH=/home/your-dreamhost-user/your-site
```

Then:

```bash
./rsync.sh           # npm ci + npm run build, then rsync
./rsync.sh --dry-run
./rsync.sh --no-build
```

Optional: `export REMOTE_USER=…` still overrides `.env` for one-off deploys.

The script never overwrites remote `.env` and excludes `vendor/` / `node_modules/`. After the first deploy (and after dependency changes), on the server:

```bash
cd /path/to/site
php composer.phar install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan storage:link
php artisan config:cache && php artisan route:cache && php artisan view:cache
```

# BaseProject (blog starter)

Laravel + Twill CMS starter for local development with **Herd** and **DBngin**. No ecommerce / Stripe — that lives in the parallel shop starter.

## Stack

- PHP 8.3+ / Laravel 12
- Twill CMS 3.5
- MySQL (DBngin locally)
- Tailwind CSS v4, Alpine.js, Barba.js
- Optional Gumlet image CDN (off locally)

## New site (recommended)

From `~/Developer/BD_PROJECTS`:

```bash
./new-twill-blog my-client-blog
```

This clones [base_project_blog](https://github.com/blake-ducharme/base_project_blog) into `my-client-blog` and runs `bin/setup.sh`. The **folder name** becomes:

- Herd URL: `http://my-client-blog.test`
- MySQL database: `my-client-blog`

### DBngin

Setup expects MySQL at `127.0.0.1:3306` as `root` with an **empty password**.

**Stop other local MySQL instances** (including Herd’s MySQL) so only DBngin owns that IP/port.

## Existing clone / manual setup

```bash
cd /path/to/your-site-folder   # folder name = Herd host
./bin/setup.sh
# ./bin/setup.sh --no-admin
# ./bin/setup.sh --no-seed
```

Or step by step:

```bash
composer install
cp .env.example .env
# edit APP_URL / DB_* or let setup.sh stamp them from the folder name
php artisan key:generate
php artisan migrate
npm install
npm run build
php artisan storage:link
php artisan db:seed
php artisan twill:superadmin
```

Admin is at `/admin`.

## Database seeding

`HomePageSeeder` is idempotent — re-running reuses the existing `home` page and refreshes Homepage settings.

```bash
php artisan db:seed
# or
php artisan db:seed --class=HomePageSeeder
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

Create a Gumlet **Web Folders** source whose Base URL matches `GUMLET_ORIGIN_BASE_URL`. Prefer `path` mode so `/storage/…` maps 1:1 onto the Gumlet host. After changing env on the server: `php artisan config:cache`.

## Deploy to Dreamhost

Build assets on your Mac, then rsync. On the server, install PHP deps with **`composer.phar`** (not a global `composer` binary).

```bash
# set remotes per site
export REMOTE_USER=your-dreamhost-user
export REMOTE_HOST=your-domain.com
export REMOTE_PATH=/home/your-dreamhost-user/your-site

./rsync.sh           # npm ci + npm run build, then rsync
./rsync.sh --dry-run
./rsync.sh --no-build
```

The script never overwrites remote `.env` and excludes `vendor/` / `node_modules/`. After the first deploy (and after dependency changes), on the server:

```bash
cd /path/to/site
php composer.phar install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan storage:link
php artisan config:cache && php artisan route:cache && php artisan view:cache
```

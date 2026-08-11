# Blog starter tooling design

**Date:** 2026-08-11  
**Status:** Approved

## Goal

Make `base_project_blog` a commerce-free Laravel + Twill blog starter that boots quickly on Herd + DBngin, deploys to Dreamhost via local asset build + rsync, and supports optional Gumlet image delivery (off in local `.env`).

## Out of scope

- Stripe / ecommerce / shop modules (lives in `bd_shop`)

## Components

### 1. Launcher (`~/Developer/BD_PROJECTS/new-twill-blog`)

- Usage: `./new-twill-blog <folder-name>`
- Clones `https://github.com/blake-ducharme/base_project_blog.git` into `BD_PROJECTS/<folder-name>`
- Runs in-repo `bin/setup.sh`
- Warns that only DBngin MySQL should listen on `127.0.0.1:3306`

### 2. In-repo `bin/setup.sh`

- `composer install`; copy `.env.example` → `.env` if missing
- Stamp from directory basename: `APP_NAME`, `APP_URL=http://{name}.test`, `TWILL_ADMIN_APP_URL`, `DB_DATABASE`
- Create MySQL DB if missing (`127.0.0.1:3306`, `root`, empty password)
- `key:generate`, migrate, `npm install` + `npm run build`, `storage:link`
- Seed homepage; prompt for `twill:superadmin` (skippable / `--no-admin`)

### 3. In-repo `rsync.sh`

- Local `npm ci` + `npm run build`, then rsync (never overwrite remote `.env`)
- `REMOTE_USER` / `REMOTE_HOST` / `REMOTE_PATH` env-overridable placeholders
- Print Dreamhost follow-ups using `composer.phar`

### 4. `.env.example`

Local-dev defaults only: empty `APP_KEY`, DBngin DB defaults, commented `MEDIA_URL`, Gumlet with `GUMLET_ENABLED=false`. No Stripe/ecomm keys.

### 5. Gumlet (ported from `bd_shop`)

- `app/Services/MediaLibrary/Gumlet.php` + `GumletParamsProcessor.php`
- `config/gumlet.php`
- `AppServiceProvider`: Gumlet when enabled + hostname set; else Twill `Glide`
- Public disk supports optional `MEDIA_URL`

### 6. Docs

README covers launcher, setup, DBngin port conflict, Gumlet, rsync + `composer.phar`.

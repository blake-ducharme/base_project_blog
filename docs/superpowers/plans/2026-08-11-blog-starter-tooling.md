# Blog Starter Tooling Implementation Plan

> **For agentic workers:** Implement task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Gumlet (toggleable), local setup + Dreamhost rsync scripts, a BD_PROJECTS launcher, and local `.env.example` / README for a commerce-free Twill blog starter.

**Architecture:** Port Gumlet image service from `bd_shop`; wire via env + AppServiceProvider. Folder-name-driven `bin/setup.sh` for Herd/DBngin. External `new-twill-blog` clones the GitHub repo then runs setup. `rsync.sh` builds assets locally and syncs code (not `.env`/`vendor`).

**Tech Stack:** Laravel 12, Twill 3.5, bash, MySQL (DBngin), npm/Vite, Dreamhost + `composer.phar`

## Global Constraints

- No Stripe / ecommerce code or env keys in this starter
- Local Gumlet default: `GUMLET_ENABLED=false`
- DBngin defaults: `127.0.0.1:3306`, user `root`, empty password
- Production PHP deps via `composer.phar` on server; assets via local `npm run build` + rsync
- Never rsync `.env`

---

## File map

| Path | Responsibility |
|------|----------------|
| `config/gumlet.php` | Gumlet env config |
| `app/Services/MediaLibrary/Gumlet.php` | Twill ImageServiceInterface |
| `app/Services/MediaLibrary/GumletParamsProcessor.php` | Param mapping |
| `app/Providers/AppServiceProvider.php` | Media library + Gumlet/Glide switch |
| `config/filesystems.php` | Optional `MEDIA_URL` on public disk |
| `.env.example` | Local template |
| `bin/setup.sh` | Local bootstrap |
| `rsync.sh` | Deploy |
| `README.md` | Docs |
| `/Users/peterducharme/Developer/BD_PROJECTS/new-twill-blog` | Clone launcher |

---

### Task 1: Gumlet + media wiring

- [ ] Add `config/gumlet.php` and MediaLibrary services (copy from `bd_shop`)
- [ ] Update `AppServiceProvider::register` for disk/Glide/Gumlet
- [ ] Update `config/filesystems.php` public disk `MEDIA_URL`
- [ ] Update `.env.example` (local defaults + Gumlet off)

**Verify:** `php artisan config:clear` succeeds; `config('gumlet.enabled')` is false with example env.

### Task 2: Scripts

- [ ] Add executable `bin/setup.sh`
- [ ] Add executable `rsync.sh` (placeholder remotes, `composer.phar` reminders)
- [ ] Add `BD_PROJECTS/new-twill-blog` launcher

**Verify:** `bash -n` on all three scripts.

### Task 3: README

- [ ] Document launcher, setup, DBngin conflict, Gumlet, rsync + Dreamhost

**Verify:** README mentions all three scripts and `GUMLET_ENABLED=false`.

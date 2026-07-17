# BaseProject

Laravel + Twill CMS starter foundation for local development with Herd.

## Stack

- PHP 8.3+ / Laravel 12
- Twill CMS 3.5
- MySQL
- Tailwind CSS v4, Alpine.js, Barba.js

## Setup

```bash
composer install
cp .env.example .env
php artisan key:generate
```

Configure `.env` for your local database and site URL (Herd default: `http://BaseProject.test`), then:

```bash
php artisan migrate
npm install
npm run build
php artisan storage:link
```

Create a Twill admin user if you do not have one yet:

```bash
php artisan twill:superadmin
```

Admin is at `/admin`.

## Database seeding

Seed a published **Home** page and select it in **Settings → Homepage**:

```bash
php artisan db:seed
```

Or run the homepage seeder only:

```bash
php artisan db:seed --class=HomePageSeeder
```

`HomePageSeeder` is idempotent — re-running it will reuse the existing `home` page and refresh the Homepage settings selection.

After seeding, visit the site root (`/`) to see the Home page, or open **Settings → Homepage** in Twill to confirm the selection.

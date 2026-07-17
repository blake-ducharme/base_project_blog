# Generic Laravel + Twill CMS — Starter Build Instructions for Claude

## Project Overview

Scaffold a clean, local Laravel + Twill CMS starter. No content modules are included — this is a blank foundation with Twill installed, a local media library, site settings for meta tags, and a base Blade layout wired to Tailwind and Barba.js. All future modules, blocks, and content types are added on top of this base.

---

## Stack

| Package | Version |
|---|---|
| PHP | 8.3.x |
| Laravel | ^12.0 |
| Twill CMS | ^3.5 |
| Composer | 2.9.x |
| Node | Current LTS |
| Database | SQLite |
| Local Server | Laravel Herd |
| CSS | Tailwind CSS v4 |
| JS | Barba.js, Alpine.js |

---

## 1. Project Creation

```bash
cd ~/Herd
composer create-project laravel/laravel BaseProject
cd BaseProject
```


---

## 2. Environment Configuration

Update `.env`:

```dotenv
APP_NAME="BaseProject"
APP_ENV=local
APP_DEBUG=true
APP_URL=http://BaseProject.test

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=base_project
DB_USERNAME=root
DB_PASSWORD=

# DB_DATABASE omitted — Laravel 12 defaults to database/database.sqlite

TWILL_ADMIN_APP_URL=http://BaseProject.test
TWILL_ADMIN_APP_PATH=admin
```


```

---

## 3. Install PHP Dependencies

```bash
composer require area17/twill:"^3.5"
```

---

## 4. Twill Installation

```bash
php artisan twill:install
```

Follow the prompt to create your admin credentials.

Publish Twill config if not already present:

```bash
php artisan vendor:publish --provider="A17\Twill\TwillServiceProvider" --tag=twill-config
```

---

## 5. Media Library — Local Disk Configuration

### 5a. `config/twill.php` — media_library key

```php
'media_library' => [
    'disk'               => 'public',
    'endpoint_type'      => 'local',
    'local_path'         => 'uploads',
    'image_service'      => 'A17\Twill\Services\MediaLibrary\Glide',
    'glide_base_path'    => 'img',
    'glide_base_url'     => null,
    'cascade_delete'     => false,
    'allowed_extensions' => ['svg', 'jpg', 'gif', 'png', 'jpeg', 'webp'],
    'use_local_storage'  => true,
],
```

### 5b. Verify `config/filesystems.php`

```php
'public' => [
    'driver'     => 'local',
    'root'       => storage_path('app/public'),
    'url'        => env('APP_URL').'/storage',
    'visibility' => 'public',
],
```

### 5c. Create storage symlink

```bash
php artisan storage:link
```

---

## 6. Frontend Setup

### 6a. Install Node packages

```bash
npm install
npm install -D tailwindcss @tailwindcss/vite @tailwindcss/typography @tailwindcss/forms
npm install @barba/core alpinejs @alpinejs/collapse
```

### 6b. `vite.config.js`

```js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        tailwindcss(),
    ],
});
```

### 6c. `resources/css/app.css`

```css
@import "tailwindcss";
@plugin "@tailwindcss/typography";
@plugin "@tailwindcss/forms";
```

### 6d. `resources/js/app.js`

```js
import './bootstrap';
import Alpine from 'alpinejs';
import collapse from '@alpinejs/collapse';
import barba from '@barba/core';

Alpine.plugin(collapse);
window.Alpine = Alpine;
Alpine.start();

barba.init({
    transitions: [
        {
            name: 'fade',
            leave({ current }) {
                return new Promise(resolve => {
                    current.container.style.transition = 'opacity 0.25s ease';
                    current.container.style.opacity = '0';
                    setTimeout(resolve, 250);
                });
            },
            enter({ next }) {
                next.container.style.opacity = '0';
                next.container.style.transition = 'opacity 0.25s ease';
                requestAnimationFrame(() => {
                    requestAnimationFrame(() => {
                        next.container.style.opacity = '1';
                    });
                });
            },
        },
    ],
    views: [
        {
            namespace: 'default',
            afterEnter() {
                Alpine.initTree(document.body);
            },
        },
    ],
});
```

---

## 7. Twill Admin Navigation

Create `config/twill-navigation.php`:

```php
<?php

return [
    'settings' => [
        'title' => 'Settings',
        'url'   => '/admin/settings/general',
    ],
];
```

Add modules to this file as they are created.

---

## 8. Site Settings

### 8a. Create the settings group

```bash
php artisan twill:make:settings general
```

### 8b. `resources/views/twill/settings/general.blade.php`

```blade
@formField('input',  ['name' => 'site_name',       'label' => 'Site Name'])
@formField('input',  ['name' => 'tagline',          'label' => 'Tagline'])
@formField('input',  ['name' => 'meta_description', 'label' => 'Default Meta Description', 'type' => 'textarea'])
@formField('input',  ['name' => 'meta_keywords',    'label' => 'Default Meta Keywords'])
@formField('medias', ['name' => 'og_image',         'label' => 'Default OG Share Image'])
```

### 8c. Register in `config/twill.php`

```php
'settings' => [
    'enabled' => true,
    'groups'  => [
        'general' => ['label' => 'General'],
    ],
],
```

---

## 9. Global `settings()` Helper

Create `app/helpers.php`:

```php
<?php

if (!function_exists('settings')) {
    function settings(string $group, string $key, mixed $default = null): mixed
    {
        try {
            return \A17\Twill\Facades\TwillCapsules::getSetting($group, $key) ?? $default;
        } catch (\Throwable) {
            return $default;
        }
    }
}
```

Register in `composer.json` under `autoload`:

```json
"autoload": {
    "files": [
        "app/helpers.php"
    ]
}
```

```bash
composer dump-autoload
```

---

## 10. Base Blade Layout

### 10a. `resources/views/layouts/app.blade.php`

```blade
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />

    <title>@yield('title', settings('general', 'site_name', config('app.name')))</title>
    <meta name="description" content="@yield('meta_description', settings('general', 'meta_description', ''))">

    @if(settings('general', 'meta_keywords'))
        <meta name="keywords" content="@yield('meta_keywords', settings('general', 'meta_keywords', ''))">
    @endif

    {{-- OG / Social --}}
    <meta property="og:title"       content="@yield('title', settings('general', 'site_name', config('app.name')))" />
    <meta property="og:description" content="@yield('meta_description', settings('general', 'meta_description', ''))" />
    <meta property="og:type"        content="website" />
    @if(settings('general', 'og_image'))
        <meta property="og:image" content="{{ settings('general', 'og_image') }}" />
    @endif

    @vite(['resources/css/app.css', 'resources/js/app.js'])
    @stack('head')
</head>
<body class="bg-white text-gray-900 antialiased">

    <div data-barba="wrapper">

        @include('partials.header')

        <main data-barba="container" data-barba-namespace="@yield('barba-namespace', 'default')">
            @yield('content')
        </main>

        @include('partials.footer')

    </div>

    @stack('scripts')
</body>
</html>
```

### 10b. `resources/views/partials/header.blade.php`

```blade
<header class="border-b border-gray-100">
    <div class="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="/" class="font-bold text-lg">
            {{ settings('general', 'site_name', config('app.name')) }}
        </a>
        {{-- Navigation goes here --}}
    </div>
</header>
```

### 10c. `resources/views/partials/footer.blade.php`

```blade
<footer class="border-t border-gray-100 py-8 px-6 mt-auto">
    <div class="max-w-6xl mx-auto text-sm text-gray-400 text-center">
        &copy; {{ date('Y') }} {{ settings('general', 'site_name', config('app.name')) }}
    </div>
</footer>
```

### 10d. `resources/views/welcome.blade.php`

Replace the default Laravel welcome view:

```blade
@extends('layouts.app')

@section('title', settings('general', 'site_name', config('app.name')))
@section('barba-namespace', 'home')

@section('content')
    <div class="max-w-3xl mx-auto px-6 py-24 text-center">
        <h1 class="text-4xl font-bold text-gray-900 mb-4">
            {{ settings('general', 'site_name', config('app.name')) }}
        </h1>
        @if(settings('general', 'tagline'))
            <p class="text-lg text-gray-500">{{ settings('general', 'tagline') }}</p>
        @endif
    </div>
@endsection
```

---

## 11. Routes

### `routes/web.php`

```php
<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
})->name('home');
```

---

## 12. Run Migrations

```bash
php artisan migrate
```

---

## 13. Final Setup Checklist

```bash
# Migrations
php artisan migrate

# Register helpers
composer dump-autoload

# Storage symlink
php artisan storage:link

# Build frontend
npm run dev       # development with watch
npm run build     # production

# Clear caches
php artisan optimize:clear
```

Then visit `http://BaseProject.test/admin`:
1. **Settings → General** — enter site name, tagline, meta description, and OG image

---

## Notes

- **Twill admin** is at `/admin` — change via `TWILL_ADMIN_APP_PATH` in `.env`
- **Media** is stored at `storage/app/public/uploads/` and served through Glide at `/img/`
- **Barba.js** requires all navigation to use standard `<a>` tags
- **Adding modules**: run `php artisan twill:make:module ModuleName`, register in `config/twill-navigation.php` and `routes/twill.php`
- **Adding settings groups**: run `php artisan twill:make:settings group-name`, create the blade form, and add the group to `config/twill.php`
- **Alpine `x-collapse`** is pre-installed for use in accordion/disclosure components
- **`@stack('head')` and `@stack('scripts')`** are available in the layout for page-specific assets
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

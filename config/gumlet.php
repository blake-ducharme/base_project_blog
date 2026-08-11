<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Gumlet delivery
    |--------------------------------------------------------------------------
    |
    | When enabled (and hostname is set), Twill front-end media URLs go through
    | Gumlet. CMS / raw URLs stay on the origin host. Keep disabled locally.
    |
    */

    'enabled' => filter_var(env('GUMLET_ENABLED', false), FILTER_VALIDATE_BOOLEAN),

    'hostname' => rtrim((string) env('GUMLET_HOSTNAME', ''), '/'),

    /*
    | Public host that serves originals (Gumlet Web Folders Base URL).
    | Example: https://your-production-host.com
    */
    'origin_base_url' => rtrim((string) env('GUMLET_ORIGIN_BASE_URL', ''), '/'),

    /*
    | path  = Web Folders  → {hostname}/{path}?params
    | fetch = Web Proxy    → {hostname}/fetch/{urlencoded_origin}?params
    */
    'url_mode' => env('GUMLET_URL_MODE', 'path'),

    'default_params' => [
        'format' => 'auto',
    ],

    'lqip_default_params' => [
        'format' => 'auto',
        'quality' => 20,
        'blur' => 50,
    ],

    'social_default_params' => [
        'format' => 'auto',
        'width' => 1200,
        'height' => 630,
        'mode' => 'crop',
    ],

    'add_params_to_svgs' => false,

];

<?php

return [
    'media_library' => [
        'disk' => 'twill_media_library',
        'endpoint_type' => 'local',
        'local_path' => 'uploads',
        'image_service' => \A17\Twill\Services\MediaLibrary\Glide::class,
        'cascade_delete' => false,
        'allowed_extensions' => ['svg', 'jpg', 'gif', 'png', 'jpeg', 'webp'],
    ],

    'glide' => [
        'base_path' => 'img',
        'base_url' => null,
    ],

    'enabled' => [
        'settings' => true,
    ],
];

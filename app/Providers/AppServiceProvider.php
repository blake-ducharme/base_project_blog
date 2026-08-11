<?php

namespace App\Providers;

use A17\Twill\Facades\TwillAppSettings;
use A17\Twill\Facades\TwillNavigation;
use A17\Twill\Services\Settings\SettingsGroup;
use A17\Twill\View\Components\Navigation\NavigationLink;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register()
    {
        $useGumlet = config('gumlet.enabled') && filled(config('gumlet.hostname'));

        config([
            'twill.media_library.disk' => 'public',
            'twill.media_library.endpoint_type' => 'local',
            // Files are stored at storage/app/public/{uuid}/… (no uploads/ prefix).
            'twill.media_library.local_path' => '',
            'twill.glide.source' => storage_path('app/public'),
            // Glide applies crops locally; Local returns the raw file and ignores crops.
            'twill.media_library.image_service' => $useGumlet
                ? \App\Services\MediaLibrary\Gumlet::class
                : \A17\Twill\Services\MediaLibrary\Glide::class,
        ]);
    }

    public function boot()
    {
        TwillNavigation::addLink(
            NavigationLink::make()->forModule('pages')
        );
        TwillNavigation::addLink(
            NavigationLink::make()->forModule('menuLinks')->title('Menu')
        );
        TwillAppSettings::registerSettingsGroups(
            SettingsGroup::make()->name('homepage')->label('Homepage'),
            SettingsGroup::make()->name('seo')->label(trans('twill-metadata::form.titles.fieldset')),
        );
    }
}

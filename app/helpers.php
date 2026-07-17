<?php

use A17\Twill\Facades\TwillAppSettings;

if (! function_exists('settings')) {
    /**
     * Read a Twill App Settings value.
     *
     * Maps settings('general', 'site_name') → general.general.site_name
     * (group + matching section blade under resources/views/twill/settings/{group}/).
     */
    function settings(string $group, string $key, mixed $default = null): mixed
    {
        try {
            $block = TwillAppSettings::getGroupDataForSectionAndName($group, $group);

            if ($block->hasImage($key)) {
                return $block->image($key) ?: $default;
            }

            $value = $block->input($key);

            return ($value === null || $value === '') ? $default : $value;
        } catch (\Throwable) {
            return $default;
        }
    }
}

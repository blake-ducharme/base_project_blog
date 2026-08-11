<?php

namespace App\Services\MediaLibrary;

use A17\Twill\Services\MediaLibrary\ImageServiceDefaults;
use A17\Twill\Services\MediaLibrary\ImageServiceInterface;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class Gumlet implements ImageServiceInterface
{
    use ImageServiceDefaults;

    public function __construct(
        protected GumletParamsProcessor $paramsProcessor
    ) {}

    public function getUrl($id, array $params = [])
    {
        $defaultParams = config('gumlet.default_params', []);
        $addParamsToSvgs = (bool) config('gumlet.add_params_to_svgs', false);

        if (! $addParamsToSvgs && Str::endsWith(strtolower((string) $id), '.svg')) {
            return $this->buildGumletUrl($id, []);
        }

        return $this->buildGumletUrl($id, array_replace($defaultParams, $params));
    }

    public function getUrlWithCrop($id, array $cropParams, array $params = [])
    {
        return $this->getUrl($id, $this->getCrop($cropParams) + $params);
    }

    public function getUrlWithFocalCrop($id, array $cropParams, $width, $height, array $params = [])
    {
        return $this->getUrl($id, $this->getFocalPointCrop($cropParams, $width, $height) + $params);
    }

    public function getLQIPUrl($id, array $params = [])
    {
        $defaultParams = config('gumlet.lqip_default_params', []);

        return $this->getUrlWithDefaultParams($id, $params, $defaultParams);
    }

    public function getSocialUrl($id, array $params = [])
    {
        $defaultParams = config('gumlet.social_default_params', []);

        return $this->getUrlWithDefaultParams($id, $params, $defaultParams);
    }

    public function getCmsUrl($id, array $params = [])
    {
        return $this->getOriginUrl($id);
    }

    public function getRawUrl($id)
    {
        return $this->getOriginUrl($id);
    }

    public function getDimensions($id)
    {
        $url = $this->getOriginUrl($id);

        try {
            [$width, $height] = getimagesize($url);

            return [
                'width' => $width,
                'height' => $height,
            ];
        } catch (\Throwable) {
            return [
                'width' => 0,
                'height' => 0,
            ];
        }
    }

    protected function getUrlWithDefaultParams($id, array $params, array $defaultParams): string
    {
        $cropParams = Arr::has($params, $this->cropParamsKeys) ? $this->getCrop($params) : [];
        $params = Arr::except($params, $this->cropParamsKeys);

        return $this->getUrl($id, array_replace($defaultParams, $cropParams + $params));
    }

    /**
     * Encode Twill crop as crop=w,h,x,y for the params processor → extract.
     */
    protected function getCrop(array $cropParams): array
    {
        if (empty($cropParams)) {
            return [];
        }

        $w = $cropParams['crop_w'] ?? null;
        $h = $cropParams['crop_h'] ?? null;
        $x = $cropParams['crop_x'] ?? 0;
        $y = $cropParams['crop_y'] ?? 0;

        if (! filled($w) || ! filled($h)) {
            return [];
        }

        return ['crop' => "{$w},{$h},{$x},{$y}"];
    }

    /**
     * Focal crop: only mode=crop (precise focal coords not sent to Gumlet).
     */
    protected function getFocalPointCrop(array $cropParams, $width, $height): array
    {
        if (empty($cropParams)) {
            return [];
        }

        $cropW = (float) ($cropParams['crop_w'] ?? 0);
        $cropH = (float) ($cropParams['crop_h'] ?? 0);
        $cropX = (float) ($cropParams['crop_x'] ?? 0);
        $cropY = (float) ($cropParams['crop_y'] ?? 0);
        $width = (float) $width;
        $height = (float) $height;

        if ($width <= 0 || $height <= 0 || $cropW <= 0 || $cropH <= 0) {
            return ['fit' => 'crop'];
        }

        $fpX = ($cropW / 2 + $cropX) / $width;
        $fpY = ($cropH / 2 + $cropY) / $height;
        $fpZ = $cropW > $cropH ? ($width / $cropW) : ($height / $cropH);

        return [
            'fit' => 'crop-'.number_format($fpX, 4, '.', '').'-'.number_format($fpY, 4, '.', '').'-'.number_format($fpZ, 4, '.', ''),
        ];
    }

    protected function buildGumletUrl(string $id, array $params): string
    {
        $originUrl = $this->getOriginUrl($id);
        $processed = $this->paramsProcessor->process($params);
        $query = http_build_query($processed);
        $hostname = rtrim((string) config('gumlet.hostname'), '/');
        $mode = config('gumlet.url_mode', 'path');

        if ($mode === 'fetch') {
            $url = $hostname.'/fetch/'.rawurlencode($originUrl);

            return $query !== '' ? $url.'?'.$query : $url;
        }

        $path = ltrim((string) (parse_url($originUrl, PHP_URL_PATH) ?: ''), '/');
        $url = $hostname.'/'.$path;

        return $query !== '' ? $url.'?'.$query : $url;
    }

    protected function getOriginUrl(string $id): string
    {
        $disk = config('twill.media_library.disk', 'public');
        $url = Storage::disk($disk)->url($id);

        if (! Str::startsWith($url, ['http://', 'https://'])) {
            $url = rtrim((string) config('app.url'), '/').'/'.ltrim($url, '/');
        }

        $originBase = rtrim((string) config('gumlet.origin_base_url'), '/');
        $appUrl = rtrim((string) config('app.url'), '/');

        if ($originBase !== '' && $appUrl !== '' && Str::startsWith($url, $appUrl)) {
            $url = $originBase.Str::after($url, $appUrl);
        }

        return $url;
    }
}

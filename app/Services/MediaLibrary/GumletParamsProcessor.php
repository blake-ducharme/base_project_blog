<?php

namespace App\Services\MediaLibrary;

use A17\Twill\Services\MediaLibrary\AbstractParamsProcessor;

class GumletParamsProcessor extends AbstractParamsProcessor
{
    public function finalizeParams()
    {
        if ($this->width) {
            $this->params['width'] = $this->width;
        }

        if ($this->height) {
            $this->params['height'] = $this->height;
        }

        if ($this->format) {
            $format = strtolower((string) $this->format);

            if (in_array($format, ['jpg', 'pjpg'], true)) {
                $format = 'jpeg';
            }

            $this->params['format'] = $format;
        }

        if ($this->quality) {
            $this->params['quality'] = $this->quality;
        }

        if ($this->fit) {
            $this->handleFitValue($this->fit);
        }

        return $this->params;
    }

    protected function handleParamFit($key, $value): void
    {
        $this->handleFitValue($value);
        unset($this->params[$key]);
    }

    /**
     * Twill crop encoded as crop=w,h,x,y → Gumlet extract=x,y,w,h
     */
    protected function handleParamCrop($key, $value): void
    {
        if (! is_string($value) || ! str_contains($value, ',')) {
            return;
        }

        $parts = array_map('trim', explode(',', $value));

        if (count($parts) !== 4) {
            return;
        }

        [$w, $h, $x, $y] = $parts;
        $this->params['extract'] = "{$x},{$y},{$w},{$h}";
        unset($this->params[$key]);
    }

    protected function handleFitValue(mixed $value): void
    {
        $value = (string) $value;

        if ($value === 'crop' || str_starts_with($value, 'crop-')) {
            $this->params['mode'] = 'crop';
            $this->fit = null;

            return;
        }

        // Native Gumlet mode values (max, fill, etc.) or pass-through.
        if (in_array($value, ['max', 'fill', 'crop', 'min'], true)) {
            $this->params['mode'] = $value;
            $this->fit = null;
        }
    }
}

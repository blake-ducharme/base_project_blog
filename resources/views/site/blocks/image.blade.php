<div class="flex items-center mt-16 -mx-5 first:mt-0 md:mx-0">
    @if($block->hasImage('highlight', 'desktop'))
        {!! TwillImage::make($block, 'highlight')
            ->preset('highlight')
            ->render([
                'imageClass' => 'block max-w-full',
            ]) !!}
    @endif
</div>

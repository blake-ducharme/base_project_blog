<?php

namespace App\Http\Controllers;

use A17\Twill\Facades\TwillAppSettings;
use App\Repositories\PageRepository;
use CwsDigital\TwillMetadata\Traits\SetsMetadata;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Collection;
use Illuminate\Support\ItemNotFoundException;

class PageDisplayController extends Controller
{
    use SetsMetadata;

    public function show(string $slug, PageRepository $pageRepository): View
    {
        $page = $pageRepository->forSlug($slug);

        if (! $page) {
            abort(404);
        }

        $this->setMetadata($page);

        return view('site.page', ['item' => $page]);
    }

    public function home(): View
    {
        try {
            $homepage = TwillAppSettings::get('homepage.homepage.page');
        } catch (ItemNotFoundException) {
            abort(404);
        }

        if ($homepage instanceof Collection && $homepage->isNotEmpty()) {
            $frontPage = $homepage->first();

            if ($frontPage?->published) {
                $this->setMetadata($frontPage);

                return view('site.page', ['item' => $frontPage]);
            }
        }

        abort(404);
    }
}

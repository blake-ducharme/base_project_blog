<?php

namespace Database\Seeders;

use A17\Twill\Facades\TwillAppSettings;
use A17\Twill\Models\Block;
use App\Models\Page;
use App\Models\Translations\PageTranslation;
use App\Repositories\PageRepository;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class HomePageSeeder extends Seeder
{
    /**
     * Create a published "Home" page and select it in Homepage settings.
     */
    public function run(): void
    {
        $page = $this->createHomePage();
        $this->assignAsHomepage($page);

        $page->refresh()->load('translations');

        if (blank($page->title) || $page->title !== 'Home') {
            throw new RuntimeException(
                "HomePageSeeder failed: expected page title \"Home\", got [{$page->title}] (page #{$page->id})."
            );
        }

        $this->command?->info("Homepage settings set to page #{$page->id} ({$page->title}).");
    }

    protected function createHomePage(): Page
    {
        /** @var PageRepository $repository */
        $repository = app(PageRepository::class);

        $locale = $this->locale();

        $existing = Page::query()
            ->whereHas('slugs', fn ($query) => $query->where('slug', 'home')->where('active', true))
            ->first();

        // Recover blank/orphan rows from a prior broken seed (page with no translations).
        if (! $existing) {
            $existing = Page::query()
                ->whereDoesntHave('translations')
                ->orderBy('id')
                ->first();
        }

        // Also recover pages that exist but have an empty title for the active locale.
        if (! $existing) {
            $existing = Page::query()
                ->whereHas('translations', function ($query) use ($locale) {
                    $query->where('locale', $locale)
                        ->where(function ($q) {
                            $q->whereNull('title')->orWhere('title', '');
                        });
                })
                ->orderBy('id')
                ->first();
        }

        $fields = $this->homePageFields($locale);

        if ($existing) {
            $repository->update($existing->id, $fields);
            $page = $existing->fresh(['translations', 'slugs']) ?? $existing;
        } else {
            $page = $repository->create($fields)->fresh(['translations', 'slugs']);
        }

        $this->ensureHomeTranslationAndSlug($page, $locale);

        return $page->fresh(['translations', 'slugs']);
    }

    protected function locale(): string
    {
        $locales = function_exists('getLocales') ? getLocales() : config('translatable.locales', ['en']);

        return $locales[0] ?? config('app.locale', 'en');
    }

    /**
     * @return array<string, mixed>
     */
    protected function homePageFields(string $locale): array
    {
        return [
            'published' => true,
            'languages' => [
                [
                    'value' => $locale,
                    'published' => true,
                ],
            ],
            'title' => [
                $locale => 'Home',
            ],
            'description' => [
                $locale => 'Welcome to the site.',
            ],
        ];
    }

    protected function ensureHomeTranslationAndSlug(Page $page, string $locale): void
    {
        // Direct upsert — bypasses Twill/Astrotomic fill quirks that can leave title blank.
        PageTranslation::query()->updateOrCreate(
            [
                'page_id' => $page->id,
                'locale' => $locale,
            ],
            [
                'title' => 'Home',
                'description' => 'Welcome to the site.',
                'active' => true,
            ]
        );

        // Clear soft-deleted duplicates for this locale if any.
        PageTranslation::onlyTrashed()
            ->where('page_id', $page->id)
            ->where('locale', $locale)
            ->forceDelete();

        $hasHomeSlug = $page->slugs()
            ->where('locale', $locale)
            ->where('slug', 'home')
            ->where('active', true)
            ->exists();

        if (! $hasHomeSlug) {
            DB::table('page_slugs')
                ->where('page_id', $page->id)
                ->where('locale', $locale)
                ->update(['active' => false]);

            $page->slugs()->create([
                'slug' => 'home',
                'locale' => $locale,
                'active' => true,
            ]);
        }
    }

    protected function assignAsHomepage(Page $page): void
    {
        $group = TwillAppSettings::getGroupForName('homepage');
        $group->boot();

        $block = TwillAppSettings::getGroupDataForSectionAndName('homepage', 'homepage');

        $this->syncBrowserSelection($block, 'page', $page);
    }

    protected function syncBrowserSelection(Block $block, string $browserName, Page $page): void
    {
        $block->saveRelated([$page], $browserName);

        $content = is_array($block->content) ? $block->content : (array) $block->content;
        $content['browsers'] = array_merge($content['browsers'] ?? [], [
            $browserName => [$page->id],
        ]);

        $block->content = $content;
        $block->save();
    }
}

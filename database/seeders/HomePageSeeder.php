<?php

namespace Database\Seeders;

use A17\Twill\Facades\TwillAppSettings;
use A17\Twill\Models\Block;
use App\Models\Page;
use App\Repositories\PageRepository;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class HomePageSeeder extends Seeder
{
    /**
     * Create a published "Home" page and select it in Homepage settings.
     */
    public function run(): void
    {
        $page = $this->createHomePage();
        $this->assignAsHomepage($page);

        $page->refresh();
        $this->command?->info("Homepage settings set to page #{$page->id} ({$page->title}).");
    }

    protected function createHomePage(): Page
    {
        /** @var PageRepository $repository */
        $repository = app(PageRepository::class);

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

        $fields = $this->homePageFields();

        if ($existing) {
            $repository->update($existing->id, $fields);
            $page = $existing->fresh(['translations', 'slugs']);
        } else {
            $page = $repository->create($fields);
            $page = $page->fresh(['translations', 'slugs']);
        }

        // Guarantee translation + slug even if Twill field prep skipped them.
        $this->ensureHomeTranslationAndSlug($page);

        return $page->fresh(['translations', 'slugs']);
    }

    /**
     * @return array<string, mixed>
     */
    protected function homePageFields(): array
    {
        return [
            'published' => true,
            'languages' => [
                [
                    'value' => 'en',
                    'published' => true,
                ],
            ],
            'title' => [
                'en' => 'Home',
            ],
            'description' => [
                'en' => 'Welcome to the site.',
            ],
            // Slug is applied in ensureHomeTranslationAndSlug() — do not pass
            // `slug` through repository update/create (it is not a pages column).
        ];
    }

    protected function ensureHomeTranslationAndSlug(Page $page): void
    {
        $translation = $page->translateOrNew('en');
        $translation->title = 'Home';
        $translation->description = $translation->description ?: 'Welcome to the site.';
        $translation->active = true;
        $page->save();

        $hasHomeSlug = $page->slugs()
            ->where('locale', 'en')
            ->where('slug', 'home')
            ->where('active', true)
            ->exists();

        if (! $hasHomeSlug) {
            DB::table('page_slugs')->where('page_id', $page->id)->where('locale', 'en')->update(['active' => false]);
            $page->slugs()->create([
                'slug' => 'home',
                'locale' => 'en',
                'active' => true,
            ]);
        }
    }

    protected function assignAsHomepage(Page $page): void
    {
        $group = TwillAppSettings::getGroupForName('homepage');
        $group->boot();

        $block = TwillAppSettings::getGroupDataForSectionAndName('homepage', 'homepage');

        // Twill admin form reads content.browsers; the related table powers the frontend facade.
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

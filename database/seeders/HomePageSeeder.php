<?php

namespace Database\Seeders;

use A17\Twill\Facades\TwillAppSettings;
use A17\Twill\Models\Block;
use App\Models\Page;
use App\Repositories\PageRepository;
use Illuminate\Database\Seeder;

class HomePageSeeder extends Seeder
{
    /**
     * Create a published "Home" page and select it in Homepage settings.
     */
    public function run(): void
    {
        $page = $this->createHomePage();
        $this->assignAsHomepage($page);

        $this->command?->info("Homepage settings set to page #{$page->id} ({$page->title}).");
    }

    protected function createHomePage(): Page
    {
        $existing = Page::query()
            ->whereHas('slugs', fn ($query) => $query->where('slug', 'home')->where('active', true))
            ->first();

        if ($existing) {
            if (! $existing->published) {
                $existing->published = true;
                $existing->save();
            }

            return $existing;
        }

        /** @var PageRepository $repository */
        $repository = app(PageRepository::class);

        return $repository->create([
            'published' => true,
            'title' => [
                'en' => 'Home',
            ],
            'description' => [
                'en' => 'Welcome to the site.',
            ],
        ]);
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

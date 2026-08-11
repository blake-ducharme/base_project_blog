<?php

namespace App\Models\Translations;

use A17\Twill\Models\Model;
use App\Models\Page;

class PageTranslation extends Model
{
    protected $baseModuleModel = Page::class;

    protected $fillable = [
        'title',
        'description',
        'active',
        'locale',
        'page_id',
    ];
}

@extends('layouts.app')

@section('title', settings('general', 'site_name', config('app.name')))
@section('barba-namespace', 'home')

@section('content')
    <div class="max-w-3xl mx-auto px-6 py-24 text-center">
        <h1 class="text-4xl font-bold text-gray-900 mb-4">
            {{ settings('general', 'site_name', config('app.name')) }}
        </h1>
        @if(settings('general', 'tagline'))
            <p class="text-lg text-gray-500">{{ settings('general', 'tagline') }}</p>
        @endif
    </div>
@endsection

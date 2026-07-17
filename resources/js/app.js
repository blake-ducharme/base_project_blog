import './bootstrap';
import Alpine from 'alpinejs';
import collapse from '@alpinejs/collapse';
import barba from '@barba/core';

Alpine.plugin(collapse);
window.Alpine = Alpine;
Alpine.start();

barba.init({
    transitions: [
        {
            name: 'fade',
            leave({ current }) {
                return new Promise(resolve => {
                    current.container.style.transition = 'opacity 0.25s ease';
                    current.container.style.opacity = '0';
                    setTimeout(resolve, 250);
                });
            },
            enter({ next }) {
                next.container.style.opacity = '0';
                next.container.style.transition = 'opacity 0.25s ease';
                requestAnimationFrame(() => {
                    requestAnimationFrame(() => {
                        next.container.style.opacity = '1';
                    });
                });
            },
        },
    ],
    views: [
        {
            namespace: 'default',
            afterEnter() {
                Alpine.initTree(document.body);
            },
        },
    ],
});

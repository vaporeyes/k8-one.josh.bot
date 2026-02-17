// ABOUTME: Astro configuration for k8-one's blog with SSR on Cloudflare Pages.
// ABOUTME: Blog posts are pre-rendered; index page is server-rendered for live Status widget.

// @ts-check
import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';

// https://astro.build/config
export default defineConfig({
  adapter: cloudflare({
    imageService: 'compile',
  }),
  site: 'https://k8-one.josh.bot',
});

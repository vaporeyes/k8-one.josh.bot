// ABOUTME: Astro configuration for k8-one's static blog.
// ABOUTME: Outputs pre-rendered HTML to dist/ for S3+CloudFront hosting.

// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  output: 'static',
  site: 'https://k8-one.josh.bot',
});

---
title: "Astro"
description: "Quick reference for Astro components, content collections, routing, and SSR patterns."
updatedDate: 2026-03-30
---

## Project Commands

```bash
# Dev server
npm run dev
npx astro dev -- --port 3000

# Build
npm run build
npx astro build

# Preview build locally
npm run preview

# Check types
npx astro check

# Add integration
npx astro add cloudflare
npx astro add tailwind
```

## Component Basics

```astro
---
// Frontmatter (runs at build/request time, never in browser)
import Header from '../components/Header.astro';

interface Props {
  title: string;
  count?: number;
}

const { title, count = 0 } = Astro.props;
const items = await fetch('https://api.example.com/items').then(r => r.json());
---

<Header />
<h1>{title}</h1>
<p>Count: {count}</p>

{items.length > 0 && (
  <ul>
    {items.map((item) => (
      <li>{item.name}</li>
    ))}
  </ul>
)}

<style>
  /* Scoped to this component by default */
  h1 { color: navy; }
</style>

<script>
  // Runs in the browser
  console.log('client-side');
</script>
```

## Slots

```astro
<!-- Layout.astro -->
<div class="layout">
  <header><slot name="header" /></header>
  <main><slot /></main>              <!-- default slot -->
  <footer><slot name="footer">Default footer</slot></footer>
</div>
```

```astro
<!-- Usage -->
<Layout>
  <h1 slot="header">Title</h1>
  <p>Main content goes in default slot</p>
  <nav slot="footer">Custom footer</nav>
</Layout>
```

## Styles

```astro
<!-- Scoped (default) -->
<style>
  h1 { color: red; }
</style>

<!-- Global -->
<style is:global>
  body { margin: 0; }
</style>

<!-- Target child component elements -->
<style>
  .content :global(h2) {
    margin-top: 2rem;
  }
</style>

<!-- Inline via define:vars -->
---
const color = 'red';
---
<style define:vars={{ color }}>
  h1 { color: var(--color); }
</style>

<!-- External stylesheet -->
<link rel="stylesheet" href="/styles/global.css" />

<!-- Import in frontmatter -->
---
import '../styles/global.css';
---
```

## Content Collections

```typescript
// src/content/config.ts
import { defineCollection, z } from 'astro:content';

const posts = defineCollection({
  type: 'content',                     // markdown/mdx
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
  }),
});

const authors = defineCollection({
  type: 'data',                        // json/yaml
  schema: z.object({
    name: z.string(),
    avatar: z.string().optional(),
  }),
});

export const collections = { posts, authors };
```

```astro
---
// Query collections
import { getCollection, getEntry } from 'astro:content';

// All entries
const posts = await getCollection('posts');

// Filtered
const published = await getCollection('posts', ({ data }) => !data.draft);

// Single entry
const post = await getEntry('posts', 'my-post-slug');

// Render content
const { Content } = await post.render();
---

<Content />
```

## Routing

```
src/pages/
  index.astro              -> /
  about.astro              -> /about/
  posts/
    index.astro            -> /posts/
    [slug].astro           -> /posts/:slug/
    [...slug].astro        -> /posts/* (catch-all)
  tags/
    [tag].astro            -> /tags/:tag/
```

```astro
---
// Static paths (SSG)
export async function getStaticPaths() {
  const posts = await getCollection('posts');
  return posts.map((post) => ({
    params: { slug: post.slug },
    props: post,
  }));
}

const post = Astro.props;
---
```

```astro
---
// Dynamic (SSR) - no getStaticPaths needed
export const prerender = false;

const { slug } = Astro.params;
---
```

## SSR vs SSG

```astro
---
// Per-page SSR opt-in
export const prerender = false;

// Access request data (SSR only)
const url = Astro.url;
const params = Astro.url.searchParams;
const cookie = Astro.cookies.get('session');
const headers = Astro.request.headers;
---
```

```astro
---
// Per-page SSG opt-in (when default is SSR)
export const prerender = true;
---
```

```javascript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';

export default defineConfig({
  output: 'server',                    // default SSR
  // output: 'static',                 // default SSG (default)
  // output: 'hybrid',                 // default SSG, opt-in SSR
  adapter: cloudflare(),
});
```

## Data Fetching

```astro
---
// Fetch at build/request time
const res = await fetch('https://api.example.com/data', {
  headers: { 'Authorization': `Bearer ${import.meta.env.API_KEY}` }
});

if (!res.ok) {
  return Astro.redirect('/error');
}

const data = await res.json();
---
```

## Environment Variables

```bash
# .env
PUBLIC_SITE_URL=https://example.com    # available client-side
API_KEY=secret123                      # server only
```

```astro
---
// Server-side (frontmatter)
const key = import.meta.env.API_KEY;

// Platform-specific (Cloudflare, Vercel, etc.)
const apiKey = Astro.locals.runtime?.env?.API_KEY;
---

<script>
  // Client-side (only PUBLIC_ prefixed)
  console.log(import.meta.env.PUBLIC_SITE_URL);
</script>
```

## Redirects and Responses

```astro
---
// Redirect
return Astro.redirect('/login', 302);

// Custom response (API route)
// src/pages/api/data.ts
export async function GET({ request }) {
  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' }
  });
}

export async function POST({ request }) {
  const body = await request.json();
  return new Response(JSON.stringify({ received: body }), { status: 201 });
}
---
```

## Script Handling

```astro
<!-- Bundled (default) - processed, deduped -->
<script>
  import { Poline } from 'poline';
  const p = new Poline({ numPoints: 5 });
</script>

<!-- Inline (no processing) -->
<script is:inline>
  alert('runs exactly as written');
</script>

<!-- External module -->
<script src="../scripts/main.ts"></script>
```

## Built-in Components

```astro
---
import { Image } from 'astro:assets';
import myImage from '../assets/photo.png';
---

<!-- Optimized image -->
<Image src={myImage} alt="Description" width={600} />

<!-- Remote image -->
<Image src="https://example.com/img.png" alt="Remote" width={400} height={300} />
```

## Integrations Config

```javascript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';
import sitemap from '@astrojs/sitemap';
import mdx from '@astrojs/mdx';

export default defineConfig({
  site: 'https://example.com',
  output: 'hybrid',
  adapter: cloudflare({
    imageService: 'compile',
  }),
  integrations: [sitemap(), mdx()],
  markdown: {
    shikiConfig: {
      theme: 'github-dark',
    },
  },
});
```

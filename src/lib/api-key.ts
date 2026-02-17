// ABOUTME: Helper to get the API key from Cloudflare runtime env (production) or import.meta.env (local dev).
// ABOUTME: Cloudflare Workers don't populate import.meta.env with secrets at runtime.

export function getApiKey(locals: App.Locals): string {
  // Cloudflare Pages runtime binding (production)
  const runtimeKey = (locals as any)?.runtime?.env?.JOSH_BOT_API_KEY;
  if (runtimeKey) return runtimeKey;

  // Fallback for local dev (astro dev reads .env)
  return import.meta.env.JOSH_BOT_API_KEY || '';
}

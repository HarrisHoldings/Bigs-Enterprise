import { createClient } from "@supabase/supabase-js";

/** True when the server has URL + non-empty service role key (nothing secret is exported). */
export function isServiceRoleKeyConfigured(): boolean {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  return Boolean(url && key);
}

/**
 * Server-only client with service role. Bypasses RLS; use only after verifying
 * the current session is allowed (e.g. `isOrgAdmin`). Never import in client components.
 *
 * Requires `SUPABASE_SERVICE_ROLE_KEY` (Supabase Dashboard → Settings → API).
 */
export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error(
      "Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY"
    );
  }

  return createClient(url, key, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

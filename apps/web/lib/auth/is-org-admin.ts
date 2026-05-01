import { getFixedAdminUserIds } from "@/lib/auth/admin-allowlist";
import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * True when the user may access `/admin`.
 *
 * Strict mode (three fixed super-admins):
 * Set `ADMIN_USER_IDS` to a comma-separated list of auth user UUIDs. Only those ids
 * gain admin access — `profiles.account_role` and `organization_members` are ignored.
 *
 * Legacy mode (omit `ADMIN_USER_IDS`):
 * `profiles.account_role = admin`, owner/admin in `organization_members`, or
 * `ADMIN_BOOTSTRAP_EMAILS` / `ADMIN_BOOTSTRAP_EMAIL_DOMAIN` (see bootstrap-admin).
 */
export async function isOrgAdmin(
  supabase: SupabaseClient,
  userId: string
): Promise<boolean> {
  const fixedIds = getFixedAdminUserIds();
  if (fixedIds) {
    return fixedIds.includes(userId);
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("account_role")
    .eq("id", userId)
    .maybeSingle();

  if (!profileError && profile?.account_role === "admin") {
    return true;
  }

  const orgSlug = process.env.ADMIN_ORG_SLUG?.trim();

  if (orgSlug) {
    const { data, error } = await supabase
      .from("organization_members")
      .select("organization_id, organizations!inner(slug)")
      .eq("user_id", userId)
      .in("role", ["owner", "admin"])
      .eq("organizations.slug", orgSlug)
      .limit(1)
      .maybeSingle();

    if (error || !data) return false;
    return true;
  }

  const { data, error } = await supabase
    .from("organization_members")
    .select("role")
    .eq("user_id", userId)
    .in("role", ["owner", "admin"])
    .limit(1)
    .maybeSingle();

  if (error || !data) return false;
  return true;
}

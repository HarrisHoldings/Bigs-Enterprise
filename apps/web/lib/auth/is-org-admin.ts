import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * True when the user may access `/admin`:
 * - `profiles.account_role = admin`, or
 * - owner/admin in `organization_members` (if you use org-based access).
 *
 * When `ADMIN_ORG_SLUG` is set, org membership only counts for that org's slug.
 */
export async function isOrgAdmin(
  supabase: SupabaseClient,
  userId: string
): Promise<boolean> {
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

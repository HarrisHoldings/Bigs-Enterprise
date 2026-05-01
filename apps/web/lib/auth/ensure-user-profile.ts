import type { SupabaseClient, User } from "@supabase/supabase-js";
import type { AccountRole } from "./account-role";

/**
 * Ensures `public.profiles` has a row for this user (RLS: insert/update own row).
 * New rows get `account_role = user`. Existing rows only get display fields updated (role preserved).
 */
export async function ensureUserProfile(
  supabase: SupabaseClient,
  user: User,
  options?: { skipIfExists?: boolean }
): Promise<{ error: Error } | null> {
  const meta = user.user_metadata ?? {};
  const displayName =
    (typeof meta.full_name === "string" && meta.full_name) ||
    (typeof meta.name === "string" && meta.name) ||
    (user.email ? user.email.split("@")[0] : null) ||
    null;

  const avatarUrl =
    typeof meta.avatar_url === "string" ? meta.avatar_url : null;

  const { data: existing } = await supabase
    .from("profiles")
    .select("id")
    .eq("id", user.id)
    .maybeSingle();

  if (options?.skipIfExists && existing) {
    return null;
  }

  if (!existing) {
    const { error } = await supabase.from("profiles").insert({
      id: user.id,
      display_name: displayName?.trim() || null,
      avatar_url: avatarUrl,
      account_role: "user" satisfies AccountRole,
    });
    if (error) return { error: new Error(error.message) };
    return null;
  }

  const { error } = await supabase
    .from("profiles")
    .update({
      display_name: displayName?.trim() || null,
      avatar_url: avatarUrl,
    })
    .eq("id", user.id);

  if (error) return { error: new Error(error.message) };
  return null;
}

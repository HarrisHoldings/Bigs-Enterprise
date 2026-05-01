import { ensureUserProfile } from "@/lib/auth/ensure-user-profile";
import { isOrgAdmin } from "@/lib/auth/is-org-admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

/**
 * Ensures the request is from a signed-in org admin; otherwise redirects.
 * Used by server actions and server components that perform admin writes.
 */
export async function requireOrgAdminSession(): Promise<{ userId: string }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  await ensureUserProfile(supabase, user, { skipIfExists: true });

  if (!(await isOrgAdmin(supabase, user.id))) {
    redirect("/login?error=forbidden");
  }

  return { userId: user.id };
}

import type { AccountRole } from "@/lib/auth/account-role";
import { requireOrgAdminSession } from "@/lib/auth/require-org-admin";
import { createAdminClient } from "@/lib/supabase/admin-client";

export type AdminDirectoryUser = {
  id: string;
  email: string;
  displayName: string | null;
  accountRole: AccountRole;
};

/** Lists auth users with profile roles for the admin Users page (service role read). */
export async function fetchAdminUserDirectory(
  page: number,
  perPage: number
): Promise<{ users: AdminDirectoryUser[]; total: number }> {
  await requireOrgAdminSession();

  const admin = createAdminClient();
  const { data: authData, error: authErr } = await admin.auth.admin.listUsers({
    page,
    perPage,
  });

  if (authErr || !authData) {
    throw new Error(authErr?.message ?? "Failed to load users.");
  }

  const rows = [...authData.users].sort((a, b) => {
    const ea = (a.email ?? "").toLowerCase();
    const eb = (b.email ?? "").toLowerCase();
    return ea.localeCompare(eb);
  });

  const ids = rows.map((u) => u.id);

  let profileRows: {
    id: string;
    display_name: string | null;
    account_role: AccountRole | null;
  }[] = [];

  if (ids.length > 0) {
    const { data: profiles, error: profErr } = await admin
      .from("profiles")
      .select("id, display_name, account_role")
      .in("id", ids);

    if (profErr) {
      throw new Error(profErr.message);
    }
    profileRows = profiles ?? [];
  }

  const map = new Map(profileRows.map((p) => [p.id, p]));

  const users: AdminDirectoryUser[] = rows.map((u) => {
    const p = map.get(u.id);
    return {
      id: u.id,
      email: u.email ?? "—",
      displayName: p?.display_name ?? null,
      accountRole:
        p?.account_role === "admin" ||
        p?.account_role === "vendor" ||
        p?.account_role === "employee" ||
        p?.account_role === "user"
          ? p.account_role
          : "user",
    };
  });

  return {
    users,
    total:
      typeof authData.total === "number" ? authData.total : users.length,
  };
}

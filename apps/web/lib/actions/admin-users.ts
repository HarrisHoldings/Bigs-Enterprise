"use server";

import {
  ACCOUNT_ROLES,
  type AccountRole,
} from "@/lib/auth/account-role";
import { requireOrgAdminSession } from "@/lib/auth/require-org-admin";
import { createAdminClient } from "@/lib/supabase/admin-client";
import { revalidatePath } from "next/cache";

function parseRole(value: unknown): AccountRole | null {
  if (typeof value !== "string") return null;
  return (ACCOUNT_ROLES as readonly string[]).includes(value)
    ? (value as AccountRole)
    : null;
}

export type UpdateRoleState = {
  ok?: boolean;
  error?: string;
};

export async function updateUserAccountRole(
  _prev: UpdateRoleState,
  formData: FormData
): Promise<UpdateRoleState> {
  await requireOrgAdminSession();
  const userId = String(formData.get("userId") ?? "").trim();
  const role = parseRole(formData.get("role"));

  if (!userId || !role) {
    return { error: "Missing user or role." };
  }

  const admin = createAdminClient();

  const { data: authData, error: authErr } =
    await admin.auth.admin.getUserById(userId);
  if (authErr || !authData?.user) {
    return {
      error: authErr?.message ?? "That sign-in account was not found.",
    };
  }

  const { data: targetRow, error: targetErr } = await admin
    .from("profiles")
    .select("account_role")
    .eq("id", userId)
    .maybeSingle();

  if (targetErr) {
    return { error: targetErr.message };
  }

  const { count: adminCount, error: countErr } = await admin
    .from("profiles")
    .select("*", { count: "exact", head: true })
    .eq("account_role", "admin");

  if (countErr) {
    return { error: countErr.message };
  }

  const admins = adminCount ?? 0;

  if (targetRow?.account_role === "admin" && role !== "admin" && admins <= 1) {
    return {
      error:
        "Cannot remove the last admin account. Assign another admin first.",
    };
  }

  if (!targetRow) {
    const { error: insertErr } = await admin.from("profiles").insert({
      id: userId,
      account_role: role,
      display_name: null,
      avatar_url: null,
    });
    if (insertErr) {
      return { error: insertErr.message };
    }
  } else {
    const { error: updateErr } = await admin
      .from("profiles")
      .update({ account_role: role })
      .eq("id", userId);
    if (updateErr) {
      return { error: updateErr.message };
    }
  }

  revalidatePath("/admin/users");
  return { ok: true };
}

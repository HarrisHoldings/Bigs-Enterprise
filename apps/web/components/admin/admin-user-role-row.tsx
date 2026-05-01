"use client";

import {
  updateUserAccountRole,
  type UpdateRoleState,
} from "@/lib/actions/admin-users";
import type { AdminDirectoryUser } from "@/lib/admin/user-directory";
import { ACCOUNT_ROLES, type AccountRole } from "@/lib/auth/account-role";
import { useActionState } from "react";

const ROLE_LABEL: Record<AccountRole, string> = {
  admin: "Admin",
  employee: "Employee",
  vendor: "Vendor",
  user: "Customer",
};

const initialState: UpdateRoleState = {};

export function AdminUserRoleRow({ user }: { user: AdminDirectoryUser }) {
  const [state, formAction, pending] = useActionState(
    updateUserAccountRole,
    initialState
  );

  return (
    <tr className="hover:bg-zinc-50/80 dark:hover:bg-zinc-900/30">
      <td className="px-4 py-3 text-xs text-zinc-800 dark:text-zinc-200">
        {user.email}
      </td>
      <td className="px-4 py-3 text-zinc-600 dark:text-zinc-400">
        {user.displayName ?? (
          <span className="italic text-zinc-400 dark:text-zinc-500">
            —
          </span>
        )}
      </td>
      <td className="px-4 py-3">
        <form action={formAction} className="flex flex-col gap-2">
          <input type="hidden" name="userId" value={user.id} />
          <div className="flex flex-wrap items-center gap-2">
            <label className="sr-only" htmlFor={`role-${user.id}`}>
              Role for {user.email}
            </label>
            <select
              id={`role-${user.id}`}
              name="role"
              defaultValue={user.accountRole}
              disabled={pending}
              className="min-w-[9.5rem] rounded-md border border-zinc-300 bg-white px-2 py-1.5 text-sm text-zinc-900 shadow-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500 disabled:opacity-60 dark:border-zinc-600 dark:bg-zinc-950 dark:text-zinc-100"
            >
              {ACCOUNT_ROLES.map((r) => (
                <option key={r} value={r}>
                  {ROLE_LABEL[r]}
                </option>
              ))}
            </select>
            <button
              type="submit"
              disabled={pending}
              className="rounded-md bg-zinc-900 px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200"
            >
              {pending ? "Saving…" : "Save"}
            </button>
          </div>
          {state.error ? (
            <span className="text-xs text-red-600 dark:text-red-400">
              {state.error}
            </span>
          ) : state.ok ? (
            <span className="text-xs text-emerald-600 dark:text-emerald-400">
              Saved.
            </span>
          ) : null}
        </form>
      </td>
    </tr>
  );
}

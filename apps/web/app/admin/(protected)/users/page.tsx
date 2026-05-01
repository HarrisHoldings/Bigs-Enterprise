import { fetchAdminUserDirectory } from "@/lib/admin/user-directory";
import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { AdminUserRoleRow } from "@/components/admin/admin-user-role-row";

export const metadata: Metadata = {
  title: "Users · Admin",
  description: "Manage account roles",
};

const PER_PAGE = 25;

export default async function AdminUsersPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  const params = await searchParams;
  const page = Math.max(1, parseInt(params.page ?? "1", 10) || 1);

  let directory: Awaited<ReturnType<typeof fetchAdminUserDirectory>>;
  try {
    directory = await fetchAdminUserDirectory(page, PER_PAGE);
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Could not load users.";
    return (
      <div className="mx-auto max-w-4xl rounded-lg border border-red-200 bg-red-50 p-6 text-red-900 dark:border-red-900 dark:bg-red-950/60 dark:text-red-100">
        <p className="font-medium">Failed to load directory</p>
        <p className="mt-2 text-sm opacity-90">{msg}</p>
        {msg.includes("SUPABASE_SERVICE_ROLE_KEY") ||
        msg.includes("service role") ? null : (
          <p className="mt-3 text-sm">
            Confirm <code className="rounded bg-black/10 px-1 py-0.5">SUPABASE_SERVICE_ROLE_KEY</code>{" "}
            is set server-side only (never exposed to the browser).
          </p>
        )}
      </div>
    );
  }

  const { users, total } = directory;
  const totalPages = Math.max(1, Math.ceil(total / PER_PAGE));

  if (page > totalPages) {
    redirect(`/admin/users?page=${totalPages}`);
  }

  const pageClamped = page;
  const prevPage = Math.max(1, pageClamped - 1);
  const nextPage = Math.min(totalPages, pageClamped + 1);

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-50">
          Users
        </h1>
        <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
          Set each person&apos;s portal role:{" "}
          <strong className="font-medium text-zinc-800 dark:text-zinc-200">
            Customer
          </strong>{" "}
          (<span className="font-mono text-xs">user</span>) is default; elevate
          to vendor, employee, or admin when needed.
        </p>
      </div>

      <div className="overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] text-left text-sm">
            <thead>
              <tr className="border-b border-zinc-200 bg-zinc-50 dark:border-zinc-800 dark:bg-zinc-900/40">
                <th className="px-4 py-3 font-medium text-zinc-700 dark:text-zinc-300">
                  Email
                </th>
                <th className="px-4 py-3 font-medium text-zinc-700 dark:text-zinc-300">
                  Name
                </th>
                <th className="px-4 py-3 font-medium text-zinc-700 dark:text-zinc-300">
                  Role
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100 dark:divide-zinc-800">
              {users.length === 0 ? (
                <tr>
                  <td
                    colSpan={3}
                    className="px-4 py-8 text-center text-zinc-500 dark:text-zinc-400"
                  >
                    No users on this page.
                  </td>
                </tr>
              ) : (
                users.map((u) => <AdminUserRoleRow key={u.id} user={u} />)
              )}
            </tbody>
          </table>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 border-t border-zinc-200 px-4 py-3 dark:border-zinc-800">
          <p className="text-xs text-zinc-500 dark:text-zinc-400">
            Showing{" "}
            <span className="font-medium text-zinc-700 dark:text-zinc-300">
              {users.length === 0 ? 0 : (pageClamped - 1) * PER_PAGE + 1}
              –
              {(pageClamped - 1) * PER_PAGE + users.length}
            </span>{" "}
            of <span className="font-medium">{total}</span>
          </p>
          <div className="flex gap-2">
            <Link
              href={`/admin/users?page=${prevPage}`}
              aria-disabled={pageClamped <= 1}
              className={`rounded-md border border-zinc-300 px-3 py-2 text-xs font-medium dark:border-zinc-600 ${
                pageClamped <= 1
                  ? "pointer-events-none opacity-40"
                  : "text-zinc-800 hover:bg-zinc-100 dark:text-zinc-200 dark:hover:bg-zinc-900"
              }`}
            >
              Previous
            </Link>
            <span className="flex items-center px-2 text-xs text-zinc-500">
              Page {pageClamped} / {totalPages}
            </span>
            <Link
              href={`/admin/users?page=${nextPage}`}
              aria-disabled={pageClamped >= totalPages}
              className={`rounded-md border border-zinc-300 px-3 py-2 text-xs font-medium dark:border-zinc-600 ${
                pageClamped >= totalPages
                  ? "pointer-events-none opacity-40"
                  : "text-zinc-800 hover:bg-zinc-100 dark:text-zinc-200 dark:hover:bg-zinc-900"
              }`}
            >
              Next
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}

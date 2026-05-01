import { isServiceRoleKeyConfigured } from "@/lib/supabase/admin-client";
import Link from "next/link";

export default async function AdminHomePage() {
  const serviceRoleOk = isServiceRoleKeyConfigured();

  return (
    <div className="mx-auto max-w-5xl space-y-8">
      {!serviceRoleOk ? (
        <div
          className="rounded-xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-950 dark:border-amber-800 dark:bg-amber-950/50 dark:text-amber-100"
          role="status"
        >
          <p className="font-medium">User management backend not configured</p>
          <p className="mt-1 text-amber-900/90 dark:text-amber-200/90">
            Set <span className="font-mono">SUPABASE_SERVICE_ROLE_KEY</span> on
            the server (never in the browser)—for example{" "}
            <span className="font-mono">apps/web/.env.local</span> or your host
            env. Then redeploy or restart Next.js. Dashboard access still works;
            the{" "}
            <Link
              href="/admin/users"
              className="font-medium underline underline-offset-2"
            >
              Users
            </Link>{" "}
            page needs this key for role edits.
          </p>
        </div>
      ) : (
        <div
          className="rounded-xl border border-emerald-300 bg-emerald-50 px-4 py-3 text-sm text-emerald-950 dark:border-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-100"
          role="status"
        >
          <p className="font-medium">Admin service role detected</p>
          <p className="mt-1 text-emerald-900/90 dark:text-emerald-200/90">
            <span className="font-mono">SUPABASE_SERVICE_ROLE_KEY</span> is set,
            so the{" "}
            <Link
              href="/admin/users"
              className="font-medium underline underline-offset-2"
            >
              Users
            </Link>{" "}
            directory and role updates can run. Open that page once to confirm
            it loads.
          </p>
        </div>
      )}

      <div className="rounded-xl border border-zinc-200 bg-white p-8 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
        <p className="text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
          Admin
        </p>
        <h1 className="mt-2 text-2xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-50">
          Dashboard
        </h1>
        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-600 dark:text-zinc-400">
          Overview of tools for your organization. Open the sidebar to switch
          between sections—or use the menu button on smaller screens.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {[
          {
            title: "Users",
            body: "Manage roles (customer, vendor, employee, admin) under Users in the sidebar.",
          },
          {
            title: "Sidebar",
            body: "Dashboard and Users are wired now. Add routes under the protected admin folder and extend admin-nav.ts.",
          },
          {
            title: "Access",
            body: "Only organization admins reach this area. Signed-in users without admin privileges are redirected.",
          },
        ].map((card) => (
          <div
            key={card.title}
            className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-800 dark:bg-zinc-950"
          >
            <h2 className="text-sm font-semibold text-zinc-900 dark:text-zinc-50">
              {card.title}
            </h2>
            <p className="mt-2 text-sm leading-relaxed text-zinc-600 dark:text-zinc-400">
              {card.body}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}

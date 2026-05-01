"use client";

import { ADMIN_NAV } from "@/components/admin/admin-nav";
import Link from "next/link";
type Props = {
  pathname: string;
  mobileNavOpen: boolean;
  closeMobileNav: () => void;
  closeButtonRef: React.RefObject<HTMLButtonElement | null>;
};

export function AdminSidebar({
  pathname,
  mobileNavOpen,
  closeMobileNav,
  closeButtonRef,
}: Props) {
  return (
    <aside
      id="admin-sidebar"
      className={`fixed inset-y-0 left-0 z-50 flex w-[min(260px,88vw)] flex-col border-r border-zinc-200 bg-white transition-transform duration-200 ease-out dark:border-zinc-800 dark:bg-zinc-950 md:static md:z-0 md:translate-x-0 ${
        mobileNavOpen
          ? "translate-x-0 shadow-xl"
          : "-translate-x-full md:shadow-none"
      }`}
    >
      <div className="flex h-14 shrink-0 items-center justify-between border-b border-zinc-200 px-4 dark:border-zinc-800 md:h-16">
        <Link
          href="/admin"
          className="font-semibold tracking-tight text-zinc-900 dark:text-zinc-50"
          onClick={closeMobileNav}
        >
          Admin
        </Link>
        <button
          ref={closeButtonRef}
          type="button"
          className="rounded-md p-2 text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-900 md:hidden"
          aria-label="Close sidebar"
          onClick={closeMobileNav}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden
          >
            <path d="M18 6 6 18" />
            <path d="m6 6 12 12" />
          </svg>
        </button>
      </div>
      <nav className="flex-1 overflow-y-auto p-3" aria-label="Admin sections">
        <p className="mb-2 px-3 text-xs font-medium uppercase tracking-wider text-zinc-400 dark:text-zinc-500">
          Menu
        </p>
        <ul className="space-y-0.5">
          {ADMIN_NAV.map((item) => {
            const active =
              pathname === item.href ||
              (item.href !== "/admin" && pathname.startsWith(`${item.href}/`));
            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={`block rounded-md px-3 py-2 text-sm font-medium transition-colors ${
                    active
                      ? "bg-zinc-900 text-white dark:bg-zinc-50 dark:text-zinc-900"
                      : "text-zinc-700 hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-900"
                  }`}
                  onClick={closeMobileNav}
                >
                  {item.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>
    </aside>
  );
}

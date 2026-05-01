"use client";

import { AdminSidebar } from "@/components/admin/admin-sidebar";
import { adminSignOut } from "@/app/admin/actions";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";

type AdminDashboardLayoutProps = {
  userEmail?: string | null;
  children: React.ReactNode;
};

export function AdminDashboardLayout({
  userEmail,
  children,
}: AdminDashboardLayoutProps) {
  const pathname = usePathname();
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [routeForNav, setRouteForNav] = useState(pathname);
  const closeButtonRef = useRef<HTMLButtonElement>(null);

  if (pathname !== routeForNav) {
    setRouteForNav(pathname);
    setMobileNavOpen(false);
  }

  const closeMobileNav = () => setMobileNavOpen(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setMobileNavOpen(false);
    };
    if (mobileNavOpen) {
      document.addEventListener("keydown", onKey);
      document.body.style.overflow = "hidden";
      closeButtonRef.current?.focus();
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [mobileNavOpen]);

  return (
    <div className="flex min-h-screen bg-zinc-50 dark:bg-zinc-950">
      <button
        type="button"
        aria-label="Close menu"
        className={`fixed inset-0 z-40 bg-black/40 transition-opacity md:hidden ${
          mobileNavOpen
            ? "pointer-events-auto opacity-100"
            : "pointer-events-none opacity-0"
        }`}
        onClick={closeMobileNav}
      />

      <AdminSidebar
        pathname={pathname}
        mobileNavOpen={mobileNavOpen}
        closeMobileNav={closeMobileNav}
        closeButtonRef={closeButtonRef}
      />

      <div className="flex flex-1 flex-col md:min-w-0">
        <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-zinc-200 bg-zinc-50/95 px-4 backdrop-blur dark:border-zinc-800 dark:bg-zinc-950/95 md:h-16 md:px-6">
          <button
            type="button"
            className="rounded-md p-2 text-zinc-600 hover:bg-zinc-200 dark:text-zinc-400 dark:hover:bg-zinc-900 md:hidden"
            aria-expanded={mobileNavOpen}
            aria-controls="admin-sidebar"
            aria-label={
              mobileNavOpen ? "Close navigation" : "Open navigation"
            }
            onClick={() => setMobileNavOpen((o) => !o)}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="22"
              height="22"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden
            >
              <path d="M4 12h16" />
              <path d="M4 18h16" />
              <path d="M4 6h16" />
            </svg>
          </button>
          <div className="min-w-0 flex-1 truncate text-sm text-zinc-600 dark:text-zinc-400">
            <span className="hidden sm:inline">Signed in as </span>
            <span className="font-medium text-zinc-900 dark:text-zinc-200">
              {userEmail ?? "—"}
            </span>
          </div>
          <form action={adminSignOut}>
            <button
              type="submit"
              className="rounded-md border border-zinc-300 px-3 py-2 text-xs font-medium text-zinc-900 transition-colors hover:bg-zinc-200 dark:border-zinc-700 dark:text-zinc-50 dark:hover:bg-zinc-900 sm:text-sm"
            >
              Sign out
            </button>
          </form>
        </header>

        <main className="flex-1 p-4 md:p-6">{children}</main>
      </div>
    </div>
  );
}

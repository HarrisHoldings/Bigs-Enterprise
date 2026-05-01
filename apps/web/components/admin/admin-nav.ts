/** Links shown in the admin sidebar. Add entries as you add routes under `(protected)`. */
export const ADMIN_NAV = [
  { href: "/admin", label: "Dashboard" },
  { href: "/admin/users", label: "Users" },
] as const;

export type AdminNavItem = (typeof ADMIN_NAV)[number];

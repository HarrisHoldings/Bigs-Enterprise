/** Values stored in `profiles.account_role` (Supabase migration 20260430000001). */
export const ACCOUNT_ROLES = [
  "admin",
  "vendor",
  "employee",
  "user",
] as const;

export type AccountRole = (typeof ACCOUNT_ROLES)[number];

/**
 * Optional comma-separated UUIDs of the only accounts that App Admin access applies to.
 *
 * Example in `.env.local` (exactly three people in your deployment):
 *
 * ADMIN_USER_IDS=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx,yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy,zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz
 *
 * When set with at least one id, `isOrgAdmin` ignores profiles and org membership.
 *
 * Omit or leave empty for legacy behaviour (profiles.account_role admin or org_members).
 */
export function getFixedAdminUserIds(): readonly string[] | undefined {
  const raw = process.env.ADMIN_USER_IDS?.trim();
  if (!raw) return undefined;
  const ids = raw.split(",").map((id) => id.trim()).filter(Boolean);
  return ids.length > 0 ? ids : undefined;
}
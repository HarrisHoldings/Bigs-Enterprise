import { AdminDashboardLayout } from "@/components/admin/admin-dashboard-layout";
import { ensureUserProfile } from "@/lib/auth/ensure-user-profile";
import { isOrgAdmin } from "@/lib/auth/is-org-admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function ProtectedAdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  await ensureUserProfile(supabase, user, { skipIfExists: true });

  const admin = await isOrgAdmin(supabase, user.id);
  if (admin) {
    return (
      <AdminDashboardLayout userEmail={user.email}>{children}</AdminDashboardLayout>
    );
  }

  redirect("/login?error=forbidden");
}

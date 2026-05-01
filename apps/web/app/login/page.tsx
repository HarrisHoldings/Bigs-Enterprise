import { LoginForm } from "@/components/admin/login-form";
import { isOrgAdmin } from "@/lib/auth/is-org-admin";
import { createClient } from "@/lib/supabase/server";
import type { Metadata } from "next";
import { redirect } from "next/navigation";

export const metadata: Metadata = {
  title: "Sign in",
  description: "Sign in to your account",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const authErrorMessage =
    params.error === "auth"
      ? "Email confirmation or sign-in link failed. Try signing in again."
      : params.error === "config"
        ? "Server configuration is missing. Check NEXT_PUBLIC_SUPABASE_* env vars."
        : null;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    if (
      params.error === "forbidden" &&
      (await isOrgAdmin(supabase, user.id))
    ) {
      redirect("/admin");
    }
  }

  const signedInEmail = user?.email ?? null;
  const showAdminDashboardLink = user
    ? await isOrgAdmin(supabase, user.id)
    : false;

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-zinc-50 px-4 dark:bg-zinc-950">
      <LoginForm
        signedInEmail={signedInEmail}
        showAdminDashboardLink={showAdminDashboardLink}
        showForbiddenMessage={params.error === "forbidden"}
        authErrorMessage={authErrorMessage}
      />
    </div>
  );
}

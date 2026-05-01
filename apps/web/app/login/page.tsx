import { LoginForm } from "@/components/admin/login-form";
import type { Metadata } from "next";

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

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-zinc-50 px-4 dark:bg-zinc-950">
      <LoginForm
        showForbiddenMessage={params.error === "forbidden"}
        authErrorMessage={authErrorMessage}
      />
    </div>
  );
}

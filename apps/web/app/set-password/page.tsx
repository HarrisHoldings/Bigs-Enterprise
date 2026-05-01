import { SetPasswordForm } from "@/components/auth/set-password-form";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Set password",
  description: "Set or update your password",
};

export default function SetPasswordPage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-zinc-50 px-4 py-12 dark:bg-zinc-950">
      <SetPasswordForm />
    </div>
  );
}

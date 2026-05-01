"use client";

import { ensureUserProfile } from "@/lib/auth/ensure-user-profile";
import { createClient } from "@/lib/supabase/client";
import Link from "next/link";
import { useState } from "react";

const inputClass =
  "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 outline-none ring-offset-white focus-visible:ring-2 focus-visible:ring-zinc-950 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50 dark:ring-offset-zinc-950 dark:focus-visible:ring-zinc-300";

export function SignUpForm() {
  const [displayName, setDisplayName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);

    if (password !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }
    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      return;
    }

    setLoading(true);
    const supabase = createClient();

    const redirectUrl = `${window.location.origin}/auth/callback?next=/`;

    const { data, error: signUpError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: redirectUrl,
        data: {
          full_name: displayName.trim() || undefined,
        },
      },
    });

    if (signUpError) {
      setLoading(false);
      const msg = signUpError.message;
      setError(
        /database error/i.test(msg)
          ? `${msg} Open Supabase → Logs (Postgres / Auth) for the underlying error and apply any pending migrations in supabase/migrations.`
          : msg
      );
      return;
    }

    if (data.session && data.user) {
      const profileResult = await ensureUserProfile(supabase, data.user, {
        skipIfExists: true,
      });
      if (profileResult) {
        setLoading(false);
        setError(profileResult.error.message);
        return;
      }
      await supabase.auth.getSession();
      window.location.assign("/");
      return;
    }

    setLoading(false);
    setInfo(
      "Check your email for a confirmation link, then sign in. Admin access is granted only by your organization."
    );
  }

  return (
    <div className="mx-auto w-full max-w-sm space-y-6 rounded-lg border border-zinc-200 bg-white p-8 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
      <div>
        <h1 className="text-xl font-semibold text-zinc-900 dark:text-zinc-50">
          Create account
        </h1>
        <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
          Customer sign up. Admin users are invited separately by your
          organization.
        </p>
      </div>
      {info ? (
        <p className="rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-900 dark:border-emerald-900/50 dark:bg-emerald-950/40 dark:text-emerald-200">
          {info}{" "}
          <Link
            href="/login"
            className="font-medium underline underline-offset-2"
          >
            Sign in
          </Link>
        </p>
      ) : null}
      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="space-y-1.5">
          <label
            htmlFor="su-name"
            className="text-sm font-medium text-zinc-700 dark:text-zinc-300"
          >
            Display name{" "}
            <span className="font-normal text-zinc-500">(optional)</span>
          </label>
          <input
            id="su-name"
            name="displayName"
            type="text"
            autoComplete="name"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            className={inputClass}
          />
        </div>
        <div className="space-y-1.5">
          <label
            htmlFor="su-email"
            className="text-sm font-medium text-zinc-700 dark:text-zinc-300"
          >
            Email
          </label>
          <input
            id="su-email"
            name="email"
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className={inputClass}
          />
        </div>
        <div className="space-y-1.5">
          <label
            htmlFor="su-password"
            className="text-sm font-medium text-zinc-700 dark:text-zinc-300"
          >
            Password
          </label>
          <input
            id="su-password"
            name="password"
            type="password"
            autoComplete="new-password"
            required
            minLength={6}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className={inputClass}
          />
        </div>
        <div className="space-y-1.5">
          <label
            htmlFor="su-confirm"
            className="text-sm font-medium text-zinc-700 dark:text-zinc-300"
          >
            Confirm password
          </label>
          <input
            id="su-confirm"
            name="confirmPassword"
            type="password"
            autoComplete="new-password"
            required
            minLength={6}
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            className={inputClass}
          />
        </div>
        {error ? (
          <p className="text-sm text-red-600 dark:text-red-400" role="alert">
            {error}
          </p>
        ) : null}
        <button
          type="submit"
          disabled={loading || !!info}
          className="flex w-full items-center justify-center rounded-md bg-zinc-900 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-900 dark:hover:bg-zinc-200"
        >
          {loading ? "Creating account…" : "Sign up"}
        </button>
      </form>
      <p className="text-center text-sm text-zinc-600 dark:text-zinc-400">
        Organization admin?{" "}
        <Link
          href="/login"
          className="font-medium text-zinc-900 underline underline-offset-2 dark:text-zinc-50"
        >
          Admin sign in
        </Link>
      </p>
    </div>
  );
}

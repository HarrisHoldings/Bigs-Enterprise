import { isOrgAdmin } from "@/lib/auth/is-org-admin";
import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  });

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    return supabaseResponse;
  }

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value)
        );
        supabaseResponse = NextResponse.next({
          request,
        });
        cookiesToSet.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(name, value, options)
        );
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const path = request.nextUrl.pathname;
  const isHome = path === "/" || path === "";
  const isLegacyAdminLogin =
    path === "/admin/login" || path.startsWith("/admin/login/");
  const isSignup = path === "/signup";
  const isForgotPassword = path === "/forgot-password";
  const isAdminArea = path === "/admin" || path.startsWith("/admin/");

  function withSessionCookies(redirectResponse: NextResponse) {
    supabaseResponse.headers.forEach((value, key) => {
      if (key.toLowerCase() === "set-cookie") {
        redirectResponse.headers.append(key, value);
      }
    });
    return redirectResponse;
  }

  if (isLegacyAdminLogin) {
    const target = request.nextUrl.clone();
    target.pathname = "/login";
    return withSessionCookies(NextResponse.redirect(target));
  }

  if (isAdminArea && !user) {
    return withSessionCookies(
      NextResponse.redirect(new URL("/login", request.url))
    );
  }

  if (isHome && user && (await isOrgAdmin(supabase, user.id))) {
    return withSessionCookies(
      NextResponse.redirect(new URL("/admin", request.url))
    );
  }

  if (isSignup && user) {
    const dest = (await isOrgAdmin(supabase, user.id)) ? "/admin" : "/";
    return withSessionCookies(
      NextResponse.redirect(new URL(dest, request.url))
    );
  }

  if (isForgotPassword && user) {
    const dest = (await isOrgAdmin(supabase, user.id)) ? "/admin" : "/";
    return withSessionCookies(
      NextResponse.redirect(new URL(dest, request.url))
    );
  }

  /**
   * Do not redirect away from `/login` when already signed in. Logged-in users
   * who open "Go to login" from `/` otherwise get bounced straight back home.
   */

  return supabaseResponse;
}

export const config = {
  matcher: [
    "/",
    "/admin/:path*",
    "/login",
    "/signup",
    "/forgot-password",
    "/set-password",
  ],
};

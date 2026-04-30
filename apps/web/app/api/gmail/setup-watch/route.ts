import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { google, type gmail_v1 } from "googleapis";
import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

/**
 * Registers Gmail push notifications via Cloud Pub/Sub (users.watch).
 * Run after deploying the push endpoint and granting publish from
 * gmail-api-push@system.gserviceaccount.com on the topic.
 *
 * Env:
 * - GMAIL_WATCH_EMAIL — mailbox to watch (must match webhook checks)
 * - GMAIL_PUBSUB_TOPIC — full topic name, e.g. projects/my-proj/topics/gmail-push
 * - GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN
 * - NEXT_PUBLIC_APP_URL — OAuth redirect base (fallback http://localhost:3000)
 * - NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 * Optional: GMAIL_SETUP_WATCH_SECRET — if set, require header x-gmail-setup-secret
 */

let supabaseSingleton: SupabaseClient<any> | null = null;

function getSupabase(): SupabaseClient<any> {
  if (!supabaseSingleton) {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) {
      throw new Error(
        "NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required"
      );
    }
    supabaseSingleton = createClient(url, key) as SupabaseClient<any>;
  }
  return supabaseSingleton;
}

async function getGmailClient(): Promise<gmail_v1.Gmail> {
  const baseUrl =
    process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
  const auth = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    `${baseUrl.replace(/\/$/, "")}/api/auth/callback/google`
  );

  auth.setCredentials({
    refresh_token: process.env.GOOGLE_REFRESH_TOKEN,
  });

  return google.gmail({ version: "v1", auth });
}

function assertAuthorized(req: NextRequest): NextResponse | null {
  const secret = process.env.GMAIL_SETUP_WATCH_SECRET;
  if (!secret) return null;
  const header = req.headers.get("x-gmail-setup-secret");
  if (header !== secret) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  return null;
}

export async function GET() {
  return NextResponse.json({
    ok: true,
    path: "gmail/setup-watch",
    method: "POST to register Gmail users.watch on your Pub/Sub topic",
  });
}

export async function POST(req: NextRequest) {
  const denied = assertAuthorized(req);
  if (denied) return denied;

  const watchEmail = process.env.GMAIL_WATCH_EMAIL;
  const topicName = process.env.GMAIL_PUBSUB_TOPIC?.trim();

  if (!watchEmail) {
    return NextResponse.json(
      { error: "GMAIL_WATCH_EMAIL is not set" },
      { status: 500 }
    );
  }
  if (!topicName) {
    return NextResponse.json(
      {
        error:
          "GMAIL_PUBSUB_TOPIC is not set (use full name: projects/PROJECT_ID/topics/TOPIC_ID)",
      },
      { status: 500 }
    );
  }

  if (
    !process.env.GOOGLE_CLIENT_ID ||
    !process.env.GOOGLE_CLIENT_SECRET ||
    !process.env.GOOGLE_REFRESH_TOKEN
  ) {
    return NextResponse.json(
      {
        error:
          "Missing GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, or GOOGLE_REFRESH_TOKEN",
      },
      { status: 500 }
    );
  }

  try {
    const gmail = await getGmailClient();

    const profile = await gmail.users.getProfile({ userId: "me" });
    const mailbox = profile.data.emailAddress?.toLowerCase();
    if (mailbox && mailbox !== watchEmail.toLowerCase()) {
      return NextResponse.json(
        {
          error:
            "OAuth token mailbox does not match GMAIL_WATCH_EMAIL",
          tokenMailbox: profile.data.emailAddress,
          expected: watchEmail,
        },
        { status: 400 }
      );
    }

    const { data, status } = await gmail.users.watch({
      userId: "me",
      requestBody: {
        topicName,
        labelIds: ["INBOX"],
        labelFilterAction: "include",
      },
    });

    if (status !== 200 || !data?.historyId) {
      console.error("users.watch unexpected response:", status, data);
      return NextResponse.json(
        { error: "Failed to register watch" },
        { status: 502 }
      );
    }

    const historyId = String(data.historyId);
    const expiration =
      data.expiration != null ? String(data.expiration) : null;

    const supabase = getSupabase();
    const { error: upsertError } = await supabase
      .from("gmail_sync_state")
      .upsert(
        {
          watch_email: watchEmail,
          last_history_id: historyId,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "watch_email" }
      );

    if (upsertError) {
      console.error("gmail_sync_state upsert:", upsertError);
      return NextResponse.json(
        {
          warning: "Watch registered but failed to save historyId to database",
          historyId,
          expiration,
          topicName,
        },
        { status: 207 }
      );
    }

    return NextResponse.json({
      ok: true,
      watchEmail,
      topicName,
      historyId,
      expiration,
      expiresAtMs: expiration,
    });
  } catch (err) {
    console.error("setup-watch error:", err);
    const message = err instanceof Error ? err.message : String(err);
    let hint: string | undefined;
    if (message === "deleted_client") {
      hint =
        "The Google OAuth client was deleted or GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET no longer match this refresh token. Create credentials in Google Cloud Console, update those env vars, then issue a new refresh token for the same Google account.";
    } else if (
      message.includes("invalid_grant") ||
      message.includes("Invalid Credentials")
    ) {
      hint =
        "Refresh token may be revoked or issued for a different OAuth client. Re-run your OAuth consent flow and set GOOGLE_REFRESH_TOKEN again.";
    } else if (
      message.includes("Resource not found") &&
      message.includes("topics")
    ) {
      hint =
        "Pub/Sub topic not found in this project, or wrong project id. Create the topic (e.g. gcloud pubsub topics create ...) and use projects/PROJECT_ID/topics/TOPIC_ID.";
    } else if (
      message.includes("Cloud PubSub") ||
      message.includes("User not authorized")
    ) {
      hint =
        "Grant the Gmail push service account permission to publish: add role Pub/Sub Publisher on this topic for gmail-api-push@system.gserviceaccount.com (see Gmail API push setup).";
    }

    return NextResponse.json(
      {
        error: "Gmail watch registration failed",
        message,
        ...(hint && { hint }),
      },
      { status: 500 }
    );
  }
}

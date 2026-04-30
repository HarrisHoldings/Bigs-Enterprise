import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { google, type gmail_v1 } from "googleapis";
import { PDFParse } from "pdf-parse";
import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

// ============================================================
// LITTLE BIGS POS — Gmail Webhook Receiver
// Fires when a new email arrives at orders@littlebigs.pizza
// Looks for Performance Foodservice invoice PDFs
// Parses each line item and updates ingredients table
// ============================================================

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

const VENDOR_EMAIL_DOMAIN = "performancefoodservice.com";
const VENDOR_CUSTOMER_NUMBER = "55090819";

type InvoiceLineItem = {
  vendorSku: string;
  qtyOrdered: number;
  qtyShipped: number;
  description: string;
  unitPrice: number;
  extension: number;
};

type ParsedInvoice = {
  invoiceNumber: string;
  invoiceDate: string;
  lineItems: InvoiceLineItem[];
};

type ProcessResult = {
  invoiceNumber: string;
  invoiceDate: string;
  purchaseOrderId: string;
  updatedItems: Array<{
    sku: string;
    name: string;
    oldCost: number | null;
    newCost: number;
    priceChanged: boolean;
    ozReceived: number;
  }>;
  unmatchedSkus: string[];
  total: number;
};

// ============================================================
// POST — receives Gmail Pub/Sub push notification
// ============================================================
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const message = body?.message;
    if (!message?.data) {
      return NextResponse.json({ error: "No message data" }, { status: 400 });
    }

    const decoded = Buffer.from(message.data, "base64").toString("utf-8");
    const notification = JSON.parse(decoded) as {
      emailAddress?: string;
      historyId?: string | number;
    };

    const { emailAddress, historyId } = notification;
    const historyIdStr =
      historyId != null ? String(historyId) : null;

    if (
      !emailAddress ||
      emailAddress !== process.env.GMAIL_WATCH_EMAIL ||
      !historyIdStr
    ) {
      return NextResponse.json(
        { error: "Wrong email address or missing historyId" },
        { status: 400 }
      );
    }

    const gmail = await getGmailClient();

    const supabase = getSupabase();

    const { data: syncRow } = await supabase
      .from("gmail_sync_state")
      .select("last_history_id")
      .eq("watch_email", emailAddress)
      .maybeSingle();

    let startHistoryId = syncRow?.last_history_id as string | undefined;
    if (!startHistoryId) {
      try {
        const b = BigInt(historyIdStr);
        const zero = BigInt(0);
        const one = BigInt(1);
        startHistoryId =
          b > zero ? (b - one).toString() : historyIdStr;
      } catch {
        startHistoryId = historyIdStr;
      }
    }

    const messages = await getNewMessageIds(gmail, startHistoryId);
    const uniqueIds = [...new Set(messages)];

    const results: ProcessResult[] = [];

    for (const id of uniqueIds) {
      const result = await processMessage(gmail, id);
      if (result) results.push(result);
    }

    await supabase.from("gmail_sync_state").upsert(
      {
        watch_email: emailAddress,
        last_history_id: historyIdStr,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "watch_email" }
    );

    return NextResponse.json({
      processed: results.length,
      results,
      messagesChecked: uniqueIds.length,
    });
  } catch (error) {
    console.error("Gmail webhook error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}

export async function GET() {
  return NextResponse.json({ ok: true, path: "gmail-webhook" });
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

async function getNewMessageIds(
  gmail: gmail_v1.Gmail,
  startHistoryId: string
): Promise<string[]> {
  const messageIds: string[] = [];
  let pageToken: string | undefined;

  try {
    do {
      const response = await gmail.users.history.list({
        userId: "me",
        startHistoryId,
        historyTypes: ["messageAdded"],
        labelId: "INBOX",
        pageToken,
      });

      const history = response.data.history ?? [];
      for (const record of history) {
        for (const msg of record.messagesAdded ?? []) {
          const id = msg.message?.id;
          if (id) messageIds.push(id);
        }
      }
      pageToken = response.data.nextPageToken ?? undefined;
    } while (pageToken);
  } catch (err: unknown) {
    const gErr = err as { code?: number };
    if (gErr.code === 404) {
      console.error(
        "Gmail history.list: startHistoryId expired or invalid — reset gmail_sync_state and renew watch"
      );
      return [];
    }
    throw err;
  }

  return messageIds;
}

async function processMessage(
  gmail: gmail_v1.Gmail,
  messageId: string
): Promise<ProcessResult | null> {
  const full = await gmail.users.messages.get({
    userId: "me",
    id: messageId,
    format: "full",
  });

  const headers = full.data.payload?.headers ?? [];
  const from =
    headers.find((h) => h.name?.toLowerCase() === "from")?.value ?? "";

  if (!from.toLowerCase().includes(VENDOR_EMAIL_DOMAIN)) {
    return null;
  }

  console.log(`Processing Performance Foodservice email: ${messageId}`);

  const pdfAttachment = findPDFAttachment(full.data.payload);

  if (!pdfAttachment?.attachmentId) {
    console.log("No PDF attachment found");
    return null;
  }

  const attachmentData = await gmail.users.messages.attachments.get({
    userId: "me",
    messageId,
    id: pdfAttachment.attachmentId,
  });

  const raw = attachmentData.data.data;
  if (!raw) {
    console.log("Empty attachment body");
    return null;
  }

  const pdfBuffer = Buffer.from(
    raw.replace(/-/g, "+").replace(/_/g, "/"),
    "base64"
  );

  const invoiceData = await parsePerformanceInvoice(pdfBuffer);

  if (!invoiceData) {
    console.log("Failed to parse invoice");
    return null;
  }

  return updateInventoryFromInvoice(invoiceData);
}

function findPDFAttachment(
  payload: gmail_v1.Schema$MessagePart | undefined
): { attachmentId?: string | null; filename?: string } | null {
  const walk = (
    part: gmail_v1.Schema$MessagePart | undefined
  ): gmail_v1.Schema$MessagePart | null => {
    if (!part) return null;
    const mime = part.mimeType ?? "";
    const name = part.filename ?? "";
    if (
      mime === "application/pdf" ||
      name.toLowerCase().endsWith(".pdf")
    ) {
      return part;
    }
    for (const p of part.parts ?? []) {
      const found = walk(p);
      if (found) return found;
    }
    return null;
  };

  const part = walk(payload);
  if (!part?.body?.attachmentId) return null;
  return {
    attachmentId: part.body.attachmentId,
    filename: part.filename ?? undefined,
  };
}

async function parsePerformanceInvoice(
  pdfBuffer: Buffer
): Promise<ParsedInvoice | null> {
  const parser = new PDFParse({ data: pdfBuffer });
  try {
    const data = await parser.getText();
    const text = data.text;

    const invoiceMatch =
      text.match(/INVOICE NO\.\s*(\d+)/) ||
      text.match(/Invoice[:\s]+(\d{7,})/i);
    const invoiceNumber = invoiceMatch?.[1] ?? "UNKNOWN";

    const dateMatch = text.match(/(\d{1,2}\/\d{1,2}\/\d{2,4})/);
    const invoiceDate =
      dateMatch?.[1] ?? new Date().toLocaleDateString("en-US");

    const lineItems = parseLineItems(text);

    if (lineItems.length === 0) {
      console.log("No line items parsed from invoice");
      return null;
    }

    return {
      invoiceNumber,
      invoiceDate,
      lineItems,
    };
  } finally {
    await parser.destroy();
  }
}

function parseLineItems(text: string): InvoiceLineItem[] {
  const items: InvoiceLineItem[] = [];
  const lines = text.split("\n");
  const itemLineRegex =
    /^\s*(\d{5,7})\s+(\d+)\s+(\d+)\s+(.+?)\s+([\d.]+)\s+([\d.]+)\s*$/;

  for (const line of lines) {
    const match = line.match(itemLineRegex);
    if (match) {
      const [, itemNum, ordered, shipped, description, unitPrice, extension] =
        match;
      if (
        description.includes("FUEL") ||
        description.includes("TAX")
      ) {
        continue;
      }
      items.push({
        vendorSku: itemNum.trim(),
        qtyOrdered: parseFloat(ordered),
        qtyShipped: parseFloat(shipped),
        description: description.trim(),
        unitPrice: parseFloat(unitPrice),
        extension: parseFloat(extension),
      });
    }
  }

  return items;
}

async function updateInventoryFromInvoice(
  invoiceData: ParsedInvoice
): Promise<ProcessResult | null> {
  const { invoiceNumber, invoiceDate, lineItems } = invoiceData;

  const supabase = getSupabase();

  const { data: vendor } = await supabase
    .from("vendors")
    .select("id")
    .eq("customer_number", VENDOR_CUSTOMER_NUMBER)
    .maybeSingle();

  if (!vendor?.id) {
    console.error("Vendor not found");
    return null;
  }

  const { data: po, error: poError } = await supabase
    .from("purchase_orders")
    .insert({
      vendor_id: vendor.id,
      invoice_number: invoiceNumber,
      invoice_date: invoiceDate,
      status: "received",
      received_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (poError) {
    console.error("Error creating purchase order:", poError);
    return null;
  }

  const updatedItems: ProcessResult["updatedItems"] = [];
  const unmatchedSkus: string[] = [];

  for (const item of lineItems) {
    const { data: ingredient } = await supabase
      .from("ingredients")
      .select("id, name, cost_per_oz, on_hand_oz, purchase_unit_oz")
      .eq("vendor_sku", item.vendorSku)
      .maybeSingle();

    if (!ingredient) {
      unmatchedSkus.push(item.vendorSku);
      continue;
    }

    const purchaseUnitOz = Number(ingredient.purchase_unit_oz ?? 0);
    const newCostPerOz =
      purchaseUnitOz > 0
        ? item.unitPrice / purchaseUnitOz
        : Number(ingredient.cost_per_oz ?? 0);

    const oldCost = ingredient.cost_per_oz != null
      ? Number(ingredient.cost_per_oz)
      : null;
    const priceChanged =
      oldCost != null
        ? Math.abs(newCostPerOz - oldCost) > 0.0001
        : true;

    const ozReceived = item.qtyShipped * (purchaseUnitOz || 0);

    const { error: updateError } = await supabase
      .from("ingredients")
      .update({
        cost_per_oz: newCostPerOz,
        case_cost: item.unitPrice,
        on_hand_oz: Number(ingredient.on_hand_oz ?? 0) + ozReceived,
        updated_at: new Date().toISOString(),
      })
      .eq("id", ingredient.id);

    if (updateError) {
      console.error(
        `Error updating ingredient ${ingredient.name}:`,
        updateError
      );
      continue;
    }

    updatedItems.push({
      sku: item.vendorSku,
      name: ingredient.name,
      oldCost,
      newCost: newCostPerOz,
      priceChanged,
      ozReceived,
    });
  }

  const subtotal = lineItems.reduce((sum, item) => sum + item.extension, 0);

  await supabase
    .from("purchase_orders")
    .update({ total: subtotal, subtotal })
    .eq("id", po.id);

  console.log(`Invoice ${invoiceNumber} processed:`);
  console.log(`  Updated: ${updatedItems.length} ingredients`);
  console.log(`  Unmatched SKUs: ${unmatchedSkus.length}`);

  return {
    invoiceNumber,
    invoiceDate,
    purchaseOrderId: po.id,
    updatedItems,
    unmatchedSkus,
    total: subtotal,
  };
}

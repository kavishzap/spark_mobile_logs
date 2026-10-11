import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { timingSafeEqual } from "node:crypto";
import { createClient } from "npm:@supabase/supabase-js@2";
import bcrypt from "npm:bcryptjs@2.4.3";
import { adminClient } from "../_shared/auth.ts";
import { corsHeaders, failure, HttpError, json } from "../_shared/http.ts";
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed", message: "Use POST." });
  }

  try {
    const body = await req.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new HttpError(400, "invalid_body", "Sign-in body must be an object.");
    }
    const record = body as Record<string, unknown>;
    const email = String(record.email ?? "").trim();
    const password = String(record.password ?? "");
    if (!email.includes("@") || email.length > 320 || password.length === 0) {
      throw new HttpError(401, "invalid_credentials", "Email or password is incorrect.");
    }

    const admin = adminClient();
    const found = await admin
      .from("sales_assistants")
      .select("id, full_name, email, is_active, password")
      .ilike("email", email)
      .limit(20);
    if (found.error) throw found.error;
    const matches = (found.data ?? []).filter((row) =>
      String(row.email ?? "").trim().toLowerCase() === email.toLowerCase()
    );
    if (matches.length > 1) {
      throw new HttpError(
        403,
        "assistant_not_found",
        "More than one assistant uses this email. Contact your administrator.",
      );
    }
    if (matches.length !== 1) {
      throw new HttpError(401, "invalid_credentials", "Email or password is incorrect.");
    }
    const assistant = matches[0];
    if (!passwordsMatch(assistant.password, password)) {
      throw new HttpError(401, "invalid_credentials", "Email or password is incorrect.");
    }
    if (assistant.is_active !== true) {
      throw new HttpError(
        403,
        "assistant_inactive",
        "This sales assistant account is inactive. Contact your administrator.",
      );
    }

    const session = await openSession(admin, String(assistant.id));
    return json(200, {
      ...session,
      full_name: String(assistant.full_name ?? ""),
    });
  } catch (error) {
    return failure(error);
  }
});

function passwordsMatch(stored: unknown, given: string): boolean {
  const value = typeof stored === "string" ? stored : "";
  if (value.length === 0) return false;
  if (/^\$2[aby]\$/.test(value)) {
    return bcrypt.compareSync(given, value);
  }
  const left = new TextEncoder().encode(value);
  const right = new TextEncoder().encode(given);
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

async function openSession(
  admin: ReturnType<typeof adminClient>,
  assistantId: string,
): Promise<{ access_token: string; refresh_token: string; expires_in: number }> {
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) {
    throw new HttpError(500, "server_error", "Sync is not configured.");
  }
  const email = `assistant.${assistantId}@assistants.spark.app`;
  const oneTime = `${crypto.randomUUID()}${crypto.randomUUID()}`;
  const created = await admin.auth.admin.createUser({
    id: assistantId,
    email,
    password: oneTime,
    email_confirm: true,
    app_metadata: { assistant_id: assistantId },
  });
  if (created.error) {
    const duplicate = /already|exists|registered|duplicate/i.test(created.error.message ?? "");
    if (!duplicate) throw created.error;
    const updated = await admin.auth.admin.updateUserById(assistantId, {
      password: oneTime,
      email_confirm: true,
      app_metadata: { assistant_id: assistantId },
    });
    if (updated.error) throw updated.error;
  }

  const anon = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const signed = await anon.auth.signInWithPassword({ email, password: oneTime });
  const session = signed.data.session;
  if (signed.error || !session) {
    throw signed.error ?? new HttpError(500, "server_error", "Sign-in could not be completed.");
  }
  return {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_in: session.expires_in ?? 3600,
  };
}

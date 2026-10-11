import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, assistantIdFromUser, requireUser } from "../_shared/auth.ts";
import { corsHeaders, failure, HttpError, json } from "../_shared/http.ts";
import {
  clientSuppliedIdentity,
  evaluateSyncAccess,
  validateCall,
  type AssistantAccess,
  type DeviceAccess,
} from "../_shared/policy.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed", message: "Use POST." });
  }

  try {
    const user = await requireUser(req);
    const body = await req.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new HttpError(400, "invalid_body", "Sync body must be an object.");
    }
    const record = body as Record<string, unknown>;
    if (clientSuppliedIdentity(record)) {
      throw new HttpError(
        400,
        "untrusted_identity_fields",
        "sales_assistant_id must not be supplied. It is taken from the registered device.",
      );
    }

    const deviceId = String(record.device_id ?? "");
    if (!/^[0-9a-f-]{36}$/i.test(deviceId)) {
      throw new HttpError(400, "invalid_device_id", "device_id must be the registered device UUID.");
    }
    if (!Array.isArray(record.calls)) {
      throw new HttpError(400, "invalid_body", "calls must be an array.");
    }
    if (record.calls.length > 100) {
      throw new HttpError(400, "batch_too_large", "Send at most 100 calls at a time.");
    }

    const admin = adminClient();
    const deviceResult = await admin
      .from("sales_assistant_devices")
      .select("*")
      .eq("id", deviceId)
      .maybeSingle();
    if (deviceResult.error) throw deviceResult.error;

    const deviceRow = deviceResult.data;
    let assistantRow: Record<string, unknown> | null = null;
    if (deviceRow) {
      const assistantResult = await admin
        .from("sales_assistants")
        .select("*")
        .eq("id", deviceRow.sales_assistant_id)
        .maybeSingle();
      if (assistantResult.error) throw assistantResult.error;
      assistantRow = assistantResult.data;
    }

    const access = evaluateSyncAccess({
      jwtUserId: user.id,
      boundAssistantId: assistantIdFromUser(user),
      assistant: assistantRow ? toAssistant(assistantRow) : null,
      device: deviceRow ? toDevice(deviceRow) : null,
      requestedDeviceId: deviceId,
    });
    if (!access.ok) {
      throw new HttpError(403, access.code, access.message);
    }

    const now = new Date();
    const accepted: Record<string, unknown>[] = [];
    const rejected: { android_call_id: string; reason: string }[] = [];
    const seen = new Set<string>();
    for (const item of record.calls) {
      if (!item || typeof item !== "object" || Array.isArray(item)) {
        rejected.push({ android_call_id: "", reason: "invalid_record" });
        continue;
      }
      const call = item as Record<string, unknown>;
      const reason = validateCall(call, now);
      const androidCallId = String(call.android_call_id ?? "");
      if (reason) {
        rejected.push({ android_call_id: androidCallId, reason });
        continue;
      }
      if (seen.has(androidCallId)) {
        continue;
      }
      seen.add(androidCallId);
      accepted.push({
        sales_assistant_id: access.salesAssistantId,
        device_id: access.deviceId,
        android_call_id: androidCallId,
        phone_number: String(call.phone_number),
        call_type: String(call.call_type),
        call_date: new Date(String(call.call_date)).toISOString(),
        duration_seconds: call.duration_seconds,
        synced_at: now.toISOString(),
      });
    }

    if (accepted.length > 0) {
      const upsert = await admin.from("call_logs").upsert(accepted, {
        onConflict: "device_id,android_call_id",
      });
      if (upsert.error) throw upsert.error;
    }

    const touched = await admin
      .from("sales_assistant_devices")
      .update({ last_sync_at: now.toISOString() })
      .eq("id", access.deviceId);
    if (touched.error) throw touched.error;

    const audit = await admin.from("call_sync_audit").insert({
      sales_assistant_id: access.salesAssistantId,
      device_id: access.deviceId,
      actor_user_id: user.id,
      event_type: "sync_call_logs",
      record_count: record.calls.length,
      accepted_count: accepted.length,
      rejected_count: rejected.filter((item) => item.android_call_id).length,
      details: { rejected },
    });
    if (audit.error) {
      console.error("call_sync_audit insert failed", audit.error);
    }

    return json(200, {
      acknowledged: accepted.map((row) => row.android_call_id),
      rejected: rejected.filter((item) => item.android_call_id),
      server_time: now.toISOString(),
    });
  } catch (error) {
    return failure(error);
  }
});

function toAssistant(row: Record<string, unknown>): AssistantAccess {
  return {
    id: String(row.id),
    isActive: row.is_active === true,
  };
}

function toDevice(row: Record<string, unknown>): DeviceAccess {
  return {
    id: String(row.id),
    salesAssistantId: String(row.sales_assistant_id),
    isActive: row.is_active === true,
  };
}

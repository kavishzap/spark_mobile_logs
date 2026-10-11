import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, assistantIdFromUser, requireUser } from "../_shared/auth.ts";
import { corsHeaders, failure, HttpError, json } from "../_shared/http.ts";
import {
  evaluateEnrollment,
  namesMatch,
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
      throw new HttpError(400, "invalid_body", "Enrollment body must be an object.");
    }
    const record = body as Record<string, unknown>;
    if ("company_id" in record || "sales_assistant_id" in record) {
      throw new HttpError(
        400,
        "untrusted_identity_fields",
        "sales_assistant_id is derived on the server from the signed-in name and email.",
      );
    }

    const fullName = String(record.full_name ?? "").trim().replace(/\s+/g, " ");
    if (fullName.length < 2 || fullName.length > 120) {
      throw new HttpError(400, "invalid_full_name", "Enter the name on your sales assistant profile.");
    }
    const deviceName = clip(record.device_name, 120, "Phone");
    const deviceModel = clip(record.device_model, 120, "Unknown");
    const androidVersion = clip(record.android_version, 32, "Unknown");
    const appVersion = clip(record.app_version, 32, "Unknown");

    const admin = adminClient();
    const assistantRow = await findAssistant(admin, assistantIdFromUser(user), fullName);
    if (!assistantRow) {
      throw new HttpError(
        403,
        "assistant_not_found",
        "This name and email are not linked to an active sales assistant.",
      );
    }

    const devices = await loadDevices(admin, String(assistantRow.id));
    const decision = evaluateEnrollment({
      assistant: toAssistant(assistantRow),
      devices,
      jwtUserId: user.id,
      boundAssistantId: assistantIdFromUser(user),
    });
    if (!decision.ok) {
      throw new HttpError(403, decision.code, decision.message);
    }

    const device = decision.createDevice
      ? await insertDevice(admin, {
        salesAssistantId: String(assistantRow.id),
        deviceName,
        deviceModel,
        androidVersion,
        appVersion,
      })
      : await updateDevice(admin, decision.deviceId!, {
        deviceName,
        deviceModel,
        androidVersion,
        appVersion,
      });

    return json(200, {
      assistant: {
        id: assistantRow.id,
        full_name: assistantRow.full_name,
        email: assistantRow.email,
        phone_number: assistantRow.phone_number,
        is_active: assistantRow.is_active,
      },
      device: {
        id: device.id,
        device_name: device.device_name,
        device_model: device.device_model,
        android_version: device.android_version,
        app_version: device.app_version,
        is_active: device.is_active,
        last_sync_at: device.last_sync_at,
      },
    });
  } catch (error) {
    return failure(error);
  }
});

function clip(value: unknown, max: number, fallback: string): string {
  const text = String(value ?? "").trim();
  const chosen = text.length === 0 ? fallback : text;
  return chosen.slice(0, max);
}

async function findAssistant(
  admin: ReturnType<typeof adminClient>,
  assistantId: string,
  fullName: string,
): Promise<Record<string, unknown> | null> {
  if (!assistantId) return null;
  const byId = await admin
    .from("sales_assistants")
    .select("id, full_name, email, phone_number, is_active")
    .eq("id", assistantId)
    .maybeSingle();
  if (byId.error) throw byId.error;
  if (!byId.data) return null;
  if (!namesMatch(byId.data.full_name, fullName)) {
    throw new HttpError(
      403,
      "name_mismatch",
      "The name does not match this sales assistant.",
    );
  }
  return byId.data;
}

async function loadDevices(
  admin: ReturnType<typeof adminClient>,
  assistantId: string,
): Promise<DeviceAccess[]> {
  const owned = await admin
    .from("sales_assistant_devices")
    .select("*")
    .eq("sales_assistant_id", assistantId)
    .order("created_at", { ascending: true });
  if (owned.error) throw owned.error;
  return (owned.data ?? []).map(toDevice);
}

async function insertDevice(
  admin: ReturnType<typeof adminClient>,
  input: {
    salesAssistantId: string;
    deviceName: string;
    deviceModel: string;
    androidVersion: string;
    appVersion: string;
  },
) {
  const { data, error } = await admin
    .from("sales_assistant_devices")
    .insert({
      sales_assistant_id: input.salesAssistantId,
      device_name: input.deviceName,
      device_model: input.deviceModel,
      android_version: input.androidVersion,
      app_version: input.appVersion,
      is_active: true,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

async function updateDevice(
  admin: ReturnType<typeof adminClient>,
  deviceId: string,
  input: {
    deviceName: string;
    deviceModel: string;
    androidVersion: string;
    appVersion: string;
  },
) {
  const { data, error } = await admin
    .from("sales_assistant_devices")
    .update({
      device_name: input.deviceName,
      device_model: input.deviceModel,
      android_version: input.androidVersion,
      app_version: input.appVersion,
    })
    .eq("id", deviceId)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

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

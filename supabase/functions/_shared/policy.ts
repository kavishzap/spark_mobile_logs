// Keep this decision table aligned with the Dart policies in
// lib/features/devices/domain/enrollment_policy.dart and
// lib/features/sync/domain/sync_access_policy.dart.

export interface AssistantAccess {
  id: string;
  isActive: boolean;
}

export interface DeviceAccess {
  id: string;
  salesAssistantId: string;
  isActive: boolean;
}

export type EnrollmentDecision =
  | { ok: true; createDevice: boolean; deviceId?: string }
  | { ok: false; code: string; message: string };

export function evaluateEnrollment(input: {
  assistant: AssistantAccess;
  devices: DeviceAccess[];
  jwtUserId: string;
  boundAssistantId: string;
}): EnrollmentDecision {
  if (!input.jwtUserId || !input.boundAssistantId) {
    return deny("unauthenticated", "Sign in before registering this phone.");
  }
  if (input.assistant.id !== input.boundAssistantId) {
    return deny(
      "identity_mismatch",
      "This sign-in does not match the registered assistant.",
    );
  }
  if (!input.assistant.isActive) {
    return deny(
      "assistant_inactive",
      "This sales assistant account is inactive. Contact your administrator.",
    );
  }

  const own = input.devices.filter((device) => device.salesAssistantId === input.assistant.id);
  if (own.length > 0) {
    const active = own.find((device) => device.isActive);
    const chosen = active ?? own[0];
    return { ok: true, createDevice: false, deviceId: chosen.id };
  }
  return { ok: true, createDevice: true };
}

export type SyncAccessDecision =
  | { ok: true; salesAssistantId: string; deviceId: string }
  | { ok: false; code: string; message: string };

export function evaluateSyncAccess(input: {
  jwtUserId: string;
  boundAssistantId: string;
  assistant: AssistantAccess | null;
  device: DeviceAccess | null;
  requestedDeviceId: string;
}): SyncAccessDecision {
  if (!input.jwtUserId || !input.boundAssistantId) {
    return deny("unauthenticated", "Sign in again to synchronize calls.");
  }
  if (!input.assistant) {
    return deny("assistant_not_found", "No sales assistant profile is linked to this sign-in.");
  }
  if (!input.assistant.isActive) {
    return deny("assistant_inactive", "This sales assistant account is inactive.");
  }
  if (input.assistant.id !== input.boundAssistantId) {
    return deny("identity_mismatch", "This sign-in does not match the registered assistant.");
  }
  if (!input.device || input.device.id !== input.requestedDeviceId) {
    return deny("device_not_assigned", "This phone is not the registered device.");
  }
  if (!input.device.isActive) {
    return deny("device_inactive", "This phone was deactivated.");
  }
  if (input.device.salesAssistantId !== input.assistant.id) {
    return deny("device_not_assigned", "This phone is not assigned to the signed-in assistant.");
  }
  return {
    ok: true,
    salesAssistantId: input.device.salesAssistantId,
    deviceId: input.device.id,
  };
}

export function clientSuppliedIdentity(body: Record<string, unknown>): boolean {
  return Object.prototype.hasOwnProperty.call(body, "company_id") ||
    Object.prototype.hasOwnProperty.call(body, "sales_assistant_id");
}

export function namesMatch(stored: unknown, submitted: string): boolean {
  const left = normalize(stored);
  const right = normalize(submitted);
  return left.length > 0 && left === right;
}

export function normalize(value: unknown): string {
  return String(value ?? "").trim().replace(/\s+/g, " ").toLocaleLowerCase();
}

const callIdPattern = /^[A-Za-z0-9_.:-]{1,128}$/;
const phonePattern = /^(unknown|private|\+?[0-9*#]{2,32})$/;
const callTypes = new Set(["incoming", "outgoing", "missed", "rejected", "blocked"]);

export function validateCall(
  call: Record<string, unknown>,
  now: Date,
): string | null {
  const androidCallId = String(call.android_call_id ?? "");
  const phoneNumber = String(call.phone_number ?? "");
  const callType = String(call.call_type ?? "");
  const duration = call.duration_seconds;
  if (!callIdPattern.test(androidCallId)) return "invalid_android_call_id";
  if (!phonePattern.test(phoneNumber)) return "invalid_phone_number";
  if (!callTypes.has(callType)) return "invalid_call_type";
  if (typeof duration !== "number" || !Number.isInteger(duration) || duration < 0 || duration > 86400) {
    return "invalid_duration";
  }
  const rawDate = String(call.call_date ?? "");
  const hasZone = rawDate.endsWith("Z") || rawDate.includes("+") || /-\d{2}:\d{2}$/.test(rawDate);
  const parsed = new Date(rawDate);
  if (!hasZone || Number.isNaN(parsed.getTime())) return "invalid_call_date";
  if (parsed.getTime() > now.getTime() + 5 * 60 * 1000) return "call_date_in_future";
  if (parsed.getTime() < now.getTime() - 366 * 24 * 60 * 60 * 1000) return "call_date_too_old";
  return null;
}

function deny(code: string, message: string): { ok: false; code: string; message: string } {
  return { ok: false, code, message };
}

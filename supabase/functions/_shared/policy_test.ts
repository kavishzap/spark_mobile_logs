import { assertEquals } from "jsr:@std/assert@1";
import {
  clientSuppliedIdentity,
  evaluateEnrollment,
  evaluateSyncAccess,
  namesMatch,
  validateCall,
  type AssistantAccess,
  type DeviceAccess,
} from "./policy.ts";

const assistant: AssistantAccess = {
  id: "assistant-a",
  isActive: true,
};

const device: DeviceAccess = {
  id: "device-a",
  salesAssistantId: "assistant-a",
  isActive: true,
};

Deno.test("inactive assistant cannot enroll", () => {
  const decision = evaluateEnrollment({
    assistant: { ...assistant, isActive: false },
    devices: [],
    jwtUserId: "user-a",
    boundAssistantId: "assistant-a",
  });
  assertEquals(decision.ok, false);
  if (!decision.ok) assertEquals(decision.code, "assistant_inactive");
});

Deno.test("an existing device is reused instead of inserting another", () => {
  const enrollment = evaluateEnrollment({
    assistant,
    devices: [{ ...device, isActive: false }, { ...device, id: "device-b", isActive: true }],
    jwtUserId: "user-a",
    boundAssistantId: "assistant-a",
  });
  assertEquals(enrollment.ok, true);
  if (enrollment.ok) {
    assertEquals(enrollment.createDevice, false);
    assertEquals(enrollment.deviceId, "device-b");
  }

  const sync = evaluateSyncAccess({
    jwtUserId: "user-a",
    boundAssistantId: "assistant-a",
    assistant,
    device: { ...device, isActive: false },
    requestedDeviceId: "device-a",
  });
  assertEquals(sync.ok, false);
  if (!sync.ok) assertEquals(sync.code, "device_inactive");
});

Deno.test("an existing active phone is reused", () => {
  const decision = evaluateEnrollment({
    assistant,
    devices: [device],
    jwtUserId: "user-a",
    boundAssistantId: "assistant-a",
  });
  assertEquals(decision.ok, true);
  if (decision.ok) {
    assertEquals(decision.createDevice, false);
    assertEquals(decision.deviceId, "device-a");
  }
});

Deno.test("sync stamps the registered assistant, not a client id", () => {
  const decision = evaluateSyncAccess({
    jwtUserId: "user-a",
    boundAssistantId: "assistant-a",
    assistant,
    device,
    requestedDeviceId: "device-a",
  });
  assertEquals(decision.ok, true);
  if (decision.ok) {
    assertEquals(decision.salesAssistantId, "assistant-a");
    assertEquals(decision.deviceId, "device-a");
  }
  assertEquals(clientSuppliedIdentity({ company_id: "company-b", device_id: "device-a" }), true);
  assertEquals(namesMatch("Asha Seller", " asha   seller "), true);
  assertEquals(namesMatch("Asha Seller", "Other Seller"), false);
});

Deno.test("a different assistant is rejected", () => {
  const decision = evaluateSyncAccess({
    jwtUserId: "user-a",
    boundAssistantId: "assistant-b",
    assistant,
    device,
    requestedDeviceId: "device-a",
  });
  assertEquals(decision.ok, false);
  if (!decision.ok) assertEquals(decision.code, "identity_mismatch");
});

Deno.test("validateCall rejects a future timestamp", () => {
  const reason = validateCall({
    android_call_id: "42",
    phone_number: "+23051234567",
    call_type: "outgoing",
    call_date: "2999-01-01T00:00:00Z",
    duration_seconds: 10,
  }, new Date("2026-10-11T00:00:00Z"));
  assertEquals(reason, "call_date_in_future");
});

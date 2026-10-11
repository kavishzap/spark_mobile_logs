import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2";
import { HttpError } from "./http.ts";

export function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    throw new HttpError(500, "server_error", "Sync is not configured.");
  }
  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function requireUser(req: Request): Promise<User> {
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authorization = req.headers.get("Authorization");
  if (!url || !anonKey || !authorization) {
    throw new HttpError(401, "unauthenticated", "Sign in again to continue.");
  }
  const client = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    throw new HttpError(401, "unauthenticated", "Sign in again to continue.");
  }
  return data.user;
}

export function assistantIdFromUser(user: User): string {
  const metadata = user.app_metadata ?? {};
  const value = metadata["assistant_id"];
  return typeof value === "string" ? value : "";
}

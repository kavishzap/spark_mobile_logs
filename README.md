# Spark Mauritius Sales Monitoring System

Flutter app for company-owned phones. Call-log collection runs on Android. The same app can be installed on an iPhone for sign-in and device registration, because iOS does not let apps read the cellular call log. A signed-in sales assistant registers that phone, grants call-log access after a written disclosure, and the app uploads normal cellular call metadata to the existing Supabase tables. A separate web back office reads those tables.

The app does not read WhatsApp, SMS, contact names, microphone audio, or call recordings. It does not keep a hidden foreground service and it does not try to bypass Android battery limits.

## What you need

- Flutter 3.44 or the current stable channel (this project was built with Flutter 3.44.4 / Dart 3.12)
- Android SDK, a device or emulator on Android 8 (API 26) or newer
- A Supabase project that already has `sales_assistants`, `sales_assistant_devices`, and `call_logs`
- The Supabase CLI if you want to deploy the Edge Functions from this repo

Do not put the service role key in the app. The phone uses only the anon (publishable) key. The Edge Functions hold the service role key, which Supabase injects in the function environment.

## Database migration

The existing tables are not recreated or renamed. One new migration adds the columns and controls the mobile client needs. **Read this section before you run it.**

File: `supabase/migrations/20261011120000_mobile_sync_security.sql`

It does three things:

1. Creates `call_sync_audit` for server-side sync audit rows. The mobile roles cannot read or write it.
2. Stops `anon` and `authenticated` from inserting, updating, or deleting `call_logs`. A trigger enforces the same rule. The web back office can keep selecting call logs through the policies you already have. Writes from the phone go through `sync-call-logs`, which uses the service role.
3. Lets a signed-in assistant read their own rows when the Auth email matches `sales_assistants.email`.

If the web back office currently inserts into `call_logs` with a signed-in user JWT, move that write to the service role or an Edge Function before you apply the migration. Selecting call logs is unchanged.

Apply it only after that check:

```bash
supabase db push
```

Or paste the file into the Supabase SQL editor.

The app does not read or write `company_id`. Sign-in uses `sales_assistants.email` and `sales_assistants.password`.

### Assistant

Insert the assistant row with the email and password they will type on the phone. The password can be the plain value they type, or a bcrypt hash.

```sql
insert into public.sales_assistants (full_name, email, password, phone_number, is_active)
values (
  'Asha Seller',
  'asha@company.com',
  'their-password',
  '+23051234567',
  true
);
```

To stop a phone:

```sql
update public.sales_assistant_devices
set is_active = false
where id = 'DEVICE_UUID';
```

To stop an employee:

```sql
update public.sales_assistants
set is_active = false
where id = 'ASSISTANT_UUID';
```

The next sync or sign-in then stops collection and clears the local queue. One active device row is kept per assistant. Signing in again updates that row. If every device for the assistant is inactive, sign-in stays blocked until you set `is_active` back to true.

## Edge Functions

`POST /functions/v1/enroll-device` checks the signed-in user, matches `full_name` and email to `sales_assistants`, and registers or refreshes the device. It rejects a client-supplied `sales_assistant_id`.

`POST /functions/v1/sync-call-logs` loads the device, checks that it belongs to the signed-in assistant, and upserts on `(device_id, android_call_id)`. `sales_assistant_id` on each call row comes from the device, not the client. `sales_assistant_devices.last_sync_at` is updated only after that upsert succeeds. The response lists acknowledged Android call ids.

Deploy both functions after the migration:

```bash
supabase functions deploy sign-in-assistant
supabase functions deploy enroll-device
supabase functions deploy sync-call-logs
```

The functions expect `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` in the function environment. Hosted Supabase provides those. Keep `verify_jwt` enabled, as in `supabase/config.toml`.

Server decision tests:

```bash
deno test supabase/functions/_shared/policy_test.ts
```

## App configuration

```bash
cp config.json.example config.json
```

Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Project Settings → API. Set `ADMIN_EMAIL` to the address shown on the settings screen. `LOOKBACK_DAYS` is how far back the first sync reads (default 30). `LOCAL_RETENTION_DAYS` is how long synced rows stay on the phone (default 90).

`config.json` is gitignored.

## Run and build

```bash
flutter pub get
flutter run --dart-define-from-file=config.json
flutter build apk --dart-define-from-file=config.json
```

The debug and release APKs are written under `build/app/outputs/flutter-apk/`. A debug APK was compiled in this workspace. `workmanager_android` still applies the older Kotlin Gradle plugin, which Flutter warns about. The current build succeeds. Upgrade that plugin when a Built-in Kotlin release is available.

Install a build on a connected phone with:

```bash
flutter install --dart-define-from-file=config.json
```

`minSdk` is 26. `applicationId` is `com.spark.sales`. The manifest requests `INTERNET`, `ACCESS_NETWORK_STATE`, and `READ_CALL_LOG` only.

Call log reading lives in `packages/call_log_android`. It is a plugin so the WorkManager background engine can read the log, not only the foreground activity. `android/app/src/main/kotlin/.../MainActivity.kt` stays a normal Flutter activity.

## Tests

```bash
flutter test
```

The suite covers call-type mapping, timestamps, duration parsing, duplicate prevention, offline queue recovery, retry backoff, unauthorized devices, permission denial, employee deactivation, and device deactivation. Android call rows are mocked. The sync service test uses a local SQLite file, not a device.

## Physical phone checklist

1. Apply the migration and deploy both Edge Functions.
2. Insert an active `sales_assistants` row with `email` and `password`, then sign in with that email and password.
3. Install the app with the `config.json` defines above.
4. Sign in. The app should show the monitoring disclosure, not the dashboard.
5. Read the disclosure, confirm it, and allow call log access. Deny it once and confirm the screen says synchronization cannot run.
6. Place or receive a normal cellular call. WhatsApp calls must not appear.
7. Open the dashboard and tap **Sync Now**. The call should show as synced, and `call_logs` should contain one row. `sales_assistant_id` must match the device, even if the client tries to send a different id.
8. Tap **Sync Now** again. The same Android call id must not create a second row.
9. Turn on airplane mode, place another call, and confirm it stays pending. Turn the network back on and confirm it uploads.
10. Force-stop the app and open it again. The pending queue must still be there if it had not uploaded.
11. Leave the phone idle. WorkManager is scheduled for 15 minutes. Android may run it later because of Doze or the manufacturer battery settings. Exempt the app from battery optimization only through your MDM policy if you need more reliable timing. Do not add a persistent foreground service.
12. Turn off **Call monitoring** in Settings. New calls must stop uploading. Sign out and confirm the local list is cleared.
13. Set `sales_assistants.is_active` or the device `is_active` to false. The next sync or sign-in must stop collection and return the phone to the sign-in screen.

## Distribution

`READ_CALL_LOG` is restricted on Google Play. This app is meant for company-owned phones distributed through an MDM or a private managed-Play channel, not as a public Play app. Before a managed-Play release, complete Google's permission declaration and confirm the app is only installed on devices your organization owns. Declaring the permission in the manifest is not enough for a public store listing.

Android can also hide or delay call-log rows on some OEM builds. Test the phone models you actually issue.

## How sync works

- The first read covers `LOOKBACK_DAYS`. Later reads start from the newest call already seen, with a six-hour overlap.
- New rows go into SQLite (`pending`, `syncing`, `synced`, `failed`) and survive process death.
- Uploads are batches of 50. Failures use exponential backoff, capped at 10 attempts. **Retry synchronization** resets failed rows.
- The server upsert is idempotent on `(device_id, android_call_id)`.
- Background work uses WorkManager's minimum periodic interval of 15 minutes and requires a network connection. The app also syncs on open, resume, **Sync Now**, and when connectivity returns while the process is alive.
- Sign-out, a disabled monitoring switch, or a server revocation cancels that work and deletes the local queue.

Local call rows sit in the app-private database, backup is disabled, and credentials sit in encrypted storage. The database itself is not separately encrypted. Uninstalling the app removes it.

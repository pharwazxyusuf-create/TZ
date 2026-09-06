# TZ production setup

The repository contains the TZ Flutter app, Supabase schema, and server-side functions for Temz Store.

## 1. Supabase database
Run the migrations in order:
1. `supabase/migrations/001_tz_schema.sql`
2. `supabase/migrations/002_tz_workflows.sql`
3. `supabase/migrations/003_initial_admin_allowlist.sql`
4. `supabase/migrations/004_agent_onboarding.sql`

The initial admin email allowlist is:
- pharwazxyusuf@gmail.com
- mytemzbusiness@gmail.com
- omolaratemilade567@gmail.com

The first-time admin screen uses the user's chosen password and Supabase email confirmation. Do not put passwords in source control.

## 2. Supabase Auth mobile redirect
In Supabase Dashboard → Authentication → URL Configuration → Redirect URLs, add this exact URL:

`tz://auth-callback/`

This redirect is required for admin email confirmation, password reset, and agent access links to return to the TZ mobile app. Supabase's mobile auth documentation requires the custom callback URI to be in the project's allowed redirect URLs. 

## 3. Agent access links
Deploy:
- `supabase/functions/admin-invite-agent`
- `supabase/functions/wp-order-webhook`
- `supabase/functions/agent-reminders`

`admin-invite-agent` is protected by the caller's Supabase access token and checks `profiles.role = 'admin'`. It creates or refreshes an agent's one-time access link and never exposes the Supabase secret key to Flutter.

The TZ admin app then provides:
**Agents → ADD AGENT → CREATE & SHARE ACCESS LINK**.

The admin can share the returned link by WhatsApp. When the agent opens it on a phone with TZ installed, the link returns to TZ and the agent is required to set a personal password before entering the agent dashboard.

## 4. Server-side secrets
Edge Functions require Supabase's server-side secret/service-role credential. Never put a service-role/secret key in the Flutter app.

Required for WordPress:
- `TZ_WEBHOOK_SECRET`

Supabase automatically exposes the project URL and server credentials to deployed Edge Functions according to the project's current function environment.

## 5. WordPress
Configure WPForms/Fluent Forms to POST one JSON payload to the deployed `wp-order-webhook` endpoint and send the `x-tz-webhook-secret` header. The webhook accepts a `products` array or a main `product` plus `cross_sells`, looks up admin-controlled prices, and creates one TZ order containing all line items.

## 6. Agent reminders
Invoke `agent-reminders` every 3 hours from a trusted scheduler. It creates a reminder notification only when the assigned order has not reached a final outcome.

## 7. Build
Codemagic runs `tool/fix_build.py` before analysis/build. That script applies the mobile deep-link configuration, corrected Supabase initialization, role-specific navigation, agent onboarding screens, and the clean Temz Store SVG logo before the release build.

The Android build is a release APK suitable for real-device testing. iOS is currently built unsigned for later App Store/TestFlight signing.

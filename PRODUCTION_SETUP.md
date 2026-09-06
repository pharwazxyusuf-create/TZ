# TZ production setup

The repository now contains the production Flutter target plus the Supabase database and Edge Functions.

## Supabase database
Run the migrations in order:
1. `supabase/migrations/001_tz_schema.sql`
2. `supabase/migrations/002_tz_workflows.sql`
3. `supabase/migrations/003_initial_admin_allowlist.sql`

The initial admin email allowlist is:
- pharwazxyusuf@gmail.com
- mytemzbusiness@gmail.com
- omolaratemilade567@gmail.com

Create those users in Supabase Authentication. Their profile is automatically promoted to `admin` by migration 003. Do not put passwords in source control.

## Edge Functions
Deploy:
- `supabase/functions/wp-order-webhook`
- `supabase/functions/agent-reminders`

Required server-side secrets:
- `SUPABASE_SERVICE_ROLE_KEY` (Supabase provides this to Edge Functions when configured)
- `TZ_WEBHOOK_SECRET` for the WordPress webhook

Never put a service-role/secret key in the Flutter app.

## WordPress
Configure WPForms/Fluent Forms to POST one JSON payload to the deployed `wp-order-webhook` endpoint and send the `x-tz-webhook-secret` header. The webhook accepts a `products` array or a main `product` plus `cross_sells`, looks up admin-controlled prices, and creates one TZ order containing all line items.

## Agent reminders
Invoke `agent-reminders` every 3 hours from a trusted scheduler. It creates a reminder notification only when the assigned order has not reached a final outcome.

## Build
Codemagic now targets `lib/production_main.dart` for Android and Windows. The production target uses Supabase Auth and live database queries rather than the old demo credentials/local order lists.

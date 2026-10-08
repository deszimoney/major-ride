# Security setup

The storefront is browser code, so browser-side checks are for user experience only. Supabase Row Level Security and the payment verification function are the authority for private data, admin changes, and completed payments.

## Required Supabase setup

1. Back up the existing database, then run `supabase-schema.sql` in the Supabase SQL editor. This removes the old plaintext `users.password` column, removes permissive policies, and backfills profiles for Auth accounts that existed before the profile trigger was installed. It does not seed an administrator account.
2. Create an account through the storefront, or use the Auth user you already created. In the Supabase SQL editor, promote only that account by its Auth user ID. Replace the UUID below with the user's ID from **Authentication → Users**:

   ```sql
   do $$
   declare
     target_user_id uuid := '<the intended Supabase Auth user UUID>';
   begin
     insert into public.users (id, name, email, provider, role)
     select
       id::text,
       coalesce(nullif(raw_user_meta_data ->> 'name', ''), split_part(email, '@', 1)),
       email,
       coalesce(raw_app_meta_data ->> 'provider', 'email'),
       'admin'
     from auth.users
     where id = target_user_id
       and email is not null
     on conflict (id) do update set role = 'admin';

     if not found then
       raise exception 'No Auth user with that UUID and an email address was found.';
     end if;
   end
   $$;
   ```

   This also creates a missing profile for an existing Auth user. Check that exactly the intended account can access the admin page after refreshing it. Never grant admin from browser code, by email alone, or from user metadata.
3. Deploy `supabase/functions/verify-paystack-order/index.ts` as the `verify-paystack-order` Edge Function.
4. Set the Edge Function secrets in Supabase (never in this repository or frontend):

   - `PAYSTACK_SECRET_KEY`: the Paystack secret key for the active environment.
   - `SITE_ORIGINS`: comma-separated exact browser origins allowed to call the function. For GitHub Pages this is typically `https://deszimoney.github.io`; include a custom site origin separately if used.

   Supabase supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` to deployed functions. Never put the service-role key in `supabase-config.js`.
5. In Supabase Authentication settings, allow only the deployed site URLs and configure email confirmation/reset redirects. Configure the appropriate Paystack public key in `paystack-config.js`; public keys are expected to be visible in browser code.
6. Rotate the Google OAuth client secret that was previously committed locally. Keep the new secret only in Supabase Authentication settings or a secret manager.

Until the schema and function are deployed, browsing the catalog remains available, but secure account/admin/payment operations will fail closed. Client-side Paystack success callbacks alone are not proof of payment.

## Hosting note

The storefront includes a restrictive Content Security Policy and referrer policy as HTML metadata. GitHub Pages does not let this repository configure arbitrary HTTP response headers; use a host that supports security headers if you need `Strict-Transport-Security`, `X-Content-Type-Options`, `Permissions-Policy`, and `frame-ancestors` headers. Keep TLS enabled and enable GitHub's dependency/security alerts.

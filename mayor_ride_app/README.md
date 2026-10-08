# Mayor Ride Co. — Flutter app

A Flutter port of the Mayor Ride Co. website (Android, iOS, and Web), sharing
the same Supabase project and Paystack account as the site in
`E:\CLIENTS\MICHAEL`.

## What's in here

| Website file | App equivalent | Notes |
|---|---|---|
| `supabase-config.js` | `lib/config/app_config.dart` | Same Supabase URL/anon key |
| `paystack-config.js` | `lib/config/app_config.dart` | Same Paystack public key |
| `database.js` | `lib/services/*_repository.dart` + `lib/providers/*_provider.dart` | Split into typed repositories (Supabase I/O) and providers (state + local cache) |
| `auth.js` | `lib/services/auth_repository.dart`, `lib/widgets/auth_sheet.dart` | Login / sign up / forgot / reset, Google OAuth |
| `shop.js` | `lib/screens/shop_screen.dart`, `lib/widgets/product_card.dart` | Category filter + search |
| `cart.js` | `lib/providers/cart_provider.dart`, `lib/widgets/cart_sheet.dart`, `lib/services/checkout/` | Paystack checkout (WebView on mobile, JS interop on web) |
| `admin.js` | `lib/screens/admin_screen.dart` | Product manager, orders, cart activity, reports |
| `index.html` / `about.html` / `contact.html` | `lib/screens/home_screen.dart` / `about_screen.dart` / `contact_screen.dart` | |
| `style.css` (`:root` tokens) | `lib/theme/app_theme.dart` | Same colour palette and serif type |
| `images/` | `assets/images/` | Copied in; `supabase-schema.sql` is unchanged — same database |

## First-time setup

```bash
flutter pub get
```

### Android

Nothing else required — `minSdkVersion` from the Flutter template already
satisfies `webview_flutter`. Run with:

```bash
flutter run -d <android-device-or-emulator>
```

### iOS (needs a Mac)

```bash
cd ios && pod install && cd ..
flutter run -d <ios-device-or-simulator>
```

### Web

```bash
flutter run -d chrome
```

## Supabase / Paystack configuration

Both apps point at the **same** project, so changes made in one show up in
the other:

- `lib/config/app_config.dart` holds the Supabase URL/anon key and the
  Paystack **public** key only — never put the Paystack secret key here.
- Google sign-in requires a redirect URL registered in Supabase under
  **Authentication → URL Configuration**: add `mayorrideco://login-callback`
  (already wired into the Android manifest and iOS Info.plist).
- Password-reset emails link back to that same URL scheme.

## Known gaps vs. the website

- The contact form is UI-only, matching the original (which also had no
  submit handler). Wire it to an email service or a Supabase table if you
  want real submissions.
- Payment verification is client-reported, same trust model the website
  uses (`onSuccess` from Paystack is taken at face value). For production,
  verify the transaction reference server-side via a Supabase Edge Function
  before marking an order paid — `AppConfig.paymentVerifyFunction` is a
  ready-made hook for that once you build it.

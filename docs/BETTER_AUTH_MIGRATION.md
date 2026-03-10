# Better Auth Migration

Auth has been migrated from Supabase Auth to [Better Auth](https://www.better-auth.com/).

## Setup

1. **Add to `.env`:**
   ```env
   BETTER_AUTH_URL=https://your-api.com
   ```
   Use the base URL of your Better Auth backend (e.g. `https://api.example.com`).

2. **Backend:** Ensure you have a Better Auth server configured with:
   - Email/password (sign up, sign in, password reset)
   - Apple OAuth (for iOS/macOS)
   - Google OAuth (for Android/web)
   - `sendResetPassword` callback for password reset emails
   - **`trustedOrigins`** must include the app scheme so OAuth redirects back to the Flutter app:

   ```ts
   // auth.ts (Better Auth server)
   import { betterAuth } from "better-auth";

   export const auth = betterAuth({
     // ...other options
     trustedOrigins: [
       "https://your-web-app.com",  // if you have a web app
       "storia://",                 // required: allows storia://login-callback for mobile
     ],
   });
   ```

   Without `storia://` in `trustedOrigins`, Better Auth rejects the callback URL and redirects to your default (e.g. the web app landing page) instead of back to the mobile app.

3. **iOS:** Add "Sign in with Apple" capability in Xcode if using Apple OAuth.

4. **Deep links:** Password reset links use `storia://login-callback?token=xxx`. The app handles this via `app_links`. Ensure your Info.plist/AndroidManifest URL schemes include `storia`.

## What Changed

- **Auth provider:** Supabase Auth → Better Auth Flutter client
- **Session model:** `Session` from `better_auth_flutter` (replaces Supabase `Session`)
- **Password reset:** Uses `requestPasswordReset` and `resetPassword` against Better Auth API
- **OAuth:** Uses `socialSignIn` + `flutter_web_auth_2` for Apple/Google
- **Data layer:** Supabase is still used for books; only auth was migrated

## Supabase

Supabase remains configured for the book/data layer. If your Supabase RLS used the auth JWT, you may need to adapt it to work with your Better Auth backend or use a service role for data access.

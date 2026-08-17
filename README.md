[한국어](README-kr.md)

# Wikiman Flutter

The Android and iOS companion app for [Wikiman](https://github.com/kendrickkim/wikiman).

It opens an existing Wikiman site in a WebView and lets the site owner send
text, photos, and files from the system share sheet directly to Quick Posts.
This is an admin tool, not a standalone wiki server.

## What it does

- Connects to a Wikiman site after confirming the account has `writer` access
- Keeps the connection details in the device secure store
- Receives text, images, and files through the Android and iOS share sheet
- Uploads shared files and prepares a Markdown draft in Quick Posts
- Matches the WebView and system bars to the selected site theme
- Returns to the connection screen when the web session logs out

## Run locally

You need Flutter 3.11 or newer with the Android or iOS toolchain configured.

```bash
flutter pub get
flutter run
```

Enter the URL of a running Wikiman site and sign in with its writer account.

## Platform notes

### iOS

Before distributing the app, assign the same Development Team and App Group to
both the `Runner` and `ShareExtension` targets. The extension copies shared
files into that App Group so the main app can upload them.

### Private-network HTTP

The app allows cleartext HTTP for Wikiman instances on a private network. Use
HTTPS whenever the site is reachable from the public internet.

Shared uploads use the limit configured in **Site admin → Attachments → Size
limit**. The server enforces the same limit.

## App icons

Launcher icons and the connection-screen logo are generated from the frontend
favicon:

```bash
node tool/generate-app-icons.mjs
```

Install the frontend dependencies first because the script uses its `sharp`
package and `public/icons/favicon.svg`.

## Related repositories

- [Wikiman hub](https://github.com/kendrickkim/wikiman)
- [Frontend](https://github.com/kendrickkim/wikiman-frontend)
- [Node backend](https://github.com/kendrickkim/wikiman-backend)
- [PHP backend](https://github.com/kendrickkim/wikiman-backend-php)

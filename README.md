[한국어](README-kr.md)

# Wikiman Flutter

Flutter app that opens Wikiman in an admin-only WebView.

The backend and frontend live in separate repositories.

## Features

- Enter Wikiman URL, admin username, and password
- Enter the WebView only after the login API confirms `writer` permission
- Store connection details in the device secure store and prefill them next time
- Return to the connection screen automatically when the web session logs out
- Show **Change connection** in the web user menu only inside the app
- Receive text, images, and files via the Android·iOS share sheet as **Wikiman**
- Upload shared files and open the quick-post editor with a Markdown draft

## Run

```bash
flutter run
```

Supports Android and iOS. Cleartext HTTP is allowed so private-network Wikiman
instances work; prefer HTTPS on the public internet.

Shared file size limits follow **Site admin → Attachments → Size limit** and are
enforced on the server as well. For iOS distribution, set the same Development
Team and App Group entitlements on both the Runner and ShareExtension targets.

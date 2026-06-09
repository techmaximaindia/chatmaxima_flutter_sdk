# ChatMaxima Flutter SDK

Embed ChatMaxima live chat (AI bot + human agents) inside your own Android and
iOS apps. The SDK speaks the same realtime protocol as the ChatMaxima website
widget, gated by a **mobile_app channel API key** instead of a website domain.

## How it works

```
your app  ──init(apiKey)──▶  POST /mobileapp/session/   (API-key auth, returns
                                                          conversation + config)
your app  ──Socket.IO──────▶  connect.chatmaxima.com     (bot/agent replies,
                                                          typing, receipts)
your app  ──send message───▶  POST /webhooks/livechatwidget/
```

Messages ride the same pipeline as the website widget, so the conversation
shows up in the shared inbox, runs your bot flows, and supports human handoff
with no extra wiring.

## 1. Create a channel and get an API key

In the ChatMaxima dashboard go to **Mobile App Channel**, create a channel, and
copy its API key. Optionally restrict the key to your app's bundle id /
package name.

## 2. Add the dependency

```yaml
dependencies:
  chatmaxima_flutter_sdk:
    git:
      url: https://github.com/techmaximaindia/chatmaxima_flutter_sdk.git
```

> The SDK depends on the ChatMaxima `chatview` fork. If you vendor both
> packages locally, point the dependency at your local path.

## 3. Initialize and open chat

```dart
import 'package:chatmaxima_flutter_sdk/chatmaxima_flutter_sdk.dart';

// once, e.g. at app start
await Chatmaxima.instance.init(
  api_key: 'cmk_your_key',
  // optional: identify the user so the lead is pre-filled
  lead_info: const CmLeadInfo(name: 'Jane', email: 'jane@acme.com'),
  // optional: enforce the key's bundle-id allow-list
  bundle_id: 'com.acme.app',
);

// open the ready-made chat screen
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const ChatMaximaChatScreen(),
));
```

Or let the screen bootstrap itself:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const ChatMaximaChatScreen(api_key: 'cmk_your_key'),
));
```

## Embedding without the full screen

Use `ChatMaximaChatView` inside your own layout once `init()` has completed:

```dart
Scaffold(
  appBar: AppBar(title: const Text('Support')),
  body: const ChatMaximaChatView(),
);
```

## Other API

```dart
// Send a message programmatically
await Chatmaxima.instance.send_text('Hello');

// Start a fresh conversation (keeps the same visitor identity)
await Chatmaxima.instance.start_new_conversation();

// Release resources (e.g. on logout)
Chatmaxima.instance.dispose();
```

## Self-hosted / staging

```dart
await Chatmaxima.instance.init(
  api_key: 'cmk_your_key',
  base_url: 'https://your-host.example.com/', // must end with a slash
  socket_url: 'https://connect.your-host.example.com',
);
```

## Voice calling

If the channel has a voice agent configured, the chat screen shows a call
button in the header and the user can talk to the AI voice agent (LiveKit,
the same path as the website widget). To open the call screen directly:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const CmCallScreen(), // uses the initialized session
));
```

Calling needs microphone permission, declared by the **host app**:

- **Android** (`android/app/src/main/AndroidManifest.xml`):

  ```xml
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
  ```
  `minSdkVersion` must be **23** or higher.

- **iOS** (`ios/Runner/Info.plist`):

  ```xml
  <key>NSMicrophoneUsageDescription</key>
  <string>Used for voice calls with support.</string>
  ```

## Notes

- Visitor id and conversation id are persisted (per API key) so a returning
  user keeps their history.
- Images, voice notes, and any file type can be sent; received audio plays in
  a built-in player, other files open in the device's default app.
- Keep your API key out of source control where practical. Even though it is a
  low-privilege client credential (it can only start a chat session), pairing
  it with a bundle-id restriction is recommended.

See `example/` for a complete runnable app.

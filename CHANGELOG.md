# Changelog

## 0.1.0

- Initial release of the ChatMaxima Flutter SDK.
- `Chatmaxima.instance.init()` bootstraps a session against the mobile_app
  channel (`POST /mobileapp/session/`) using an API key.
- Realtime bot + human-agent messaging over `connect.chatmaxima.com`
  (Socket.IO), including agent typing indicators.
- Drop-in UI: `ChatMaximaChatScreen` (full screen) and `ChatMaximaChatView`
  (embeddable), rendered with the ChatMaxima `chatview` fork.
- Visitor + conversation identity persisted across launches.
- Optional per-key app bundle-id allow-list enforced server-side.

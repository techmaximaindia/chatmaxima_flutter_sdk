# Changelog

## 0.2.0

- Dynamic Widgets. A bot can now show a widget from the ChatMaxima Widget
  Library (product card, order tracking, booking form, coupon and so on) and
  the SDK draws it natively: cards, rows and columns, text, images, icons,
  buttons, text fields, choice chips, date and time pickers, checkboxes and
  sliders, in your theme colour. A pressed button is sent back to the bot with
  what the user filled in, the same way the website widget does it.
- Link buttons open in the device browser and copy buttons copy to the
  clipboard without sending anything to the bot.
- Not drawn yet: tabs show their panels one after another; popups, video and
  audio players inside a widget are skipped. A widget received in an earlier
  app session shows as its text when the conversation is reopened.

## 0.1.1

- Visitor session token. The SDK stores the `session_token` that
  `POST /mobileapp/session/` returns (paired with the visitor id it was issued
  for) and sends it on every session, message, media upload and history call
  and in the realtime handshake. ChatMaxima is moving to refuse visitor
  requests without a valid token; apps on 0.1.0 will stop sending and
  receiving once that is enforced, so update before then.
- A first launch no longer generates the visitor id on the device: the
  backend creates it, so the visitor is issued a token from the start.
  Visitors from 0.1.0 keep their id; once tokens are enforced they start a
  fresh chat identity (their history stays in the agent inbox).

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

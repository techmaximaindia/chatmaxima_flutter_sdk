# Changelog

## 0.3.1

- A reopened conversation shows your earlier answers to a widget as they
  were sent (the button and what was chosen), not as a "Form submitted" record,
  with your name on them.
- Messages loaded from the conversation history show the device's local time.
- The text a bot sends with a widget is drawn in a chat bubble and stays
  inside the screen, as does the widget below it.
- Bold and italic marks in a widget's text and in the text above it are drawn
  as bold and italic, not as asterisks.

## 0.3.0

- Dark mode. The chat screen, the message field and widgets follow your app's
  theme: when `Theme.of(context).brightness` is dark, the chat uses dark
  surfaces and light text. Your brand colour stays the same in both.
- Languages. The SDK's own texts (Retry, Copied, Required, call status, send
  errors and so on) are shown in Arabic, Chinese, English, French, Hebrew,
  Hindi, Italian, Portuguese, Russian, Spanish, Tamil and Telugu, following
  your app's locale. To force a language, set `CmStrings.language_code = 'ar'`
  before opening the chat; right-to-left languages then mirror the chat too.
  What the bot says is not translated by the SDK.

## 0.2.1

- A reopened conversation draws its earlier widgets again instead of showing
  them as text. Widgets the conversation has moved past are shown locked; a
  widget that is the latest message can still be answered.
- When a widget button is pressed, your own bubble now shows the button and
  what was chosen or filled in (for example "Add to Cart" and "Size: 42"),
  not the button's label alone.

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

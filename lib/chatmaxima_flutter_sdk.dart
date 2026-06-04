/// ChatMaxima Flutter SDK.
///
/// Embed ChatMaxima live chat (bot + human agents) inside your Android and
/// iOS apps. Speaks the same realtime protocol as the ChatMaxima website
/// widget, gated by a mobile_app channel API key.
///
/// Quick start:
/// ```dart
/// import 'package:chatmaxima_flutter_sdk/chatmaxima_flutter_sdk.dart';
///
/// await Chatmaxima.instance.init(api_key: 'cmk_xxx');
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const ChatMaximaChatScreen(),
/// ));
/// ```
library chatmaxima_flutter_sdk;

export 'src/chatmaxima.dart';
export 'src/cm_config.dart';
export 'src/models/cm_lead_info.dart';
export 'src/models/cm_session.dart';
export 'src/models/cm_site_config.dart';
export 'src/services/cm_api_client.dart' show CmApiException;
export 'src/ui/chatmaxima_chat_view.dart';
export 'src/ui/chatmaxima_chat_screen.dart';

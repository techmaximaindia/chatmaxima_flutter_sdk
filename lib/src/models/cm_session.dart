import 'cm_site_config.dart';

/// The resolved session returned by `POST /mobileapp/session/`.
///
/// Holds the identifiers the realtime + send endpoints need, plus the
/// channel appearance config.
class CmSession
{
	final String account_alias;
	final String conversation_id;
	final String end_user_id;
	final String team_alias;
	final String team_name;
	final String? cb_lead_id;

	/// Visitor session token issued by the backend for [end_user_id]. Sent back on every send, upload, history call
	/// and socket handshake so ChatMaxima knows the request comes from this visitor. '' when the backend did not issue
	/// one (a returning visitor that could not prove its id); the visitor then works unproven until enforcement.
	final String session_token;

	/// Realtime server resolved by the backend (e.g. connect.chatmaxima.com).
	final String socket_url;

	/// Voice-agent streaming server (LiveKit token endpoint host),
	/// e.g. https://streaming.chatmaxima.com .
	final String streaming_url;

	/// REST endpoint the SDK posts outgoing messages to.
	final String send_message_url;

	final CmSiteConfig site;

	/// Public media upload endpoint, derived from [send_message_url].
	/// (.../webhooks/livechatwidget/ -> .../webhooks/upload_media/)
	String get upload_media_url
	{
		if (send_message_url.contains('webhooks/livechatwidget/'))
		{
			return send_message_url.replaceAll('webhooks/livechatwidget/', 'webhooks/upload_media/');
		}
		return send_message_url; // fallback; server still accepts account_alias
	}

	const CmSession({
		required this.account_alias,
		required this.conversation_id,
		required this.end_user_id,
		required this.team_alias,
		required this.team_name,
		required this.cb_lead_id,
		this.session_token = '',
		required this.socket_url,
		required this.streaming_url,
		required this.send_message_url,
		required this.site,
	});

	factory CmSession.from_json(Map<String, dynamic> json)
	{
		final site_json = (json['site'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
		return CmSession(
			account_alias: (json['account_alias'] ?? json['app_id'] ?? '').toString(),
			conversation_id: (json['conversation_id'] ?? '').toString(),
			end_user_id: (json['end_user_id'] ?? '').toString(),
			team_alias: (json['team_alias'] ?? '').toString(),
			team_name: (json['team_name'] ?? '').toString(),
			cb_lead_id: json['cb_lead_id']?.toString(),
			session_token: (json['session_token'] ?? '').toString(),
			socket_url: (json['socket_url'] ?? 'https://connect.chatmaxima.com').toString(),
			streaming_url: (json['streaming_url'] ?? 'https://streaming.chatmaxima.com').toString(),
			send_message_url: (json['send_message_url'] ?? '').toString(),
			site: CmSiteConfig.from_json(site_json),
		);
	}
}

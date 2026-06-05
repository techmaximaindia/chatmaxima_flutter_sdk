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

	/// Realtime server resolved by the backend (e.g. connect.chatmaxima.com).
	final String socket_url;

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
		required this.socket_url,
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
			socket_url: (json['socket_url'] ?? 'https://connect.chatmaxima.com').toString(),
			send_message_url: (json['send_message_url'] ?? '').toString(),
			site: CmSiteConfig.from_json(site_json),
		);
	}
}

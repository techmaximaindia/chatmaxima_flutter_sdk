import 'package:chatview/chatview.dart';

/// Translates ChatMaxima socket payloads into chatview [Message] objects.
///
/// Inbound bot/agent messages are attributed to the synthetic [agentUserId]
/// so chatview renders them as the "other" party; the app user keeps their
/// own id. Mirrors the mapping used by the ChatMaxima agent app.
class CmMessageMapper
{
	/// Stable id for every bot/agent/system message (the non-user side).
	static const String agent_user_id = 'chatmaxima';

	/// Map an `incoming` / `incomingapp` socket payload to a [Message].
	static Message from_incoming(Map<String, dynamic> json, {required String app_user_id})
	{
		final message_data = (json['message_data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
		final source = (json['source'] ?? '').toString();
		final media_type = (json['media_type'] ?? '').toString().toLowerCase();
		final media_url = (json['media_url'] ?? '').toString();
		final answer = (json['answer'] ?? json['content'] ?? '').toString();

		// incomingapp can echo the user's own message back; attribute it to the
		// app user so it does not appear as an agent bubble.
		final is_own_echo = source == 'widget' || source == 'mobile_app';
		final sent_by = is_own_echo ? app_user_id : agent_user_id;

		final type = _resolve_type(media_type);
		final id = (json['message_id'] ?? DateTime.now().microsecondsSinceEpoch).toString();

		return Message(
			id: id,
			message: type == MessageType.image ? media_url : _with_media_fallback(answer, type, media_url),
			createdAt: DateTime.now(),
			sendBy: sent_by,
			profilename: (json['profile_name'] ?? '').toString(),
			chatmaxima_profile_image: (message_data['profile_image'] ?? '').toString(),
			messageType: type,
			status: MessageStatus.delivered,
			message_id: (message_data['cb_message_id'] ?? '').toString(),
			image_text_message: type == MessageType.image ? answer : '',
		);
	}

	/// Build the locally-shown optimistic copy of a message the user just sent.
	static Message outgoing({
		required String app_user_id,
		required String text,
		String media_url = '',
		MessageType type = MessageType.text,
	})
	{
		return Message(
			id: DateTime.now().microsecondsSinceEpoch.toString(),
			message: type == MessageType.image ? media_url : text,
			createdAt: DateTime.now(),
			sendBy: app_user_id,
			messageType: type,
			status: MessageStatus.pending,
			image_text_message: type == MessageType.image ? text : '',
		);
	}

	static MessageType _resolve_type(String media_type)
	{
		if (media_type == 'image') return MessageType.image;
		return MessageType.text; // audio/video/file shown as a link for now
	}

	// For non-image media, surface the URL so the user can still reach it.
	static String _with_media_fallback(String answer, MessageType type, String media_url)
	{
		if (type == MessageType.text && media_url.isNotEmpty)
		{
			return answer.isEmpty ? media_url : '$answer\n$media_url';
		}
		return answer;
	}
}

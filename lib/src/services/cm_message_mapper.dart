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
			message: (type == MessageType.image || type == MessageType.voice) ? media_url : _with_media_fallback(answer, type, media_url),
			createdAt: DateTime.now(),
			sendBy: sent_by,
			profilename: (json['profile_name'] ?? '').toString(),
			chatmaxima_profile_image: (message_data['profile_image'] ?? '').toString(),
			messageType: type,
			status: MessageStatus.delivered,
			message_id: (message_data['cb_message_id'] ?? '').toString(),
			image_text_message: type == MessageType.image ? answer : '',
			replyMessage: _reply_from_incoming(message_data, app_user_id, sent_by),
		);
	}

	// Build a ReplyMessage from the incoming payload's parent_message fields so
	// the quoted bubble renders above a reply.
	static ReplyMessage _reply_from_incoming(Map<String, dynamic> message_data, String app_user_id, String sent_by)
	{
		final parent_text = (message_data['parent_message'] ?? '').toString();
		final parent_id = (message_data['parent_message_id'] ?? '').toString();
		if (parent_text.isEmpty && parent_id.isEmpty)
		{
			return const ReplyMessage();
		}
		return ReplyMessage(
			message: parent_text,
			messageId: parent_id,
			replyBy: sent_by,
			replyTo: app_user_id,
			messageType: MessageType.text,
		);
	}

	/// Build the locally-shown optimistic copy of a message the user just sent.
	/// [id] should be the cb_reference_messsage_sid so the server echo dedupes
	/// against this bubble.
	static Message outgoing({
		required String app_user_id,
		required String text,
		String? id,
		String media_url = '',
		MessageType type = MessageType.text,
		ReplyMessage? reply,
		String profilename = 'You',
		String profile_image = '',
	})
	{
		return Message(
			id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
			message: type == MessageType.image ? media_url : text,
			createdAt: DateTime.now(),
			sendBy: app_user_id,
			messageType: type,
			status: MessageStatus.pending,
			image_text_message: type == MessageType.image ? text : '',
			profilename: profilename,
			chatmaxima_profile_image: profile_image,
			replyMessage: reply ?? const ReplyMessage(),
		);
	}

	/// Stable de-duplication id for an incoming/echo payload: prefer the
	/// client reference sid (round-tripped by the server for the user's own
	/// messages), else the server message id.
	static String dedup_id(Map<String, dynamic> json)
	{
		final message_data = (json['message_data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
		final sid = (message_data['cb_reference_messsage_sid'] ?? json['cb_reference_messsage_sid'] ?? '').toString();
		if (sid.isNotEmpty) return sid;
		return (json['message_id'] ?? '').toString();
	}

	/// Map one history record (Elasticsearch _source from get_whatsapp_messages)
	/// into a [Message]. `cb_message_type == 'incoming'` is the app user; bot /
	/// outgoing / agent records are attributed to [agentUserId].
	static Message from_history(Map<String, dynamic> json, {required String app_user_id})
	{
		final direction = (json['cb_message_type'] ?? '').toString().toLowerCase();
		final is_user = direction == 'incoming';
		final media_type = (json['cb_media_type'] ?? json['media_type'] ?? '').toString().toLowerCase();
		final media_url = (json['cb_media_url'] ?? json['media_url'] ?? '').toString();
		final text = (json['cb_message_text'] ?? json['text'] ?? json['answer'] ?? '').toString();
		final type = _resolve_type(media_type);

		return Message(
			id: (json['cb_message_id'] ?? json['cb_reference_messsage_sid'] ?? json['message_id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
			message: (type == MessageType.image || type == MessageType.voice) ? media_url : text,
			createdAt: _parse_history_date(json['cb_message_datetime']),
			sendBy: is_user ? app_user_id : agent_user_id,
			messageType: type,
			status: MessageStatus.delivered,
			profilename: is_user ? '' : (json['profile_name'] ?? '').toString(),
			chatmaxima_profile_image: (json['profile_image'] ?? '').toString(),
			message_id: (json['cb_message_id'] ?? '').toString(),
			image_text_message: type == MessageType.image ? text : '',
		);
	}

	/// Best-effort id for de-duping a history record against live socket echoes.
	static String history_dedup_id(Map<String, dynamic> json)
	{
		final sid = (json['cb_reference_messsage_sid'] ?? '').toString();
		if (sid.isNotEmpty) return sid;
		return (json['cb_message_id'] ?? json['message_id'] ?? '').toString();
	}

	static DateTime _parse_history_date(dynamic value)
	{
		if (value == null) return DateTime.now();
		if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
		final s = value.toString();
		final epoch = int.tryParse(s);
		if (epoch != null) return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
		return DateTime.tryParse(s) ?? DateTime.now();
	}

	static MessageType _resolve_type(String media_type)
	{
		if (media_type == 'image') return MessageType.image;
		if (media_type == 'audio' || media_type == 'voice') return MessageType.voice;
		return MessageType.text; // video/file shown as a link for now
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

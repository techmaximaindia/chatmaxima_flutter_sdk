/// One row in the visitor's conversation list, as returned by
/// `POST /mobileapp/conversations/`.
class CmConversation
{
	/// The conversation id (used to open / resume the thread).
	final String id;

	/// Preview text of the most recent message.
	final String last_message;

	/// Media type of the last message ('image', 'audio', '' for text).
	final String last_media_type;

	/// Human-friendly time label for the last message.
	final String last_message_label;

	/// Count of unread agent/bot messages.
	final int unread_count;

	/// Display name on the last outgoing (agent/bot) message, if any.
	final String profile_name;

	/// Avatar URL on the last outgoing message, if any.
	final String profile_image;

	const CmConversation({
		required this.id,
		required this.last_message,
		required this.last_media_type,
		required this.last_message_label,
		required this.unread_count,
		required this.profile_name,
		required this.profile_image,
	});

	factory CmConversation.from_json(Map<String, dynamic> json)
	{
		return CmConversation(
			id: (json['id'] ?? json['conversation_id'] ?? '').toString(),
			last_message: (json['cb_message_text'] ?? json['last_message'] ?? '').toString(),
			last_media_type: (json['cb_media_type'] ?? '').toString(),
			last_message_label: (json['latest_message_datetime'] ?? json['cb_message_datetime'] ?? '').toString(),
			unread_count: _as_int(json['unread_message_sent_count']),
			profile_name: (json['profile_name'] ?? '').toString(),
			profile_image: (json['image'] ?? json['profile_image'] ?? '').toString(),
		);
	}

	/// A short preview that falls back to a media label when text is empty.
	String get preview
	{
		if (last_message.isNotEmpty) return last_message;
		switch (last_media_type)
		{
			case 'image':
				return '📷 Photo';
			case 'audio':
			case 'voice':
				return '🎤 Voice message';
			case 'video':
				return '🎬 Video';
			case '':
				return '';
			default:
				return '📎 Attachment';
		}
	}

	static int _as_int(dynamic v)
	{
		if (v is int) return v;
		if (v is String) return int.tryParse(v) ?? 0;
		return 0;
	}
}

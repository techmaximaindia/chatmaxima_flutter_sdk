import 'dart:convert';

import 'package:chatview/chatview.dart';

import '../ui/cm_a2ui_surface.dart';

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

		final id = (json['message_id'] ?? DateTime.now().microsecondsSinceEpoch).toString();

		// A Dynamic Widget (A2UI surface): keep the payload in the registry and
		// mark the message so the custom builder draws the widget. The text the
		// server sent with it stays in image_text_message as the caption.
		final widget_payload = is_own_echo ? null : CmA2uiPayload.from_extra_params(json['extra_params']);
		if (widget_payload != null)
		{
			CmA2uiRegistry.put(id, widget_payload);
			return Message(
				id: id,
				message: '${CmA2uiRegistry.marker}$id',
				createdAt: DateTime.now(),
				sendBy: sent_by,
				profilename: (json['profile_name'] ?? '').toString(),
				chatmaxima_profile_image: (message_data['profile_image'] ?? '').toString(),
				messageType: MessageType.custom,
				status: MessageStatus.delivered,
				message_id: (message_data['cb_message_id'] ?? '').toString(),
				image_text_message: widget_payload.hide_text ? '' : answer,
			);
		}

		final type = _resolve_type(media_type);

		return Message(
			id: id,
			message: (type == MessageType.image || type == MessageType.custom) ? media_url : _with_media_fallback(answer, type, media_url),
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

	// Build a ReplyMessage from the incoming payload's parent_message so the
	// quoted bubble renders the original content. The backend sends
	// parent_message as an object: { cm_parent_message_text,
	// cm_parent_message_media_type, cm_parent_message_media_url }. (Older /
	// alternate payloads may send a plain string; both are handled.)
	static ReplyMessage _reply_from_incoming(Map<String, dynamic> message_data, String app_user_id, String sent_by)
	{
		final parent = message_data['parent_message'];
		final parent_id = (message_data['parent_message_id'] ?? '').toString();

		String parent_text = '';
		String media_type = '';
		String media_url = '';

		if (parent is Map)
		{
			parent_text = (parent['cm_parent_message_text'] ?? '').toString();
			media_type = (parent['cm_parent_message_media_type'] ?? '').toString().toLowerCase();
			media_url = (parent['cm_parent_message_media_url'] ?? '').toString();
		}
		else if (parent is String)
		{
			parent_text = parent;
		}

		if (parent_text.isEmpty && media_url.isEmpty && parent_id.isEmpty)
		{
			return const ReplyMessage();
		}

		final type = _reply_type(media_type);
		final is_media = type != MessageType.text;
		return ReplyMessage(
			messageId: parent_id,
			message: is_media ? media_url : parent_text, // media -> url, text -> text
			image_text_message: is_media ? parent_text : '', // caption on media replies
			messageType: type,
			replyBy: sent_by,
			replyTo: app_user_id,
		);
	}

	// Quoted-reply preview type: image as image, other media as custom (icon),
	// everything else as text. Mirrors the agent app's reply mapping.
	static MessageType _reply_type(String media_type)
	{
		if (media_type == 'image') return MessageType.image;
		if (media_type == 'video' || media_type == 'audio' || media_type == 'voice' || media_type == 'file')
		{
			return MessageType.custom;
		}
		return MessageType.text;
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
	///
	/// [previous_widget] is the Dynamic Widget shown just before this record, so
	/// the user's answer to it reads as it did when it was sent. [user_name] is
	/// the app user's display name, as on the bubbles sent in this session.
	static Message from_history(Map<String, dynamic> json, {required String app_user_id, CmA2uiPayload? previous_widget, String user_name = ''})
	{
		final direction = (json['cb_message_type'] ?? '').toString().toLowerCase();
		final is_user = direction == 'incoming';
		final media_type = (json['cb_media_type'] ?? json['media_type'] ?? '').toString().toLowerCase();
		final media_url = (json['cb_media_url'] ?? json['media_url'] ?? '').toString();
		final text = (json['cb_message_text'] ?? json['text'] ?? json['answer'] ?? '').toString();
		final type = _resolve_type(media_type);
		final history_id = (json['cb_message_id'] ?? json['cb_reference_messsage_sid'] ?? json['message_id'] ?? DateTime.now().microsecondsSinceEpoch).toString();

		// A Dynamic Widget sent earlier: its payload is stored with the message
		// (cb_message_options.a2ui), so a reopened conversation draws it again.
		final widget_payload = is_user ? null : CmA2uiPayload.from_extra_params(_message_options(json['cb_message_options']));
		if (widget_payload != null)
		{
			CmA2uiRegistry.put(history_id, widget_payload);
			return Message(
				id: history_id,
				message: '${CmA2uiRegistry.marker}$history_id',
				createdAt: _parse_history_date(json['cb_message_datetime']),
				sendBy: agent_user_id,
				messageType: MessageType.custom,
				status: MessageStatus.delivered,
				profilename: (json['profile_name'] ?? '').toString(),
				chatmaxima_profile_image: (json['profile_image'] ?? '').toString(),
				message_id: (json['cb_message_id'] ?? '').toString(),
				image_text_message: widget_payload.hide_text ? '' : text,
			);
		}

		return Message(
			id: history_id,
			message: (type == MessageType.image || type == MessageType.custom) ? media_url : (is_user ? widget_answer_text(text, previous_widget) : text),
			createdAt: _parse_history_date(json['cb_message_datetime']),
			sendBy: is_user ? app_user_id : agent_user_id,
			messageType: type,
			status: MessageStatus.delivered,
			profilename: is_user ? user_name : (json['profile_name'] ?? '').toString(),
			chatmaxima_profile_image: (json['profile_image'] ?? '').toString(),
			message_id: (json['cb_message_id'] ?? '').toString(),
			image_text_message: type == MessageType.image ? text : '',
		);
	}

	static final RegExp _widget_answer_pattern = RegExp(r'^Form submitted \((.*?)\):\s*');

	/// A pressed widget button is stored as "Form submitted (add_to_cart):" and
	/// one "field: value" line per answer. Turn that record back into what the
	/// user's bubble showed when it was sent: the button's label, then the
	/// answers. Any other text is returned unchanged.
	static String widget_answer_text(String text, CmA2uiPayload? previous_widget)
	{
		final match = _widget_answer_pattern.firstMatch(text);
		if (match == null) return text;

		final action_name = (match.group(1) ?? '').trim();
		String label = '';
		final lines = <String>[];
		for (final raw_line in text.substring(match.end).split('\n'))
		{
			final line = raw_line.trim();
			final split_at = line.indexOf(':');
			if (split_at <= 0) continue;
			final field = line.substring(0, split_at).trim();
			final value = line.substring(split_at + 1).trim();
			if (value.isEmpty || value == '(empty)') continue;
			if (field == 'button')
			{
				label = value; // the pressed button's own label, when the widget sent it
				continue;
			}
			if (field == 'item' || field == 'value')
			{
				lines.add(value);
				continue;
			}
			lines.add('$field: $value');
		}
		if (label.isEmpty && previous_widget != null)
		{
			label = previous_widget.button_label(action_name);
		}
		if (label.isEmpty)
		{
			label = _readable_name(action_name);
		}
		if (label.isNotEmpty) lines.insert(0, label);
		if (lines.isEmpty) return text;
		return lines.join('\n');
	}

	// "download_ticket" -> "Download ticket", for a button whose widget is not at hand.
	static String _readable_name(String action_name)
	{
		final words = action_name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
		if (words.isEmpty) return '';
		return words[0].toUpperCase() + words.substring(1);
	}

	// cb_message_options arrives as a JSON string (or already decoded).
	static dynamic _message_options(dynamic value)
	{
		if (value is Map) return value;
		if (value is String && value.isNotEmpty)
		{
			try
			{
				return jsonDecode(value);
			}
			catch (_)
			{
				return null;
			}
		}
		return null;
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
		final s = value.toString().trim();
		final epoch = int.tryParse(s);
		if (epoch != null) return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
		// Stored times are UTC, with or without a zone on the string. The chat
		// shows the time as given, so hand it the device's local time, as it gets
		// for the messages of this session.
		final has_zone = RegExp(r'(Z|[+\-]\d{2}:?\d{2})$').hasMatch(s);
		final parsed = DateTime.tryParse(has_zone ? s : '${s.replaceFirst(' ', 'T')}Z');
		if (parsed == null) return DateTime.tryParse(s) ?? DateTime.now();
		return parsed.toLocal();
	}

	static MessageType _resolve_type(String media_type)
	{
		if (media_type == 'image') return MessageType.image;
		// audio / voice / video / file all render via the custom builder
		// (voice player or file card).
		if (media_type == 'audio' || media_type == 'voice' || media_type == 'video' || media_type == 'file')
		{
			return MessageType.custom;
		}
		return MessageType.text;
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

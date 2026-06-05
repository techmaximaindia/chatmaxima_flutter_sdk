import 'package:chatview/chatview.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../chatmaxima.dart';
import '../cm_config.dart';
import '../models/cm_session.dart';
import '../services/cm_message_mapper.dart';
import '../services/cm_socket_client.dart';

/// Embeddable ChatMaxima chat surface (no Scaffold / AppBar of its own).
///
/// Drop it into any layout once [Chatmaxima.instance] has been initialized.
/// It owns the realtime connection, renders messages via chatview, and sends
/// the user's messages. For a ready-made full screen use [ChatMaximaChatScreen].
class ChatMaximaChatView extends StatefulWidget
{
	/// Optional explicit session/config. Defaults to the initialized singleton.
	final CmSession? session;
	final CmConfig? config;

	/// Optional custom app bar passed through to chatview.
	final Widget? app_bar;

	const ChatMaximaChatView({
		super.key,
		this.session,
		this.config,
		this.app_bar,
	});

	@override
	State<ChatMaximaChatView> createState() => _ChatMaximaChatViewState();
}

class _ChatMaximaChatViewState extends State<ChatMaximaChatView>
{
	late final CmSession _session;
	late final CmConfig _config;
	late final ChatController _chat_controller;
	late final ChatUser _current_user;
	late final ChatUser _agent_user;
	CmSocketClient? _socket;

	// Message ids already shown (sent sids + rendered incoming ids) for dedupe.
	final Set<String> _seen_ids = <String>{};

	@override
	void initState()
	{
		super.initState();
		_session = widget.session ?? Chatmaxima.instance.session;
		_config = widget.config ?? Chatmaxima.instance.config;

		_current_user = ChatUser(
			id: _session.end_user_id,
			name: _config.lead_info?.name ?? 'You',
			chatmaxima_user_name: 'You',
			platform: 'mobile_app',
		);

		_agent_user = ChatUser(
			id: CmMessageMapper.agent_user_id,
			name: _session.site.title,
			profilePhoto: _session.site.logo_bot,
			chatmaxima_user_name: _session.site.assign_bot_name,
			platform: 'mobile_app',
		);

		_chat_controller = ChatController(
			initialMessageList: <Message>[],
			scrollController: ScrollController(),
			chatUsers: [_agent_user],
		);

		_connect_socket();
		_load_history();
	}

	// Load the existing thread so a resumed conversation shows its messages.
	// Falls back to the channel's opening message for a brand-new conversation.
	Future<void> _load_history() async
	{
		try
		{
			final records = await Chatmaxima.instance.api.fetch_messages(
				session: _session,
				conversation_id: _session.conversation_id,
			);
			if (!mounted) return;
			if (records.isEmpty)
			{
				_seed_first_message();
				return;
			}
			for (final record in records)
			{
				// Remember ids so a live socket echo of a historical message
				// is not appended a second time.
				final dedup = CmMessageMapper.history_dedup_id(record);
				if (dedup.isNotEmpty) _seen_ids.add(dedup);
				_chat_controller.addMessage(CmMessageMapper.from_history(record, app_user_id: _current_user.id));
			}
		}
		catch (_)
		{
			if (mounted) _seed_first_message();
		}
	}

	void _connect_socket()
	{
		final socket = CmSocketClient(_config, _session);

		socket.on_incoming = (data)
		{
			if (!mounted) return;
			// Dedupe: the server echoes the user's own message back (carrying the
			// cb_reference_messsage_sid we sent). Skip anything we've already shown.
			final id = CmMessageMapper.dedup_id(data);
			if (id.isNotEmpty && _seen_ids.contains(id)) return;
			if (id.isNotEmpty) _seen_ids.add(id);

			final message = CmMessageMapper.from_incoming(data, app_user_id: _current_user.id);
			// Belt-and-braces: never render our own message as an agent bubble.
			if (message.sendBy == _current_user.id) return;
			_chat_controller.addMessage(message);
			_chat_controller.setTypingIndicator = false;
		};

		socket.on_agent_typing = (typing)
		{
			if (!mounted) return;
			_chat_controller.setTypingIndicator = typing;
		};

		socket.on_message_deleted = (_) {}; // could mark a message deleted here

		socket.connect();
		_socket = socket;
	}

	// Show the channel's opening message if one is configured.
	void _seed_first_message()
	{
		final first = _session.site.label_first_msg;
		if (first != null && first.trim().isNotEmpty)
		{
			_chat_controller.addMessage(Message(
				id: 'welcome',
				message: first,
				createdAt: DateTime.now(),
				sendBy: CmMessageMapper.agent_user_id,
				status: MessageStatus.delivered,
				profilename: _session.site.assign_bot_name,
			));
		}
	}

	void _on_send_tap(String message, ReplyMessage reply_message, MessageType message_type, String? image_message)
	{
		if (message_type == MessageType.image)
		{
			_handle_image_send(message, image_message ?? '', reply_message);
			return;
		}

		if (message_type == MessageType.voice)
		{
			_handle_voice_send(message, reply_message);
			return;
		}

		// Generate the reference sid up front: it is both the optimistic
		// bubble's id and the value sent to the server, so the echoed-back copy
		// dedupes against this bubble instead of appearing as a second message.
		final sid = _gen_reference_sid();
		_seen_ids.add(sid);

		final has_reply = reply_message.message.isNotEmpty;

		_chat_controller.addMessage(CmMessageMapper.outgoing(
			app_user_id: _current_user.id,
			id: sid,
			text: message,
			type: MessageType.text,
			reply: has_reply ? reply_message : null,
			profilename: _current_user.name,
		));

		Chatmaxima.instance.api.send_message(
			session: _session,
			query: message,
			reference_sid: sid,
			parent_message_id: reply_message.messageId.isNotEmpty ? reply_message.messageId : null,
		).catchError((e) => _on_send_error());
	}

	// Optimistically show the local image, upload it to get a public URL, then
	// send that URL. Handles the comma-joined multi-image path the picker emits.
	Future<void> _handle_image_send(String paths, String caption, ReplyMessage reply_message) async
	{
		final list = paths.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
		final has_reply = reply_message.message.isNotEmpty;

		for (final path in list)
		{
			final sid = _gen_reference_sid();
			_seen_ids.add(sid);

			// Local path renders immediately via File() in the image bubble.
			_chat_controller.addMessage(CmMessageMapper.outgoing(
				app_user_id: _current_user.id,
				id: sid,
				text: caption,
				media_url: path,
				type: MessageType.image,
				reply: has_reply ? reply_message : null,
				profilename: _current_user.name,
			));

			try
			{
				final uploaded = await Chatmaxima.instance.api.upload_media(session: _session, file_path: path);
				await Chatmaxima.instance.api.send_message(
					session: _session,
					query: caption,
					media_url: uploaded.media_url,
					media_type: uploaded.media_type.isNotEmpty ? uploaded.media_type : 'image',
					reference_sid: sid,
					parent_message_id: reply_message.messageId.isNotEmpty ? reply_message.messageId : null,
				);
			}
			catch (e)
			{
				_on_send_error();
			}
		}
	}

	// Optimistically show the recorded voice note (plays from the local file),
	// upload the audio, then send the resulting URL.
	Future<void> _handle_voice_send(String path, ReplyMessage reply_message) async
	{
		if (path.trim().isEmpty) return;
		final sid = _gen_reference_sid();
		_seen_ids.add(sid);

		_chat_controller.addMessage(Message(
			id: sid,
			message: path,            // local file path -> plays immediately
			createdAt: DateTime.now(),
			sendBy: _current_user.id,
			messageType: MessageType.voice,
			status: MessageStatus.pending,
			profilename: _current_user.name,
		));

		try
		{
			final uploaded = await Chatmaxima.instance.api.upload_media(session: _session, file_path: path);
			await Chatmaxima.instance.api.send_message(
				session: _session,
				query: '',
				media_url: uploaded.media_url,
				media_type: uploaded.media_type.isNotEmpty ? uploaded.media_type : 'audio',
				reference_sid: sid,
				parent_message_id: reply_message.messageId.isNotEmpty ? reply_message.messageId : null,
			);
		}
		catch (e)
		{
			_on_send_error();
		}
	}

	void _on_send_error()
	{
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('Message failed to send. Please try again.')),
		);
	}

	// 10-char client message id, mirroring the website widget's makeid(10).
	String _gen_reference_sid()
	{
		return const Uuid().v4().replaceAll('-', '').substring(0, 10);
	}

	@override
	void dispose()
	{
		_socket?.dispose();
		_chat_controller.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context)
	{
		final theme_color = _session.site.theme_color;
		final on_theme = _session.site.theme_foreground_color;

		// Distinct surfaces so bubbles never blend into the background:
		// chat background = light grey, incoming bubble = white, outgoing = brand.
		const chat_background = Color(0xFFECEFF3);
		const incoming_bubble = Color(0xFFFFFFFF);
		const incoming_text = Color(0xFF1F2937);

		return ChatView(
			currentUser: _current_user,
			chatController: _chat_controller,
			onSendTap: _on_send_tap,
			chatViewState: ChatViewState.hasMessages,
			appBar: widget.app_bar as ChatViewAppBar?,
			featureActiveConfig: const FeatureActiveConfig(
				enableSwipeToReply: true,
				enableReactionPopup: false,
				enableTextField: true,
				enablePagination: false,
				lastSeenAgoBuilderVisibility: false,
				receiptsBuilderVisibility: false,
				enableCurrentUserProfileAvatar: true, // show the user's avatar on outgoing bubbles
				enableOtherUserProfileAvatar: true,
				enableTranslateMessage: false,        // long-press: keep only Reply + Copy
				enableTicketFromMessage: false,
			),
			chatBackgroundConfig: const ChatBackgroundConfiguration(
				backgroundColor: chat_background,
			),
			typeIndicatorConfig: TypeIndicatorConfiguration(
				flashingCircleDarkColor: theme_color,
				flashingCircleBrightColor: theme_color.withValues(alpha: 0.4),
			),
			repliedMessageConfig: RepliedMessageConfiguration(
				backgroundColor: theme_color.withValues(alpha: 0.12),
				verticalBarColor: theme_color,
				textStyle: const TextStyle(color: Color(0xFF374151), fontSize: 13),
				replyTitleTextStyle: TextStyle(color: theme_color, fontWeight: FontWeight.w600, fontSize: 12),
			),
			sendMessageConfig: SendMessageConfiguration(
				allowRecordingVoice: true,            // record + send voice messages
				enableMaxIA: false,                   // hide the agent-only AI compose button
				enableCameraImagePicker: _session.site.allow_attachment, // now backed by file_picker
				enableGalleryImagePicker: _session.site.allow_attachment,
				defaultSendButtonColor: theme_color,
				textFieldBackgroundColor: Theme.of(context).cardColor,
			),
			chatBubbleConfig: ChatBubbleConfiguration(
				outgoingChatBubbleConfig: ChatBubble(
					color: theme_color,
					textStyle: TextStyle(color: on_theme, fontSize: 15),
				),
				inComingChatBubbleConfig: const ChatBubble(
					color: incoming_bubble,
					textStyle: TextStyle(color: incoming_text, fontSize: 15),
				),
			),
		);
	}
}

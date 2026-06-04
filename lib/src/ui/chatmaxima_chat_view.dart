import 'package:chatview/chatview.dart';
import 'package:flutter/material.dart';

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
		_seed_first_message();
	}

	void _connect_socket()
	{
		final socket = CmSocketClient(_config, _session);

		socket.on_incoming = (data)
		{
			final message = CmMessageMapper.from_incoming(data, app_user_id: _current_user.id);
			// Ignore our own echo (already shown optimistically).
			if (message.sendBy == _current_user.id) return;
			if (!mounted) return;
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
		// Optimistic local echo.
		_chat_controller.addMessage(CmMessageMapper.outgoing(
			app_user_id: _current_user.id,
			text: message,
			type: MessageType.text,
		));

		Chatmaxima.instance.send_text(message).catchError((e)
		{
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Message failed to send. Please try again.')),
			);
		});
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
			),
			chatBackgroundConfig: ChatBackgroundConfiguration(
				backgroundColor: Theme.of(context).scaffoldBackgroundColor,
			),
			sendMessageConfig: SendMessageConfiguration(
				allowRecordingVoice: false,
				enableCameraImagePicker: _session.site.allow_attachment,
				enableGalleryImagePicker: _session.site.allow_attachment,
				defaultSendButtonColor: theme_color,
				textFieldBackgroundColor: Theme.of(context).cardColor,
			),
			chatBubbleConfig: ChatBubbleConfiguration(
				outgoingChatBubbleConfig: ChatBubble(color: theme_color),
				inComingChatBubbleConfig: ChatBubble(color: Theme.of(context).cardColor),
			),
		);
	}
}

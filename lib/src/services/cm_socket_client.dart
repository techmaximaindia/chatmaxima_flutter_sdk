import 'package:socket_io_client/socket_io_client.dart' as io;

import '../cm_config.dart';
import '../models/cm_session.dart';

/// Realtime channel to connect.chatmaxima.com. Emits `storeClientInfo` on
/// connect (the handshake that subscribes this device to its conversation)
/// and surfaces the inbound events the website widget uses.
///
/// Wire callbacks before calling [connect].
class CmSocketClient
{
	final CmConfig _config;
	final CmSession _session;

	io.Socket? _socket;

	/// A bot or human-agent message arrived. Payload is the raw `incoming` map.
	void Function(Map<String, dynamic> data)? on_incoming;

	/// Agent started (true) / stopped (false) typing.
	void Function(bool typing)? on_agent_typing;

	/// A read/delivery receipt for one of our messages.
	void Function(Map<String, dynamic> data)? on_message_read;

	/// An agent deleted a message.
	void Function(Map<String, dynamic> data)? on_message_deleted;

	/// Connection lifecycle.
	void Function()? on_connect;
	void Function()? on_disconnect;

	CmSocketClient(this._config, this._session);

	bool get is_connected => _socket?.connected ?? false;

	void connect()
	{
		final url = _config.socket_url ?? _session.socket_url;

		final socket = io.io(
			url,
			io.OptionBuilder()
				.setTransports(['websocket'])
				.disableAutoConnect()
				.build(),
		);
		_socket = socket;

		socket.onConnect((_)
		{
			_log('socket connected');
			socket.emit('storeClientInfo', _handshake_payload());
			on_connect?.call();
		});

		socket.onDisconnect((_)
		{
			_log('socket disconnected');
			on_disconnect?.call();
		});

		// Bot / agent message (also echoes our own message via incomingapp).
		socket.on('incoming', (data) => _forward(on_incoming, data));
		socket.on('incomingapp', (data) => _forward(on_incoming, data));

		socket.on('agent_is_typing', (_) => on_agent_typing?.call(true));
		socket.on('agent_is_not_typing', (_) => on_agent_typing?.call(false));

		socket.on('is_agent_read_message', (data) => _forward(on_message_read, data));
		socket.on('message_is_deleted', (data) => _forward(on_message_deleted, data));

		socket.connect();
	}

	/// Tell agents the visitor is typing (best-effort; safe if unsupported).
	void send_typing()
	{
		_socket?.emit('user_is_typing', {'id': _session.conversation_id});
	}

	void send_not_typing()
	{
		_socket?.emit('user_not_typing', {'id': _session.conversation_id});
	}

	void dispose()
	{
		_socket?.dispose();
		_socket = null;
	}

	Map<String, dynamic> _handshake_payload()
	{
		return {
			'id': _session.conversation_id,
			'account_alias': _session.account_alias,
			'team_alias': _session.team_alias,
			'team_name': _session.team_name,
			'user_type': 'lead',
			'user_alias': _session.cb_lead_id ?? '',
			'user_name': _config.lead_info?.name ?? '',
			'user_email': _config.lead_info?.email ?? '',
			'profile_id': _session.end_user_id,
			'device_id': '',
			'domain': 'mobile_app',
			'location': '',
			'from': 'mobile_app_chat',
		};
	}

	void _forward(void Function(Map<String, dynamic>)? cb, dynamic data)
	{
		if (cb == null) return;
		if (data is Map)
		{
			cb(data.cast<String, dynamic>());
		}
	}

	void _log(String message)
	{
		if (_config.debug)
		{
			// ignore: avoid_print
			print('[chatmaxima] $message');
		}
	}
}

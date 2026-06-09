import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;

import '../models/cm_session.dart';

/// Thrown when a call cannot be started (no voice agent, token error, etc).
class CmCallException implements Exception
{
	final String message;
	CmCallException(this.message);
	@override
	String toString() => 'CmCallException: $message';
}

/// Starts/stops an AI voice-agent call over LiveKit, mirroring the website
/// widget: POST {streaming_url}/livekit/connect for a token, then join the room.
class CmCallService
{
	final CmSession _session;
	final http.Client _http;

	lk.Room? room;

	CmCallService(this._session, {http.Client? client}) : _http = client ?? http.Client();

	bool get is_available => _session.site.voice_agent_enabled && (_session.site.voice_chat_bot_alias ?? '').isNotEmpty;

	/// Fetch LiveKit credentials (server URL + access token) for this visitor.
	Future<({String url, String token})> fetch_credentials() async
	{
		final endpoint = '${_session.streaming_url.replaceAll(RegExp(r"/+$"), "")}/livekit/connect';
		final payload = {
			'account_alias': _session.account_alias,
			'bot_alias': _session.site.voice_chat_bot_alias,
			'conversation_id': 'v_${_session.conversation_id}', // widget prefixes voice convos with v_
			'team_alias': _session.team_alias,
			'user_id': _session.end_user_id,
		};

		http.Response res;
		try
		{
			res = await _http.post(
				Uri.parse(endpoint),
				headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
				body: jsonEncode(payload),
			);
		}
		catch (e)
		{
			throw CmCallException('Could not reach the voice server: $e');
		}

		if (res.statusCode != 200)
		{
			throw CmCallException('Voice server error (${res.statusCode}).');
		}

		try
		{
			final json = jsonDecode(res.body) as Map<String, dynamic>;
			final url = (json['url'] ?? '').toString();
			final token = (json['token'] ?? '').toString();
			if (url.isEmpty || token.isEmpty)
			{
				throw CmCallException('Voice server did not return a token.');
			}
			return (url: url, token: token);
		}
		on CmCallException
		{
			rethrow;
		}
		catch (_)
		{
			throw CmCallException('Unexpected response from the voice server.');
		}
	}

	/// Fetch credentials, connect to the room, and publish the microphone.
	Future<lk.Room> connect() async
	{
		if (!is_available)
		{
			throw CmCallException('Voice calling is not enabled for this channel.');
		}
		final creds = await fetch_credentials();
		final r = lk.Room(roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true));
		await r.connect(creds.url, creds.token);
		await r.localParticipant?.setMicrophoneEnabled(true);
		room = r;
		return r;
	}

	/// Mute / unmute the local microphone.
	Future<void> set_muted(bool muted) async
	{
		await room?.localParticipant?.setMicrophoneEnabled(!muted);
	}

	Future<void> disconnect() async
	{
		try
		{
			await room?.disconnect();
		}
		catch (_) {}
		await room?.dispose();
		room = null;
	}

	void close() => _http.close();
}

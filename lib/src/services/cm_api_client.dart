import 'dart:convert';
import 'package:http/http.dart' as http;

import '../cm_config.dart';
import '../models/cm_session.dart';

/// Thrown when the session bootstrap fails (bad/revoked key, network, etc).
class CmApiException implements Exception
{
	final String message;
	final int? status_code;
	CmApiException(this.message, {this.status_code});

	@override
	String toString() => 'CmApiException($status_code): $message';
}

/// REST layer for the Mobile App channel: bootstraps a session and posts
/// outgoing messages. Bot/agent replies arrive over the socket, not here.
class CmApiClient
{
	final CmConfig _config;
	final http.Client _http;

	CmApiClient(this._config, {http.Client? client}) : _http = client ?? http.Client();

	/// API-key authenticated bootstrap. Returns the resolved [CmSession].
	Future<CmSession> create_session({
		required String user_id,
		required String conversation_id,
	}) async
	{
		final body = <String, dynamic>{
			'user_id': user_id,
			'conversation_id': conversation_id,
			if (_config.bundle_id != null) 'bundle_id': _config.bundle_id,
			if (_config.lead_info != null) 'lead_info': _config.lead_info!.to_json(),
		};

		http.Response res;
		try
		{
			res = await _http.post(
				Uri.parse(_config.session_endpoint),
				headers: {
					'Content-Type': 'application/json',
					'Accept': 'application/json',
					'Authorization': 'Bearer ${_config.api_key}',
				},
				body: jsonEncode(body),
			);
		}
		catch (e)
		{
			throw CmApiException('Network error reaching ${_config.session_endpoint}: $e');
		}

		if (res.statusCode != 200)
		{
			throw CmApiException(_extract_error(res.body), status_code: res.statusCode);
		}

		Map<String, dynamic> json;
		try
		{
			json = jsonDecode(res.body) as Map<String, dynamic>;
		}
		catch (_)
		{
			throw CmApiException('Unexpected response from server.', status_code: res.statusCode);
		}

		if (json['error'] != null)
		{
			throw CmApiException(json['error'].toString(), status_code: res.statusCode);
		}

		return CmSession.from_json(json);
	}

	/// Send a message into the conversation. Mirrors the website widget's
	/// multipart POST to /webhooks/livechatwidget/. The actual reply is
	/// delivered back through the socket, so this returns once accepted.
	Future<void> send_message({
		required CmSession session,
		required String query,
		String media_url = '',
		String media_type = '',
		String? parent_message_id,
		Map<String, dynamic>? customer_data,
		String? reference_sid,
	}) async
	{
		final request = http.MultipartRequest('POST', Uri.parse(session.send_message_url));
		request.fields.addAll({
			'query': query,
			'user_id': session.end_user_id,
			'account_alias': session.account_alias,
			'conversation_id': session.conversation_id,
			// Client-side message id (spelling matches backend). The server
			// echoes it back so the client can dedupe its own message.
			'cb_reference_messsage_sid': reference_sid ?? _reference_sid(),
			'message_user_datetime': _now_with_millis(),
			'media_url': media_url,
			'media_type': media_type,
			'preview_bot_alias': '',
			'send_encrypt_message': 'false',
			'cb_message_parent_id': parent_message_id ?? '',
			'customer_data': jsonEncode(customer_data ?? (_config.lead_info?.to_json() ?? {})),
			'page_url_details': jsonEncode({'source': 'mobile_app'}),
		});

		http.StreamedResponse res;
		try
		{
			res = await request.send();
		}
		catch (e)
		{
			throw CmApiException('Failed to send message: $e');
		}

		if (res.statusCode != 200)
		{
			throw CmApiException('Send failed', status_code: res.statusCode);
		}
	}

	/// Upload a local media file (image/audio/file) and return the public URL +
	/// resolved media_type. Mirrors the widget's POST to /webhooks/upload_media/.
	Future<({String media_url, String media_type})> upload_media({
		required CmSession session,
		required String file_path,
	}) async
	{
		final request = http.MultipartRequest('POST', Uri.parse(session.upload_media_url));
		request.fields['account_alias'] = session.account_alias;
		request.files.add(await http.MultipartFile.fromPath('file', file_path));

		http.StreamedResponse streamed;
		try
		{
			streamed = await request.send();
		}
		catch (e)
		{
			throw CmApiException('Failed to upload media: $e');
		}

		final body = await streamed.stream.bytesToString();
		if (streamed.statusCode != 200)
		{
			throw CmApiException('Media upload failed', status_code: streamed.statusCode);
		}

		try
		{
			final json = jsonDecode(body) as Map<String, dynamic>;
			final url = (json['media_url'] ?? '').toString();
			final type = (json['media_type'] ?? '').toString();
			if (url.isEmpty)
			{
				throw CmApiException('Upload returned no media_url.');
			}
			return (media_url: url, media_type: type);
		}
		on CmApiException
		{
			rethrow;
		}
		catch (_)
		{
			throw CmApiException('Unexpected upload response.');
		}
	}

	/// Fetch the visitor's past conversations (raw JSON maps; map with
	/// CmConversation.from_json). Returns [] on any non-fatal failure.
	Future<List<Map<String, dynamic>>> fetch_conversations({required CmSession session}) async
	{
		final url = '${_config.base_url}mobileapp/conversations/';
		final res = await _post_json(url, {'user_id': session.end_user_id});
		final data = res['data'];
		if (data is List)
		{
			return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
		}
		return <Map<String, dynamic>>[];
	}

	/// Fetch the message history of a conversation (raw JSON maps; map with
	/// CmMessageMapper.from_history). Returns [] on any non-fatal failure.
	Future<List<Map<String, dynamic>>> fetch_messages({
		required CmSession session,
		required String conversation_id,
	}) async
	{
		final url = '${_config.base_url}mobileapp/messages/';
		final res = await _post_json(url, {
			'user_id': session.end_user_id,
			'conversation_id': conversation_id,
		});
		final data = res['data'];
		if (data is List)
		{
			return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
		}
		return <Map<String, dynamic>>[];
	}

	// Shared authenticated JSON POST used by the list/history endpoints.
	Future<Map<String, dynamic>> _post_json(String url, Map<String, dynamic> body) async
	{
		http.Response res;
		try
		{
			res = await _http.post(
				Uri.parse(url),
				headers: {
					'Content-Type': 'application/json',
					'Accept': 'application/json',
					'Authorization': 'Bearer ${_config.api_key}',
				},
				body: jsonEncode(body),
			);
		}
		catch (e)
		{
			throw CmApiException('Network error reaching $url: $e');
		}
		if (res.statusCode != 200)
		{
			throw CmApiException('Request failed', status_code: res.statusCode);
		}
		try
		{
			final decoded = jsonDecode(res.body);
			return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
		}
		catch (_)
		{
			return <String, dynamic>{};
		}
	}

	void close() => _http.close();

	String _extract_error(String body)
	{
		try
		{
			final json = jsonDecode(body);
			if (json is Map && json['error'] != null) return json['error'].toString();
		}
		catch (_) {}
		return 'Could not start chat session.';
	}

	// 10-char reference id matching the widget's client-generated sid.
	String _reference_sid()
	{
		const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
		final ms = DateTime.now().microsecondsSinceEpoch;
		final buf = StringBuffer();
		var seed = ms;
		for (var i = 0; i < 10; i++)
		{
			buf.write(chars[seed % chars.length]);
			seed = seed ~/ chars.length + 7;
		}
		return buf.toString();
	}

	// "yyyy-MM-dd HH:mm:ss.SSSS" to match the widget's message_user_datetime.
	String _now_with_millis()
	{
		final now = DateTime.now();
		String two(int n) => n.toString().padLeft(2, '0');
		final date = '${now.year}-${two(now.month)}-${two(now.day)}';
		final time = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
		final frac = now.millisecond.toString().padLeft(4, '0');
		return '$date $time.$frac';
	}
}

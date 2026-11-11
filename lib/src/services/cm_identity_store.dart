import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persists the visitor id and conversation id between launches, scoped per
/// API key so multiple channels in one app do not collide. This mirrors how
/// the website widget keeps identity in localStorage.
class CmIdentityStore
{
	static const _uuid = Uuid();

	final String _user_key;
	final String _conversation_key;
	final String _session_token_key;

	CmIdentityStore(String api_key)
		: _user_key = 'cm_user_id:$api_key',
		  _conversation_key = 'cm_conversation_id:$api_key',
		  _session_token_key = 'cm_session_token:$api_key';

	/// Return the stored visitor id, or null for a first launch. The visitor id is never generated on the device:
	/// the backend creates it on the first session call and only a visitor it created (or one proving its id with
	/// its session token) is given a token, so a device-made id would never be proven.
	Future<String?> get_user_id() async
	{
		final prefs = await SharedPreferences.getInstance();
		final id = prefs.getString(_user_key);
		if (id == null || id.isEmpty)
		{
			return null;
		}
		return id;
	}

	/// The session token stored for [user_id], or null. The token is kept together with the visitor id it was issued
	/// for and is only returned for that same id, so a request never pairs one visitor's id with another's token.
	Future<String?> get_session_token(String? user_id) async
	{
		if (user_id == null || user_id.isEmpty)
		{
			return null;
		}
		final prefs = await SharedPreferences.getInstance();
		final raw = prefs.getString(_session_token_key);
		if (raw == null || raw.isEmpty)
		{
			return null;
		}
		try
		{
			final stored = jsonDecode(raw);
			if (stored is Map && stored['u'] == user_id && (stored['t'] ?? '').toString().isNotEmpty)
			{
				return stored['t'].toString();
			}
		}
		catch (_) {}
		return null;
	}

	/// Return the stored conversation id, generating and persisting one if absent.
	Future<String> get_or_create_conversation_id() async
	{
		final prefs = await SharedPreferences.getInstance();
		var id = prefs.getString(_conversation_key);
		if (id == null || id.isEmpty)
		{
			id = _uuid.v4();
			await prefs.setString(_conversation_key, id);
		}
		return id;
	}

	/// Persist server-confirmed identifiers (the backend may return the
	/// canonical conversation id / visitor id) and the session token issued for that visitor.
	Future<void> save({String? user_id, String? conversation_id, String? session_token}) async
	{
		final prefs = await SharedPreferences.getInstance();
		if (user_id != null && user_id.isNotEmpty) await prefs.setString(_user_key, user_id);
		if (conversation_id != null && conversation_id.isNotEmpty) await prefs.setString(_conversation_key, conversation_id);
		if (user_id != null && user_id.isNotEmpty && session_token != null && session_token.isNotEmpty)
		{
			await prefs.setString(_session_token_key, jsonEncode({'u': user_id, 't': session_token}));
		}
	}

	/// Forget the current conversation (e.g. "start new chat"). The visitor id
	/// is kept so the same person stays recognised.
	Future<void> reset_conversation() async
	{
		final prefs = await SharedPreferences.getInstance();
		await prefs.remove(_conversation_key);
	}

	/// Forget everything for this key (full logout).
	Future<void> clear() async
	{
		final prefs = await SharedPreferences.getInstance();
		await prefs.remove(_user_key);
		await prefs.remove(_conversation_key);
		await prefs.remove(_session_token_key);
	}
}

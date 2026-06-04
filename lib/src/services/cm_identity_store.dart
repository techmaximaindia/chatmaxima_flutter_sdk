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

	CmIdentityStore(String api_key)
		: _user_key = 'cm_user_id:$api_key',
		  _conversation_key = 'cm_conversation_id:$api_key';

	/// Return the stored visitor id, generating and persisting one if absent.
	Future<String> get_or_create_user_id() async
	{
		final prefs = await SharedPreferences.getInstance();
		var id = prefs.getString(_user_key);
		if (id == null || id.isEmpty)
		{
			id = _uuid.v4();
			await prefs.setString(_user_key, id);
		}
		return id;
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
	/// canonical conversation id / visitor id).
	Future<void> save({String? user_id, String? conversation_id}) async
	{
		final prefs = await SharedPreferences.getInstance();
		if (user_id != null && user_id.isNotEmpty) await prefs.setString(_user_key, user_id);
		if (conversation_id != null && conversation_id.isNotEmpty) await prefs.setString(_conversation_key, conversation_id);
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
	}
}

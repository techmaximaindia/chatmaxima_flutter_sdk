import 'cm_config.dart';
import 'models/cm_lead_info.dart';
import 'models/cm_session.dart';
import 'services/cm_api_client.dart';
import 'services/cm_identity_store.dart';

/// Entry point for the ChatMaxima SDK.
///
/// Call [init] once (e.g. at app start or just before opening chat) to
/// bootstrap a session with your mobile_app channel API key. The drop-in
/// UI ([ChatMaximaChatScreen]) then uses the live session automatically.
///
/// ```dart
/// await Chatmaxima.instance.init(api_key: 'cmk_xxx');
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const ChatMaximaChatScreen(),
/// ));
/// ```
class Chatmaxima
{
	Chatmaxima._();

	/// Shared instance.
	static final Chatmaxima instance = Chatmaxima._();

	CmConfig? _config;
	CmApiClient? _api;
	CmIdentityStore? _identity;
	CmSession? _session;

	bool get is_initialized => _session != null;

	CmConfig get config => _require(_config, 'config');
	CmApiClient get api => _require(_api, 'api');
	CmIdentityStore get identity => _require(_identity, 'identity');
	CmSession get session => _require(_session, 'session');

	/// Bootstrap a session. Returns the resolved [CmSession] (also kept on the
	/// singleton). Throws [CmApiException] on a bad/revoked key or network error.
	Future<CmSession> init({
		required String api_key,
		String base_url = 'https://chatmaxima.com/',
		String? socket_url,
		String? bundle_id,
		CmLeadInfo? lead_info,
		bool debug = false,
	}) async
	{
		return init_with(CmConfig(
			api_key: api_key,
			base_url: base_url,
			socket_url: socket_url,
			bundle_id: bundle_id,
			lead_info: lead_info,
			debug: debug,
		));
	}

	/// Bootstrap from a prepared [CmConfig].
	Future<CmSession> init_with(CmConfig config) async
	{
		_config = config;
		_api = CmApiClient(config);
		_identity = CmIdentityStore(config.api_key);

		final user_id = await _identity!.get_or_create_user_id();
		final conversation_id = await _identity!.get_or_create_conversation_id();

		final session = await _api!.create_session(
			user_id: user_id,
			conversation_id: conversation_id,
		);

		// Persist the server-confirmed identifiers.
		await _identity!.save(
			user_id: session.end_user_id,
			conversation_id: session.conversation_id,
		);
		_session = session;
		return session;
	}

	/// Abandon the current conversation and start a fresh one (keeps the same
	/// visitor identity). Re-bootstraps and returns the new session.
	Future<CmSession> start_new_conversation() async
	{
		_ensure_initialized();
		await _identity!.reset_conversation();
		final user_id = await _identity!.get_or_create_user_id();
		final conversation_id = await _identity!.get_or_create_conversation_id();
		final session = await _api!.create_session(
			user_id: user_id,
			conversation_id: conversation_id,
		);
		await _identity!.save(user_id: session.end_user_id, conversation_id: session.conversation_id);
		_session = session;
		return session;
	}

	/// Send a text message into the active conversation. Replies arrive over
	/// the socket (handled by the chat UI). Throws if not initialized.
	Future<void> send_text(String text) async
	{
		_ensure_initialized();
		await _api!.send_message(session: _session!, query: text);
	}

	/// Release resources. Call when fully done (e.g. user logs out).
	void dispose()
	{
		_api?.close();
		_config = null;
		_api = null;
		_identity = null;
		_session = null;
	}

	void _ensure_initialized()
	{
		if (!is_initialized)
		{
			throw StateError('Chatmaxima.init() must be awaited before use.');
		}
	}

	T _require<T>(T? value, String what)
	{
		if (value == null)
		{
			throw StateError('Chatmaxima not initialized: missing $what. Call init() first.');
		}
		return value;
	}
}

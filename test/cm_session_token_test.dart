import 'dart:convert';

import 'package:chatmaxima_flutter_sdk/src/cm_config.dart';
import 'package:chatmaxima_flutter_sdk/src/services/cm_api_client.dart';
import 'package:chatmaxima_flutter_sdk/src/services/cm_identity_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The visitor session token: a first launch lets the backend create the visitor, a returning visitor proves its id
// with the token issued for it, and every later call carries that token.
void main()
{
	TestWidgetsFlutterBinding.ensureInitialized();

	final requests = <Map<String, dynamic>>[];
	Map<String, dynamic> next_session = {};

	http.Client mock_backend()
	{
		return MockClient((request) async
		{
			final body = jsonDecode(request.body) as Map<String, dynamic>;
			requests.add({'path': request.url.path, ...body});
			if (request.url.path.endsWith('/mobileapp/session/'))
			{
				return http.Response(jsonEncode(next_session), 200);
			}
			return http.Response(jsonEncode({'data': []}), 200);
		});
	}

	setUp(()
	{
		requests.clear();
		SharedPreferences.setMockInitialValues({});
	});

	test('first launch sends no visitor id, then the stored id goes with its token', () async
	{
		const config = CmConfig(api_key: 'cmk_test');
		final api = CmApiClient(config, client: mock_backend());
		final identity = CmIdentityStore(config.api_key);

		// First launch: nothing stored, so no user_id and no token go up
		expect(await identity.get_user_id(), isNull);
		next_session = {'end_user_id': 'visitor-1', 'conversation_id': 'conv-1', 'session_token': 'cmw2.p.s1', 'account_alias': 'acct'};
		final first = await api.create_session(user_id: null, conversation_id: 'conv-1', session_token: null);
		expect(requests.last.containsKey('user_id'), isFalse);
		expect(requests.last.containsKey('session_token'), isFalse);
		expect(first.session_token, 'cmw2.p.s1');
		await identity.save(user_id: first.end_user_id, conversation_id: first.conversation_id, session_token: first.session_token);

		// Next launch: the stored id goes with the token issued for it
		final user_id = await identity.get_user_id();
		final token = await identity.get_session_token(user_id);
		expect(user_id, 'visitor-1');
		expect(token, 'cmw2.p.s1');
		next_session = {'end_user_id': 'visitor-1', 'conversation_id': 'conv-1', 'session_token': 'cmw2.p.s2', 'account_alias': 'acct'};
		final second = await api.create_session(user_id: user_id, conversation_id: 'conv-1', session_token: token);
		expect(requests.last['user_id'], 'visitor-1');
		expect(requests.last['session_token'], 'cmw2.p.s1');

		// History calls carry the current token
		await api.fetch_conversations(session: second);
		expect(requests.last['session_token'], 'cmw2.p.s2');
		await api.fetch_messages(session: second, conversation_id: 'conv-1');
		expect(requests.last['session_token'], 'cmw2.p.s2');
		expect(requests.last['conversation_id'], 'conv-1');
	});

	test('a token is only handed out for the visitor it was issued to', () async
	{
		final identity = CmIdentityStore('cmk_test');
		await identity.save(user_id: 'visitor-1', session_token: 'cmw2.p.s1');
		expect(await identity.get_session_token('visitor-1'), 'cmw2.p.s1');
		expect(await identity.get_session_token('visitor-2'), isNull);
		expect(await identity.get_session_token(null), isNull);

		// The backend started a fresh visitor: the new id replaces the old pair
		await identity.save(user_id: 'visitor-2', session_token: 'cmw2.p.s9');
		expect(await identity.get_session_token('visitor-1'), isNull);
		expect(await identity.get_session_token('visitor-2'), 'cmw2.p.s9');

		// An empty token (unproven visitor) never wipes or replaces a stored pair
		await identity.save(user_id: 'visitor-2', session_token: '');
		expect(await identity.get_session_token('visitor-2'), 'cmw2.p.s9');

		await identity.clear();
		expect(await identity.get_user_id(), isNull);
		expect(await identity.get_session_token('visitor-2'), isNull);
	});
}

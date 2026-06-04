// Compilation smoke test. Importing the chatview barrel forces the whole
// package to compile, including chatui_textfield.dart (audioplayers /
// permission_handler) and chat_view_appbar.dart (previously coupled to the
// host app). If the fork were still broken, this file would fail to COMPILE,
// so simply building + running it is the assertion. We avoid pumping the full
// ChatView to keep the test free of layout-overflow noise in the tiny test
// viewport.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chatview/chatview.dart';

void main()
{
	test('chatview fork compiles standalone and exposes the decoupled appbar API', ()
	{
		// The decoupled handler replaces the old host-app import; referencing it
		// proves the new API exists.
		ChatViewAppBar.onProfileTap = (context, data) {};
		expect(ChatViewAppBar.onProfileTap, isNotNull);

		// Construct the core types (no pump → no layout) to exercise the symbols.
		final controller = ChatController(
			initialMessageList: <Message>[],
			scrollController: ScrollController(),
			chatUsers: [ChatUser(id: '2', name: 'Agent', chatmaxima_user_name: 'Agent')],
		);
		const appBar = ChatViewAppBar(chatTitle: 'Test');

		expect(controller.initialMessageList, isEmpty);
		expect(appBar.chatTitle, 'Test');

		controller.dispose();
		ChatViewAppBar.onProfileTap = null;
	});
}

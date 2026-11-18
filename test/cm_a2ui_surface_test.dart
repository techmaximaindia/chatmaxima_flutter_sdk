import 'dart:convert';
import 'dart:io';

import 'package:chatmaxima_flutter_sdk/src/cm_strings.dart';
import 'package:chatmaxima_flutter_sdk/src/services/cm_message_mapper.dart';
import 'package:chatmaxima_flutter_sdk/src/ui/cm_a2ui_surface.dart';
import 'package:chatmaxima_flutter_sdk/src/ui/cm_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Draws every built-in Widget Library template (as the server renders it) and
// presses the Product Card's button, so a layout the renderer cannot handle
// fails here instead of in a customer's app.
void main()
{
	final fixtures = (jsonDecode(File('test/fixtures/widget_templates.json').readAsStringSync()) as Map).cast<String, dynamic>();

	for (final entry in fixtures.entries)
	{
		testWidgets('draws ${entry.key}', (tester) async
		{
			final payload = CmA2uiPayload.from_extra_params(entry.value);
			expect(payload, isNotNull);
			await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: CmA2uiSurface(
				message_id: 'm_${entry.key}',
				payload: payload!,
				accent: const Color(0xFF3B7DDD),
				on_action: (action, label) {},
			)))));
			await tester.pump();
			// Network images cannot load in tests (the framework answers 400); the renderer shows its placeholder.
			final error = tester.takeException();
			if (error != null && !error.toString().contains('NetworkImage') && !error.toString().contains('HTTP') && !error.toString().contains('statusCode'))
			{
				fail('render error: $error');
			}
			expect(find.byType(Text), findsWidgets);
		});
	}

	testWidgets('product card: choose a size, press the button, get the A2UI action', (tester) async
	{
		tester.view.physicalSize = const Size(1200, 4000);
		addTearDown(tester.view.resetPhysicalSize);
		final payload = CmA2uiPayload.from_extra_params(fixtures['product_card'])!;
		Map<String, dynamic>? sent;
		String sent_label = '';
		await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: CmA2uiSurface(
			message_id: 'm_press',
			payload: payload,
			accent: const Color(0xFF3B7DDD),
			on_action: (action, label) { sent = action; sent_label = label; },
		)))));
		await tester.pump();
		tester.takeException(); // the sample image cannot load in a test
		await tester.tap(find.text('42'));
		await tester.pump();
		await tester.tap(find.text('Add to Cart'));
		await tester.pump();
		expect(sent, isNotNull);
		expect(sent!['name'], 'add_to_cart');
		expect(sent!['surfaceId'], startsWith('cmw_'));
		expect((sent!['context'] as Map)['size'], ['42']);
		expect(sent_label.split('\n').first, 'Add to Cart'); // the bubble: the button, then what was chosen
		expect(sent_label.split('\n').last, endsWith(': 42'));
		expect(CmA2uiRegistry.is_answered('m_press'), isTrue);
	});

	testWidgets('dark theme: the widget takes the dark chat colours', (tester) async
	{
		tester.view.physicalSize = const Size(1200, 4000);
		addTearDown(tester.view.resetPhysicalSize);
		final payload = CmA2uiPayload.from_extra_params(fixtures['coupon_code_card'])!;
		await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: SingleChildScrollView(child: CmA2uiSurface(
			message_id: 'm_dark',
			payload: payload,
			accent: const Color(0xFF3B7DDD),
			on_action: (action, label) {},
		)))));
		await tester.pump();
		tester.takeException();
		final card = tester.widgetList<Container>(find.byType(Container)).map((container) => container.decoration).whereType<BoxDecoration>().first;
		expect(card.color, CmPalette.dark.incoming_bubble);
	});

	testWidgets('strings follow the forced language and fall back to English', (tester) async
	{
		CmStrings.language_code = 'ar';
		addTearDown(() => CmStrings.language_code = null);
		expect(CmStrings.of(null).copied, 'تم النسخ');
		CmStrings.language_code = 'xx';
		expect(CmStrings.of(null).copied, 'Copied');
		CmStrings.language_code = 'pt-BR';
		expect(CmStrings.of(null).yes, 'Sim');
	});

	test('history: a stored widget is drawn again when the conversation is reopened', ()
	{
		final message = CmMessageMapper.from_history(<String, dynamic>{
			'cb_message_id': 'h_1',
			'cb_message_type': 'outgoing',
			'cb_message_text': 'Product card text',
			'cb_message_options': jsonEncode(fixtures['product_card']),
		}, app_user_id: 'me');
		expect(message.message, '${CmA2uiRegistry.marker}h_1');
		expect(CmA2uiRegistry.get('h_1'), isNotNull);

		final plain = CmMessageMapper.from_history(<String, dynamic>{
			'cb_message_id': 'h_2',
			'cb_message_type': 'outgoing',
			'cb_message_text': 'Hello',
			'cb_message_options': '{"buttons":[]}',
		}, app_user_id: 'me');
		expect(plain.message, 'Hello');
	});
}

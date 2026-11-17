import 'dart:convert';
import 'dart:io';

import 'package:chatmaxima_flutter_sdk/src/ui/cm_a2ui_surface.dart';
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
		expect(sent_label, 'Add to Cart');
		expect(CmA2uiRegistry.is_answered('m_press'), isTrue);
	});
}

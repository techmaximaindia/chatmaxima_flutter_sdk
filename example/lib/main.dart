import 'package:flutter/material.dart';
import 'package:chatmaxima_flutter_sdk/chatmaxima_flutter_sdk.dart';

void main()
{
	runApp(const DemoApp());
}

class DemoApp extends StatelessWidget
{
	const DemoApp({super.key});

	@override
	Widget build(BuildContext context)
	{
		return MaterialApp(
			title: 'ChatMaxima SDK Demo',
			theme: ThemeData(
				colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2A6AC1)),
				useMaterial3: true,
			),
			home: const LaunchScreen(),
		);
	}
}

/// A tiny launcher: enter a channel API key (and optionally your name/email),
/// then open the chat. In a real app you would call
/// `Chatmaxima.instance.init(api_key: ...)` once at startup and just push
/// `const ChatMaximaChatScreen()` from a support button.
class LaunchScreen extends StatefulWidget
{
	const LaunchScreen({super.key});

	@override
	State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
{
	final _api_key_controller = TextEditingController();
	final _base_url_controller = TextEditingController(text: 'https://chatmaxima.com/');
	final _name_controller = TextEditingController();
	final _email_controller = TextEditingController();

	@override
	void dispose()
	{
		_api_key_controller.dispose();
		_base_url_controller.dispose();
		_name_controller.dispose();
		_email_controller.dispose();
		super.dispose();
	}

	void _open_chat()
	{
		final api_key = _api_key_controller.text.trim();
		if (api_key.isEmpty)
		{
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Enter your channel API key first.')),
			);
			return;
		}

		final name = _name_controller.text.trim();
		final email = _email_controller.text.trim();

		Navigator.push(context, MaterialPageRoute(
			builder: (_) => ChatMaximaChatScreen(
				api_key: api_key,
				base_url: _base_url_controller.text.trim().isEmpty
					? 'https://chatmaxima.com/'
					: _base_url_controller.text.trim(),
				lead_info: (name.isNotEmpty || email.isNotEmpty)
					? CmLeadInfo(
						name: name.isEmpty ? null : name,
						email: email.isEmpty ? null : email,
					)
					: null,
			),
		));
	}

	@override
	Widget build(BuildContext context)
	{
		return Scaffold(
			appBar: AppBar(title: const Text('ChatMaxima SDK Demo')),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(20),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						const SizedBox(height: 8),
						const Text(
							'Enter the API key from your Mobile App Channel.',
							style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
						),
						const SizedBox(height: 16),
						TextField(
							controller: _api_key_controller,
							decoration: const InputDecoration(
								labelText: 'API Key',
								hintText: 'cmk_...',
								border: OutlineInputBorder(),
							),
						),
						const SizedBox(height: 12),
						TextField(
							controller: _base_url_controller,
							decoration: const InputDecoration(
								labelText: 'Base URL',
								border: OutlineInputBorder(),
							),
						),
						const Divider(height: 36),
						const Text('Optional: identify the user', style: TextStyle(color: Colors.grey)),
						const SizedBox(height: 12),
						TextField(
							controller: _name_controller,
							decoration: const InputDecoration(
								labelText: 'Name',
								border: OutlineInputBorder(),
							),
						),
						const SizedBox(height: 12),
						TextField(
							controller: _email_controller,
							keyboardType: TextInputType.emailAddress,
							decoration: const InputDecoration(
								labelText: 'Email',
								border: OutlineInputBorder(),
							),
						),
						const SizedBox(height: 24),
						FilledButton.icon(
							onPressed: _open_chat,
							icon: const Icon(Icons.chat_bubble_outline),
							label: const Padding(
								padding: EdgeInsets.symmetric(vertical: 12),
								child: Text('Open Chat'),
							),
						),
					],
				),
			),
		);
	}
}

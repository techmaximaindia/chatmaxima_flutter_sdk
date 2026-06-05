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

/// Enter a channel API key (and optionally name/email), initialise the SDK,
/// then open the conversation list. In a real app you would call
/// `Chatmaxima.instance.init(api_key: ...)` once at startup.
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
	bool _busy = false;

	@override
	void dispose()
	{
		_api_key_controller.dispose();
		_base_url_controller.dispose();
		_name_controller.dispose();
		_email_controller.dispose();
		super.dispose();
	}

	Future<void> _open() async
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

		setState(() => _busy = true);
		try
		{
			await Chatmaxima.instance.init(
				api_key: api_key,
				base_url: _base_url_controller.text.trim().isEmpty
					? 'https://chatmaxima.com/'
					: _base_url_controller.text.trim(),
				lead_info: (name.isNotEmpty || email.isNotEmpty)
					? CmLeadInfo(name: name.isEmpty ? null : name, email: email.isEmpty ? null : email)
					: null,
			);
			if (!mounted) return;
			Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsScreen()));
		}
		catch (e)
		{
			final message = e is CmApiException ? e.message : 'Could not start. Please try again.';
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
		}
		finally
		{
			if (mounted) setState(() => _busy = false);
		}
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
							decoration: const InputDecoration(labelText: 'API Key', hintText: 'cmk_...', border: OutlineInputBorder()),
						),
						const SizedBox(height: 12),
						TextField(
							controller: _base_url_controller,
							decoration: const InputDecoration(labelText: 'Base URL', border: OutlineInputBorder()),
						),
						const Divider(height: 36),
						const Text('Optional: identify the user', style: TextStyle(color: Colors.grey)),
						const SizedBox(height: 12),
						TextField(
							controller: _name_controller,
							decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
						),
						const SizedBox(height: 12),
						TextField(
							controller: _email_controller,
							keyboardType: TextInputType.emailAddress,
							decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
						),
						const SizedBox(height: 24),
						FilledButton.icon(
							onPressed: _busy ? null : _open,
							icon: _busy
								? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
								: const Icon(Icons.chat_bubble_outline),
							label: const Padding(
								padding: EdgeInsets.symmetric(vertical: 12),
								child: Text('Continue'),
							),
						),
					],
				),
			),
		);
	}
}

/// Lists the visitor's past conversations. Tap one to resume it, or start a
/// fresh chat from the button.
class ConversationsScreen extends StatefulWidget
{
	const ConversationsScreen({super.key});

	@override
	State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
{
	late Future<List<CmConversation>> _future;

	@override
	void initState()
	{
		super.initState();
		_future = Chatmaxima.instance.list_conversations();
	}

	Future<void> _refresh() async
	{
		setState(() => _future = Chatmaxima.instance.list_conversations());
		await _future;
	}

	Future<void> _open(String? conversation_id) async
	{
		await Navigator.push(context, MaterialPageRoute(
			builder: (_) => ChatMaximaChatScreen(conversation_id: conversation_id),
		));
		if (mounted) _refresh(); // reflect new messages on return
	}

	Future<void> _new_chat() async
	{
		await Chatmaxima.instance.start_new_conversation();
		if (!mounted) return;
		_open(Chatmaxima.instance.session.conversation_id);
	}

	@override
	Widget build(BuildContext context)
	{
		return Scaffold(
			appBar: AppBar(title: const Text('Conversations')),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: _new_chat,
				icon: const Icon(Icons.add_comment_outlined),
				label: const Text('New chat'),
			),
			body: RefreshIndicator(
				onRefresh: _refresh,
				child: FutureBuilder<List<CmConversation>>(
					future: _future,
					builder: (context, snapshot)
					{
						if (snapshot.connectionState == ConnectionState.waiting)
						{
							return const Center(child: CircularProgressIndicator());
						}
						final items = snapshot.data ?? const <CmConversation>[];
						if (items.isEmpty)
						{
							return ListView(
								children: const [
									SizedBox(height: 120),
									Icon(Icons.forum_outlined, size: 48, color: Colors.grey),
									SizedBox(height: 12),
									Center(child: Text('No conversations yet. Start a new chat.')),
								],
							);
						}
						return ListView.separated(
							itemCount: items.length,
							separatorBuilder: (_, __) => const Divider(height: 1),
							itemBuilder: (context, i)
							{
								final c = items[i];
								return ListTile(
									leading: CircleAvatar(
										backgroundImage: c.profile_image.isNotEmpty ? NetworkImage(c.profile_image) : null,
										child: c.profile_image.isEmpty ? const Icon(Icons.support_agent) : null,
									),
									title: Text(c.profile_name.isNotEmpty ? c.profile_name : 'Conversation'),
									subtitle: Text(c.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
									trailing: Column(
										mainAxisAlignment: MainAxisAlignment.center,
										crossAxisAlignment: CrossAxisAlignment.end,
										children: [
											Text(c.last_message_label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
											if (c.unread_count > 0)
												Container(
													margin: const EdgeInsets.only(top: 4),
													padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
													decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
													child: Text('${c.unread_count}', style: const TextStyle(color: Colors.white, fontSize: 11)),
												),
										],
									),
									onTap: () => _open(c.id),
								);
							},
						);
					},
				),
			),
		);
	}
}

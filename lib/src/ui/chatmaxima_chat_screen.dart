import 'package:flutter/material.dart';

import '../chatmaxima.dart';
import '../models/cm_lead_info.dart';
import '../models/cm_session.dart';
import '../services/cm_api_client.dart';
import 'chatmaxima_chat_view.dart';

/// A complete, themed chat screen you can push straight onto the navigator.
///
/// If [Chatmaxima.instance] is already initialized it shows the chat
/// immediately. Otherwise pass [api_key] (and optional lead/config) and the
/// screen bootstraps the session itself, showing loading and error states.
///
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const ChatMaximaChatScreen(api_key: 'cmk_xxx'),
/// ));
/// ```
class ChatMaximaChatScreen extends StatefulWidget
{
	/// API key to bootstrap with, when the SDK is not already initialized.
	final String? api_key;
	final String base_url;
	final String? bundle_id;
	final CmLeadInfo? lead_info;

	/// Optional title override for the app bar (defaults to channel title).
	final String? title;

	const ChatMaximaChatScreen({
		super.key,
		this.api_key,
		this.base_url = 'https://chatmaxima.com/',
		this.bundle_id,
		this.lead_info,
		this.title,
	});

	@override
	State<ChatMaximaChatScreen> createState() => _ChatMaximaChatScreenState();
}

class _ChatMaximaChatScreenState extends State<ChatMaximaChatScreen>
{
	late Future<CmSession> _bootstrap;

	@override
	void initState()
	{
		super.initState();
		_bootstrap = _ensure_session();
	}

	Future<CmSession> _ensure_session()
	{
		if (Chatmaxima.instance.is_initialized)
		{
			return Future.value(Chatmaxima.instance.session);
		}
		if (widget.api_key == null)
		{
			return Future.error(CmApiException(
				'Chatmaxima is not initialized. Call Chatmaxima.instance.init() or pass api_key.',
			));
		}
		return Chatmaxima.instance.init(
			api_key: widget.api_key!,
			base_url: widget.base_url,
			bundle_id: widget.bundle_id,
			lead_info: widget.lead_info,
		);
	}

	void _retry()
	{
		setState(() => _bootstrap = _ensure_session());
	}

	@override
	Widget build(BuildContext context)
	{
		return FutureBuilder<CmSession>(
			future: _bootstrap,
			builder: (context, snapshot)
			{
				if (snapshot.connectionState == ConnectionState.waiting)
				{
					return _scaffold(widget.title ?? 'Chat', const Center(child: CircularProgressIndicator()));
				}

				if (snapshot.hasError)
				{
					return _scaffold(widget.title ?? 'Chat', _error_view(snapshot.error));
				}

				final session = snapshot.data!;
				final site = session.site;
				return Scaffold(
					appBar: site.show_header
						? AppBar(
							backgroundColor: site.theme_color,
							foregroundColor: site.theme_foreground_color,
							titleSpacing: 0,
							title: Row(
								children: [
									if (site.logo_bot != null)
										Padding(
											padding: const EdgeInsets.only(right: 10),
											child: CircleAvatar(
												radius: 16,
												backgroundColor: Colors.white,
												backgroundImage: NetworkImage(site.logo_bot!),
											),
										),
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												Text(widget.title ?? site.title,
													style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
												if (site.team_name.isNotEmpty)
													Text(site.team_name,
														style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
											],
										),
									),
								],
							),
						)
						: null,
					body: ChatMaximaChatView(session: session),
				);
			},
		);
	}

	Widget _scaffold(String title, Widget body)
	{
		return Scaffold(
			appBar: AppBar(title: Text(title)),
			body: body,
		);
	}

	Widget _error_view(Object? error)
	{
		final message = error is CmApiException ? error.message : 'Could not start chat. Please try again.';
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(24),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
						const SizedBox(height: 12),
						Text(message, textAlign: TextAlign.center),
						const SizedBox(height: 16),
						FilledButton(onPressed: _retry, child: const Text('Retry')),
					],
				),
			),
		);
	}
}

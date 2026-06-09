import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import '../chatmaxima.dart';
import '../models/cm_session.dart';
import '../services/cm_call_service.dart';

enum _CallState { connecting, connected, error, ended }

/// Full-screen AI voice-agent call (same path as the website widget: LiveKit).
///
/// Push it when [CmSession.site.voice_agent_enabled] is true. It requests the
/// microphone, joins the LiveKit room, and shows call controls.
class CmCallScreen extends StatefulWidget
{
	final CmSession? session;
	const CmCallScreen({super.key, this.session});

	@override
	State<CmCallScreen> createState() => _CmCallScreenState();
}

class _CmCallScreenState extends State<CmCallScreen>
{
	late final CmSession _session;
	late final CmCallService _service;
	lk.EventsListener<lk.RoomEvent>? _listener;

	_CallState _state = _CallState.connecting;
	String _error = '';
	bool _muted = false;
	bool _agent_speaking = false;

	@override
	void initState()
	{
		super.initState();
		_session = widget.session ?? Chatmaxima.instance.session;
		_service = CmCallService(_session);
		_start();
	}

	Future<void> _start() async
	{
		// Microphone permission is required before joining.
		final status = await Permission.microphone.request();
		if (!status.isGranted)
		{
			_fail('Microphone permission is needed to start a call.');
			return;
		}

		try
		{
			final room = await _service.connect();
			if (!mounted) return;

			final listener = room.createListener();
			listener
				..on<lk.RoomDisconnectedEvent>((_) => _end())
				..on<lk.ActiveSpeakersChangedEvent>((e)
				{
					final speaking = e.speakers.any((p) => p is lk.RemoteParticipant);
					if (mounted) setState(() => _agent_speaking = speaking);
				});
			_listener = listener;

			setState(() => _state = _CallState.connected);
		}
		on CmCallException catch (e)
		{
			_fail(e.message);
		}
		catch (e)
		{
			_fail('Could not start the call. Please try again.');
		}
	}

	void _fail(String message)
	{
		if (!mounted) return;
		setState(()
		{
			_state = _CallState.error;
			_error = message;
		});
	}

	Future<void> _toggle_mute() async
	{
		setState(() => _muted = !_muted);
		await _service.set_muted(_muted);
	}

	Future<void> _end() async
	{
		await _listener?.dispose();
		_listener = null;
		await _service.disconnect();
		if (mounted && _state != _CallState.ended)
		{
			setState(() => _state = _CallState.ended);
			Navigator.of(context).maybePop();
		}
	}

	@override
	void dispose()
	{
		_listener?.dispose();
		_service.disconnect();
		_service.close();
		super.dispose();
	}

	@override
	Widget build(BuildContext context)
	{
		final accent = _session.site.theme_color;
		final bot_name = _session.site.assign_bot_name.isNotEmpty ? _session.site.assign_bot_name : _session.site.title;

		return Scaffold(
			backgroundColor: const Color(0xFF0F172A),
			body: SafeArea(
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
					child: Column(
						children: [
							const Spacer(),
							_avatar(accent, bot_name),
							const SizedBox(height: 24),
							Text(bot_name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
							const SizedBox(height: 8),
							Text(_status_text(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
							if (_state == _CallState.error)
								Padding(
									padding: const EdgeInsets.only(top: 16),
									child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
								),
							const Spacer(),
							_controls(accent),
							const SizedBox(height: 8),
						],
					),
				),
			),
		);
	}

	Widget _avatar(Color accent, String name)
	{
		final logo = _session.site.logo_bot;
		final pulse = _agent_speaking ? 18.0 : 0.0;
		return AnimatedContainer(
			duration: const Duration(milliseconds: 200),
			padding: EdgeInsets.all(pulse),
			decoration: BoxDecoration(
				shape: BoxShape.circle,
				color: accent.withValues(alpha: _agent_speaking ? 0.25 : 0.0),
			),
			child: CircleAvatar(
				radius: 56,
				backgroundColor: accent,
				backgroundImage: (logo != null && logo.isNotEmpty) ? NetworkImage(logo) : null,
				child: (logo == null || logo.isEmpty)
					? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold))
					: null,
			),
		);
	}

	String _status_text()
	{
		switch (_state)
		{
			case _CallState.connecting:
				return 'Connecting…';
			case _CallState.connected:
				return _agent_speaking ? 'Speaking…' : 'Connected';
			case _CallState.error:
				return 'Call failed';
			case _CallState.ended:
				return 'Call ended';
		}
	}

	Widget _controls(Color accent)
	{
		if (_state == _CallState.error)
		{
			return Row(
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					_round_button(icon: Icons.refresh, color: accent, onTap: ()
					{
						setState(() { _state = _CallState.connecting; _error = ''; });
						_start();
					}),
					const SizedBox(width: 28),
					_round_button(icon: Icons.call_end, color: const Color(0xFFEF4444), onTap: () => Navigator.of(context).maybePop()),
				],
			);
		}

		return Row(
			mainAxisAlignment: MainAxisAlignment.center,
			children: [
				_round_button(
					icon: _muted ? Icons.mic_off : Icons.mic,
					color: _muted ? Colors.white24 : Colors.white30,
					enabled: _state == _CallState.connected,
					onTap: _toggle_mute,
				),
				const SizedBox(width: 28),
				_round_button(icon: Icons.call_end, color: const Color(0xFFEF4444), onTap: _end),
			],
		);
	}

	Widget _round_button({required IconData icon, required Color color, required VoidCallback onTap, bool enabled = true})
	{
		return Opacity(
			opacity: enabled ? 1 : 0.4,
			child: Material(
				color: color,
				shape: const CircleBorder(),
				child: InkWell(
					customBorder: const CircleBorder(),
					onTap: enabled ? onTap : null,
					child: Padding(
						padding: const EdgeInsets.all(18),
						child: Icon(icon, color: Colors.white, size: 28),
					),
				),
			),
		);
	}
}

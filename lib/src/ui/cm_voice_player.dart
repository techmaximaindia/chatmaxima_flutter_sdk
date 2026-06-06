import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;

/// A compact voice-note player built on just_audio.
///
/// Ported from the ChatMaxima agent app's custom player. Crucially it resets
/// to the start when playback completes (the bug where the UI stayed in a
/// finished state). Plays both remote URLs and local file paths.
class CmVoicePlayer extends StatefulWidget
{
	final String audio_url;
	final bool is_right_aligned;
	final Color accent;

	const CmVoicePlayer({
		super.key,
		required this.audio_url,
		required this.is_right_aligned,
		this.accent = const Color(0xFF2A6AC1),
	});

	@override
	State<CmVoicePlayer> createState() => _CmVoicePlayerState();
}

class _CmVoicePlayerState extends State<CmVoicePlayer>
{
	late final ja.AudioPlayer _player;
	bool _playing = false;
	bool _loading = false;
	Duration _duration = Duration.zero;
	Duration _position = Duration.zero;
	bool _dragging = false;

	@override
	void initState()
	{
		super.initState();
		_player = ja.AudioPlayer();
		_attach_listeners();
		_load();
	}

	Future<void> _load() async
	{
		try
		{
			if (widget.audio_url.startsWith('http'))
			{
				await _player.setUrl(widget.audio_url);
			}
			else
			{
				await _player.setFilePath(widget.audio_url); // local recording
			}
		}
		catch (_)
		{
			// leave in a non-playable state; the play button will just no-op
		}
	}

	void _attach_listeners()
	{
		_player.playerStateStream.listen((state)
		{
			if (!mounted) return;
			setState(()
			{
				_playing = state.playing;
				_loading = state.processingState == ja.ProcessingState.loading ||
					state.processingState == ja.ProcessingState.buffering;
			});

			// Completion -> reset to the start so the bubble is replayable.
			if (state.processingState == ja.ProcessingState.completed && mounted)
			{
				_player.pause();
				_player.seek(Duration.zero);
				setState(()
				{
					_playing = false;
					_position = Duration.zero;
				});
			}
		});

		_player.durationStream.listen((d)
		{
			if (mounted && d != null) setState(() => _duration = d);
		});

		_player.positionStream.listen((p)
		{
			if (mounted && !_dragging) setState(() => _position = p);
		});
	}

	Future<void> _toggle() async
	{
		if (_playing)
		{
			await _player.pause();
		}
		else
		{
			// If at the end, restart from zero.
			if (_position >= _duration && _duration > Duration.zero)
			{
				await _player.seek(Duration.zero);
			}
			await _player.play();
		}
	}

	@override
	void dispose()
	{
		_player.dispose();
		super.dispose();
	}

	String _fmt(Duration d)
	{
		final m = d.inMinutes.remainder(60).toString();
		final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
		return '$m:$s';
	}

	@override
	Widget build(BuildContext context)
	{
		final on_color = widget.is_right_aligned ? Colors.white : widget.accent;
		final track_color = widget.is_right_aligned ? Colors.white70 : widget.accent.withValues(alpha: 0.4);
		final max_ms = _duration.inMilliseconds.toDouble();
		final pos_ms = _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble();

		return Row(
			mainAxisSize: MainAxisSize.min,
			children: [
				IconButton(
					padding: EdgeInsets.zero,
					constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
					onPressed: _toggle,
					icon: _loading
						? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: on_color))
						: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: on_color, size: 30),
				),
				Expanded(
					child: SliderTheme(
						data: SliderThemeData(
							trackHeight: 2.5,
							activeTrackColor: on_color,
							inactiveTrackColor: track_color,
							thumbColor: on_color,
							thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
							overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
						),
						child: Slider(
							min: 0,
							max: max_ms <= 0 ? 1 : max_ms,
							value: max_ms <= 0 ? 0 : pos_ms,
							onChangeStart: (_) => _dragging = true,
							onChanged: (v) => setState(() => _position = Duration(milliseconds: v.toInt())),
							onChangeEnd: (v) async
							{
								_dragging = false;
								await _player.seek(Duration(milliseconds: v.toInt()));
							},
						),
					),
				),
				Padding(
					padding: const EdgeInsets.only(right: 6),
					child: Text(
						_duration > Duration.zero ? _fmt(_position) : '',
						style: TextStyle(color: on_color, fontSize: 11),
					),
				),
			],
		);
	}
}

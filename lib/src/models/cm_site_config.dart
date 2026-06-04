import 'package:flutter/material.dart';

/// Appearance and behaviour for the chat channel, returned by the session
/// bootstrap. Drives the default look of [ChatMaximaChatScreen].
class CmSiteConfig
{
	final String title;
	final String team_name;
	final String theme_color_hex;
	final String theme_foreground_color_hex;
	final String? logo_site;
	final String? logo_bot;
	final String welcome_title;
	final String? label_first_msg;
	final bool show_header;
	final bool show_conversation_history;
	final bool allow_attachment;
	final bool speech_to_text;
	final String default_language;
	final String assign_bot_name;

	const CmSiteConfig({
		required this.title,
		required this.team_name,
		required this.theme_color_hex,
		required this.theme_foreground_color_hex,
		this.logo_site,
		this.logo_bot,
		required this.welcome_title,
		this.label_first_msg,
		required this.show_header,
		required this.show_conversation_history,
		required this.allow_attachment,
		required this.speech_to_text,
		required this.default_language,
		required this.assign_bot_name,
	});

	/// Primary brand color parsed from the hex string.
	Color get theme_color => _parse_hex(theme_color_hex, const Color(0xFF2A6AC1));

	/// Foreground (on-primary) color parsed from the hex string.
	Color get theme_foreground_color => _parse_hex(theme_foreground_color_hex, Colors.white);

	factory CmSiteConfig.from_json(Map<String, dynamic> json)
	{
		bool yes(dynamic v) => (v ?? 'Y').toString().toUpperCase() == 'Y';

		return CmSiteConfig(
			title: (json['title'] ?? 'Chat').toString(),
			team_name: (json['team_name'] ?? '').toString(),
			theme_color_hex: (json['theme_color'] ?? '#2a6ac1').toString(),
			theme_foreground_color_hex: (json['theme_foreground_color'] ?? '#FFFFFF').toString(),
			logo_site: _empty_to_null(json['logo_site']),
			logo_bot: _empty_to_null(json['logo_bot']),
			welcome_title: (json['welcome_title'] ?? 'Welcome').toString(),
			label_first_msg: _empty_to_null(json['label_first_msg']),
			show_header: yes(json['show_header']),
			show_conversation_history: yes(json['show_conversation_history']),
			allow_attachment: yes(json['allow_attachment']),
			speech_to_text: yes(json['speech_to_text']),
			default_language: (json['default_language'] ?? 'en').toString(),
			assign_bot_name: (json['assign_bot_name'] ?? '').toString(),
		);
	}

	static String? _empty_to_null(dynamic v)
	{
		if (v == null) return null;
		final s = v.toString();
		return s.isEmpty ? null : s;
	}

	static Color _parse_hex(String hex, Color fallback)
	{
		try
		{
			var value = hex.replaceAll('#', '').trim();
			if (value.length == 6) value = 'FF$value'; // add opaque alpha
			return Color(int.parse(value, radix: 16));
		}
		catch (_)
		{
			return fallback;
		}
	}
}

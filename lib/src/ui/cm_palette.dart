import 'package:flutter/material.dart';

/// The chat screen's own colours, light or dark after the host app's theme
/// (Theme.of(context).brightness). The brand colour comes from the channel's
/// settings and is the same in both.
class CmPalette
{
	final Color chat_background;
	final Color incoming_bubble;
	final Color incoming_text;
	final Color secondary_text; // quoted replies, captions
	final Color hint;
	final Color icon;
	final Color field_background;

	const CmPalette({
		required this.chat_background,
		required this.incoming_bubble,
		required this.incoming_text,
		required this.secondary_text,
		required this.hint,
		required this.icon,
		required this.field_background,
	});

	// Distinct surfaces so bubbles never blend into the background:
	// chat background = light grey, incoming bubble = white, outgoing = brand.
	static const CmPalette light = CmPalette(
		chat_background: Color(0xFFECEFF3),
		incoming_bubble: Color(0xFFFFFFFF),
		incoming_text: Color(0xFF1F2937),
		secondary_text: Color(0xFF374151),
		hint: Color(0xFF9CA3AF),
		icon: Color(0xFF6B7280),
		field_background: Color(0xFFFFFFFF),
	);

	static const CmPalette dark = CmPalette(
		chat_background: Color(0xFF111418),
		incoming_bubble: Color(0xFF222933),
		incoming_text: Color(0xFFE5E7EB),
		secondary_text: Color(0xFFD1D5DB),
		hint: Color(0xFF7B8494),
		icon: Color(0xFF9CA3AF),
		field_background: Color(0xFF222933),
	);

	static CmPalette of(BuildContext context)
	{
		if (Theme.of(context).brightness == Brightness.dark)
		{
			return dark;
		}
		return light;
	}
}

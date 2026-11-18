import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a ChatMaxima Dynamic Widget: an A2UI v1.0 surface the bot sends as
/// `extra_params.a2ui.messages` (createSurface / updateComponents /
/// updateDataModel). Mirrors the web widget's renderer for the components the
/// Widget Library produces: Card, Column, Row, List, Text, Image, Icon,
/// Divider, Button, TextField, ChoicePicker, DateTimeInput, CheckBox, Slider.
/// Tabs draw their panels one after another; Modal, Video and AudioPlayer are
/// not drawn.
///
/// The server has already checked the layout, expanded repeated lists and kept
/// only an allowlist of style properties, so this reads plain values. Unknown
/// components and style values are skipped, never guessed.
class CmA2uiPayload
{
	final String surface_id;
	final Map<String, Map<String, dynamic>> components;
	final Map<String, dynamic> data;
	final bool hide_text;

	const CmA2uiPayload({required this.surface_id, required this.components, required this.data, required this.hide_text});

	/// Parse `extra_params.a2ui`. Returns null when it holds no drawable surface.
	static CmA2uiPayload? from_extra_params(dynamic extra_params)
	{
		if (extra_params is! Map) return null;
		final a2ui = extra_params['a2ui'];
		if (a2ui is! Map) return null;
		final messages = a2ui['messages'];
		if (messages is! List) return null;

		String surface_id = '';
		final components = <String, Map<String, dynamic>>{};
		Map<String, dynamic> data = <String, dynamic>{};

		for (final message in messages)
		{
			if (message is! Map) continue;
			final create = message['createSurface'];
			if (create is Map)
			{
				surface_id = (create['surfaceId'] ?? '').toString();
			}
			final update = message['updateComponents'];
			if (update is Map && update['components'] is List)
			{
				for (final component in update['components'] as List)
				{
					if (component is Map && component['id'] != null)
					{
						components[component['id'].toString()] = component.cast<String, dynamic>();
					}
				}
			}
			final model = message['updateDataModel'];
			if (model is Map && model['value'] is Map)
			{
				data = _deep_copy(model['value'] as Map);
			}
		}

		if (!components.containsKey('root')) return null;
		return CmA2uiPayload(surface_id: surface_id, components: components, data: data, hide_text: a2ui['hide_text'] == true);
	}

	static Map<String, dynamic> _deep_copy(Map source)
	{
		final copy = <String, dynamic>{};
		source.forEach((key, value)
		{
			copy[key.toString()] = _copy_value(value);
		});
		return copy;
	}

	static dynamic _copy_value(dynamic value)
	{
		if (value is Map) return _deep_copy(value);
		if (value is List) return value.map(_copy_value).toList();
		return value;
	}
}

/// Holds the widgets received in this app session, keyed by the chat message
/// id, so the chat UI package's own Message model needs no extra field.
class CmA2uiRegistry
{
	static const String marker = 'cmwidget:';
	static final Map<String, CmA2uiPayload> _payloads = <String, CmA2uiPayload>{};
	static final Set<String> _answered = <String>{};

	static void put(String message_id, CmA2uiPayload payload)
	{
		_payloads[message_id] = payload;
	}

	static CmA2uiPayload? get(String message_id) => _payloads[message_id];

	static bool is_answered(String message_id) => _answered.contains(message_id);

	static void mark_answered(String message_id)
	{
		_answered.add(message_id);
	}
}

/// Called when a Button that talks to the bot is pressed. [action] is the A2UI
/// v1.0 action object; [label] is the button's text, for the user's own bubble.
typedef CmA2uiActionCallback = void Function(Map<String, dynamic> action, String label);

class CmA2uiSurface extends StatefulWidget
{
	final String message_id;
	final CmA2uiPayload payload;
	final Color accent;
	final Color on_accent;
	final CmA2uiActionCallback on_action;

	const CmA2uiSurface({
		super.key,
		required this.message_id,
		required this.payload,
		required this.accent,
		required this.on_action,
		this.on_accent = Colors.white,
	});

	@override
	State<CmA2uiSurface> createState() => _CmA2uiSurfaceState();
}

class _CmA2uiSurfaceState extends State<CmA2uiSurface>
{
	late Map<String, dynamic> _data;
	final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};
	bool _show_errors = false;
	String _copied_id = '';

	bool get _locked => CmA2uiRegistry.is_answered(widget.message_id);

	@override
	void initState()
	{
		super.initState();
		_data = CmA2uiPayload._deep_copy(widget.payload.data);
	}

	@override
	void dispose()
	{
		for (final controller in _controllers.values)
		{
			controller.dispose();
		}
		super.dispose();
	}

	// ---------------------------------------------------------------- data

	String? _binding(dynamic value)
	{
		if (value is Map && value['@path'] is String) return value['@path'] as String;
		return null;
	}

	dynamic _value_at(String path)
	{
		dynamic current = _data;
		for (final token in path.split('/'))
		{
			if (token.isEmpty) continue;
			if (current is Map)
			{
				current = current[token];
			}
			else if (current is List)
			{
				final index = int.tryParse(token);
				if (index == null || index < 0 || index >= current.length) return null;
				current = current[index];
			}
			else
			{
				return null;
			}
		}
		return current;
	}

	void _set_at(String path, dynamic value)
	{
		final tokens = path.split('/').where((token) => token.isNotEmpty).toList();
		if (tokens.isEmpty) return;
		Map<String, dynamic> cursor = _data;
		for (int index = 0; index < tokens.length - 1; index++)
		{
			final next = cursor[tokens[index]];
			if (next is Map<String, dynamic>)
			{
				cursor = next;
			}
			else
			{
				final created = <String, dynamic>{};
				cursor[tokens[index]] = created;
				cursor = created;
			}
		}
		cursor[tokens.last] = value;
	}

	dynamic _resolve(dynamic value)
	{
		final path = _binding(value);
		if (path != null) return _value_at(path);
		return value;
	}

	String _resolve_string(dynamic value)
	{
		final resolved = _resolve(value);
		if (resolved == null || resolved is Map || resolved is List || resolved is bool) return '';
		return resolved.toString();
	}

	// --------------------------------------------------------------- style

	Color? _color(dynamic value)
	{
		if (value is! String) return null;
		final text = value.trim();
		final scheme = Theme.of(context).colorScheme;
		switch (text)
		{
			case r'$primary': return widget.accent;
			case r'$on-primary': return widget.on_accent;
			case r'$text': return scheme.onSurface;
			case r'$muted': return scheme.onSurface.withValues(alpha: 0.6);
			case r'$surface': return scheme.surface;
			case r'$subtle': return scheme.onSurface.withValues(alpha: 0.06);
			case r'$border': return scheme.onSurface.withValues(alpha: 0.14);
			case r'$success': return const Color(0xFF16A34A);
			case r'$warning': return const Color(0xFFD97706);
			case r'$danger': return scheme.error;
		}
		if (text.startsWith('#'))
		{
			String hex = text.substring(1);
			if (hex.length == 3)
			{
				hex = hex.split('').map((digit) => '$digit$digit').join();
			}
			if (hex.length == 6)
			{
				hex = 'FF$hex';
			}
			else if (hex.length == 8)
			{
				hex = hex.substring(6) + hex.substring(0, 6); // CSS #RRGGBBAA -> ARGB
			}
			else
			{
				return null;
			}
			final parsed = int.tryParse(hex, radix: 16);
			if (parsed == null) return null;
			return Color(parsed);
		}
		final match = RegExp(r'^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([0-9.]+)\s*)?\)$').firstMatch(text);
		if (match != null)
		{
			final alpha = double.tryParse(match.group(4) ?? '1') ?? 1;
			return Color.fromRGBO(int.parse(match.group(1)!).clamp(0, 255), int.parse(match.group(2)!).clamp(0, 255), int.parse(match.group(3)!).clamp(0, 255), alpha.clamp(0, 1).toDouble());
		}
		return null;
	}

	double? _number(dynamic value)
	{
		if (value is num) return value.toDouble();
		if (value is String)
		{
			final match = RegExp(r'^(-?[0-9.]+)(px)?$').firstMatch(value.trim());
			if (match != null) return double.tryParse(match.group(1)!);
		}
		return null;
	}

	EdgeInsets _insets(Map style, String name)
	{
		double top = 0, right = 0, bottom = 0, left = 0;
		final all = style[name];
		if (all is num)
		{
			top = right = bottom = left = all.toDouble();
		}
		else if (all is String)
		{
			final parts = all.trim().split(RegExp(r'\s+')).map((part) => _number(part) ?? 0).toList();
			if (parts.length == 1) { top = right = bottom = left = parts[0]; }
			else if (parts.length == 2) { top = bottom = parts[0]; right = left = parts[1]; }
			else if (parts.length == 3) { top = parts[0]; right = left = parts[1]; bottom = parts[2]; }
			else if (parts.length >= 4) { top = parts[0]; right = parts[1]; bottom = parts[2]; left = parts[3]; }
		}
		top = _number(style['${name}Top']) ?? top;
		right = _number(style['${name}Right']) ?? right;
		bottom = _number(style['${name}Bottom']) ?? bottom;
		left = _number(style['${name}Left']) ?? left;
		return EdgeInsets.fromLTRB(left < 0 ? 0 : left, top < 0 ? 0 : top, right < 0 ? 0 : right, bottom < 0 ? 0 : bottom);
	}

	Map _style(Map<String, dynamic> component)
	{
		final style = component['style'];
		if (style is Map) return style;
		return const <String, dynamic>{};
	}

	BoxBorder? _border(Map style)
	{
		final border = style['border'];
		if (border is String)
		{
			final match = RegExp(r'^([0-9.]+)px\s+\w+\s+(.+)$').firstMatch(border.trim());
			if (match != null)
			{
				final color = _color(match.group(2));
				if (color != null) return Border.all(color: color, width: double.tryParse(match.group(1)!) ?? 1);
			}
		}
		final border_color = _color(style['borderColor']);
		if (border_color != null) return Border.all(color: border_color, width: _number(style['borderWidth']) ?? 1);
		return null;
	}

	// Wraps [child] in the box model the component's style asks for.
	Widget _boxed(Map<String, dynamic> component, Widget child, {EdgeInsets? default_padding, Color? default_background, BoxBorder? default_border, double default_radius = 0})
	{
		final style = _style(component);
		final has_padding = style.keys.any((key) => key.toString().startsWith('padding'));
		final padding = has_padding ? _insets(style, 'padding') : (default_padding ?? EdgeInsets.zero);
		final margin = _insets(style, 'margin');
		final background = _color(style['backgroundColor']) ?? _color(style['background']) ?? default_background;
		final border = _border(style) ?? default_border;
		final radius = _number(style['borderRadius']) ?? default_radius;
		final width = _number(style['width']);
		final height = _number(style['height']);
		final opacity = _number(style['opacity']);

		Widget boxed = child;
		final needs_container = background != null || border != null || radius > 0 || width != null || height != null || padding != EdgeInsets.zero || margin != EdgeInsets.zero;
		if (needs_container)
		{
			boxed = Container(
				width: width,
				height: height,
				margin: margin,
				padding: padding,
				clipBehavior: radius > 0 ? Clip.antiAlias : Clip.none,
				decoration: BoxDecoration(color: background, border: border, borderRadius: radius > 0 ? BorderRadius.circular(radius) : null),
				child: child,
			);
		}
		if (opacity != null && opacity >= 0 && opacity < 1)
		{
			boxed = Opacity(opacity: opacity, child: boxed);
		}
		return boxed;
	}

	MainAxisAlignment _main_axis(dynamic value)
	{
		switch (value)
		{
			case 'center': return MainAxisAlignment.center;
			case 'flex-end':
			case 'end': return MainAxisAlignment.end;
			case 'space-between': return MainAxisAlignment.spaceBetween;
			case 'space-around': return MainAxisAlignment.spaceAround;
			case 'space-evenly': return MainAxisAlignment.spaceEvenly;
		}
		return MainAxisAlignment.start;
	}

	CrossAxisAlignment _cross_axis(dynamic value, CrossAxisAlignment fallback)
	{
		switch (value)
		{
			case 'center': return CrossAxisAlignment.center;
			case 'flex-end':
			case 'end': return CrossAxisAlignment.end;
			case 'flex-start':
			case 'start': return CrossAxisAlignment.start;
			case 'stretch': return CrossAxisAlignment.stretch;
		}
		return fallback;
	}

	// ---------------------------------------------------------- components

	List<String> _child_ids(Map<String, dynamic> component)
	{
		final children = component['children'];
		if (children is List) return children.map((child) => child.toString()).toList();
		return const <String>[];
	}

	Widget _build(String id, int depth, {bool in_row = false})
	{
		final component = widget.payload.components[id];
		if (component == null || depth > 24) return const SizedBox.shrink();
		final type = (component['component'] ?? '').toString();
		Widget built;
		switch (type)
		{
			case 'Card':
				built = _card(component, depth);
				break;
			case 'Column':
			case 'List':
				built = _column(component, depth);
				break;
			case 'Row':
				built = _row(component, depth);
				break;
			case 'Tabs':
				built = _tabs(component, depth);
				break;
			case 'Text':
				built = _text(component);
				break;
			case 'Image':
				built = _image(component);
				break;
			case 'Icon':
				built = _icon(component);
				break;
			case 'Divider':
				built = Divider(height: 1, thickness: 1, color: _color(_style(component)['color']) ?? _color(r'$border'));
				break;
			case 'Button':
				built = _button(component, in_row);
				break;
			case 'TextField':
				built = _text_field(component);
				break;
			case 'ChoicePicker':
				built = _choice_picker(component);
				break;
			case 'DateTimeInput':
				built = _date_time(component);
				break;
			case 'CheckBox':
				built = _check_box(component);
				break;
			case 'Slider':
				built = _slider(component);
				break;
			default:
				return const SizedBox.shrink(); // Modal, Video, AudioPlayer and anything newer
		}
		if (in_row)
		{
			final flex = _number(_style(component)['flex']);
			final is_fluid = type != 'Button' && type != 'Icon' && type != 'Image'; // everything else may hold a Row or wrapping text, which needs a bounded width
			if (flex != null && flex > 0)
			{
				return Expanded(flex: flex.round().clamp(1, 12), child: built);
			}
			if (is_fluid && _number(_style(component)['width']) == null)
			{
				return Flexible(child: built);
			}
		}
		return built;
	}

	List<Widget> _spaced(List<Widget> children, double gap, Axis axis)
	{
		if (gap <= 0 || children.length < 2) return children;
		final spaced = <Widget>[];
		for (int index = 0; index < children.length; index++)
		{
			if (index > 0)
			{
				spaced.add(axis == Axis.vertical ? SizedBox(height: gap) : SizedBox(width: gap));
			}
			spaced.add(children[index]);
		}
		return spaced;
	}

	Widget _card(Map<String, dynamic> component, int depth)
	{
		final child_id = (component['child'] ?? '').toString();
		return _boxed(
			component,
			_build(child_id, depth + 1),
			default_padding: const EdgeInsets.all(14),
			default_background: _color(r'$surface'),
			default_border: Border.all(color: _color(r'$border')!),
			default_radius: 14,
		);
	}

	Widget _column(Map<String, dynamic> component, int depth)
	{
		final style = _style(component);
		final children = _child_ids(component).map((child) => _build(child, depth + 1)).toList();
		return _boxed(component, Column(
			mainAxisSize: MainAxisSize.min,
			mainAxisAlignment: _main_axis(style['justifyContent']),
			crossAxisAlignment: _cross_axis(style['alignItems'], CrossAxisAlignment.stretch),
			children: _spaced(children, _number(style['gap']) ?? 8, Axis.vertical),
		));
	}

	Widget _row(Map<String, dynamic> component, int depth)
	{
		final style = _style(component);
		final children = _child_ids(component).map((child) => _build(child, depth + 1, in_row: true)).toList();
		return _boxed(component, Row(
			mainAxisAlignment: _main_axis(style['justifyContent']),
			crossAxisAlignment: style['alignItems'] == 'stretch' ? CrossAxisAlignment.start : _cross_axis(style['alignItems'], CrossAxisAlignment.center), // a Row inside the chat list has no fixed height to stretch to
			children: _spaced(children, _number(style['gap']) ?? 8, Axis.horizontal),
		));
	}

	Widget _tabs(Map<String, dynamic> component, int depth)
	{
		final panels = <Widget>[];
		final tabs = component['tabs'];
		if (tabs is List)
		{
			for (final tab in tabs)
			{
				if (tab is! Map) continue;
				final title = _resolve_string(tab['title']);
				if (title.isNotEmpty)
				{
					panels.add(Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: _color(r'$text'))));
				}
				panels.add(_build((tab['child'] ?? '').toString(), depth + 1));
			}
		}
		return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(panels, 8, Axis.vertical));
	}

	TextStyle _text_style(Map<String, dynamic> component, {Color? fallback_color, double fallback_size = 14})
	{
		final style = _style(component);
		final is_caption = component['variant'] == 'caption';
		FontWeight weight = FontWeight.w400;
		final raw_weight = style['fontWeight'];
		final numeric_weight = raw_weight is num ? raw_weight.toInt() : int.tryParse(raw_weight?.toString() ?? '');
		if (numeric_weight != null)
		{
			final index = ((numeric_weight / 100).round() - 1).clamp(0, 8);
			weight = FontWeight.values[index];
		}
		else if (raw_weight == 'bold')
		{
			weight = FontWeight.w700;
		}
		final size = _number(style['fontSize']) ?? (is_caption ? 12 : fallback_size);
		final line_height = _number(style['lineHeight']);
		return TextStyle(
			color: _color(style['color']) ?? (is_caption ? _color(r'$muted') : (fallback_color ?? _color(r'$text'))),
			fontSize: size,
			fontWeight: weight,
			fontStyle: style['fontStyle'] == 'italic' ? FontStyle.italic : FontStyle.normal,
			letterSpacing: _number(style['letterSpacing']),
			height: line_height == null ? null : (line_height > 4 ? line_height / size : line_height),
			decoration: (style['textDecoration'] == 'line-through' || style['textDecorationLine'] == 'line-through') ? TextDecoration.lineThrough : (style['textDecoration'] == 'underline' ? TextDecoration.underline : TextDecoration.none),
		);
	}

	String _cased(String text, dynamic transform)
	{
		if (transform == 'uppercase') return text.toUpperCase();
		if (transform == 'lowercase') return text.toLowerCase();
		return text;
	}

	TextAlign _text_align(dynamic value)
	{
		if (value == 'center') return TextAlign.center;
		if (value == 'right' || value == 'end') return TextAlign.end;
		return TextAlign.start;
	}

	Widget _text(Map<String, dynamic> component)
	{
		final style = _style(component);
		final text = _cased(_resolve_string(component['text']), style['textTransform']);
		if (text.isEmpty) return const SizedBox.shrink();
		return _boxed(component, Text(text, style: _text_style(component), textAlign: _text_align(style['textAlign'])));
	}

	Widget _image(Map<String, dynamic> component)
	{
		final url = _resolve_string(component['url']);
		if (!url.startsWith('https://')) return const SizedBox.shrink();
		final style = _style(component);
		final radius = _number(style['borderRadius']) ?? 10;
		final width = _number(style['width']);
		final height = _number(style['height']);
		return Container(
			margin: _insets(style, 'margin'),
			child: ClipRRect(
				borderRadius: BorderRadius.circular(radius),
				child: Image.network(
					url,
					width: width,
					height: height ?? (width == null ? 170 : null),
					fit: style['objectFit'] == 'contain' ? BoxFit.contain : BoxFit.cover,
					errorBuilder: (context, error, stack) => Container(
						width: width,
						height: height ?? 80,
						color: _color(r'$subtle'),
						alignment: Alignment.center,
						child: Icon(Icons.image_not_supported_outlined, color: _color(r'$muted')),
					),
				),
			),
		);
	}

	static const Map<String, IconData> _icons = <String, IconData>{
		'accountCircle': Icons.account_circle_outlined, 'add': Icons.add, 'arrowBack': Icons.arrow_back, 'arrowForward': Icons.arrow_forward,
		'attachFile': Icons.attach_file, 'calendarToday': Icons.calendar_today_outlined, 'call': Icons.call_outlined, 'camera': Icons.camera_alt_outlined,
		'check': Icons.check, 'close': Icons.close, 'delete': Icons.delete_outline, 'download': Icons.download_outlined, 'edit': Icons.edit_outlined,
		'event': Icons.event_outlined, 'error': Icons.error_outline, 'favorite': Icons.favorite, 'favoriteOff': Icons.favorite_border,
		'folder': Icons.folder_outlined, 'help': Icons.help_outline, 'home': Icons.home_outlined, 'info': Icons.info_outline,
		'locationOn': Icons.location_on_outlined, 'lock': Icons.lock_outline, 'lockOpen': Icons.lock_open, 'mail': Icons.mail_outline,
		'menu': Icons.menu, 'moreVert': Icons.more_vert, 'moreHoriz': Icons.more_horiz, 'notifications': Icons.notifications_none,
		'notificationsOff': Icons.notifications_off_outlined, 'payment': Icons.payment, 'person': Icons.person_outline, 'phone': Icons.phone_outlined,
		'photo': Icons.photo_outlined, 'print': Icons.print_outlined, 'refresh': Icons.refresh, 'search': Icons.search, 'send': Icons.send_outlined,
		'settings': Icons.settings_outlined, 'share': Icons.share_outlined, 'shoppingCart': Icons.shopping_cart_outlined, 'star': Icons.star,
		'starHalf': Icons.star_half, 'starOff': Icons.star_border, 'upload': Icons.upload_outlined, 'visibility': Icons.visibility_outlined,
		'visibilityOff': Icons.visibility_off_outlined, 'warning': Icons.warning_amber_outlined, 'play': Icons.play_arrow, 'pause': Icons.pause, 'stop': Icons.stop,
	};

	Widget _icon(Map<String, dynamic> component)
	{
		final icon = _icons[(component['name'] ?? '').toString()];
		if (icon == null) return const SizedBox.shrink();
		final style = _style(component);
		return Icon(icon, size: _number(style['fontSize']) ?? _number(style['width']) ?? 18, color: _color(style['color']) ?? _color(r'$text'));
	}

	// ------------------------------------------------------------- buttons

	Future<void> _open_url(String url) async
	{
		if (!url.startsWith('https://')) return;
		final uri = Uri.tryParse(url);
		if (uri == null) return;
		if (await canLaunchUrl(uri))
		{
			await launchUrl(uri, mode: LaunchMode.externalApplication);
		}
	}

	List<Map<String, dynamic>> _inputs()
	{
		const input_types = <String>{'TextField', 'ChoicePicker', 'DateTimeInput', 'CheckBox', 'Slider'};
		final reachable = <Map<String, dynamic>>[];
		final seen = <String>{};
		void walk(String id)
		{
			final component = widget.payload.components[id];
			if (component == null || !seen.add(id)) return;
			if (input_types.contains(component['component']))
			{
				reachable.add(component);
				return;
			}
			if (component['child'] != null) walk(component['child'].toString());
			for (final child in _child_ids(component))
			{
				walk(child);
			}
			final tabs = component['tabs'];
			if (tabs is List)
			{
				for (final tab in tabs)
				{
					if (tab is Map && tab['child'] != null) walk(tab['child'].toString());
				}
			}
		}
		walk('root');
		return reachable;
	}

	// The first failing check of an input, as a short message; null when it passes.
	String? _failing_check(Map<String, dynamic> component)
	{
		final checks = component['@checks'];
		if (checks is! List) return null;
		for (final rule in checks)
		{
			if (rule is! Map || rule['condition'] is! Map) continue;
			final condition = rule['condition'] as Map;
			final args = condition['args'] is Map ? condition['args'] as Map : const {};
			final value = _resolve(args['value']);
			final text = (value == null || value is bool || value is List) ? '' : value.toString().trim();
			final call = condition['@call'];
			if (call == 'required')
			{
				final is_empty = value == null || value == false || (value is List && value.isEmpty) || (value is! bool && value is! List && text.isEmpty);
				if (is_empty) return 'Required';
			}
			else if (call == 'email' && text.isNotEmpty)
			{
				if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'Enter a valid email';
			}
			else if (call == 'regex' && text.isNotEmpty && args['pattern'] is String)
			{
				bool matches = true;
				try
				{
					matches = RegExp(args['pattern'] as String).hasMatch(text);
				}
				catch (_)
				{
					matches = true; // an unusable pattern never blocks the visitor
				}
				if (!matches) return 'Check this value';
			}
		}
		return null;
	}

	void _press(Map<String, dynamic> component, String label)
	{
		final action = component['action'];
		if (action is! Map) return;

		final function_call = action['functionCall'];
		if (function_call is Map)
		{
			final args = function_call['args'] is Map ? function_call['args'] as Map : const {};
			if (function_call['@call'] == 'openUrl')
			{
				_open_url(_resolve_string(args['url']));
			}
			else if (function_call['@call'] == 'copyToClipboard')
			{
				Clipboard.setData(ClipboardData(text: _resolve_string(args['text'])));
				setState(() { _copied_id = component['id'].toString(); });
				Future<void>.delayed(const Duration(seconds: 2), ()
				{
					if (mounted) setState(() { _copied_id = ''; });
				});
			}
			return; // nothing goes to the bot, and the widget stays usable
		}

		final event = action['event'];
		if (event is! Map || _locked) return;
		final has_error = _inputs().any((input) => _failing_check(input) != null);
		if (has_error)
		{
			setState(() { _show_errors = true; });
			return;
		}
		final context_values = <String, dynamic>{};
		final raw_context = event['context'];
		if (raw_context is Map)
		{
			raw_context.forEach((key, value)
			{
				context_values[key.toString()] = _resolve(value);
			});
		}
		CmA2uiRegistry.mark_answered(widget.message_id);
		setState(() {});
		widget.on_action(<String, dynamic>{
			'name': (event['name'] ?? 'submit').toString(),
			'surfaceId': widget.payload.surface_id,
			'sourceComponentId': component['id'].toString(),
			'timestamp': DateTime.now().toUtc().toIso8601String(),
			'context': context_values,
		}, _response_summary(label, context_values));
	}

	// What the user's own bubble shows for a pressed button: the button's label, then one
	// "Field: value" line per answer sent with it (the website widget shows the same as a card).
	String _response_summary(String label, Map<String, dynamic> context_values)
	{
		final field_labels = <String, String>{};
		final option_labels = <String, String>{};
		for (final input in _inputs())
		{
			final path = _binding(input['value']);
			if (path != null)
			{
				final key = path.split('/').where((token) => token.isNotEmpty).toList();
				final field_label = _resolve_string(input['label']).trim();
				if (key.isNotEmpty && field_label.isNotEmpty)
				{
					field_labels[key.last] = field_label;
				}
			}
			final options = input['options'];
			if (options is List)
			{
				for (final option in options)
				{
					if (option is Map && option['value'] != null && option['label'] != null)
					{
						option_labels[option['value'].toString()] = _resolve_string(option['label']);
					}
				}
			}
		}
		String readable(dynamic value)
		{
			if (value is bool) return value ? 'Yes' : 'No';
			if (value is List) return value.map((item) => option_labels[item.toString()] ?? item.toString()).join(', ');
			if (value == null) return '';
			return option_labels[value.toString()] ?? value.toString();
		}
		final lines = <String>[];
		if (label.isNotEmpty) lines.add(label);
		context_values.forEach((key, value)
		{
			if (key == 'button') return; // the label line already says which button
			final text = readable(value).trim();
			if (text.isEmpty) return;
			if (key == 'item' || key == 'value')
			{
				lines.add(text);
				return;
			}
			lines.add('${field_labels[key] ?? key}: $text');
		});
		return lines.join('\n');
	}

	Widget _button(Map<String, dynamic> component, bool in_row)
	{
		final style = _style(component);
		final label_component = widget.payload.components[(component['child'] ?? '').toString()];
		String label = '';
		if (label_component != null)
		{
			label = _resolve_string(label_component['text']);
		}
		final action = component['action'];
		final is_local = action is Map && action['functionCall'] is Map;
		final is_primary = component['variant'] == 'primary';
		final is_borderless = component['variant'] == 'borderless';
		final background = _color(style['backgroundColor']) ?? _color(style['background']) ?? (is_primary ? widget.accent : (is_borderless ? Colors.transparent : _color(r'$surface')));
		final has_own_background = style['backgroundColor'] != null || style['background'] != null;
		final foreground_fallback = (is_primary && !has_own_background) ? widget.on_accent : _color(r'$text');
		final enabled = is_local || !_locked;
		final is_copied = _copied_id == component['id'].toString();
		final has_padding = style.keys.any((key) => key.toString().startsWith('padding'));

		final content = Row(
			mainAxisSize: MainAxisSize.min,
			mainAxisAlignment: MainAxisAlignment.center,
			children: <Widget>[
				if (is_copied) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check, size: 16, color: foreground_fallback)),
				Flexible(child: Text(
					is_copied ? 'Copied' : label,
					textAlign: TextAlign.center,
					style: label_component == null ? TextStyle(color: foreground_fallback, fontWeight: FontWeight.w600) : _text_style(label_component, fallback_color: foreground_fallback).copyWith(fontWeight: _style(label_component)['fontWeight'] == null ? FontWeight.w600 : null),
				)),
			],
		);

		final button = Opacity(
			opacity: enabled ? 1 : 0.55,
			child: Material(
				color: background,
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(_number(style['borderRadius']) ?? 10),
					side: (is_primary || is_borderless || has_own_background) ? BorderSide.none : BorderSide(color: _color(r'$border')!),
				),
				clipBehavior: Clip.antiAlias,
				child: InkWell(
					onTap: enabled ? () => _press(component, label) : null,
					child: Padding(
						padding: has_padding ? _insets(style, 'padding') : const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
						child: content,
					),
				),
			),
		);
		final width = _number(style['width']);
		if (width != null) return SizedBox(width: width, child: button);
		if (in_row) return button;
		return SizedBox(width: double.infinity, child: button);
	}

	// -------------------------------------------------------------- inputs

	Widget _labelled(Map<String, dynamic> component, Widget field)
	{
		final label = _resolve_string(component['label']);
		final error = _show_errors ? _failing_check(component) : null;
		return Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.start,
			children: <Widget>[
				if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _color(r'$text')))),
				field,
				if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error, style: TextStyle(fontSize: 12, color: _color(r'$danger')))),
			],
		);
	}

	InputDecoration _decoration()
	{
		final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _color(r'$border')!));
		return InputDecoration(
			isDense: true,
			filled: true,
			fillColor: _color(r'$subtle'),
			contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
			border: border,
			enabledBorder: border,
			disabledBorder: border,
			focusedBorder: border.copyWith(borderSide: BorderSide(color: widget.accent, width: 1.4)),
		);
	}

	Widget _text_field(Map<String, dynamic> component)
	{
		final path = _binding(component['value']) ?? '';
		final id = component['id'].toString();
		final controller = _controllers.putIfAbsent(id, () => TextEditingController(text: _resolve_string(component['value'])));
		final variant = (component['variant'] ?? '').toString();
		TextInputType keyboard = TextInputType.text;
		if (variant == 'number') keyboard = TextInputType.number;
		final checks = component['@checks'];
		if (checks is List)
		{
			for (final rule in checks)
			{
				if (rule is Map && rule['condition'] is Map)
				{
					final call = (rule['condition'] as Map)['@call'];
					if (call == 'email') keyboard = TextInputType.emailAddress;
					if (call == 'regex') keyboard = TextInputType.phone;
				}
			}
		}
		return _labelled(component, TextField(
			controller: controller,
			enabled: !_locked,
			keyboardType: variant == 'longText' ? TextInputType.multiline : keyboard,
			maxLines: variant == 'longText' ? 3 : 1,
			obscureText: variant == 'obscured',
			style: TextStyle(fontSize: 14, color: _color(r'$text')),
			decoration: _decoration(),
			onChanged: (value)
			{
				if (path.isNotEmpty) _set_at(path, value);
				if (_show_errors) setState(() {});
			},
		));
	}

	Widget _choice_picker(Map<String, dynamic> component)
	{
		final path = _binding(component['value']) ?? '';
		final is_multiple = component['variant'] == 'multipleSelection';
		final current = _value_at(path);
		final selected = <String>[];
		if (current is List)
		{
			selected.addAll(current.map((item) => item.toString()));
		}
		else if (current != null && current.toString().isNotEmpty)
		{
			selected.add(current.toString());
		}
		final chips = <Widget>[];
		final options = component['options'];
		if (options is List)
		{
			for (final option in options)
			{
				if (option is! Map) continue;
				final value = (option['value'] ?? '').toString();
				final is_selected = selected.contains(value);
				chips.add(GestureDetector(
					onTap: _locked ? null : ()
					{
						final next = List<String>.from(selected);
						if (is_multiple)
						{
							if (is_selected) { next.remove(value); } else { next.add(value); }
						}
						else
						{
							next..clear()..add(value);
						}
						setState(() { _set_at(path, next); });
					},
					child: Container(
						padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
						decoration: BoxDecoration(
							color: is_selected ? widget.accent : _color(r'$surface'),
							borderRadius: BorderRadius.circular(20),
							border: Border.all(color: is_selected ? widget.accent : _color(r'$border')!),
						),
						child: Text(_resolve_string(option['label']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: is_selected ? widget.on_accent : _color(r'$text'))),
					),
				));
			}
		}
		return _labelled(component, Wrap(spacing: 8, runSpacing: 8, children: chips));
	}

	String _two(int value) => value.toString().padLeft(2, '0');

	Widget _date_time(Map<String, dynamic> component)
	{
		final path = _binding(component['value']) ?? '';
		final wants_date = component['enableDate'] == true;
		final wants_time = component['enableTime'] == true;
		final current = _resolve_string(component['value']);
		return _labelled(component, GestureDetector(
			onTap: _locked ? null : () async
			{
				final now = DateTime.now();
				String date_part = '';
				String time_part = '';
				if (wants_date || !wants_time)
				{
					final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 100), lastDate: DateTime(now.year + 10));
					if (picked == null) return;
					date_part = '${picked.year}-${_two(picked.month)}-${_two(picked.day)}';
				}
				if (wants_time)
				{
					if (!mounted) return;
					final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
					if (picked == null) return;
					time_part = '${_two(picked.hour)}:${_two(picked.minute)}';
				}
				String value = date_part;
				if (date_part.isNotEmpty && time_part.isNotEmpty) { value = '${date_part}T$time_part'; }
				else if (time_part.isNotEmpty) { value = time_part; }
				if (!mounted) return;
				setState(() { _set_at(path, value); });
			},
			child: InputDecorator(
				decoration: _decoration().copyWith(suffixIcon: Icon(wants_time && !wants_date ? Icons.schedule : Icons.calendar_today_outlined, size: 18, color: _color(r'$muted'))),
				child: Text(current.isEmpty ? ' ' : current.replaceAll('T', ' '), style: TextStyle(fontSize: 14, color: _color(r'$text'))),
			),
		));
	}

	Widget _check_box(Map<String, dynamic> component)
	{
		final path = _binding(component['value']) ?? '';
		final checked = _value_at(path) == true;
		final error = _show_errors ? _failing_check(component) : null;
		return Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.start,
			children: <Widget>[
				GestureDetector(
					behavior: HitTestBehavior.opaque,
					onTap: _locked ? null : () => setState(() { _set_at(path, !checked); }),
					child: Row(
						children: <Widget>[
							Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, size: 22, color: checked ? widget.accent : _color(r'$muted')),
							const SizedBox(width: 8),
							Flexible(child: Text(_resolve_string(component['label']), style: TextStyle(fontSize: 14, color: _color(r'$text')))),
						],
					),
				),
				if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error, style: TextStyle(fontSize: 12, color: _color(r'$danger')))),
			],
		);
	}

	Widget _slider(Map<String, dynamic> component)
	{
		final path = _binding(component['value']) ?? '';
		final min = _number(component['min']) ?? 0;
		final max = _number(component['max']) ?? 100;
		if (max <= min) return const SizedBox.shrink();
		final value = (_number(_value_at(path)) ?? min).clamp(min, max).toDouble();
		final steps = _number(component['steps']);
		return _labelled(component, Row(
			children: <Widget>[
				Expanded(child: Slider(
					value: value,
					min: min,
					max: max,
					divisions: steps == null ? null : steps.round().clamp(1, 1000),
					activeColor: widget.accent,
					onChanged: _locked ? null : (next) => setState(() { _set_at(path, steps == null ? next.roundToDouble() : next); }),
				)),
				Text(value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1), style: TextStyle(fontSize: 13, color: _color(r'$text'))),
			],
		));
	}

	@override
	Widget build(BuildContext context)
	{
		return ConstrainedBox(
			constraints: const BoxConstraints(maxWidth: 320),
			child: _build('root', 0),
		);
	}
}

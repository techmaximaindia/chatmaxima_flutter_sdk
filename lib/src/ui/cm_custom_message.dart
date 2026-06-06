import 'package:chatview/chatview.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cm_voice_player.dart';

const _audio_exts = ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'oga', 'opus', 'flac', 'amr', 'wma', 'caf', 'aiff', 'aif', '3ga'];

// Type -> visual config for the file card (icon + colours + short label).
const Map<String, Map<String, dynamic>> _file_configs = {
	'pdf':  {'bg': Color(0xFFFFEDED), 'color': Color(0xFFD32F2F), 'icon': Icons.picture_as_pdf_rounded, 'label': 'PDF'},
	'doc':  {'bg': Color(0xFFE3F2FD), 'color': Color(0xFF1565C0), 'icon': Icons.description_rounded, 'label': 'DOC'},
	'docx': {'bg': Color(0xFFE3F2FD), 'color': Color(0xFF1565C0), 'icon': Icons.description_rounded, 'label': 'DOCX'},
	'xls':  {'bg': Color(0xFFE8F5E9), 'color': Color(0xFF2E7D32), 'icon': Icons.table_chart_rounded, 'label': 'XLS'},
	'xlsx': {'bg': Color(0xFFE8F5E9), 'color': Color(0xFF2E7D32), 'icon': Icons.table_chart_rounded, 'label': 'XLSX'},
	'csv':  {'bg': Color(0xFFE8F5E9), 'color': Color(0xFF2E7D32), 'icon': Icons.table_chart_rounded, 'label': 'CSV'},
	'ppt':  {'bg': Color(0xFFFFF3E0), 'color': Color(0xFFE65100), 'icon': Icons.slideshow_rounded, 'label': 'PPT'},
	'pptx': {'bg': Color(0xFFFFF3E0), 'color': Color(0xFFE65100), 'icon': Icons.slideshow_rounded, 'label': 'PPTX'},
	'txt':  {'bg': Color(0xFFF3E5F5), 'color': Color(0xFF6A1B9A), 'icon': Icons.article_rounded, 'label': 'TXT'},
	'mp4':  {'bg': Color(0xFFE8EAF6), 'color': Color(0xFF283593), 'icon': Icons.videocam_rounded, 'label': 'MP4'},
	'mov':  {'bg': Color(0xFFE8EAF6), 'color': Color(0xFF1A237E), 'icon': Icons.videocam_rounded, 'label': 'MOV'},
	'mkv':  {'bg': Color(0xFFE8EAF6), 'color': Color(0xFF283593), 'icon': Icons.videocam_rounded, 'label': 'MKV'},
	'webm': {'bg': Color(0xFFE8EAF6), 'color': Color(0xFF283593), 'icon': Icons.videocam_rounded, 'label': 'WEBM'},
	'zip':  {'bg': Color(0xFFFFF8E1), 'color': Color(0xFFF57F17), 'icon': Icons.folder_zip_rounded, 'label': 'ZIP'},
	'rar':  {'bg': Color(0xFFFFF8E1), 'color': Color(0xFFE65100), 'icon': Icons.folder_zip_rounded, 'label': 'RAR'},
};

const Map<String, dynamic> _default_file_config = {
	'bg': Color(0xFFF5F5F5), 'color': Color(0xFF616161), 'icon': Icons.insert_drive_file_rounded, 'label': 'FILE',
};

/// Builds the widget for a MessageType.custom message: a voice player for
/// audio, otherwise a tappable file card that opens externally.
Widget cm_custom_message_builder(Message message, {required String current_user_id, required Color accent})
{
	final url = message.message;
	final is_right = message.sendBy == current_user_id;
	final ext = _ext_of(url);

	if (_audio_exts.contains(ext))
	{
		return SizedBox(
			width: 240,
			child: CmVoicePlayer(audio_url: url, is_right_aligned: is_right, accent: accent),
		);
	}

	return _file_card(url, message.image_text_message);
}

Widget _file_card(String url, String caption)
{
	final name = _file_name(url);
	final ext = _ext_of(url);
	final cfg = _file_configs[ext] ?? _default_file_config;
	final bg = cfg['bg'] as Color;
	final icon_color = cfg['color'] as Color;
	final icon = cfg['icon'] as IconData;
	final label = cfg['label'] as String;
	final display = name.length > 26 ? '${name.substring(0, 22)}…' : name;

	return Container(
		constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
		decoration: BoxDecoration(
			color: bg,
			borderRadius: BorderRadius.circular(12),
			border: Border.all(color: icon_color.withValues(alpha: 0.18)),
		),
		child: Material(
			color: Colors.transparent,
			child: InkWell(
				borderRadius: BorderRadius.circular(12),
				onTap: () => _open_external(url),
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Stack(
								clipBehavior: Clip.none,
								children: [
									Container(
										width: 44, height: 52,
										decoration: BoxDecoration(
											color: Colors.white,
											borderRadius: BorderRadius.circular(8),
											border: Border.all(color: icon_color.withValues(alpha: 0.15)),
										),
										child: Center(child: Icon(icon, color: icon_color, size: 26)),
									),
									Positioned(
										bottom: -4, right: -6,
										child: Container(
											padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
											decoration: BoxDecoration(color: icon_color, borderRadius: BorderRadius.circular(4)),
											child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
										),
									),
								],
							),
							const SizedBox(width: 14),
							Flexible(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									mainAxisSize: MainAxisSize.min,
									children: [
										Text(display, maxLines: 2, overflow: TextOverflow.ellipsis,
											style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
										const SizedBox(height: 2),
										Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												Icon(Icons.open_in_new_rounded, size: 12, color: icon_color),
												const SizedBox(width: 4),
												Text('Tap to open', style: TextStyle(fontSize: 11, color: icon_color)),
											],
										),
										if (caption.isNotEmpty)
											Padding(
												padding: const EdgeInsets.only(top: 4),
												child: Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis,
													style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
											),
									],
								),
							),
						],
					),
				),
			),
		),
	);
}

Future<void> _open_external(String url) async
{
	if (!url.startsWith('http')) return; // local optimistic copy: skip until uploaded
	final uri = Uri.tryParse(url);
	if (uri == null) return;
	if (await canLaunchUrl(uri))
	{
		await launchUrl(uri, mode: LaunchMode.externalApplication);
	}
}

String _file_name(String url)
{
	final clean = url.split('?').first;
	final name = clean.split('/').last;
	return name.isEmpty ? 'file' : name;
}

String _ext_of(String url)
{
	final name = _file_name(url);
	final dot = name.lastIndexOf('.');
	if (dot == -1 || dot == name.length - 1) return '';
	return name.substring(dot + 1).toLowerCase();
}

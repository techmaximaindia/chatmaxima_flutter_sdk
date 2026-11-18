import 'package:flutter/widgets.dart';

/// The SDK's own fixed texts (buttons, errors, call status) in the language of
/// the host app. The language is taken from [CmStrings.language_code] when the
/// app sets it, else from the app's locale, else from the device; anything not
/// translated here falls back to English. What a bot or a widget says comes
/// from ChatMaxima and is not translated here.
class CmStrings
{
	/// Set to force a language (for example 'ar'); null follows the app.
	static String? language_code;

	final Map<String, String> _texts;

	const CmStrings._(this._texts);

	static CmStrings of(BuildContext? context)
	{
		String code = language_code ?? '';
		if (code.isEmpty && context != null)
		{
			code = Localizations.maybeLocaleOf(context)?.languageCode ?? '';
		}
		if (code.isEmpty)
		{
			code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
		}
		return CmStrings._(_all[code.toLowerCase().split(RegExp('[-_]')).first] ?? _all['en']!);
	}

	/// Languages written right to left, for apps that do not set a Directionality themselves.
	static bool is_rtl(String code) => code == 'ar' || code == 'he';

	String _text(String key) => _texts[key] ?? _all['en']![key] ?? key;

	String get chat => _text('chat');
	String get retry => _text('retry');
	String get call => _text('call');
	String get start_error => _text('start_error');
	String get send_error => _text('send_error');
	String get tap_to_open => _text('tap_to_open');
	String get you => _text('you');
	String get required => _text('required');
	String get valid_email => _text('valid_email');
	String get check_value => _text('check_value');
	String get yes => _text('yes');
	String get no => _text('no');
	String get copied => _text('copied');
	String get call_connecting => _text('call_connecting');
	String get call_speaking => _text('call_speaking');
	String get call_connected => _text('call_connected');
	String get call_failed => _text('call_failed');
	String get call_ended => _text('call_ended');
	String get mic_needed => _text('mic_needed');
	String get call_start_error => _text('call_start_error');

	static const Map<String, Map<String, String>> _all = <String, Map<String, String>>{
		'en': <String, String>{
			'chat': 'Chat',
			'retry': 'Retry',
			'call': 'Call',
			'start_error': 'Could not start chat. Please try again.',
			'send_error': 'Message failed to send. Please try again.',
			'tap_to_open': 'Tap to open',
			'you': 'You',
			'required': 'Required',
			'valid_email': 'Enter a valid email',
			'check_value': 'Check this value',
			'yes': 'Yes',
			'no': 'No',
			'copied': 'Copied',
			'call_connecting': 'Connecting…',
			'call_speaking': 'Speaking…',
			'call_connected': 'Connected',
			'call_failed': 'Call failed',
			'call_ended': 'Call ended',
			'mic_needed': 'Microphone permission is needed to start a call.',
			'call_start_error': 'Could not start the call. Please try again.',
		},
		'ar': <String, String>{
			'chat': 'المحادثة',
			'retry': 'إعادة المحاولة',
			'call': 'اتصال',
			'start_error': 'تعذر بدء المحادثة. يرجى المحاولة مرة أخرى.',
			'send_error': 'تعذر إرسال الرسالة. يرجى المحاولة مرة أخرى.',
			'tap_to_open': 'اضغط للفتح',
			'you': 'أنت',
			'required': 'مطلوب',
			'valid_email': 'أدخل بريدًا إلكترونيًا صالحًا',
			'check_value': 'تحقق من هذه القيمة',
			'yes': 'نعم',
			'no': 'لا',
			'copied': 'تم النسخ',
			'call_connecting': 'جارٍ الاتصال…',
			'call_speaking': 'يتحدث…',
			'call_connected': 'متصل',
			'call_failed': 'فشل الاتصال',
			'call_ended': 'انتهت المكالمة',
			'mic_needed': 'يلزم إذن الميكروفون لبدء المكالمة.',
			'call_start_error': 'تعذر بدء المكالمة. يرجى المحاولة مرة أخرى.',
		},
		'es': <String, String>{
			'chat': 'Chat',
			'retry': 'Reintentar',
			'call': 'Llamar',
			'start_error': 'No se pudo iniciar el chat. Inténtalo de nuevo.',
			'send_error': 'No se pudo enviar el mensaje. Inténtalo de nuevo.',
			'tap_to_open': 'Toca para abrir',
			'you': 'Tú',
			'required': 'Obligatorio',
			'valid_email': 'Introduce un correo válido',
			'check_value': 'Revisa este valor',
			'yes': 'Sí',
			'no': 'No',
			'copied': 'Copiado',
			'call_connecting': 'Conectando…',
			'call_speaking': 'Hablando…',
			'call_connected': 'Conectado',
			'call_failed': 'Llamada fallida',
			'call_ended': 'Llamada finalizada',
			'mic_needed': 'Se necesita permiso del micrófono para iniciar una llamada.',
			'call_start_error': 'No se pudo iniciar la llamada. Inténtalo de nuevo.',
		},
		'fr': <String, String>{
			'chat': 'Discussion',
			'retry': 'Réessayer',
			'call': 'Appeler',
			'start_error': 'Impossible de démarrer la discussion. Veuillez réessayer.',
			'send_error': 'Échec de l’envoi du message. Veuillez réessayer.',
			'tap_to_open': 'Appuyez pour ouvrir',
			'you': 'Vous',
			'required': 'Obligatoire',
			'valid_email': 'Saisissez une adresse e-mail valide',
			'check_value': 'Vérifiez cette valeur',
			'yes': 'Oui',
			'no': 'Non',
			'copied': 'Copié',
			'call_connecting': 'Connexion…',
			'call_speaking': 'En train de parler…',
			'call_connected': 'Connecté',
			'call_failed': 'Échec de l’appel',
			'call_ended': 'Appel terminé',
			'mic_needed': 'L’autorisation du micro est nécessaire pour démarrer un appel.',
			'call_start_error': 'Impossible de démarrer l’appel. Veuillez réessayer.',
		},
		'he': <String, String>{
			'chat': 'צ׳אט',
			'retry': 'נסו שוב',
			'call': 'התקשרו',
			'start_error': 'לא ניתן להתחיל את הצ׳אט. נסו שוב.',
			'send_error': 'שליחת ההודעה נכשלה. נסו שוב.',
			'tap_to_open': 'הקישו לפתיחה',
			'you': 'את/ה',
			'required': 'שדה חובה',
			'valid_email': 'הזינו כתובת אימייל תקינה',
			'check_value': 'בדקו את הערך הזה',
			'yes': 'כן',
			'no': 'לא',
			'copied': 'הועתק',
			'call_connecting': 'מתחבר…',
			'call_speaking': 'מדבר…',
			'call_connected': 'מחובר',
			'call_failed': 'השיחה נכשלה',
			'call_ended': 'השיחה הסתיימה',
			'mic_needed': 'נדרשת הרשאת מיקרופון כדי להתחיל שיחה.',
			'call_start_error': 'לא ניתן להתחיל את השיחה. נסו שוב.',
		},
		'hi': <String, String>{
			'chat': 'चैट',
			'retry': 'फिर से प्रयास करें',
			'call': 'कॉल करें',
			'start_error': 'चैट शुरू नहीं हो सकी। कृपया फिर से प्रयास करें।',
			'send_error': 'संदेश भेजा नहीं जा सका। कृपया फिर से प्रयास करें।',
			'tap_to_open': 'खोलने के लिए टैप करें',
			'you': 'आप',
			'required': 'आवश्यक',
			'valid_email': 'मान्य ईमेल दर्ज करें',
			'check_value': 'यह मान जांचें',
			'yes': 'हां',
			'no': 'नहीं',
			'copied': 'कॉपी किया गया',
			'call_connecting': 'कनेक्ट हो रहा है…',
			'call_speaking': 'बोल रहा है…',
			'call_connected': 'कनेक्ट हो गया',
			'call_failed': 'कॉल विफल',
			'call_ended': 'कॉल समाप्त',
			'mic_needed': 'कॉल शुरू करने के लिए माइक्रोफ़ोन की अनुमति चाहिए।',
			'call_start_error': 'कॉल शुरू नहीं हो सकी। कृपया फिर से प्रयास करें।',
		},
		'it': <String, String>{
			'chat': 'Chat',
			'retry': 'Riprova',
			'call': 'Chiama',
			'start_error': 'Impossibile avviare la chat. Riprova.',
			'send_error': 'Invio del messaggio non riuscito. Riprova.',
			'tap_to_open': 'Tocca per aprire',
			'you': 'Tu',
			'required': 'Obbligatorio',
			'valid_email': 'Inserisci un’email valida',
			'check_value': 'Controlla questo valore',
			'yes': 'Sì',
			'no': 'No',
			'copied': 'Copiato',
			'call_connecting': 'Connessione…',
			'call_speaking': 'Sta parlando…',
			'call_connected': 'Connesso',
			'call_failed': 'Chiamata non riuscita',
			'call_ended': 'Chiamata terminata',
			'mic_needed': 'Serve l’autorizzazione al microfono per avviare una chiamata.',
			'call_start_error': 'Impossibile avviare la chiamata. Riprova.',
		},
		'pt': <String, String>{
			'chat': 'Chat',
			'retry': 'Tentar novamente',
			'call': 'Ligar',
			'start_error': 'Não foi possível iniciar o chat. Tente novamente.',
			'send_error': 'Falha ao enviar a mensagem. Tente novamente.',
			'tap_to_open': 'Toque para abrir',
			'you': 'Você',
			'required': 'Obrigatório',
			'valid_email': 'Digite um e-mail válido',
			'check_value': 'Verifique este valor',
			'yes': 'Sim',
			'no': 'Não',
			'copied': 'Copiado',
			'call_connecting': 'Conectando…',
			'call_speaking': 'Falando…',
			'call_connected': 'Conectado',
			'call_failed': 'Falha na chamada',
			'call_ended': 'Chamada encerrada',
			'mic_needed': 'A permissão do microfone é necessária para iniciar uma chamada.',
			'call_start_error': 'Não foi possível iniciar a chamada. Tente novamente.',
		},
		'ru': <String, String>{
			'chat': 'Чат',
			'retry': 'Повторить',
			'call': 'Позвонить',
			'start_error': 'Не удалось начать чат. Попробуйте ещё раз.',
			'send_error': 'Не удалось отправить сообщение. Попробуйте ещё раз.',
			'tap_to_open': 'Нажмите, чтобы открыть',
			'you': 'Вы',
			'required': 'Обязательное поле',
			'valid_email': 'Введите корректный email',
			'check_value': 'Проверьте это значение',
			'yes': 'Да',
			'no': 'Нет',
			'copied': 'Скопировано',
			'call_connecting': 'Соединение…',
			'call_speaking': 'Говорит…',
			'call_connected': 'Соединено',
			'call_failed': 'Сбой звонка',
			'call_ended': 'Звонок завершён',
			'mic_needed': 'Для звонка нужно разрешение на микрофон.',
			'call_start_error': 'Не удалось начать звонок. Попробуйте ещё раз.',
		},
		'ta': <String, String>{
			'chat': 'அரட்டை',
			'retry': 'மீண்டும் முயலவும்',
			'call': 'அழைக்கவும்',
			'start_error': 'அரட்டையைத் தொடங்க முடியவில்லை. மீண்டும் முயலவும்.',
			'send_error': 'செய்தியை அனுப்ப முடியவில்லை. மீண்டும் முயலவும்.',
			'tap_to_open': 'திறக்க தட்டவும்',
			'you': 'நீங்கள்',
			'required': 'தேவையானது',
			'valid_email': 'சரியான மின்னஞ்சலை உள்ளிடவும்',
			'check_value': 'இந்த மதிப்பைச் சரிபார்க்கவும்',
			'yes': 'ஆம்',
			'no': 'இல்லை',
			'copied': 'நகலெடுக்கப்பட்டது',
			'call_connecting': 'இணைக்கிறது…',
			'call_speaking': 'பேசுகிறது…',
			'call_connected': 'இணைக்கப்பட்டது',
			'call_failed': 'அழைப்பு தோல்வியடைந்தது',
			'call_ended': 'அழைப்பு முடிந்தது',
			'mic_needed': 'அழைப்பைத் தொடங்க மைக்ரோஃபோன் அனுமதி தேவை.',
			'call_start_error': 'அழைப்பைத் தொடங்க முடியவில்லை. மீண்டும் முயலவும்.',
		},
		'te': <String, String>{
			'chat': 'చాట్',
			'retry': 'మళ్లీ ప్రయత్నించండి',
			'call': 'కాల్ చేయండి',
			'start_error': 'చాట్ ప్రారంభించలేకపోయాం. మళ్లీ ప్రయత్నించండి.',
			'send_error': 'సందేశం పంపడం విఫలమైంది. మళ్లీ ప్రయత్నించండి.',
			'tap_to_open': 'తెరవడానికి నొక్కండి',
			'you': 'మీరు',
			'required': 'తప్పనిసరి',
			'valid_email': 'సరైన ఇమెయిల్ నమోదు చేయండి',
			'check_value': 'ఈ విలువను తనిఖీ చేయండి',
			'yes': 'అవును',
			'no': 'కాదు',
			'copied': 'కాపీ అయింది',
			'call_connecting': 'కనెక్ట్ అవుతోంది…',
			'call_speaking': 'మాట్లాడుతోంది…',
			'call_connected': 'కనెక్ట్ అయింది',
			'call_failed': 'కాల్ విఫలమైంది',
			'call_ended': 'కాల్ ముగిసింది',
			'mic_needed': 'కాల్ ప్రారంభించడానికి మైక్రోఫోన్ అనుమతి అవసరం.',
			'call_start_error': 'కాల్ ప్రారంభించలేకపోయాం. మళ్లీ ప్రయత్నించండి.',
		},
		'zh': <String, String>{
			'chat': '聊天',
			'retry': '重试',
			'call': '呼叫',
			'start_error': '无法开始聊天，请重试。',
			'send_error': '消息发送失败，请重试。',
			'tap_to_open': '点击打开',
			'you': '你',
			'required': '必填',
			'valid_email': '请输入有效的邮箱',
			'check_value': '请检查此值',
			'yes': '是',
			'no': '否',
			'copied': '已复制',
			'call_connecting': '正在连接…',
			'call_speaking': '正在讲话…',
			'call_connected': '已连接',
			'call_failed': '通话失败',
			'call_ended': '通话已结束',
			'mic_needed': '需要麦克风权限才能开始通话。',
			'call_start_error': '无法开始通话，请重试。',
		},
	};
}

import 'models/cm_lead_info.dart';

/// Configuration for a ChatMaxima SDK session.
///
/// Only [apiKey] is required. The other values default to ChatMaxima's
/// production hosts and are overridable for self-hosted / staging setups.
class CmConfig
{
	/// The mobile_app channel API key (dashboard > Mobile App Channel).
	final String api_key;

	/// REST base, e.g. https://chatmaxima.com/ . Must end with a slash.
	final String base_url;

	/// Optional override for the realtime server. When null the value
	/// returned by the session bootstrap (`socket_url`) is used.
	final String? socket_url;

	/// The app's bundle id / package name. Sent on bootstrap so the backend
	/// can enforce a per-key bundle-id allow-list. Optional.
	final String? bundle_id;

	/// Optional known visitor details to attach to the lead on first contact.
	final CmLeadInfo? lead_info;

	/// When true, the SDK logs protocol activity to the console.
	final bool debug;

	const CmConfig({
		required this.api_key,
		this.base_url = 'https://chatmaxima.com/',
		this.socket_url,
		this.bundle_id,
		this.lead_info,
		this.debug = false,
	});

	/// REST endpoint that bootstraps a session (API-key authenticated).
	String get session_endpoint => '${base_url}mobileapp/session/';
}

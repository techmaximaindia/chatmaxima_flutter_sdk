/// Optional details about the end user, attached to the ChatMaxima lead the
/// first time the app starts a conversation. All fields are optional.
class CmLeadInfo
{
	final String? name;
	final String? email;
	final String? phone_no;

	/// Free-form source tag stored on the lead (defaults to "mobile_app").
	final String source;

	const CmLeadInfo({
		this.name,
		this.email,
		this.phone_no,
		this.source = 'mobile_app',
	});

	Map<String, dynamic> to_json()
	{
		return {
			'name': name ?? '',
			'email': email ?? '',
			'phone_no': phone_no ?? '',
			'source': source,
		};
	}
}

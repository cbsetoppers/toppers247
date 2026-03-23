/// Model representing the app-wide settings row from Supabase `settings` table.
class AppSettings {
  final bool isMaintenanceMode;
  final String maintenanceMessage;
  final String maintenanceTitle;
  final String? minAppVersion;   // optional: force-update if app is too old
  final String? contactEmail;    // shown on maintenance screen

  const AppSettings({
    required this.isMaintenanceMode,
    this.maintenanceMessage =
        'We are performing scheduled maintenance to improve your experience. Please check back shortly.',
    this.maintenanceTitle = 'Under Maintenance',
    this.minAppVersion,
    this.contactEmail,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isMaintenanceMode: json['maintenance'] == true,
      maintenanceMessage: json['maintenance_message'] as String? ??
          'We are performing scheduled maintenance to improve your experience. Please check back shortly.',
      maintenanceTitle:
          json['maintenance_title'] as String? ?? 'Under Maintenance',
      minAppVersion: json['min_app_version'] as String?,
      contactEmail: json['contact_email'] as String?,
    );
  }

  /// Safe defaults — used when the settings fetch fails (no network, etc.)
  static const AppSettings defaults = AppSettings(isMaintenanceMode: false);
}

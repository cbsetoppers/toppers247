import '../utils/crypto_utils.dart';

class AppConstants {
  static const String _authKey = 'T0PPERS_SECURE_KEY_247';
  static const String _encodedUrl = 'PEQkIDZofHA7Lic+Oj85LygvPEpCWCRRIz8tP30sJjUiNzM2OmUmNg==';
  static const String _encodedAnon = 'MUkaOCcVMDYcLAkcBz8WegswFkF9WQYFMxMMZBo0Ix0VFhh8cS48Ey9RB3o9fzkaPzYLHTscLhMoHwwCNhAxeFhtPXlmGSg6IQUUMSwwPx80KR0DNVd8bSJTFxY/MGE3JwwqIjsmMnI2Awx7An45diUyd2Y6ExAPMwwKFDYELxxsfE5yLn0UBXccKTggDC4DZiYcAnMUNXMAeT5XZB0RC2AQG3VtYhsxcg89aA5LYE41eRYCIiEaPWdzOmMbKhcEKWhsYHJwNWUmCAclOBQDDA==';
  static const String _encodedServiceRole = 'MUkaOCcVMDYcLAkcBz8WegswFkF9WQYFMxMMZBo0Ix0VFhh8cS48Ey9RB3o9fzkaPzYLHTscLhMoHwwCNhAxeFhtPXlmGSg6IQUUMSwwPx80KR0DNVd8bSJTFxY/MGE3JwwqIjsmMnI2Awx7An46fjwzKwgjBmETJTY/fCwRFhAse1lbPFQTGXMfBzxgCBcYJQsLEnYWHEVdbQxYJxkvPSoSFyJxGhYiJwUvOmtUZRk9XGYxHDRqFgw9Cx0ocBQJEg5man1VDl4DMQsNMRhmcC5lPSAofTAMB1tX';
  static const String _encodedRzpId = 'JkogDyk7JToMFhcGFX0PMQc9Pl9Gbhk=';
  static const String _encodedRzpSecret = 'MgQ8Zy5nJDsWEDsmIHdvInwyLlV7QgB3';

  static String get supabaseUrl => CryptoUtils.decode(_encodedUrl, _authKey);
  static String get supabaseAnonKey => CryptoUtils.decode(_encodedAnon, _authKey);
  static String get supabaseServiceRoleKey => CryptoUtils.decode(_encodedServiceRole, _authKey);
  static String get razorpayKeyId => CryptoUtils.decode(_encodedRzpId, _authKey);
  static String get razorpayKeySecret => CryptoUtils.decode(_encodedRzpSecret, _authKey);

  static const String appName = 'T0PPERS 24/7';

  static const String aiDisclaimer =
      "NOTES: AI-generated content may contains mistakes. "
      "T0PPERS 24/7 is not responsible for this as AI is in its testing phase.";
}

class AppConfig {
  const AppConfig._();

  static const appName = 'ReAccess Hub';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  static String get recoveryLetterUrl {
    const configured = String.fromEnvironment('RECOVERY_LETTER_URL');
    return configured.isNotEmpty
        ? configured
        : '$apiBaseUrl/public/letter-template';
  }

  static const requestTimeout = Duration(seconds: 20);
}

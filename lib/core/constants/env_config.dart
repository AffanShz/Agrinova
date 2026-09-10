class EnvConfig {
  static String get modelTomatoUrl =>
      const String.fromEnvironment('MODEL_TOMATO');
  static String get modelPlantUrl =>
      const String.fromEnvironment('MODEL_PLANT');
  static String get modelRiceUrl =>
      const String.fromEnvironment('MODEL_RICE');
  static String get modelTeaUrl =>
      const String.fromEnvironment('MODEL_TEA');

  static String get supabaseUrl =>
      const String.fromEnvironment('SUPABASE_URL');
  static String get supabaseAnonKey =>
      const String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get openWeatherApiKey =>
      const String.fromEnvironment('OPENWEATHER_API_KEY');
  static String get geminiApiKey =>
      const String.fromEnvironment('GEMINI_API_KEY');

  static String get midtransClientKey =>
      const String.fromEnvironment('MIDTRANS_CLIENT_KEY');

  /// Assert or validate that all base URLs use HTTPS for security
  static bool validateHttpsUrls() {
    final urls = [
      modelTomatoUrl,
      modelPlantUrl,
      modelRiceUrl,
      modelTeaUrl,
      supabaseUrl,
    ];
    for (final url in urls) {
      if (url.isNotEmpty && !url.startsWith('https://')) {
        return false;
      }
    }
    return true;
  }
}

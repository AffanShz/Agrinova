import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agrinova/core/constants/env_config.dart';

class WeatherService {
  String get apiKey => EnvConfig.openWeatherApiKey;

  // Timeout duration for all requests
  static const Duration _timeout = Duration(seconds: 10);

  Future<Map<String, dynamic>> fetchCurrentWeather(
      {required double lat, required double lon}) async {
    if (apiKey.isEmpty) {
      throw Exception('API Key not configured. Build with --dart-define-from-file=secrets.json');
    }

    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=id');
    final response = await http.get(url).timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load current weather');
    }
  }

  Future<Map<String, dynamic>> fetchForecast({required double lat, required double lon}) async {
    if (apiKey.isEmpty) {
      throw Exception('API Key not configured. Build with --dart-define-from-file=secrets.json');
    }

    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=id');
    final response = await http.get(url).timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load forecast');
    }
  }
}

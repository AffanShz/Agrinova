import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agrinova/utils/weather_utils.dart';

class HomeWeatherCard extends StatelessWidget {
  final Map<String, dynamic> currentWeather;
  final String? shortLocation;
  final bool isRealTimeGps;
  final VoidCallback? onRefresh;

  const HomeWeatherCard({
    super.key,
    required this.currentWeather,
    this.shortLocation,
    this.isRealTimeGps = true,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final main = currentWeather['main'];
    final weatherList = currentWeather['weather'];
    final weather = (weatherList is List && weatherList.isNotEmpty && weatherList[0] is Map)
        ? Map<String, dynamic>.from(weatherList[0] as Map)
        : null;

    if (main == null || weather == null) return const SizedBox();
    final weatherMain = weather['main'] as String?;
    final gradientColors = _getWeatherGradient(weatherMain);
    final temp = (main['temp'] as num?)?.toStringAsFixed(0) ?? '--';
    final humidity = main['humidity'];
    final windSpeed = currentWeather['wind']?['speed'];

    String locationText = shortLocation?.isNotEmpty == true
        ? shortLocation!
        : currentWeather['name'] ?? '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isRealTimeGps ? Icons.location_on : Icons.location_off,
                color: isRealTimeGps ? Colors.white70 : Colors.amber.shade200,
                size: 14,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  locationText,
                  style: TextStyle(
                    color: isRealTimeGps ? Colors.white : Colors.amber.shade100,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onRefresh != null)
                GestureDetector(
                  onTap: onRefresh,
                  child: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              weather['icon'] != null
                  ? CachedNetworkImage(
                      imageUrl:
                          'https://openweathermap.org/img/wn/${weather['icon']}@2x.png',
                      width: 56,
                      height: 56,
                      placeholder: (context, url) => Icon(
                        _getWeatherIcon(weatherMain),
                        size: 40,
                        color: Colors.white70,
                      ),
                      errorWidget: (context, url, error) => Icon(
                        _getWeatherIcon(weatherMain),
                        size: 40,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _getWeatherIcon(weatherMain),
                      size: 40,
                      color: Colors.white,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$temp°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      WeatherUtils.translateWeather(weather['description'] ?? ''),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (humidity != null)
                    _InfoChip(icon: Icons.water_drop, text: '$humidity%'),
                  const SizedBox(height: 4),
                  if (windSpeed != null)
                    _InfoChip(icon: Icons.air, text: '$windSpeed m/s'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _getWeatherGradient(String? weatherMain) {
    switch (weatherMain?.toLowerCase()) {
      case 'clear':
        return [const Color(0xFFFF8C00), const Color(0xFFFFD700)];
      case 'clouds':
        return [const Color(0xFF546E7A), const Color(0xFF90A4AE)];
      case 'rain':
      case 'drizzle':
        return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
      case 'thunderstorm':
        return [const Color(0xFF37474F), const Color(0xFF546E7A)];
      case 'snow':
        return [const Color(0xFFB3E5FC), const Color(0xFFE1F5FE)];
      case 'mist':
      case 'haze':
      case 'fog':
        return [const Color(0xFF78909C), const Color(0xFFB0BEC5)];
      default:
        return [const Color(0xff1B5E20), const Color(0xff4CAF50)];
    }
  }

  IconData _getWeatherIcon(String? weatherMain) {
    switch (weatherMain?.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'haze':
      case 'fog':
        return Icons.blur_on;
      default:
        return Icons.wb_cloudy;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  // Timeout for requests
  static const Duration _timeout = Duration(seconds: 10);

  Future<Map<String, String>> getDetailedLocation(
      double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&addressdetails=1&accept-language=id');

      final response = await http.get(url, headers: {
        'User-Agent': 'AgriNova/1.0',
      }).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};

        final district = address['district'] ?? address['city_district'] ?? '';
        final regency = address['county'] ?? address['city'] ?? '';
        final province = address['state'] ?? '';

        final shortParts = <String>[];
        if (district.isNotEmpty) shortParts.add(district);
        if (regency.isNotEmpty) shortParts.add(regency);
        if (province.isNotEmpty) shortParts.add(province);

        return {
          'village': address['village'] ??
              address['suburb'] ??
              address['neighbourhood'] ??
              '',
          'district': district,
          'regency': regency,
          'province': province,
          'short': shortParts.join(', '),
          'full': _buildFullAddress(address),
        };
      }
    } catch (e) {
      // Return empty if geocoding fails or timeout
    }

    return {
      'village': '',
      'district': '',
      'regency': '',
      'province': '',
      'short': '',
      'full': '',
    };
  }

  String _buildFullAddress(Map<String, dynamic> address) {
    List<String> parts = [];

    // Village/Desa
    String? village =
        address['village'] ?? address['suburb'] ?? address['neighbourhood'];
    if (village != null && village.isNotEmpty) {
      parts.add(village);
    }

    // District/Kecamatan
    String? district = address['district'] ?? address['city_district'];
    if (district != null && district.isNotEmpty) {
      parts.add(district);
    }

    // Regency/Kabupaten or City
    String? regency = address['county'] ?? address['city'];
    if (regency != null && regency.isNotEmpty) {
      parts.add(regency);
    }

    // Province
    String? province = address['state'];
    if (province != null && province.isNotEmpty) {
      parts.add(province);
    }

    return parts.join(', ');
  }
}

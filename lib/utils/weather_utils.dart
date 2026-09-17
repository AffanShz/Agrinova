class WeatherUtils {
  static String translateWeather(String description) {
    if (description.isEmpty) return description;
    final lower = description.toLowerCase();
    if (lower.contains('thunderstorm') || lower.contains('petir')) return 'Hujan Petir';
    if (lower.contains('drizzle') || lower.contains('gerimis')) return 'Gerimis';
    if (lower.contains('rain') || lower.contains('hujan')) {
      if (lower.contains('heavy') || lower.contains('deras')) return 'Hujan Deras';
      if (lower.contains('light') || lower.contains('ringan')) return 'Hujan Ringan';
      return 'Hujan';
    }
    if (lower.contains('cloud') || lower.contains('berawan') || lower.contains('awan')) return 'Berawan';
    if (lower.contains('clear') || lower.contains('cerah')) return 'Cerah';
    if (lower.contains('mist') || lower.contains('fog') || lower.contains('kabut')) return 'Berkabut';
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  static String? getRecommendation(int conditionId) {
    if (conditionId >= 200 && conditionId < 300) {
      return 'Potensi badai petir. Tunda pemupukan karena berisiko hanyut dan hindari area terbuka.';
    }

    if (conditionId >= 500 && conditionId < 600) {
      if (conditionId >= 502) {
        return 'Hujan deras terdeteksi! Segera buka saluran drainase agar lahan tidak tergenang.';
      }
    }

    if (conditionId >= 600 && conditionId < 700) {
      return 'Suhu sangat rendah terdeteksi. Lindungi tanaman dari kondisi beku.';
    }

    if (conditionId >= 700 && conditionId < 800) {
      if (conditionId == 781) {
        return 'Peringatan tornado! Segera cari tempat berlindung dan amankan peralatan.';
      }
      if (conditionId == 762) {
        return 'Peringatan abu vulkanik! Tutup tanaman dan hindari aktivitas luar ruangan.';
      }
    }

    final temp = _lastKnownTemp;
    if (temp != null) {
      if (temp >= 40) {
        return 'Suhu sangat tinggi ($temp°C)! Pastikan irigasi cukup dan beri peneduh pada tanaman muda.';
      }
      if (temp <= 5) {
        return 'Suhu sangat rendah ($temp°C)! Lindungi tanaman dari potensi embun beku.';
      }
    }

    return null;
  }

  static int? _lastKnownTemp;

  static void updateTemperature(int temp) {
    _lastKnownTemp = temp;
  }
}

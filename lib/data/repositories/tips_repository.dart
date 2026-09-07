import 'package:flutter/foundation.dart';
import 'package:agrinova/data/datasources/tips_services.dart';
import 'package:agrinova/core/services/cache_service.dart';

/// Repository untuk mengelola data Tips Pertanian
/// Abstraksi antara BLoC dan datasource (API/Cache)
class TipsRepository {
  final TipsService _tipsService;
  final CacheService _cacheService;

  TipsRepository({
    required TipsService tipsService,
    required CacheService cacheService,
  })  : _tipsService = tipsService,
        _cacheService = cacheService;

  /// Dummy data tips lokal untuk fallback.
  /// Keys mengikuti schema yang dipakai UI & DB (title/category/content/image_url).
  static final List<Map<String, dynamic>> _dummyTips = [
    {
      'id': 1,
      'title': 'Cara Menanam Padi yang Benar',
      'category': 'Padi',
      'content':
          'Padi adalah tanaman pangan utama. Berikut langkah menanam padi:\n1. Persiapan lahan selama 2 minggu\n2. Penyemaian benih berkualitas\n3. Penanaman dengan jarak 25x25cm\n4. Pemeliharaan rutin selama pertumbuhan\n5. Panen saat padi sudah masak kuning',
      'image_url':
          'https://images.unsplash.com/photo-1536657464919-892534f60d6e?auto=format&fit=crop&q=80&w=1080',
      'tips_ekstra': 'Gunakan benih yang telah disertifikasi untuk hasil optimal.'
    },
    {
      'id': 2,
      'title': 'Budidaya Jagung untuk Pemula',
      'category': 'Jagung',
      'content':
          'Jagung adalah komoditas bernilai tinggi. Tips budidaya jagung:\n1. Pilih varietas yang sesuai iklim\n2. Olah tanah hingga subur\n3. Tanam dengan jarak 75x25cm\n4. Berikan pupuk NPK saat berumur 3 minggu\n5. Rawat hingga panen (±4 bulan)',
      'image_url':
          'https://images.unsplash.com/photo-1551754655-cd27e38d2076?auto=format&fit=crop&q=80&w=1080',
      'tips_ekstra': 'Jagung membutuhkan sinar matahari penuh untuk pertumbuhan optimal.'
    },
    {
      'id': 3,
      'title': 'Nutrisi Tanaman & Pemupukan Tepat',
      'category': 'Nutrisi Tanaman',
      'content':
          'Pemupukan yang tepat meningkatkan hasil panen hingga 40%.\nMacam nutrisi utama:\n- N (Nitrogen): untuk pertumbuhan daun dan batang\n- P (Fosfor): untuk pembentukan akar dan buah\n- K (Kalium): untuk ketahanan tanaman\nBerikan pupuk sesuai kebutuhan tanaman di setiap fase pertumbuhan.',
      'image_url':
          'https://images.unsplash.com/photo-1585314062340-f1a5a7c9328d?auto=format&fit=crop&q=80&w=1080',
      'tips_ekstra':
          'Gunakan pupuk organik sebagai dasar, tambah pupuk kimia sesuai kebutuhan.'
    },
    {
      'id': 4,
      'title': 'Pencegahan & Pengendalian Hama Tanaman',
      'category': 'Hama & Penyakit',
      'content':
          'Hama dapat merusak hasil panen hingga 50%. Cara pencegahan:\n1. Gunakan bibit sehat\n2. Lakukan rotasi tanaman\n3. Pantau kehadiran hama secara berkala\n4. Gunakan pestisida nabati sebagai alternatif ramah lingkungan\n5. Aplikasi pestisida kimia jika diperlukan',
      'image_url':
          'https://images.unsplash.com/photo-1471193945509-9ad0617afabf?auto=format&fit=crop&q=80&w=1080',
      'tips_ekstra':
          'Panen hama secara manual pada tahap awal lebih efektif dan aman.'
    },
    {
      'id': 5,
      'title': 'Manajemen Irigasi di Musim Kering',
      'category': 'Teknik Pertanian',
      'content':
          'Irigasi yang tepat sangat penting saat musim kering:\n1. Siram pada pagi atau sore hari untuk meminimalkan penguapan\n2. Berikan air secara konsisten, jangan hingga kering total\n3. Gunakan mulsa untuk menjaga kelembaban tanah\n4. Manfaatkan teknologi tetes (drip irrigation) jika memungkinkan',
      'image_url':
          'https://images.unsplash.com/photo-1563514227147-6d2ff665a6a0?auto=format&fit=crop&q=80&w=1080',
      'tips_ekstra':
          'Monitor curah hujan dan sesuaikan jadwal irigasi untuk efisiensi air.'
    },
  ];

  /// Fetch semua tips
  /// Prioritas: Cache dulu, lalu API jika online, terakhir dummy data
  Future<List<Map<String, dynamic>>> fetchTips({
    bool forceRefresh = false,
  }) async {
    // 1. Cek offline mode
    final offlineMode = _cacheService.getOfflineMode();

    // 2. Load dari cache dulu
    List<Map<String, dynamic>>? cachedData;
    if (!forceRefresh) {
      cachedData = _cacheService.getCachedTips();
      if (cachedData != null && cachedData.isNotEmpty) {
        debugPrint(
            'TipsRepository: Loaded ${cachedData.length} tips from cache');

        // Jika offline mode, langsung return cache
        if (offlineMode) {
          return cachedData;
        }
      }
    }

    // 3. Fetch dari API
    try {
      final tips = await _tipsService.fetchTips();

      // Save ke cache
      await _cacheService.saveTipsData(tips);

      debugPrint('TipsRepository: Fetched ${tips.length} tips from API');
      return tips;
    } catch (e) {
      debugPrint('TipsRepository: API error - $e');

      // Fallback ke cache jika API gagal
      if (cachedData != null && cachedData.isNotEmpty) {
        return cachedData;
      }

      // Fallback terakhir: gunakan dummy data lokal
      debugPrint(
          'TipsRepository: Using ${_dummyTips.length} dummy tips as fallback');
      return _dummyTips;
    }
  }
}

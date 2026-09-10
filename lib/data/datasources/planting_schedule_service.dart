import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pengelola Jadwal Tanam dengan arsitektur Offline-First + Cloud Sync.
///
/// - Saat offline: perubahan disimpan ke Hive lokal dan ditandai `is_synced: false`.
/// - Saat online: perubahan didorong ke tabel `planting_schedules` Supabase.
/// - Data cloud adalah sumber utama; data lokal Hive menjadi fallback offline.
class PlantingScheduleService {
  static const String _boxName = 'plantingSchedule';

  static const Duration _timeout = Duration(seconds: 10);

  Box get _box {
    if (!Hive.isBoxOpen(_boxName)) {
      throw Exception('Hive box $_boxName is not open');
    }
    return Hive.box(_boxName);
  }

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _userId => _supabase?.auth.currentUser?.id;

  bool get _isOnline =>
      _supabase != null && _userId != null && !_isOfflineMode();

  bool _isOfflineMode() {
    try {
      // Hindari dependency circular: baca flag offline langsung dari settings box
      final settingsBox = Hive.isBoxOpen('settingsCache')
          ? Hive.box('settingsCache')
          : null;
      return settingsBox?.get('isOfflineMode') == true;
    } catch (_) {
      return false;
    }
  }

  // ─── MAPPING ────────────────────────────────────────────────────────────
  // Skema Hive (lama): nama_tanaman / tanggal_tanam / catatan
  // Skema Supabase: plant_name / planting_date / notes

  Map<String, dynamic> _toLocalMap({
    required String namaTanaman,
    required DateTime tanggalTanam,
    String? catatan,
    required bool synced,
    int? cloudId,
  }) =>
      {
        'nama_tanaman': namaTanaman,
        'tanggal_tanam': tanggalTanam.toIso8601String(),
        'catatan': catatan,
        'is_synced': synced,
        'cloud_id': cloudId,
      };

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime(2000);
  }

  List<Map<String, dynamic>> _sortSchedules(List<Map<String, dynamic>> list) {
    list.sort((a, b) =>
        _parseDate(a['tanggal_tanam']).compareTo(_parseDate(b['tanggal_tanam'])));
    return list;
  }

  // ─── FETCH (menggabungkan cloud + lokal) ────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchSchedules() async {
    try {
      // 1. Baca dulu dari Hive (cepat, tersedia offline)
      final local = _readLocalSchedules();

      // 2. Jika sedang online, tarik data terbaru dari cloud dan merge
      if (_isOnline) {
        final cloud = await _fetchCloudSchedules();
        final merged = await _mergeCloudToLocal(cloud, local);
        return _sortSchedules(merged);
      }

      return _sortSchedules(local);
    } catch (e) {
      // Fallback penuh ke lokal saat cloud error
      debugPrint('PlantingScheduleService: fetch error, fallback lokal: $e');
      return _sortSchedules(_readLocalSchedules());
    }
  }

  List<Map<String, dynamic>> _readLocalSchedules() {
    final data = _box.toMap();
    return data.entries.map((e) {
      final map = Map<String, dynamic>.from(e.value);
      map['id'] = e.key;
      return map;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchCloudSchedules() async {
    final response = await _supabase!
        .from('planting_schedules')
        .select()
        .eq('user_id', _userId!)
        .order('planting_date', ascending: true)
        .timeout(_timeout);

    return (response as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return {
        'id': map['id'],
        'nama_tanaman': map['plant_name'] ?? 'Tanpa Nama',
        'tanggal_tanam': _parseDate(map['planting_date']).toIso8601String(),
        'catatan': map['notes'],
        'is_synced': true,
        'cloud_id': map['id'],
      };
    }).toList();
  }

  /// Merge data cloud ke lokal:
  /// - Baris cloud baru (belum ada cloud_id-nya di lokal) disalin ke Hive.
  /// - Baris lokal ber-flag `is_synced: false` dipertahankan (akan di-push saat sync).
  Future<List<Map<String, dynamic>>> _mergeCloudToLocal(
    List<Map<String, dynamic>> cloud,
    List<Map<String, dynamic>> local,
  ) async {
    final localCloudIds = local
        .map((s) => s['cloud_id'])
        .where((id) => id != null)
        .toSet();
    final unsynced = local.where((s) => s['is_synced'] != true).toList();

    for (final cloudRow in cloud) {
      final cloudId = cloudRow['cloud_id'];
      if (!localCloudIds.contains(cloudId)) {
        final newKey = await _box.add(_toLocalMap(
          namaTanaman: cloudRow['nama_tanaman'],
          tanggalTanam: _parseDate(cloudRow['tanggal_tanam']),
          catatan: cloudRow['catatan'],
          synced: true,
          cloudId: cloudId is int ? cloudId : null,
        ));
        // Re-inject id untuk return list
        final added = _box.get(newKey) as Map;
        added['id'] = newKey;
      }
    }

    // Hasil merge: baris cloud + baris lokal belum tersinkron
    return [...cloud, ...unsynced];
  }

  // ─── ADD ────────────────────────────────────────────────────────────────

  Future<int> addSchedule({
    required String namaTanaman,
    required DateTime tanggalTanam,
    String? catatan,
  }) async {
    // 1. Simpan ke Hive terlebih dahulu (offline-first)
    int id;
    int? cloudId;

    if (_isOnline) {
      try {
        final cloudRow = await _pushToCloud(
          namaTanaman: namaTanaman,
          tanggalTanam: tanggalTanam,
          catatan: catatan,
        );
        cloudId = cloudRow;
      } catch (e) {
        debugPrint('PlantingScheduleService: cloud insert gagal, offline queue: $e');
      }
    }

    id = await _box.add(
      _toLocalMap(
        namaTanaman: namaTanaman,
        tanggalTanam: tanggalTanam,
        catatan: catatan,
        synced: cloudId != null,
        cloudId: cloudId,
      ),
    );
    return id;
  }

  Future<int?> _pushToCloud({
    required String namaTanaman,
    required DateTime tanggalTanam,
    String? catatan,
  }) async {
    final response = await _supabase!
        .from('planting_schedules')
        .insert({
          'user_id': _userId,
          'plant_name': namaTanaman,
          'planting_date':
              '${tanggalTanam.year.toString().padLeft(4, '0')}-'
              '${tanggalTanam.month.toString().padLeft(2, '0')}-'
              '${tanggalTanam.day.toString().padLeft(2, '0')}',
          'notes': catatan,
        })
        .select('id')
        .single()
        .timeout(_timeout);

    return response['id'] as int?;
  }

  // ─── UPDATE ─────────────────────────────────────────────────────────────

  Future<void> updateSchedule({
    required int id,
    required String namaTanaman,
    required DateTime tanggalTanam,
    String? catatan,
  }) async {
    final existing = _box.get(id) as Map?;
    final cloudId = existing?['cloud_id'] as int?;
    bool synced = false;

    if (_isOnline) {
      try {
        if (cloudId != null) {
          await _supabase!
              .from('planting_schedules')
              .update({
                'plant_name': namaTanaman,
                'planting_date':
                    '${tanggalTanam.year.toString().padLeft(4, '0')}-'
                    '${tanggalTanam.month.toString().padLeft(2, '0')}-'
                    '${tanggalTanam.day.toString().padLeft(2, '0')}',
                'notes': catatan,
              })
              .eq('id', cloudId)
              .eq('user_id', _userId!)
              .timeout(_timeout);
          synced = true;
        } else {
          // Belum punya cloud_id (dibuat offline) — insert baru
          final newCloudId = await _pushToCloud(
            namaTanaman: namaTanaman,
            tanggalTanam: tanggalTanam,
            catatan: catatan,
          );
          synced = newCloudId != null;
          if (synced) {
            await _box.put(id, _toLocalMap(
              namaTanaman: namaTanaman,
              tanggalTanam: tanggalTanam,
              catatan: catatan,
              synced: true,
              cloudId: newCloudId,
            ));
            return;
          }
        }
      } catch (e) {
        debugPrint('PlantingScheduleService: cloud update gagal: $e');
      }
    }

    await _box.put(id, _toLocalMap(
      namaTanaman: namaTanaman,
      tanggalTanam: tanggalTanam,
      catatan: catatan,
      synced: synced,
      cloudId: cloudId,
    ));
  }

  // ─── DELETE ────────────────────────────────────────────────────────────

  Future<void> deleteSchedule(int id) async {
    final existing = _box.get(id) as Map?;
    final cloudId = existing?['cloud_id'] as int?;

    // Hapus di cloud terlebih dahulu; jika sukses, hapus lokal
    if (_isOnline && cloudId != null) {
      try {
        await _supabase!
            .from('planting_schedules')
            .delete()
            .eq('id', cloudId)
            .eq('user_id', _userId!)
            .timeout(_timeout);
      } on SocketException catch (e) {
        debugPrint('PlantingScheduleService: cloud delete offline: $e');
      } catch (e) {
        debugPrint('PlantingScheduleService: cloud delete error: $e');
      }
    }

    await _box.delete(id);
  }

  // ─── PENDING SYNC (background push) ─────────────────────────────────────

  /// Dorong seluruh baris lokal ber-flag `is_synced: false` ke cloud.
  /// Dipanggil saat koneksi pulih atau saat app start.
  Future<int> syncPendingSchedules() async {
    if (!_isOnline) return 0;

    int pushed = 0;
    final data = _box.toMap();

    for (final entry in data.entries) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      if (map['is_synced'] == true) continue;

      try {
        if (map['cloud_id'] == null) {
          final cloudId = await _pushToCloud(
            namaTanaman: map['nama_tanaman']?.toString() ?? 'Tanpa Nama',
            tanggalTanam: _parseDate(map['tanggal_tanam']),
            catatan: map['catatan']?.toString(),
          );
          if (cloudId != null) {
            map['cloud_id'] = cloudId;
            map['is_synced'] = true;
            await _box.put(entry.key, map);
            pushed++;
          }
        }
      } catch (e) {
        debugPrint('PlantingScheduleService: syncPending item gagal: $e');
      }
    }

    if (pushed > 0) {
      debugPrint('PlantingScheduleService: $pushed jadwal tersinkron ke cloud');
    }
    return pushed;
  }
}

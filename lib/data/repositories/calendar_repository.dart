import 'package:flutter/foundation.dart';
import 'package:agrinova/data/datasources/planting_schedule_service.dart';

/// Repository untuk mengelola Jadwal Tanam
/// Mendukung arsitektur Offline-First (Hive) dan Cloud Sync (Supabase)
class CalendarRepository {
  final PlantingScheduleService _scheduleService;

  CalendarRepository({
    required PlantingScheduleService scheduleService,
  }) : _scheduleService = scheduleService;

  /// Fetch semua jadwal tanam (cloud merge dengan offline fallback)
  Future<List<Map<String, dynamic>>> fetchSchedules() async {
    try {
      final schedules = await _scheduleService.fetchSchedules();
      debugPrint('CalendarRepository: Loaded ${schedules.length} schedules');
      return schedules;
    } catch (e) {
      debugPrint('CalendarRepository: Error fetching schedules - $e');
      rethrow;
    }
  }

  /// Tambah jadwal baru
  Future<int> addSchedule({
    required String namaTanaman,
    required DateTime tanggalTanam,
    String? catatan,
  }) async {
    try {
      final id = await _scheduleService.addSchedule(
        namaTanaman: namaTanaman,
        tanggalTanam: tanggalTanam,
        catatan: catatan,
      );
      debugPrint('CalendarRepository: Added schedule with ID $id');
      return id;
    } catch (e) {
      debugPrint('CalendarRepository: Error adding schedule - $e');
      rethrow;
    }
  }

  /// Update jadwal yang sudah ada
  Future<void> updateSchedule({
    required int id,
    required String namaTanaman,
    required DateTime tanggalTanam,
    String? catatan,
  }) async {
    try {
      await _scheduleService.updateSchedule(
        id: id,
        namaTanaman: namaTanaman,
        tanggalTanam: tanggalTanam,
        catatan: catatan,
      );
      debugPrint('CalendarRepository: Updated schedule $id');
    } catch (e) {
      debugPrint('CalendarRepository: Error updating schedule - $e');
      rethrow;
    }
  }

  /// Hapus jadwal
  Future<void> deleteSchedule(int id) async {
    try {
      await _scheduleService.deleteSchedule(id);
      debugPrint('CalendarRepository: Deleted schedule $id');
    } catch (e) {
      debugPrint('CalendarRepository: Error deleting schedule - $e');
      rethrow;
    }
  }

  /// Sinkronkan jadwal offline yang tertunda
  Future<int> syncPendingSchedules() async {
    return await _scheduleService.syncPendingSchedules();
  }
}

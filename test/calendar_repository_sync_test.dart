import 'package:flutter_test/flutter_test.dart';
import 'package:agrinova/data/repositories/calendar_repository.dart';
import 'package:agrinova/data/datasources/planting_schedule_service.dart';

class MockPlantingScheduleService implements PlantingScheduleService {
  final List<Map<String, dynamic>> _storage = [];
  int _idCounter = 1;
  int syncCallCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Map<String, dynamic>>> fetchSchedules() async {
    return List.from(_storage);
  }

  @override
  Future<int> addSchedule({
    required String namaTanaman,
    required DateTime tanggalTanam,
    String? catatan,
  }) async {
    final id = _idCounter++;
    _storage.add({
      'id': id,
      'nama_tanaman': namaTanaman,
      'tanggal_tanam': tanggalTanam.toIso8601String(),
      'catatan': catatan,
      'is_synced': false,
    });
    return id;
  }

  @override
  Future<void> updateSchedule({
    required int id,
    required String namaTanaman,
    required DateTime tanggalTanam,
    String? catatan,
  }) async {
    final idx = _storage.indexWhere((e) => e['id'] == id);
    if (idx != -1) {
      _storage[idx] = {
        'id': id,
        'nama_tanaman': namaTanaman,
        'tanggal_tanam': tanggalTanam.toIso8601String(),
        'catatan': catatan,
        'is_synced': false,
      };
    }
  }

  @override
  Future<void> deleteSchedule(int id) async {
    _storage.removeWhere((e) => e['id'] == id);
  }

  @override
  Future<int> syncPendingSchedules() async {
    syncCallCount++;
    int count = 0;
    for (var i = 0; i < _storage.length; i++) {
      if (_storage[i]['is_synced'] == false) {
        _storage[i]['is_synced'] = true;
        count++;
      }
    }
    return count;
  }
}

void main() {
  group('CalendarRepository Sync Tests', () {
    late MockPlantingScheduleService mockService;
    late CalendarRepository repository;

    setUp(() {
      mockService = MockPlantingScheduleService();
      repository = CalendarRepository(scheduleService: mockService);
    });

    test('Add schedule saves item locally with unsynced state', () async {
      final id = await repository.addSchedule(
        namaTanaman: 'Padi Ciherang',
        tanggalTanam: DateTime(2026, 10, 15),
        catatan: 'Musim hujan pertama',
      );

      expect(id, 1);
      final list = await repository.fetchSchedules();
      expect(list.length, 1);
      expect(list.first['nama_tanaman'], 'Padi Ciherang');
      expect(list.first['is_synced'], false);
    });

    test('Sync pending schedules pushes unsynced items and marks them synced', () async {
      await repository.addSchedule(
        namaTanaman: 'Padi Ciherang',
        tanggalTanam: DateTime(2026, 10, 15),
      );
      await repository.addSchedule(
        namaTanaman: 'Jagung Hibrida',
        tanggalTanam: DateTime(2026, 11, 1),
      );

      final syncedCount = await repository.syncPendingSchedules();
      expect(syncedCount, 2);
      expect(mockService.syncCallCount, 1);

      final list = await repository.fetchSchedules();
      expect(list.every((item) => item['is_synced'] == true), true);
    });

    test('Update schedule updates data and resets sync flag', () async {
      final id = await repository.addSchedule(
        namaTanaman: 'Tomat Cherry',
        tanggalTanam: DateTime(2026, 9, 20),
      );
      await repository.syncPendingSchedules();

      await repository.updateSchedule(
        id: id,
        namaTanaman: 'Tomat Beef',
        tanggalTanam: DateTime(2026, 9, 25),
        catatan: 'Ganti varietas',
      );

      final list = await repository.fetchSchedules();
      expect(list.first['nama_tanaman'], 'Tomat Beef');
      expect(list.first['is_synced'], false);
    });

    test('Delete schedule removes item from repository', () async {
      final id = await repository.addSchedule(
        namaTanaman: 'Cabai Rawit',
        tanggalTanam: DateTime(2026, 8, 10),
      );

      await repository.deleteSchedule(id);
      final list = await repository.fetchSchedules();
      expect(list.isEmpty, true);
    });
  });
}

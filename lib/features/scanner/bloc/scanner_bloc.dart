import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/datasources/pest_scanner_service.dart';
import '../../../data/datasources/pest_services.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final ImagePicker _picker = ImagePicker();
  final PestScannerService _scannerService = PestScannerService();
  final PestService _pestService = PestService();

  /// Hanya 3 jenis tanaman yang didukung model penyakit.
  static const List<String> supportedPlants = ['Tomat', 'Padi', 'Teh'];

  String _currentPlantType = 'Tomat';

  ScannerBloc() : super(const ScannerInitial()) {
    on<ScanWithSelectedPlant>(_onScanWithSelectedPlant);
    on<ScanWithAutoDetect>(_onScanWithAutoDetect);
    on<ResetScanner>(_onResetScanner);
    on<SetPlantType>(_onSetPlantType);
  }

  void _onSetPlantType(SetPlantType event, Emitter<ScannerState> emit) {
    if (!supportedPlants.contains(event.plantType)) return;
    _currentPlantType = event.plantType;
    emit(ScannerInitial(selectedPlantType: _currentPlantType));
  }

  // ─── Alur MANUAL ──────────────────────────────────────────────────────────
  Future<void> _onScanWithSelectedPlant(
      ScanWithSelectedPlant event, Emitter<ScannerState> emit) async {
    final imagePath = await _pickImage(event.source, emit);
    if (imagePath == null) return;

    await _analyzeDisease(
      emit,
      imagePath: imagePath,
      plantType: _currentPlantType,
    );
  }

  // ─── Alur AUTO DETEKSI (Menggunakan Gemini Vision AI) ───────────────────────
  Future<void> _onScanWithAutoDetect(
      ScanWithAutoDetect event, Emitter<ScannerState> emit) async {
    final imagePath = await _pickImage(event.source, emit);
    if (imagePath == null) return;

    try {
      emit(const ScannerLoading(message: 'Menghubungkan ke server AI...'));
      await Future.delayed(const Duration(milliseconds: 600));
      if (!emit.isDone) {
        emit(const ScannerLoading(message: 'Menganalisis gambar daun tanaman...'));
      }

      final geminiResult = await _scannerService.analyzeWithGeminiVision(File(imagePath));
      if (!emit.isDone) {
        emit(const ScannerLoading(message: 'Menyiapkan hasil diagnosa...'));
      }
      final isPlant = geminiResult['is_plant'] == true;

      if (!isPlant) {
        emit(const ScannerError(
            'Gambar tidak terdeteksi sebagai tanaman. Silakan foto ulang tanaman atau daun dengan jelas.'));
        return;
      }

      final detectedPlant = (geminiResult['plant_type'] ?? 'Tanaman').toString();
      final diseaseName = (geminiResult['disease_name'] ?? 'Sehat').toString();
      final confidence = (geminiResult['confidence'] is num)
          ? (geminiResult['confidence'] as num).toDouble()
          : 0.90;

      // Upload gambar ke cloud storage (hanya untuk histori)
      String cloudImageUrl = '';
      try {
        cloudImageUrl = await _pestService.uploadImage(imagePath);
      } catch (e) {
        debugPrint('PestScanner: Upload image for history failed (non-fatal): $e');
      }

      // Ambil detail penyakit dari DB jika ada
      Map<String, dynamic>? pestData;
      final isHealthy = diseaseName.toLowerCase() == 'sehat' || diseaseName.toLowerCase() == 'healthy';
      if (!isHealthy) {
        pestData = await _pestService.fetchDiseaseDetailByName(
          plantType: detectedPlant,
          name: diseaseName,
        );

        // Jika tidak ada di DB, buat map pestData sintetis dari analisis Gemini Vision
        pestData ??= {
          'nama_penyakit': diseaseName,
          'deskripsi': geminiResult['description'] ?? 'Penyakit terdeteksi melalui AI Gemini Vision.',
          'tindakan': geminiResult['recommendation'] ?? 'Lakukan penanganan dengan obat/pupuk yang sesuai.',
          'pencegahan': geminiResult['prevention'] ?? 'Jaga kebersihan lahan dan pola irigasi.',
        };
      }

      final recommendedDrugs = await _getRecommendedDrugs(
        plantType: detectedPlant,
        finalLabel: diseaseName,
        searchName: diseaseName,
        rawLabel: diseaseName,
      );

      // Simpan histori
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (cloudImageUrl.isNotEmpty && userId != null) {
        await _pestService.savePredictionHistory({
          'user_id': userId,
          'image_url': cloudImageUrl,
          'plant_type': detectedPlant,
          'disease': diseaseName,
          'confidence': confidence,
          'severity': 'Pending',
          'status': 'Success',
        });
      }

      emit(ScannerSuccess(
        imagePath: imagePath,
        cloudImageUrl: cloudImageUrl,
        label: diseaseName,
        confidence: confidence,
        plantType: detectedPlant,
        pestData: pestData,
        recommendedDrugs: recommendedDrugs,
      ));
    } catch (e) {
      debugPrint('ScannerBloc error: $e');
      emit(const ScannerError(
          'Gambar tidak terdeteksi sebagai tanaman. Silakan foto ulang tanaman atau daun dengan jelas.'));
    }
  }

  /// Ambil gambar; emit state perantara. Mengembalikan path atau null jika batal/gagal.
  Future<String?> _pickImage(
      ImageSource source, Emitter<ScannerState> emit) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (image == null) return null;
      emit(ScannerImagePicked(image.path));
      return image.path;
    } catch (e) {
      emit(ScannerError('Gagal mengambil gambar: $e'));
      return null;
    }
  }

  /// Upload gambar, jalankan model penyakit sesuai [plantType] (HuggingFace), ambil detail,
  /// simpan histori, dan emit hasil.
  Future<void> _analyzeDisease(
    Emitter<ScannerState> emit, {
    required String imagePath,
    required String plantType,
  }) async {
    emit(const ScannerLoading(message: 'Menghubungkan ke model penyakit... (cold-start server)'));

    try {
      // 1. Upload gambar ke Supabase Storage.
      String cloudImageUrl = '';
      try {
        if (!emit.isDone) {
          emit(const ScannerLoading(message: 'Mengunggah gambar untuk analisis...'));
        }
        cloudImageUrl = await _pestService.uploadImage(imagePath);
        debugPrint('PestScanner: Image uploaded to $cloudImageUrl');
      } catch (e) {
        if (plantType == 'Tomat') {
          throw Exception('Gagal mengunggah gambar ke cloud storage: $e');
        }
        debugPrint('PestScanner: Upload gagal (non-fatal untuk $plantType): $e');
      }

      // 2. Jalankan model penyakit sesuai jenis tanaman (HuggingFace)
      if (!emit.isDone) {
        emit(ScannerLoading(message: 'Menganalisis penyakit tanaman $plantType...'));
      }
      final Map<String, dynamic> result =
          await _runDiseaseModel(plantType, imagePath, cloudImageUrl);

      if (!emit.isDone) {
        emit(const ScannerLoading(message: 'Mencari rekomendasi penanganan...'));
      }

      final rawLabel = (result['label'] ?? 'Tidak Terdeteksi').toString();
      final confidence = (result['confidence'] ?? 0.0).toDouble();

      // 3. Map label model -> nama penyakit di DB
      final searchName = _mapLabelToSearchName(plantType, rawLabel);

      // 4. Ambil detail penyakit dari tabel sesuai tanaman
      Map<String, dynamic>? pestData;
      if (searchName != 'Sehat' && searchName != 'Tidak Terdeteksi') {
        pestData = await _pestService.fetchDiseaseDetailByName(
          plantType: plantType,
          name: searchName,
        );
      }

      final finalLabel =
          pestData != null ? pestData['nama_penyakit'] : searchName;

      // 5. Cari obat rekomendasi dari JSON
      final recommendedDrugs = await _getRecommendedDrugs(
        plantType: plantType,
        finalLabel: finalLabel,
        searchName: searchName,
        rawLabel: rawLabel,
      );

      // 6. Simpan histori (hanya jika ada URL gambar dan user login)
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (cloudImageUrl.isNotEmpty && userId != null) {
        await _pestService.savePredictionHistory({
          'user_id': userId,
          'image_url': cloudImageUrl,
          'plant_type': plantType,
          'disease': finalLabel,
          'confidence': confidence,
          'severity': 'Pending',
          'status': 'Success',
        });
      }

      emit(ScannerSuccess(
        imagePath: imagePath,
        cloudImageUrl: cloudImageUrl,
        label: finalLabel,
        confidence: confidence,
        plantType: plantType,
        pestData: pestData,
        recommendedDrugs: recommendedDrugs,
      ));
    } catch (e) {
      emit(ScannerError('Terjadi kesalahan saat analisis: ${e.toString()}'));
    }
  }

  Future<List<Map<String, dynamic>>> _getRecommendedDrugs({
    required String plantType,
    required String finalLabel,
    required String searchName,
    required String rawLabel,
  }) async {
    List<Map<String, dynamic>> recommendedDrugs = [];
    if (finalLabel == 'Sehat' || finalLabel == 'Tidak Terdeteksi') {
      return recommendedDrugs;
    }

    try {
      final jsonString = await rootBundle.loadString('katalog_obat_tanaman.json');
      final data = jsonDecode(jsonString) as List<dynamic>;

      final qPlant = plantType.toLowerCase();
      final qDisease = finalLabel.toLowerCase();
      final qSearchName = searchName.toLowerCase();
      final qRawLabel = rawLabel.toLowerCase();

      for (final item in data) {
        final drug = Map<String, dynamic>.from(item as Map<String, dynamic>);
        final sasaranRaw = drug['sasaran'];
        final tanamanRaw = drug['tanaman'];

        bool matchPlant = false;
        if (tanamanRaw is List) {
          matchPlant = tanamanRaw.any((t) => t.toString().toLowerCase().contains(qPlant));
        } else if (tanamanRaw != null) {
          matchPlant = tanamanRaw.toString().toLowerCase().contains(qPlant);
        }

        bool matchDisease = false;
        final sStr = sasaranRaw is List
            ? sasaranRaw.join(' ').toLowerCase()
            : sasaranRaw?.toString().toLowerCase() ?? '';

        if (sStr.contains(qDisease) ||
            sStr.contains(qSearchName) ||
            sStr.contains(qRawLabel) ||
            qDisease.contains(sStr) ||
            qSearchName.contains(sStr)) {
          matchDisease = true;
        } else {
          final sTokens = sStr.split(RegExp(r'[^a-z0-9]')).where((e) => e.length > 4);
          for (final t in sTokens) {
            if (qDisease.contains(t) || qSearchName.contains(t) || qRawLabel.contains(t)) {
              matchDisease = true;
              break;
            }
          }
        }

        if (matchPlant && matchDisease) {
          recommendedDrugs.add(drug);
        }
      }

      if (recommendedDrugs.isEmpty) {
        for (final item in data) {
          final drug = Map<String, dynamic>.from(item as Map<String, dynamic>);
          final tanamanRaw = drug['tanaman'];
          bool matchPlant = false;
          if (tanamanRaw is List) {
            matchPlant = tanamanRaw.any((t) => t.toString().toLowerCase().contains(qPlant));
          } else if (tanamanRaw != null) {
            matchPlant = tanamanRaw.toString().toLowerCase().contains(qPlant);
          }
          if (matchPlant) recommendedDrugs.add(drug);
        }
      }
    } catch (e) {
      debugPrint('Error loading recommended drugs: $e');
    }
    return recommendedDrugs;
  }

  /// Pilih & jalankan model penyakit yang sesuai.
  /// Tomat memakai cloud URL (JSON); Padi & Teh memakai file lokal (multipart).
  Future<Map<String, dynamic>> _runDiseaseModel(
      String plantType, String imagePath, String cloudImageUrl) {
    switch (plantType) {
      case 'Padi':
        return _scannerService.predictRice(File(imagePath));
      case 'Teh':
        return _scannerService.predictTea(File(imagePath));
      case 'Tomat':
      default:
        return _scannerService.predictTomato(cloudImageUrl);
    }
  }

  // ─── Mapping label model -> nama_penyakit di Supabase ─────────────────────
  String _mapLabelToSearchName(String plantType, String label) {
    final normalized = label.trim().toLowerCase();

    // Healthy untuk semua tanaman
    if (normalized.contains('healthy') || normalized.contains('sehat')) {
      return 'Sehat';
    }

    switch (plantType) {
      case 'Padi':
        return _padiMapping[normalized] ?? label;
      case 'Teh':
        return _tehMapping[normalized] ?? label;
      case 'Tomat':
      default:
        return _tomatoMapping[label] ??
            _tomatoMapping[label.toLowerCase()] ??
            label.replaceAll('Tomato_', '').replaceAll('_', ' ');
    }
  }

  // Tomat: label model PERSIS (case-sensitive) -> nama_penyakit
  static const Map<String, String> _tomatoMapping = {
    'Tomato_Bacterial_spot': 'Bacterial Spot (Bercak Bakteri)',
    'Tomato_Early_blight': 'Early Blight (Hawar Awal / Alternaria)',
    'Tomato_Late_blight': 'Late Blight (Hawar Lambat / Phytophthora)',
    'Tomato_Leaf_Mold': 'Leaf Mold (Jamur Daun)',
    'Tomato_Septoria_leaf_spot': 'Septoria Leaf Spot (Bercak Daun Septoria)',
    'Tomato_Spider_mites_Two_spotted_spider_mite':
        'Spider Mites (Tungau Laba-laba)',
    'Tomato_Target_Spot': 'Target Spot (Bercak Target)',
    'Tomato_Yellow_Leaf_Curl_Virus':
        'Tomato Yellow Leaf Curl Virus (Virus Kuning Keriting)',
    'Tomato_Mosaic_virus': 'Tomato Mosaic Virus (Virus Mosaik)',
  };

  // Padi: label model (lowercase) -> nama_penyakit
  static const Map<String, String> _padiMapping = {
    'brown spot': 'Brown Spot (Bercak Cokelat)',
    'leaf blast': 'Leaf Blast (Blas Daun)',
    'leaf scald': 'Leaf Scald (Gosong Daun / Hawar Pelepah Daun)',
    'narrow brown leaf spot': 'Narrow Brown Spot (Bercak Cokelat Sempit)',
    'narrow brown spot': 'Narrow Brown Spot (Bercak Cokelat Sempit)',
    'neck_blast': 'Neck Blast (Blas Leher / Patah Leher)',
    'neck blast': 'Neck Blast (Blas Leher / Patah Leher)',
    'rice hispa': 'Hispa (Hama Hispa Daun Padi)',
    'hispa': 'Hispa (Hama Hispa Daun Padi)',
    // 'bacterial leaf blight' & 'sheath blight' tidak punya detail di DB.
  };

  // Teh: label model (lowercase) -> nama_penyakit
  static const Map<String, String> _tehMapping = {
    'anthracnose': 'Anthracnose (Antraknosa)',
    'algal leaf': 'Algal Leaf Spot (Bercak Daun Alga)',
    'algal leaf spot': 'Algal Leaf Spot (Bercak Daun Alga)',
    'bird eye spot': 'Bird Eye Spot (Bercak Mata Burung)',
    'brown blight': 'Brown Blight (Hawar Cokelat)',
    'red leaf spot': 'Red Leaf Spot (Bercak Daun Merah)',
    // 'gray light' & 'white spot' tidak punya detail di DB.
  };

  void _onResetScanner(ResetScanner event, Emitter<ScannerState> emit) {
    emit(ScannerInitial(selectedPlantType: _currentPlantType));
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:agrinova/core/constants/env_config.dart';

/// Service yang membungkus seluruh model AI HuggingFace Space:
/// - MODEL_PLANT  : deteksi jenis tanaman (Padi/Teh/Tomat) - multipart file
/// - MODEL_TOMATO : penyakit tomat - JSON {image_url}
/// - MODEL_RICE   : penyakit padi - multipart file (/predict/cnn)
/// - MODEL_TEA    : penyakit teh  - multipart file
///
/// Seluruh output dinormalisasi ke {label, confidence} dengan confidence 0..1.
class PestScannerService {
  // HuggingFace Spaces need up to 90s to wake from sleep (cold start)
  static const Duration _hfTimeout = Duration(seconds: 90);
  // Gemini Vision fast failover timeout (45s per model attempt)
  static const Duration _geminiTimeout = Duration(seconds: 45);

  // ─── Deteksi jenis tanaman (MODEL_PLANT) ──────────────────────────────────
  /// Mengembalikan {plant: 'Tomat'|'Padi'|'Teh', confidence: 0..1, accepted: bool}
  Future<Map<String, dynamic>> detectPlant(File image) async {
    final data = await _postMultipart(
      baseUrl: EnvConfig.modelPlantUrl,
      path: '/predict',
      image: image,
      tag: 'MODEL_PLANT',
    );

    return {
      'plant': (data['prediction'] ?? 'Tidak Diketahui').toString(),
      'confidence': _asDouble(data['confidence']), // sudah 0..1
      'accepted': data['accepted'] == true,
    };
  }

  // ─── Penyakit Tomat (MODEL_TOMATO) ────────────────────────────────────────
  /// Model tomat menerima image_url (JSON) dan mengembalikan confidence 0..100.
  Future<Map<String, dynamic>> predictTomato(String imageUrl) async {
    try {
      final Uri url = Uri.parse('${EnvConfig.modelTomatoUrl}/predict');
      if (kDebugMode) debugPrint('PestScannerService[MODEL_TOMATO]: POST to $url');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'image_url': imageUrl}),
          )
          .timeout(_hfTimeout);

      if (kDebugMode) {
        debugPrint(
            'PestScannerService[MODEL_TOMATO]: ${response.statusCode} ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'label': (data['label'] ?? 'Tidak Diketahui').toString(),
          'confidence': _asDouble(data['confidence']) / 100.0,
        };
      }
      throw _handleError(response);
    } on TimeoutException {
      throw Exception('Koneksi timeout. Server mungkin sedang inisialisasi, coba lagi.');
    } on SocketException {
      throw Exception('Masalah koneksi internet. Silakan periksa jaringan Anda.');
    } on http.ClientException catch (e) {
      throw Exception('Kesalahan pada client HTTP: ${e.message}');
    } catch (e) {
      if (kDebugMode) debugPrint('PestScannerService[MODEL_TOMATO] Exception: $e');
      rethrow;
    }
  }

  // ─── Penyakit Padi (MODEL_RICE) ───────────────────────────────────────────
  /// Endpoint /predict/cnn, multipart file, confidence sudah 0..1.
  Future<Map<String, dynamic>> predictRice(File image) async {
    final data = await _postMultipart(
      baseUrl: EnvConfig.modelRiceUrl,
      path: '/predict/cnn',
      image: image,
      tag: 'MODEL_RICE',
    );

    return {
      'label': (data['predicted_class'] ?? 'Tidak Diketahui').toString(),
      'confidence': _asDouble(data['confidence']), // sudah 0..1
    };
  }

  // ─── Penyakit Teh (MODEL_TEA) ─────────────────────────────────────────────
  /// Endpoint /predict, multipart file, confidence 0..100.
  Future<Map<String, dynamic>> predictTea(File image) async {
    final data = await _postMultipart(
      baseUrl: EnvConfig.modelTeaUrl,
      path: '/predict',
      image: image,
      tag: 'MODEL_TEA',
    );

    return {
      'label': (data['prediction'] ?? 'Tidak Diketahui').toString(),
      'confidence': _asDouble(data['confidence']) / 100.0,
    };
  }

  // ─── Helper multipart bersama ─────────────────────────────────────────────
  Future<Map<String, dynamic>> _postMultipart({
    required String baseUrl,
    required String path,
    required File image,
    required String tag,
  }) async {
    try {
      final Uri url = Uri.parse('$baseUrl$path');
      if (kDebugMode) debugPrint('PestScannerService[$tag]: POST (multipart) to $url');

      final request = http.MultipartRequest('POST', url)
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final streamed = await request.send().timeout(_hfTimeout);
      final response =
          await http.Response.fromStream(streamed).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        debugPrint(
            'PestScannerService[$tag]: ${response.statusCode} ${response.body}');
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw _handleError(response);
    } on TimeoutException {
      throw Exception('Koneksi timeout. Server mungkin sedang inisialisasi, coba lagi.');
    } on SocketException {
      throw Exception('Masalah koneksi internet. Silakan periksa jaringan Anda.');
    } on http.ClientException catch (e) {
      throw Exception('Kesalahan pada client HTTP: ${e.message}');
    } catch (e) {
      if (kDebugMode) debugPrint('PestScannerService[$tag] Exception: $e');
      rethrow;
    }
  }

  // ─── Deteksi & Analisis Penyakit Daun menggunakan Gemini Vision AI ────────
  /// Mengisikan {is_plant, reason, plant_type, disease_name, confidence, description, recommendation, prevention}
  Future<Map<String, dynamic>> analyzeWithGeminiVision(File imageFile) async {
    final apiKey = EnvConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY tidak ditemukan pada konfigurasi aplikasi.');
    }

    final bytes = await imageFile.readAsBytes();
    final mimeType = _getMimeType(imageFile.path);
    final base64Image = base64Encode(bytes);

    const candidateModels = [
      'gemini-3.5-flash',
      'gemini-3.6-flash',
      'gemini-2.5-flash',
    ];

    const promptText = '''
Kamu adalah pakar kecerdasan buatan khusus pertanian (Plant Pathology & Crop Expert).
Tugasmu adalah menganalisis foto yang diunggah pengguna.

Lakukan dua langkah validasi:
1. PERIKSA APAKAH GAMBAR INI MERUPAKAN TANAMAN, DAUN, ATAU HASIL PERTANIAN/PERKEBUNAN.
   - Jika gambar BUKAN tanaman/daun (misalnya foto selfie manusia, mobil/motor, gedung, hewan peliharaan, sepatu, pakaian, dokumen, peralatan rumah tangga, dll.), set `is_plant` menjadi `false` dan berikan alasan singkat.
2. JIKA INI MERUPAKAN TANAMAN/DAUN:
   - Set `is_plant` menjadi `true`.
   - Identifikasi jenis tanaman (misalnya: Tomat, Padi, Teh, Cabai, Jagung, Bawang, dll.).
   - Diagnosa apakah tanaman Sehat atau Terserang Penyakit/Hama. Berikan nama penyakit/hama secara spesifik (beserta nama lokal/Indonesia yang umum).
   - Berikan nilai kepastian (confidence: 0.0 sampai 1.0).
   - Berikan deskripsi singkat gejala, rekomendasi tindakan penanganan, dan langkah pencegahan.

BERIKAN KELUARAN HANYA DALAM FORMAT JSON BERSIH (Strict JSON format tanpa markdown backticks atau teks lain):
{
  "is_plant": true,
  "reason": "Alasan jika bukan tanaman",
  "plant_type": "Nama Tanaman",
  "disease_name": "Nama Penyakit atau Sehat",
  "confidence": 0.95,
  "description": "Penjelasan singkat gejala",
  "recommendation": "Tindakan penanganan dan obat/pupuk yang disarankan",
  "prevention": "Langkah pencegahan"
}
''';

    final bodyPayload = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': promptText},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ]
    });

    Object? lastError;

    for (final model in candidateModels) {
      final Uri url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      );

      try {
        if (kDebugMode) debugPrint('PestScannerService[GeminiVision]: POST to $url');

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: bodyPayload,
            )
            .timeout(_geminiTimeout);

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = resData['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              String rawText = (parts[0]['text'] ?? '').toString().trim();
              if (rawText.startsWith('```json')) {
                rawText = rawText.substring(7);
              } else if (rawText.startsWith('```')) {
                rawText = rawText.substring(3);
              }
              if (rawText.endsWith('```')) {
                rawText = rawText.substring(0, rawText.length - 3);
              }
              rawText = rawText.trim();

              final parsedJson = jsonDecode(rawText) as Map<String, dynamic>;
              return parsedJson;
            }
          }
        } else {
          lastError = 'Gemini status ${response.statusCode}: ${response.body}';
          debugPrint('PestScannerService[GeminiVision]: Model $model status ${response.statusCode}, trying next model...');
          await Future.delayed(const Duration(milliseconds: 800));
        }
      } catch (e) {
        lastError = e;
        debugPrint('PestScannerService[GeminiVision]: Exception on model $model: $e');
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }

    throw Exception('Gagal melakukan analisis Gemini Vision: ${lastError ?? "Server sibuk"}');
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  Exception _handleError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        return Exception('Model Error: ${data['error']}');
      }
    } catch (_) {}

    switch (response.statusCode) {
      case 404:
        return Exception(
            'Endpoint model tidak ditemukan (404). Periksa konfigurasi URL di .env.');
      case 500:
        return Exception(
            'Server model mengalami gangguan (500). Silakan coba lagi nanti.');
      case 503:
        return Exception(
            'Model sedang dalam proses inisialisasi atau sedang sibuk (503).');
      default:
        return Exception(
            'Gagal menghubungi model AI (Status: ${response.statusCode})');
    }
  }
}

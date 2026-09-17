import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum PaymentStatus {
  success,
  pending,
  failed,
  unknown,
}

class MidtransTransactionResult {
  final String orderId;
  final String? token;
  final String redirectUrl;
  final bool isLiveSandbox;
  final String? errorMessage;

  MidtransTransactionResult({
    required this.orderId,
    this.token,
    required this.redirectUrl,
    required this.isLiveSandbox,
    this.errorMessage,
  });
}

class MidtransService {
  static final MidtransService _instance = MidtransService._internal();
  factory MidtransService() => _instance;
  MidtransService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<MidtransTransactionResult> createTransaction({
    required String planName,
    required int amount,
    String paymentMethod = 'qris',
    String? productId,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('Sesi tidak ditemukan. Silakan masuk kembali.');
      }

      final response = await _supabase.functions.invoke(
        'create-midtrans-payment',
        body: {
          'planName': planName,
          'amount': amount,
          'paymentMethod': paymentMethod,
          if (productId != null) 'productId': productId,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        final orderId = data['order_id'] as String;
        final token = data['token'] as String?;
        final redirectUrl = data['redirect_url'] as String? ?? '';

        if (redirectUrl.isEmpty) {
          throw Exception('URL pembayaran tidak diterima dari server.');
        }

        return MidtransTransactionResult(
          orderId: orderId,
          token: token,
          redirectUrl: redirectUrl,
          isLiveSandbox: true,
        );
      }

      // Ekstrak pesan error dari Edge Function jika ada
      String serverError = 'Gagal membuat tagihan (Status ${response.status}).';
      try {
        final errData = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : null;
        if (errData != null && errData['error'] != null) {
          serverError = errData['error'].toString();
        }
      } catch (_) {}

      throw Exception(serverError);
    } catch (e) {
      debugPrint('[MidtransService] Error memanggil Edge Function: $e');
      rethrow;
    }
  }

  /// Membuka link pembayaran Snap di Web Browser eksternal
  Future<bool> openPaymentUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[MidtransService] Gagal membuka URL pembayaran: $e');
    }
    return false;
  }

  /// Membuka Simulator Resmi Midtrans di Browser (hanya untuk mode demo)
  Future<void> openMidtransSimulator({String type = 'qris'}) async {
    final url = _simulatorUrlFor(type);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _simulatorUrlFor(String type) {
    switch (type) {
      case 'va_bca':
        return 'https://simulator.sandbox.midtrans.com/bca/va/index';
      case 'va_bni':
        return 'https://simulator.sandbox.midtrans.com/bni/va/index';
      case 'va_bri':
        return 'https://simulator.sandbox.midtrans.com/bri/va/index';
      case 'va_mandiri':
        return 'https://simulator.sandbox.midtrans.com/openapi/va/index?bank=mandiri';
      case 'va_permata':
        return 'https://simulator.sandbox.midtrans.com/permata/va/index';
      case 'va':
        return 'https://simulator.sandbox.midtrans.com/bni/va/index';
      case 'qris':
      default:
        return 'https://simulator.sandbox.midtrans.com/qris/index';
    }
  }
}

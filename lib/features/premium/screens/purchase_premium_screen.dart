import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:agrinova/core/constants/colors.dart';
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/core/services/midtrans_service.dart';
import 'package:agrinova/features/premium/widgets/demo_qr_payment_sheet.dart'; // TAMBAH INI
import 'package:agrinova/widgets/app_toast.dart';

class PurchasePremiumScreen extends StatefulWidget {
  const PurchasePremiumScreen({super.key});

  @override
  State<PurchasePremiumScreen> createState() => _PurchasePremiumScreenState();
}

class _PurchasePremiumScreenState extends State<PurchasePremiumScreen> {
  final CacheService _cacheService = CacheService();
  final MidtransService _midtransService = MidtransService();
  StreamSubscription<Map<String, dynamic>>? _subSubscription;
  Timer? _liveTicker;

  int _selectedPlanIndex =
      0; // Default to 30 Detik Demo agar user bisa langsung tes
  String _selectedPaymentMethod = 'qris';
  bool _isProcessing = false;
  late Map<String, dynamic> _subscriptionDetails;

  @override
  void initState() {
    super.initState();
    _subscriptionDetails = _cacheService.getSubscriptionDetails();

    _subSubscription = _cacheService.subscriptionUpdateStream.listen((sub) {
      if (mounted) {
        setState(() {
          _subscriptionDetails = sub;
        });
      }
    });

    _liveTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _subscriptionDetails['isActive'] == true) {
        final expiry = _subscriptionDetails['expiryDate'] as DateTime?;
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          // Trigger expiration check
          _cacheService.isPremiumActive();
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subSubscription?.cancel();
    _liveTicker?.cancel();
    super.dispose();
  }

  final List<Map<String, dynamic>> _plans = [
    {
      'title': 'Demo 1 Jam (QRIS)',
      'subtitle': 'Scan QR untuk simulasi aktivasi PRO',
      'price': 'Gratis (Demo)',
      'period': '/1 jam',
      'rawPrice': '1 Jam Demo',
      'saveTag': 'DEMO QRIS 1 JAM',
      'isPopular': true,
      'isDemoNoBrowser': true,
      'duration': const Duration(hours: 1),
      'amount': 1000,
    },
    {
      'title': '1 Bulan',
      'subtitle': 'Fleksibel, bayar bulanan',
      'price': 'Rp 29.000',
      'period': '/bulan',
      'rawPrice': 'Rp 29.000',
      'saveTag': null,
      'isPopular': false,
      'duration': const Duration(days: 30),
      'amount': 29000,
    },
    {
      'title': '1 Musim (3 Bulan)',
      'subtitle': 'Cocok untuk 1 siklus panen',
      'price': 'Rp 69.000',
      'period': '/3 bulan',
      'rawPrice': 'Rp 23.000 /bln',
      'saveTag': 'HEMAT 20%',
      'isPopular': false,
      'duration': const Duration(days: 90),
      'amount': 69000,
    },
    {
      'title': '1 Tahun',
      'subtitle': 'Pendampingan penuh tahunan',
      'price': 'Rp 199.000',
      'period': '/tahun',
      'rawPrice': 'Rp 16.500 /bln',
      'saveTag': 'HEMAT 42%',
      'isPopular': false,
      'duration': const Duration(days: 365),
      'amount': 199000,
    },
  ];

  final List<Map<String, dynamic>> _benefits = [
    {
      'icon': Icons.image_search_rounded,
      'title': 'Chat Asisten Tani Tanpa Batas',
      'desc':
          'Akun gratis terbatas 3 jawaban per hari, teks maupun foto. PRO bebas konsultasi tanpa limit.',
      'badge': 'Fitur Utama',
    },
    {
      'icon': Icons.bolt_rounded,
      'title': 'Respon AI Kilat & Prioritas',
      'desc':
          'Konsultasi kapan saja tanpa antri dengan model AI pertanian tercanggih.',
      'badge': 'Cepat',
    },
    {
      'icon': Icons.medication_liquid_rounded,
      'title': 'Dosis & Rekomendasi Obat Presisi',
      'desc': 'Panduan takaran obat tanaman dan solusi hama.',
      'badge': 'Akurat',
    },
    {
      'icon': Icons.support_agent_rounded,
      'title': 'Dukungan Prioritas',
      'desc':
          'Pengalaman aplikasi lancar tanpa gangguan dengan prioritas bantuan admin.',
      'badge': 'VIP',
    },
  ];

  final List<Map<String, String>> _faqs = [
    {
      'q': 'Berapa batas upload gambar untuk akun gratis?',
      'a':
          'Pengguna gratis mendapatkan kuota maksimal 3 kali upload gambar konsultasi di chatbot. Dengan akun PRO, Anda bisa upload foto sepuasnya tanpa batas.',
    },
    {
      'q': 'Bagaimana cara aktivasi paket setelah bayar?',
      'a':
          'Status PRO akan aktif secara instan dan otomatis begitu transaksi pembayaran terkonfirmasi.',
    },
  ];

  /// Menghitung tanggal kedaluwarsa yang akurat berdasarkan paket yang dipilih
  DateTime _calculateExpiryDate(Map<String, dynamic> plan) {
    final String title = (plan['title'] as String?) ?? '';
    final currentExpiry = _subscriptionDetails['expiryDate'] as DateTime?;
    final bool isCurrentlyActive = _subscriptionDetails['isActive'] == true &&
        currentExpiry != null &&
        currentExpiry.isAfter(DateTime.now());

    // Jika user sudah memiliki langganan aktif, perpanjang dari tanggal kedaluwarsa saat ini
    final bool isDemo = title.contains('2 Menit') || title.contains('Demo');
    final baseDate =
        isCurrentlyActive && !isDemo ? currentExpiry : DateTime.now();

    if (isDemo) {
      final demoDuration =
          plan['duration'] as Duration? ?? const Duration(hours: 1);
      return DateTime.now().add(demoDuration);
    } else if (title.contains('1 Bulan')) {
      return DateTime(
        baseDate.year,
        baseDate.month + 1,
        baseDate.day,
        baseDate.hour,
        baseDate.minute,
        baseDate.second,
      );
    } else if (title.contains('3 Bulan') || title.contains('Musim')) {
      return DateTime(
        baseDate.year,
        baseDate.month + 3,
        baseDate.day,
        baseDate.hour,
        baseDate.minute,
        baseDate.second,
      );
    } else if (title.contains('1 Tahun')) {
      return DateTime(
        baseDate.year + 1,
        baseDate.month,
        baseDate.day,
        baseDate.hour,
        baseDate.minute,
        baseDate.second,
      );
    }

    final duration = plan['duration'] as Duration?;
    if (duration != null) {
      return baseDate.add(duration);
    }
    return baseDate.add(const Duration(days: 30));
  }

  Future<DateTime> _activatePlan(Map<String, dynamic> plan) async {
    final expiryDate = _calculateExpiryDate(plan);
    await _cacheService.setSubscription(
      isActive: true,
      planName: plan['title'] as String,
      expiryDate: expiryDate,
    );
    if (mounted) {
      setState(() {
        _subscriptionDetails = _cacheService.getSubscriptionDetails();
      });
    }
    return expiryDate;
  }

  Future<void> _processPayment() async {
    final selectedPlan = _plans[_selectedPlanIndex];
    final planTitle = selectedPlan['title'] as String;
    final int amount = selectedPlan['amount'] as int? ?? 29000;
    final bool isDemoNoBrowser = selectedPlan['isDemoNoBrowser'] == true;

    setState(() => _isProcessing = true);

    try {
      // Paket Demo: tidak perlu API Midtrans / browser, langsung tampilkan sheet konfirmasi
      if (isDemoNoBrowser) {
        setState(() => _isProcessing = false);
        // Tampilkan sheet QR demo, tunggu user klik "Saya Sudah Bayar"
        if (!mounted) return;
        final orderId = 'PM-DEMO-${DateTime.now().millisecondsSinceEpoch}';
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetCtx) => DemoQrPaymentSheet(
            planName: planTitle,
            planPrice: selectedPlan['price'] as String,
            amount: amount,
            orderId: orderId,
            durationSeconds: 30,
            onConfirmPaid: () async {
              final sheetNavigator = Navigator.of(sheetCtx);
              await Future.delayed(const Duration(milliseconds: 500));
              if (!mounted) return;
              sheetNavigator.pop();
              final expiryDate = await _activatePlan(selectedPlan);
              if (!mounted) return;
              _showSuccessDialog(expiryDate);
            },
          ),
        );
        return;
      }

      final result = await _midtransService.createTransaction(
        planName: planTitle,
        amount: amount,
        paymentMethod: _selectedPaymentMethod,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Buka halaman pembayaran di browser eksternal
      await _midtransService.openPaymentUrl(result.redirectUrl);

      // Tampilkan sheet verifikasi status pembayaran
      if (mounted) {
        _showPaymentVerificationSheet(
          orderId: result.orderId,
          plan: selectedPlan,
          redirectUrl: result.redirectUrl,
          isLiveSandbox: result.isLiveSandbox,
          paymentMethod: _selectedPaymentMethod,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppToast.show(
          context,
          message: 'Terjadi kendala saat memproses tagihan: $e',
          type: ToastType.error,
        );
      }
    }
  }

  void _showPaymentVerificationSheet({
    required String orderId,
    required Map<String, dynamic> plan,
    required String redirectUrl,
    required bool isLiveSandbox,
    String paymentMethod = 'qris',
  }) {
    bool isChecking = false;
    // Simpan outer context agar tidak terkontaminasi StatefulBuilder context
    final outerContext = context;

    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.payment_rounded,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Menunggu Pembayaran',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            Text(
                              isLiveSandbox
                                  ? 'Midtrans Sandbox Gateway Aktif'
                                  : 'Mode Demo / Simulator Payment',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Order Card Details
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Order ID',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Row(
                              children: [
                                Text(
                                  orderId,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: orderId));
                                    AppToast.show(
                                      outerContext,
                                      message: 'Order ID disalin ke clipboard',
                                      type: ToastType.success,
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.copy_rounded,
                                        size: 14,
                                        color: AppColors.primaryGreen),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Paket Pilihan',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Text(
                              plan['title'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Tagihan',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Text(
                              plan['price'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Silakan selesaikan pembayaran pada halaman browser yang telah terbuka. Setelah itu, klik tombol di bawah untuk verifikasi status.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[700], height: 1.4),
                  ),

                  const SizedBox(height: 20),

                  // Button 1: Cek Status Pembayaran (API Midtrans)
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        isChecking
                            ? 'Mengecek ke Midtrans...'
                            : 'Cek Status Pembayaran',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: isChecking
                          ? null
                          : () async {
                              setSheetState(() => isChecking = true);
                              // Sinkronkan status dari server Supabase
                              // (hasil webhook Midtrans resmi)
                              await _cacheService.syncSubscriptionFromServer();
                              setSheetState(() => isChecking = false);

                              final updatedDetails =
                                  _cacheService.getSubscriptionDetails();
                              final isActive =
                                  updatedDetails['isActive'] == true;

                              if (isActive) {
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                final expiryDate = updatedDetails['expiryDate']
                                        as DateTime? ??
                                    DateTime.now()
                                        .add(const Duration(days: 30));
                                if (!mounted) return;
                                _showSuccessDialog(expiryDate);
                              } else {
                                if (outerContext.mounted) {
                                  AppToast.show(
                                    outerContext,
                                    message:
                                        'Pembayaran sedang diverifikasi server. Harap selesaikan tagihan lalu cek kembali.',
                                    type: ToastType.warning,
                                  );
                                }
                              }
                            },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Button 2: Buka Ulang Browser / Simulator
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_browser_rounded,
                              size: 16),
                          label: const Text('Buka Ulang Web',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () =>
                              _midtransService.openPaymentUrl(redirectUrl),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1976D2),
                            side: const BorderSide(color: Color(0xFF90CAF9)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.science_outlined, size: 16),
                          label: const Text('Simulator PG',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () =>
                              _midtransService.openMidtransSimulator(
                            // Pilih simulator bank yang sesuai dengan metode pembayaran
                            // paymentMethod langsung dipakai sebagai type simulator
                            type: paymentMethod,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSuccessDialog(DateTime expiryDate) {
    final selectedPlan = _plans[_selectedPlanIndex];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primaryGreen.withAlpha(50), width: 2),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryGreen,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Selamat! Akun PRO Aktif 🎉',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Paket ${selectedPlan['title']} telah aktif. Anda sekarang bisa konsultasi dengan Asisten Tani tanpa batas kuota!',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey[700], height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text('Total Pembayaran',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          selectedPlan['price'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      Navigator.pop(context,
                          true); // Return to previous screen with success
                      AppToast.show(
                        context,
                        message: 'Status AgriNova PRO berhasil diaktifkan!',
                        type: ToastType.success,
                        icon: Icons.workspace_premium_rounded,
                      );
                    },
                    child: const Text('Mulai Gunakan PRO',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = _plans[_selectedPlanIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3813),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFFFD700), size: 22),
            SizedBox(width: 8),
            Text(
              'AgriNova PRO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero Header Banner
                _buildHeroHeader(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_subscriptionDetails['isActive'] == true) ...[
                        const SizedBox(height: 20),
                        _buildActiveStatusCard(),
                      ],
                      const SizedBox(height: 24),
                      // Section Header: Pilihan Paket
                      _buildSectionTitle(
                        _subscriptionDetails['isActive'] == true
                            ? 'Perpanjang atau Ubah Paket'
                            : 'Pilih Paket Berlangganan',
                        subtitle: _subscriptionDetails['isActive'] == true
                            ? 'Pilih paket untuk memperpanjang durasi akses'
                            : 'Upgrade untuk konsultasi AI tanpa batas kuota',
                      ),
                      const SizedBox(height: 12),
                      _buildPricingPlansList(),

                      const SizedBox(height: 28),
                      // Section Header: Keuntungan PRO
                      _buildSectionTitle(
                        'Keuntungan Menjadi Member PRO',
                        subtitle:
                            'Solusi lengkap memaksimalkan produktivitas tani',
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitsList(),

                      const SizedBox(height: 28),
                      // Section Header: Metode Pembayaran
                      _buildSectionTitle(
                        'Pilih Metode Pembayaran',
                        subtitle: 'Tersedia berbagai saluran pembayaran instan',
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentMethodsList(),

                      const SizedBox(height: 28),
                      // Section Header: Tanya Jawab (FAQ)
                      _buildSectionTitle(
                        'Pertanyaan Umum (FAQ)',
                        subtitle: 'Hal yang sering ditanyakan petani',
                      ),
                      const SizedBox(height: 12),
                      _buildFaqList(),

                      const SizedBox(height: 24),
                      _buildTrustSecurityBadge(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Bottom Checkout Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomCheckoutBar(selectedPlan),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStatusCard() {
    final expiryDate = _subscriptionDetails['expiryDate'] as DateTime?;
    final expiryFormatted = expiryDate != null
        ? DateFormat('dd MMM yyyy, HH:mm:ss').format(expiryDate)
        : 'Tanpa Batas Waktu';

    final remaining = expiryDate?.difference(DateTime.now());
    String remainingStr = '';
    if (remaining != null) {
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        remainingStr = 'Waktu Habis';
      } else if (remaining.inSeconds < 60) {
        remainingStr = '${remaining.inSeconds} detik (Live)';
      } else if (remaining.inMinutes < 60) {
        remainingStr =
            '${remaining.inMinutes} menit ${remaining.inSeconds % 60} dtk';
      } else if (remaining.inHours < 24) {
        remainingStr =
            '${remaining.inHours} jam ${remaining.inMinutes % 60} mnt';
      } else {
        remainingStr = '${remaining.inDays} hari lagi';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Langganan PRO Anda Sedang Aktif',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VIP PRO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text('Paket Aktif',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _subscriptionDetails['planName'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text('Masa Berlaku Hingga',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  expiryFormatted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
          if (remainingStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text('Hitung Mundur Sisa Waktu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 12, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text(
                        remainingStr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('Kuota Asisten Tani',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Tanpa Batas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Testing helper button to revert back to Free account
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text(
                'Reset ke Akun Gratis (Uji Coba / Demo)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                await _cacheService.setSubscription(isActive: false);
                setState(() {
                  _subscriptionDetails = _cacheService.getSubscriptionDetails();
                });
                if (mounted) {
                  AppToast.show(
                    context,
                    message: 'Status direset ke Akun Gratis',
                    type: ToastType.warning,
                    icon: Icons.info_outline,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F3813),
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withAlpha(40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFFFFD700), size: 16),
                SizedBox(width: 6),
                Text(
                  'UNLIMITED AI ACCESS',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Konsultasi Tanaman & Penyakit\nTanpa Batas Kuota',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Upload foto hama daun & buah sepuasnya. Dapatkan diagnosa kilat dan solusi akurat dari asisten pintar kami.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(220),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingPlansList() {
    return Column(
      children: List.generate(_plans.length, (index) {
        final plan = _plans[index];
        final isSelected = _selectedPlanIndex == index;
        final isPopular = plan['isPopular'] == true;

        return GestureDetector(
          onTap: () => setState(() => _selectedPlanIndex = index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF1F8E9) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isSelected ? 15 : 6),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Radio check circle
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primaryGreen
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryGreen
                                : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      // Plan Detail
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  plan['title'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : Colors.black87,
                                  ),
                                ),
                                if (plan['saveTag'] != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE65100),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      plan['saveTag'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plan['subtitle'],
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      // Price
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              plan['price'],
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              plan['rawPrice'],
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? AppColors.darkGreen
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPopular)
                  Positioned(
                    top: -10,
                    right: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withAlpha(80),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'PALING LARIS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBenefitsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _benefits.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final item = _benefits[index];
          return Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: AppColors.primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['title'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.primaryGreen.withAlpha(50)),
                            ),
                            child: Text(
                              item['badge'] as String,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['desc'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentMethodsList() {
    final paymentOptions = [
      {
        'id': 'qris',
        'title': 'QRIS (GoPay, OVO, Dana, ShopeePay)',
        'icon': Icons.qr_code_2_rounded,
        'badge': 'Instan',
      },
      {
        'id': 'va',
        'title': 'Virtual Account (BCA, BRI, Mandiri, BNI)',
        'icon': Icons.account_balance_rounded,
        'badge': 'Otomatis',
      },
      {
        'id': 'card',
        'title': 'Kartu Debit / Kredit (Visa, Mastercard)',
        'icon': Icons.credit_card_rounded,
        'badge': null,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: paymentOptions.map((opt) {
          final isSelected = _selectedPaymentMethod == opt['id'];
          return InkWell(
            onTap: () =>
                setState(() => _selectedPaymentMethod = opt['id'] as String),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(opt['icon'] as IconData,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : Colors.grey[600],
                      size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      opt['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (opt['badge'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        opt['badge'] as String,
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaqList() {
    return Column(
      children: _faqs.map((faq) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ExpansionTile(
            shape: const Border(),
            title: Text(
              faq['q']!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  faq['a']!,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[700], height: 1.4),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrustSecurityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9).withAlpha(150),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.primaryGreen, size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Transaksi Terenkripsi & Jaminan Akses Instan',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.darkGreen,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar(Map<String, dynamic> selectedPlan) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Tagihan',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              selectedPlan['price'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              ' ${selectedPlan['period']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isProcessing ? null : _processPayment,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Langganan Sekarang',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

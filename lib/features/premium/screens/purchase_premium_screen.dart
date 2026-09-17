import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:agrinova/core/constants/colors.dart';
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/core/services/midtrans_service.dart';
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
  int _selectedPlanIndex = 0;
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
  }

  @override
  void dispose() {
    _subSubscription?.cancel();
    super.dispose();
  }

  final List<Map<String, dynamic>> _plans = [
    {
      'title': 'Nova Basic',
      'subtitle': 'Fleksibel, bayar bulanan',
      'price': 'Rp 29.000',
      'period': '/bulan',
      'rawPrice': 'Rp 29.000',
      'saveTag': null,
      'isPopular': false,
      'duration': const Duration(days: 30),
      'amount': 29000,
      'productId': 'ANVB',
      'paymentLink':
          'https://app.sandbox.midtrans.com/payment-links/a0cab5bd-2006-421c-9cf2-90e09a0b7b75-SJRXo6eb',
    },
    {
      'title': 'Nova Pro',
      'subtitle': 'Fitur AI Premium Plus',
      'price': 'Rp 69.000',
      'period': '/bulan',
      'rawPrice': 'Rp 69.000 /bln',
      'saveTag': 'EXTRA FITUR',
      'isPopular': true,
      'duration': const Duration(days: 30),
      'amount': 69000,
      'productId': 'ANVP',
      'paymentLink':
          'https://app.sandbox.midtrans.com/payment-links/a7abe86f-0df7-4995-9dd0-bdcc7cd3f06b-d0K4geoG',
    },
    {
      'title': 'Nova Ultimate/Bisnis',
      'subtitle': 'Pendampingan prioritas',
      'price': 'Rp 129.000',
      'period': '/bulan',
      'rawPrice': 'Rp 129.000 /bln',
      'saveTag': 'AKSES VIP',
      'isPopular': false,
      'duration': const Duration(days: 30),
      'amount': 129000,
      'productId': 'ANVU',
      'paymentLink':
          'https://app.sandbox.midtrans.com/payment-links/e95a8179-a0b0-4a67-8f26-7b70eea85154-Zb6D3VKr',
    },
  ];

  final List<Map<String, dynamic>> _benefits = [
    {
      'icon': Icons.image_search_rounded,
      'title': 'Diagnosa Penyakit Tanpa Batas',
      'desc': 'Scan foto daun tak terbatas untuk cek kondisi tanaman.',
    },
    {
      'icon': Icons.bolt_rounded,
      'title': 'Respon Asisten Tani Prioritas',
      'desc': 'Konsultasi lebih cepat tanpa antrean.',
    },
    {
      'icon': Icons.medication_liquid_rounded,
      'title': 'Rekomendasi Obat Presisi',
      'desc': 'Panduan penanganan hama dan takaran spesifik.',
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

  Future<void> _processPayment() async {
    final selectedPlan = _plans[_selectedPlanIndex];
    final planTitle = selectedPlan['title'] as String;
    final int amount = selectedPlan['amount'] as int? ?? 29000;

    setState(() => _isProcessing = true);

    try {
      String? paymentUrl = selectedPlan['paymentLink'] as String?;
      String orderId = 'PM-${selectedPlan['productId']}-${DateTime.now().millisecondsSinceEpoch}';

      try {
        // Panggil edge function untuk mencatat transaksi dan mendapatkan URL Snap dinamis (Aman)
        final result = await _midtransService.createTransaction(
          planName: planTitle,
          amount: amount,
          productId: selectedPlan['productId'] as String?,
        );
        paymentUrl = result.redirectUrl;
        orderId = result.orderId;
      } catch (e) {
        debugPrint('createTransaction error, fallback to direct paymentLink: $e');
        if (paymentUrl == null) rethrow;
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Buka halaman pembayaran di browser eksternal
      await _midtransService.openPaymentUrl(paymentUrl);

      // Tampilkan sheet verifikasi status pembayaran
      if (mounted) {
        _showPaymentVerificationSheet(
          orderId: orderId,
          plan: selectedPlan,
          redirectUrl: paymentUrl,
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
                              'Selesaikan pembayaran di halaman Midtrans',
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

                  // Button 1: Cek Status Pembayaran (API Midtrans / Manual Verifikasi)
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
                            ? 'Mengecek ke server...'
                            : 'Cek Status Pembayaran',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: isChecking
                          ? null
                          : () async {
                              setSheetState(() => isChecking = true);
                              
                              // Sinkronkan status dari server Supabase (hasil webhook Midtrans)
                              await _cacheService.syncSubscriptionFromServer();
                              setSheetState(() => isChecking = false);

                              final updatedDetails = _cacheService.getSubscriptionDetails();
                              final isActive = updatedDetails['isActive'] == true;

                              if (isActive) {
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                final expiryDate = updatedDetails['expiryDate'] as DateTime? ??
                                    DateTime.now().add(const Duration(days: 30));
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

                  // Button 2: Buka Ulang Browser
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                    label: const Text('Buka Halaman Pembayaran',
                        style: TextStyle(fontSize: 13)),
                    onPressed: () =>
                        _midtransService.openPaymentUrl(redirectUrl),
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
                      // Section Header: Keuntungan Langganan
                      _buildSectionTitle(
                        'Keuntungan Langganan',
                        subtitle:
                            'Maksimalkan produktivitas dan hasil panen Anda',
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitsList(),

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
        ? DateFormat('dd MMM yyyy').format(expiryDate)
        : 'Tanpa Batas Waktu';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.primaryGreen, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Langganan Aktif',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Paket',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text(
                _subscriptionDetails['planName'] as String,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Berlaku Hingga',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text(
                expiryFormatted,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF0F3813),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Akses Penuh',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Konsultasi Tanaman\nTanpa Batas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dapatkan diagnosa akurat dan solusi instan dari asisten pintar kami, kapan saja Anda membutuhkannya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 14,
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

  int _getPlanRank(String? planName) {
    if (planName == null) return 0;
    final lower = planName.toLowerCase();
    if (lower.contains('ultimate') || lower.contains('bisnis')) return 3;
    if (lower.contains('pro')) return 2;
    if (lower.contains('basic')) return 1;
    return 0;
  }

  Widget _buildPricingPlansList() {
    final currentActivePlanName = _subscriptionDetails['isActive'] == true
        ? (_subscriptionDetails['planName'] as String? ?? '')
        : '';
    final currentRank = _getPlanRank(currentActivePlanName);

    return Column(
      children: List.generate(_plans.length, (index) {
        final plan = _plans[index];
        final planTitle = plan['title'] as String;
        final planRank = _getPlanRank(planTitle);
        final isSelected = _selectedPlanIndex == index;
        final isPopular = plan['isPopular'] == true;
        final isCurrentPlan = _subscriptionDetails['isActive'] == true &&
            currentActivePlanName.toLowerCase() == planTitle.toLowerCase();
        final isUpgrade = _subscriptionDetails['isActive'] == true &&
            planRank > currentRank;
        final isDowngrade = _subscriptionDetails['isActive'] == true &&
            !isCurrentPlan &&
            planRank < currentRank;

        return GestureDetector(
          onTap: () => setState(() => _selectedPlanIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isCurrentPlan
                  ? const Color(0xFFE8F5E9)
                  : isSelected
                      ? const Color(0xFFF1F8E9)
                      : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentPlan
                    ? const Color(0xFF2E7D32)
                    : isSelected
                        ? AppColors.primaryGreen
                        : Colors.grey[300]!,
                width: (isCurrentPlan || isSelected) ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isSelected ? 15 : 6),
                  blurRadius: isSelected ? 12 : 8,
                  offset: isSelected ? const Offset(0, 4) : const Offset(0, 3),
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
                      // Radio check / active badge circle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrentPlan
                              ? const Color(0xFF2E7D32)
                              : isSelected
                                  ? AppColors.primaryGreen
                                  : Colors.transparent,
                          border: Border.all(
                            color: isCurrentPlan
                                ? const Color(0xFF2E7D32)
                                : isSelected
                                    ? AppColors.primaryGreen
                                    : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                        child: (isCurrentPlan || isSelected)
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
                                    color: isCurrentPlan
                                        ? const Color(0xFF1B5E20)
                                        : isSelected
                                            ? AppColors.primaryGreen
                                            : Colors.black87,
                                  ),
                                ),
                                if (isCurrentPlan) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified_rounded,
                                            size: 11, color: Colors.white),
                                        SizedBox(width: 3),
                                        Text(
                                          'SEDANG DIGUNAKAN',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (isUpgrade) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1565C0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.upgrade_rounded,
                                            size: 11, color: Colors.white),
                                        SizedBox(width: 2),
                                        Text(
                                          'TINGKATKAN LAYANAN',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (isDowngrade) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade600,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'UBAH KE PAKET INI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ] else if (plan['saveTag'] != null) ...[
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
                              isCurrentPlan
                                  ? 'Paket aktif saat ini'
                                  : plan['subtitle'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isCurrentPlan
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey[600],
                                fontWeight: isCurrentPlan
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
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
                                color: isCurrentPlan
                                    ? const Color(0xFF1B5E20)
                                    : isSelected
                                        ? AppColors.primaryGreen
                                        : Colors.black87,
                              ),
                            ),
                            Text(
                              plan['rawPrice'],
                              style: TextStyle(
                                fontSize: 11,
                                color: isCurrentPlan
                                    ? const Color(0xFF2E7D32)
                                    : isSelected
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
                if (isPopular && !isCurrentPlan && !isUpgrade)
                  Positioned(
                    top: -10,
                    right: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'REKOMENDASI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
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
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
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
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, color: Colors.grey, size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Pembayaran Aman Terenkripsi',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500),
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
                                    'Lanjut Pembayaran',
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

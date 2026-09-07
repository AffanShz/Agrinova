import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:agrinova/core/constants/colors.dart';

class TipsDetailScreen extends StatelessWidget {
  final Map<String, dynamic> tipData;

  const TipsDetailScreen({super.key, required this.tipData});

  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);

  String get _title =>
      tipData['title'] ?? 'common.untitled'.tr();

  String get _category => tipData['category'] ?? 'Umum';

  String get _imageUrl => tipData['image_url'] ?? '';

  String get _content =>
      tipData['content'] ?? 'tips.content_unavailable'.tr();

  String get _extraTip =>
      tipData['tips_ekstra']?.toString() ?? '';

  /// Estimasi waktu baca: ~200 kata/menit, dibulatkan ke atas (min. 1 menit).
  int get _readingMinutes {
    final words = _content.trim().split(RegExp(r'\s+')).length;
    return words < 200 ? 1 : (words / 200).ceil();
  }

  /// Kategori &rarr; pasangan (ikon, warna aksen) untuk badge.
  (IconData, Color) _categoryStyle(String category) {
    switch (category.toLowerCase()) {
      case 'padi':
        return (Icons.grass_rounded, const Color(0xFF8D6E63));
      case 'jagung':
        return (Icons.energy_savings_leaf_rounded, const Color(0xFFF59E0B));
      case 'nutrisi tanaman':
        return (Icons.science_rounded, const Color(0xFF0288D1));
      case 'hama & penyakit':
        return (Icons.bug_report_rounded, const Color(0xFFD32F2F));
      case 'teknik pertanian':
        return (Icons.agriculture_rounded, const Color(0xFF7B1FA2));
      default:
        return (Icons.eco_rounded, AppColors.primaryGreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (catIcon, catColor) = _categoryStyle(_category);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      appBar: AppBar(
        title: Text('tips.detail_title'.tr()),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroImage(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge kategori + waktu baca
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildCategoryBadge(catIcon, catColor),
                      _buildMetaChip(
                        Icons.schedule_rounded,
                        '$_readingMinutes menit baca',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Judul artikel
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      height: 1.3,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Garis aksen pemisah
                  Container(
                    width: 56,
                    height: 4,
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Isi artikel (Markdown)
                  MarkdownBody(
                    data: _content,
                    selectable: true,
                    onTapLink: (text, href, title) => _openLink(href),
                    styleSheet: _articleStyle(context),
                  ),
                  // Tips ekstra (callout)
                  if (_extraTip.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildExtraTipBox(),
                  ],
                  const SizedBox(height: 28),
                  _buildEndMarker(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Komponen UI
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeroImage() {
    if (_imageUrl.isEmpty) {
      return SizedBox(height: 180, child: _heroPlaceholder());
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: _imageUrl,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        width: double.infinity,
        placeholder: (context, url) => Container(
          color: AppColors.lightGreen,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) =>
            SizedBox(height: 180, child: _heroPlaceholder()),
      ),
    );
  }

  Widget _heroPlaceholder() => Container(
        width: double.infinity,
        color: AppColors.lightGreen,
        child: const Center(
          child: Icon(Icons.image_outlined, size: 52, color: Colors.grey),
        ),
      );

  Widget _buildCategoryBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            _category,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Callout "Tips Tambahan" — menampilkan field `tips_ekstra` dari artikel.
  Widget _buildExtraTipBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tips_and_updates_rounded,
                  size: 18, color: Color(0xFFF57F17)),
              SizedBox(width: 6),
              Text(
                'Tips Tambahan',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF57F17),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _extraTip,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: Color(0xFF5D4037),
            ),
          ),
        ],
      ),
    );
  }

  /// Penanda akhir artikel.
  Widget _buildEndMarker() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 32, height: 2, color: Colors.grey.shade300),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.eco_rounded, size: 16, color: AppColors.primaryGreen),
          ),
          Container(width: 32, height: 2, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Utilitas
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openLink(String? href) async {
    if (href == null || href.isEmpty) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Gaya baca untuk artikel panjang: lapang, hierarki judul jelas, dan
  /// poin daftar yang mudah dipindai — disesuaikan dengan konten artikel
  /// bertema pertanian (langkah, poin, dan catatan penekanan).
  MarkdownStyleSheet _articleStyle(BuildContext context) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(fontSize: 15.5, height: 1.7, color: _textPrimary),
      pPadding: const EdgeInsets.only(bottom: 14),
      h1: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: _textPrimary,
          height: 1.35),
      h2: const TextStyle(
          fontSize: 18.5,
          fontWeight: FontWeight.w800,
          color: _textPrimary,
          height: 1.35),
      h3: const TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryGreen,
          height: 1.35),
      h4: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          height: 1.35),
      h1Padding: const EdgeInsets.only(top: 22, bottom: 10),
      h2Padding: const EdgeInsets.only(top: 20, bottom: 10),
      h3Padding: const EdgeInsets.only(top: 18, bottom: 8),
      h4Padding: const EdgeInsets.only(top: 16, bottom: 8),
      strong: const TextStyle(
          fontWeight: FontWeight.w700, color: Color(0xFF14532D)),
      em: const TextStyle(fontStyle: FontStyle.italic),
      listBullet: const TextStyle(
          fontSize: 15.5, height: 1.7, color: AppColors.primaryGreen),
      listIndent: 22,
      blockquotePadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: AppColors.primaryGreen, width: 3.5),
        ),
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13.5,
        backgroundColor: Colors.grey.shade200,
        color: Colors.black87,
      ),
      codeblockPadding: const EdgeInsets.all(14),
      codeblockDecoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      a: const TextStyle(
        color: AppColors.primaryGreen,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primaryGreen,
        fontWeight: FontWeight.w600,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      checkbox: const TextStyle(color: AppColors.primaryGreen),
    );
  }
}

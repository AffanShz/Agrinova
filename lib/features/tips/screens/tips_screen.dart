import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:agrinova/core/constants/colors.dart';

import 'package:agrinova/features/tips/bloc/tips_bloc.dart';
import 'package:agrinova/features/tips/screens/tips_detail_screen.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('tips.title'.tr()),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: BlocBuilder<TipsBloc, TipsState>(
        builder: (context, state) {
          if (state is TipsInitial || state is TipsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TipsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<TipsBloc>().add(LoadTips());
                    },
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            );
          }

          if (state is TipsLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<TipsBloc>().add(RefreshTips());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller:
                            _searchController, // ... existing controller
                        onChanged: (value) {
                          // Debounce
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_searchController.text == value) {
                              if (!context.mounted) return;
                              context
                                  .read<TipsBloc>()
                                  .add(SearchTips(query: value));
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'common.search'.tr(),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildChip(context, 'tips.category_all'.tr(),
                                'Semua', state.selectedCategory),
                            _buildChip(context, 'tips.category_padi'.tr(),
                                'Padi', state.selectedCategory),
                            _buildChip(context, 'tips.category_jagung'.tr(),
                                'Jagung', state.selectedCategory),
                            _buildChip(context, 'tips.category_nutrisi'.tr(),
                                'Nutrisi', state.selectedCategory),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Tips Grid
                      _buildTipsGrid(state.filteredTips),
                    ],
                  ),
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTipsGrid(List<Map<String, dynamic>> tips) {
    if (tips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('tips.empty'.tr()),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: tips.length,
      itemBuilder: (context, index) {
        final tip = tips[index];
        return _buildTipCard(
          context,
          tip['title'] ?? 'common.untitled'.tr(),
          tip['category'] ?? 'Semua',
          tip['image_url'] ?? '',
          tip,
        );
      },
    );
  }

  Widget _buildChip(BuildContext context, String label, String value,
      String selectedCategory) {
    final isSelected = selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          context.read<TipsBloc>().add(FilterTipsByCategory(category: value));
        },
        child: Chip(
          label: Text(
            label,
            style: TextStyle(color: isSelected ? Colors.white : Colors.black),
          ),
          backgroundColor: isSelected ? AppColors.primaryGreen : Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildTipCard(
    BuildContext context,
    String title,
    String category,
    String imageUrl,
    Map<String, dynamic> tipData,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TipsDetailScreen(tipData: tipData),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.image, color: Colors.grey),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.image, color: Colors.grey),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(color: AppColors.primaryGreen, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

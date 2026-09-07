import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:agrinova/core/constants/colors.dart';
import 'package:agrinova/logic/app_lifecycle/app_bloc.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<OnboardingContent> _getContents() => [
        OnboardingContent(
          titleKey: "onboarding.page1_title",
          descriptionKey: "onboarding.page1_desc",
          imagePath: 'assets/images/onboarding_welcome.png',
          badgeIcon: Icons.eco_rounded,
        ),
        OnboardingContent(
          titleKey: "onboarding.page2_title",
          descriptionKey: "onboarding.page2_desc",
          imagePath: 'assets/images/onboarding_weather.png',
          badgeIcon: Icons.cloud_sync_rounded,
        ),
        OnboardingContent(
          titleKey: "onboarding.page3_title",
          descriptionKey: "onboarding.page3_desc",
          imagePath: 'assets/images/onboarding_pests.png',
          badgeIcon: Icons.bug_report_rounded,
        ),
        OnboardingContent(
          titleKey: "onboarding.page4_title",
          descriptionKey: "onboarding.page4_desc",
          imagePath: 'assets/images/onboarding_calendar.png',
          badgeIcon: Icons.calendar_month_rounded,
        ),
        OnboardingContent(
          titleKey: "onboarding.page5_title",
          descriptionKey: "onboarding.page5_desc",
          imagePath: 'assets/images/onboarding_tips.png',
          badgeIcon: Icons.lightbulb_rounded,
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onComplete() {
    context.read<AppBloc>().add(CompleteOnboarding());
  }

  @override
  Widget build(BuildContext context) {
    final contents = _getContents();
    final isLastPage = _currentPage == contents.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedOpacity(
                    opacity: isLastPage ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: isLastPage ? null : _onComplete,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text("onboarding.skip".tr()),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: contents.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return OnboardingPage(content: contents[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 28.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      contents.length,
                      (index) {
                        final isSelected = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: isSelected ? 28 : 8,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.primaryGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLastPage) {
                          _onComplete();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: AppColors.primaryGreen.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLastPage
                                ? "onboarding.start".tr()
                                : "onboarding.next".tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastPage
                                ? Icons.check_circle_outline_rounded
                                : Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
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

class OnboardingPage extends StatelessWidget {
  final OnboardingContent content;

  const OnboardingPage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imageHeight = (size.height * 0.34).clamp(200.0, 320.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Container(
              height: imageHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Image.asset(
                  content.imagePath,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                content.badgeIcon,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              content.titleKey.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content.descriptionKey.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class OnboardingContent {
  final String titleKey;
  final String descriptionKey;
  final String imagePath;
  final IconData badgeIcon;

  OnboardingContent({
    required this.titleKey,
    required this.descriptionKey,
    required this.imagePath,
    required this.badgeIcon,
  });
}

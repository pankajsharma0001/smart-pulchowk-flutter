import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      icon: Icons.auto_awesome_rounded,
      title: 'Your Smart Companion',
      description:
          'Your ultimate digital guide to navigating IOE Pulchowk Campus with ease and intelligence.',
      colors: [const Color(0xFF2563EB), const Color(0xFF6366F1)],
    ),
    OnboardingSlide(
      icon: Icons.map_rounded,
      title: 'Interactive Campus Map',
      description:
          'Locate classrooms, departments, and utilities with precision using our interactive 3D map.',
      colors: [const Color(0xFF6366F1), const Color(0xFF0EA5E9)],
    ),
    OnboardingSlide(
      icon: Icons.notifications_active_rounded,
      title: 'Never Miss a Notice',
      description:
          'Stay updated with real-time alerts for exam results, form deadlines, and campus events.',
      colors: [const Color(0xFF0EA5E9), const Color(0xFF2DD4BF)],
    ),
    OnboardingSlide(
      icon: Icons.psychology_rounded,
      title: 'AI Campus Expert',
      description:
          'Ask our intelligent assistant anything about the campus and get instant, helpful answers.',
      colors: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
    ),
  ];

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: AppAnimations.slow,
        curve: AppAnimations.entranceCurve,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await StorageService.setHasSeenOnboarding(true);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MainLayout(key: MainLayout.mainLayoutKey),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AppAnimations.extraSlow,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic Background Gradient
          AnimatedContainer(
            duration: AppAnimations.extraSlow,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _slides[_currentPage].colors.map((c) {
                  return isDark
                      ? c.withValues(alpha: 0.15)
                      : c.withValues(alpha: 0.08);
                }).toList(),
              ),
            ),
          ),

          // Animated Background Accents
          Positioned(
            top: -100,
            right: -50,
            child: AnimatedContainer(
              duration: AppAnimations.extraSlow,
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _slides[_currentPage].colors[0].withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header with Skip
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Skip',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      haptics.selectionClick();
                      setState(() => _currentPage = index);
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return _buildSlide(_slides[index], isDark);
                    },
                  ),
                ),

                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicators
                      Row(
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: AppAnimations.normal,
                            margin: const EdgeInsets.only(right: 8),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Next / Get Started Button
                      GestureDetector(
                        onTap: () {
                          haptics.lightImpact();
                          _nextPage();
                        },
                        child: AnimatedContainer(
                          duration: AppAnimations.normal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.base,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            boxShadow: AppShadows.glow(AppColors.primary),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage == _slides.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                style: AppTextStyles.button.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Icon(
                                _currentPage == _slides.length - 1
                                    ? Icons.check_circle_rounded
                                    : Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 18,
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
        ],
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glasspormhic Card for Icon
          Container(
            width: 160,
            height: 160,
            decoration: isDark
                ? AppDecorations.glassDark(borderRadius: AppRadius.xxxl)
                : AppDecorations.glass(borderRadius: AppRadius.xxxl),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: slide.colors[0].withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(slide.icon, size: 56, color: slide.colors[0]),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.huge),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(
              fontSize: 32,
              height: 1.1,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Description
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> colors;

  OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.colors,
  });
}

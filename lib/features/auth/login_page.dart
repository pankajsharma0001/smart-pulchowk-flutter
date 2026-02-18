import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smart_pulchowk/core/services/auth_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final bool success = await AuthService.signInWithGoogle();

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Sign in was cancelled or failed. Please try again.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      }
      // On success, AuthWrapper will automatically navigate via stream.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing in: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Immersive gradient background
          _buildBackground(isDark),

          // 2. Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLoginCard(context, isDark),
                        const SizedBox(height: AppSpacing.xl),
                        _buildBenefitsSection(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ──────────────────────────────────────────────────────────

  Widget _buildBackground(bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.surfaceGradientDark
            : AppColors.surfaceGradientLight,
      ),
      child: Stack(
        children: [
          // Decorative blobs
          Positioned(
            top: -100,
            right: -50,
            child: _buildBlob(
              size: 300,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _buildBlob(
              size: 250,
              color: AppColors.secondary.withValues(alpha: 0.08),
            ),
          ),
          if (!isDark)
            Positioned(
              top: 200,
              left: -100,
              child: _buildBlob(
                size: 200,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ── Login Card ──────────────────────────────────────────────────────────

  Widget _buildLoginCard(BuildContext context, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: isDark
          ? AppDecorations.glassDark(borderRadius: AppRadius.xxl)
          : AppDecorations.glass(borderRadius: AppRadius.xxl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App icon
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.glow(AppColors.primary),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 42,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Title
          Text(
            'Smart Pulchowk',
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Tagline
          Text(
            'Your Campus, Reimagined',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Google Sign-In button
          _buildGoogleButton(context, isDark),
          const SizedBox(height: AppSpacing.xl),

          // Legal footer
          Text(
            'By signing in, you agree to our Terms of Service and Privacy Policy',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Google Button ───────────────────────────────────────────────────────

  Widget _buildGoogleButton(BuildContext context, bool isDark) {
    final backgroundColor = isDark ? const Color(0xFF131314) : Colors.white;
    final textColor = isDark
        ? const Color(0xFFE3E3E3)
        : const Color(0xFF1F1F1F);
    final borderColor = isDark
        ? const Color(0xFF8E918F)
        : const Color(0xFF747775);

    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: InkWell(
          onTap: _isLoading ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: _isLoading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: textColor,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/google_logo.svg',
                        height: 24,
                        width: 24,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Continue with Google',
                        style: AppTextStyles.button.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Benefits Section ────────────────────────────────────────────────────

  Widget _buildBenefitsSection(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          _buildBenefitItem(
            context,
            Icons.verified_user_rounded,
            'Secure Campus Access',
            'Sign in with your campus account for full verified access.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBenefitItem(
            context,
            Icons.dashboard_customize_rounded,
            'Personalized Dashboard',
            'Get instant updates on classes, assignments, and routines.',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/features/wifi_login/wifi_login_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

class WifiLoginPage extends StatefulWidget {
  const WifiLoginPage({super.key});

  @override
  State<WifiLoginPage> createState() => _WifiLoginPageState();
}

class _WifiLoginPageState extends State<WifiLoginPage>
    with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Build state
  _BuildPhase _phase = _BuildPhase.idle;
  String? _buildId;
  String? _runId;
  String? _errorMessage;
  String? _downloadUrl;
  String? _apkName;
  List<BuildStep> _steps = [];
  Timer? _pollTimer;

  // Download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localApkPath;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startBuild() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      haptics.error();
      setState(() {
        _errorMessage = 'Please enter both username and password.';
      });
      return;
    }

    haptics.mediumImpact();
    setState(() {
      _phase = _BuildPhase.starting;
      _errorMessage = null;
      _steps = [];
      _downloadUrl = null;
      _apkName = null;
    });

    try {
      final buildId = await WifiLoginService.startBuild(
        username: username,
        password: password,
      );
      if (!mounted) return;

      setState(() {
        _buildId = buildId;
        _phase = _BuildPhase.building;
      });

      _progressController.forward();
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      haptics.error();
      setState(() {
        _phase = _BuildPhase.error;
        _errorMessage = 'Failed to start build. Please try again.';
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_buildId == null || !mounted) return;

      try {
        final status = await WifiLoginService.checkStatus(_buildId!);

        // Fetch steps if we have a runId
        if (status.runId != null) {
          _runId = status.runId;
          final steps = await WifiLoginService.fetchSteps(_runId!);
          if (mounted) {
            setState(() {
              _steps = steps;
            });
          }
        }

        if (status.isCompleted) {
          _pollTimer?.cancel();

          if (status.isSuccess) {
            // Fetch download URL
            final apkInfo = await WifiLoginService.getApkDownloadUrl(_buildId!);
            if (mounted) {
              haptics.success();
              setState(() {
                _phase = _BuildPhase.completed;
                _downloadUrl = apkInfo?['url'];
                _apkName = apkInfo?['name'];
              });
            }
          } else {
            if (mounted) {
              haptics.error();
              setState(() {
                _phase = _BuildPhase.error;
                _errorMessage = 'Build failed. Please check your credentials and try again.';
              });
            }
          }
        }
      } catch (e) {
        debugPrint('WifiLoginPage: Poll error: $e');
      }
    });
  }

  void _downloadApk() async {
    if (_downloadUrl == null) return;
    haptics.mediumImpact();

    // If already downloaded and file exists, trigger share sheet directly
    if (_localApkPath != null) {
      final file = File(_localApkPath!);
      if (await file.exists()) {
        try {
          await Share.shareXFiles(
            [XFile(_localApkPath!)],
            text: 'Install the Campus WiFi Auto-Login APK',
          );
          return;
        } catch (e) {
          debugPrint('WifiLoginPage: Share error: $e');
        }
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_downloadUrl!));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var downloadedBytes = 0;
      final chunks = <List<int>>[];

      await for (final chunk in response.stream) {
        chunks.add(chunk);
        downloadedBytes += chunk.length;
        if (mounted && totalBytes > 0) {
          setState(() {
            _downloadProgress = downloadedBytes / totalBytes;
          });
        }
      }

      final bytes = Uint8List(downloadedBytes);
      var offset = 0;
      for (final chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      final tempDir = await getTemporaryDirectory();
      final apkName = _apkName ?? 'pcampus-login.apk';
      final file = File('${tempDir.path}/$apkName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      haptics.success();
      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _localApkPath = file.path;
      });

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Install the Campus WiFi Auto-Login APK',
      );
    } catch (e) {
      debugPrint('WifiLoginPage: Download error: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e. Opening in browser...'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Fallback: try opening in external browser
        try {
          final uri = Uri.parse(_downloadUrl!);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }
  }

  void _resetBuild() {
    haptics.lightImpact();
    _pollTimer?.cancel();
    _progressController.reset();
    setState(() {
      _phase = _BuildPhase.idle;
      _buildId = null;
      _runId = null;
      _errorMessage = null;
      _downloadUrl = null;
      _apkName = null;
      _steps = [];
      _isDownloading = false;
      _downloadProgress = 0.0;
      _localApkPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'WiFi Login APK',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),

            // ── Info Banner ──
            _InfoBanner(isDark: isDark),

            const SizedBox(height: AppSpacing.xl),

            // ── Credential Form ──
            if (_phase == _BuildPhase.idle || _phase == _BuildPhase.error)
              _CredentialForm(
                usernameController: _usernameController,
                passwordController: _passwordController,
                obscurePassword: _obscurePassword,
                onTogglePassword: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                errorMessage: _errorMessage,
                onBuild: _startBuild,
                isDark: isDark,
              ),

            // ── Building Progress ──
            if (_phase == _BuildPhase.starting || _phase == _BuildPhase.building)
              _BuildingProgress(
                steps: _steps,
                pulseAnimation: _pulseController,
                isDark: isDark,
                phase: _phase,
              ),

            // ── Build Complete ──
            if (_phase == _BuildPhase.completed)
              _BuildComplete(
                apkName: _apkName,
                onDownload: _downloadApk,
                onReset: _resetBuild,
                isDark: isDark,
                isDownloading: _isDownloading,
                downloadProgress: _downloadProgress,
                localApkPath: _localApkPath,
              ),

            // ── Build Error with Retry ──
            if (_phase == _BuildPhase.error)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: InkWell(
                  onTap: _startBuild,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Retry Build',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Enums ─────────────────────────────────────────────────────────────────────

enum _BuildPhase { idle, starting, building, completed, error }

// ── Info Banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final bool isDark;
  const _InfoBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E293B).withValues(alpha: 0.8),
                  const Color(0xFF0F172A).withValues(alpha: 0.8),
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.05),
                  AppColors.secondary.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.wifi_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campus WiFi Auto-Login',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Build a standalone APK that logs you into Pulchowk Campus WiFi with one tap. Your credentials are only used during APK generation.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Credential Form ──────────────────────────────────────────────────────────

class _CredentialForm extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final String? errorMessage;
  final VoidCallback onBuild;
  final bool isDark;

  const _CredentialForm({
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.errorMessage,
    required this.onBuild,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.borderDark : AppColors.borderLight)
              .withValues(alpha: 0.5),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WIFI CREDENTIALS',
            style: AppTextStyles.overline.copyWith(
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),

          // Username field
          _InputField(
            controller: usernameController,
            label: 'Username',
            hint: 'Enter your WiFi username',
            icon: Icons.person_outline_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Password field
          _InputField(
            controller: passwordController,
            label: 'Password',
            hint: 'Enter your WiFi password',
            icon: Icons.lock_outline_rounded,
            obscure: obscurePassword,
            isDark: isDark,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
              onPressed: onTogglePassword,
            ),
          ),

          // Error message
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Build button
          InkWell(
            onTap: onBuild,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.glow(AppColors.primary),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Build APK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Security note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined,
                  size: 14,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Credentials are not stored on any server',
                style: AppTextStyles.labelSmall.copyWith(
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Input Field ──────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final bool isDark;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    required this.isDark,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            ),
            prefixIcon: Icon(icon, size: 20,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.06),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                    .withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                    .withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Building Progress ────────────────────────────────────────────────────────

class _BuildingProgress extends StatelessWidget {
  final List<BuildStep> steps;
  final Animation<double> pulseAnimation;
  final bool isDark;
  final _BuildPhase phase;

  const _BuildingProgress({
    required this.steps,
    required this.pulseAnimation,
    required this.isDark,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with pulse
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: 0.3 + pulseAnimation.value * 0.4,
                          ),
                          blurRadius: 8 + pulseAnimation.value * 8,
                          spreadRadius: pulseAnimation.value * 3,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Text(
                phase == _BuildPhase.starting
                    ? 'Starting Build...'
                    : 'Building APK...',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            'This may take a few minutes. Please wait.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),

          // Build steps
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...steps.map((step) => _BuildStepTile(step: step, isDark: isDark)),
          ] else ...[
            const SizedBox(height: 20),
            _PendingStepShimmer(isDark: isDark),
          ],
        ],
      ),
    );
  }
}

// ── Build Step Tile ──────────────────────────────────────────────────────────

class _BuildStepTile extends StatelessWidget {
  final BuildStep step;
  final bool isDark;

  const _BuildStepTile({required this.step, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    if (step.isCompleted && step.isSuccess) {
      icon = Icons.check_circle_rounded;
      color = AppColors.success;
    } else if (step.isCompleted && step.isFailed) {
      icon = Icons.error_rounded;
      color = const Color(0xFFEF4444);
    } else if (step.isInProgress) {
      icon = Icons.sync_rounded;
      color = AppColors.primary;
    } else {
      icon = Icons.radio_button_unchecked_rounded;
      color = isDark ? AppColors.textMutedDark : AppColors.textMuted;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          step.isInProgress
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.name,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: step.isInProgress ? FontWeight.w700 : FontWeight.w500,
                color: step.isInProgress
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pending Step Shimmer ─────────────────────────────────────────────────────

class _PendingStepShimmer extends StatelessWidget {
  final bool isDark;
  const _PendingStepShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 120.0 + i * 30,
                height: 12,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Build Complete ───────────────────────────────────────────────────────────

class _BuildComplete extends StatelessWidget {
  final String? apkName;
  final VoidCallback onDownload;
  final VoidCallback onReset;
  final bool isDark;
  final bool isDownloading;
  final double downloadProgress;
  final String? localApkPath;

  const _BuildComplete({
    required this.apkName,
    required this.onDownload,
    required this.onReset,
    required this.isDark,
    required this.isDownloading,
    required this.downloadProgress,
    required this.localApkPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Success icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'APK Built Successfully!',
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            apkName ?? 'pcampus-login.apk',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Download / Share action
          if (isDownloading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading...',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text(
                        '${(downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: downloadProgress > 0 ? downloadProgress : null,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: onDownload,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: localApkPath != null
                        ? [AppColors.primary, AppColors.secondary]
                        : [AppColors.success, const Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.glow(
                    localApkPath != null ? AppColors.primary : AppColors.success,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      localApkPath != null ? Icons.share_rounded : Icons.download_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      localApkPath != null ? 'Share / Install APK' : 'Download APK',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Build another
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Build Another'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

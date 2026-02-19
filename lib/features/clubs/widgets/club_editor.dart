import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/club.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ClubEditor extends StatefulWidget {
  final Club? club;
  final ClubProfile? profile;

  const ClubEditor({super.key, this.club, this.profile});

  @override
  State<ClubEditor> createState() => _ClubEditorState();
}

class _ClubEditorState extends State<ClubEditor> {
  // Flow Control
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  // Basic Club Info
  late TextEditingController _nameController;
  late TextEditingController _descriptionController; // Tagline on web
  late TextEditingController _logoUrlController;
  late TextEditingController _emailController;

  // Profile Info
  late TextEditingController _aboutController;
  late TextEditingController _missionController;
  late TextEditingController _visionController;
  late TextEditingController _achievementsController;
  late TextEditingController _benefitsController;
  late TextEditingController _estYearController;

  // Contact & Social
  late TextEditingController _contactPhoneController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;
  late TextEditingController _linkedinController;
  late TextEditingController _twitterController;
  late TextEditingController _discordController;
  late TextEditingController _githubController;

  bool _isSaving = false;
  bool _isCreateMode = false;
  String? _pickedLogoPath;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isCreateMode = widget.club == null;

    _nameController = TextEditingController(text: widget.club?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.club?.description ?? '',
    );
    _logoUrlController = TextEditingController(
      text: widget.club?.logoUrl ?? '',
    );
    _emailController = TextEditingController(text: widget.club?.email ?? '');

    _aboutController = TextEditingController(
      text: widget.profile?.aboutClub ?? '',
    );
    _missionController = TextEditingController(
      text: widget.profile?.mission ?? '',
    );
    _visionController = TextEditingController(
      text: widget.profile?.vision ?? '',
    );
    _achievementsController = TextEditingController(
      text: widget.profile?.achievements ?? '',
    );
    _benefitsController = TextEditingController(
      text: widget.profile?.benefits ?? '',
    );
    _estYearController = TextEditingController(
      text: widget.profile?.establishedYear?.toString() ?? '',
    );

    _contactPhoneController = TextEditingController(
      text: widget.profile?.contactPhone ?? '',
    );
    _websiteController = TextEditingController(
      text: widget.profile?.websiteUrl ?? '',
    );
    _addressController = TextEditingController(
      text: widget.profile?.address ?? '',
    );

    // Social Links
    final socials = widget.profile?.socialLinks ?? {};
    _facebookController = TextEditingController(
      text: socials['facebook'] ?? '',
    );
    _instagramController = TextEditingController(
      text: socials['instagram'] ?? '',
    );
    _linkedinController = TextEditingController(
      text: socials['linkedin'] ?? '',
    );
    _twitterController = TextEditingController(text: socials['twitter'] ?? '');
    _discordController = TextEditingController(text: socials['discord'] ?? '');
    _githubController = TextEditingController(text: socials['github'] ?? '');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _logoUrlController.dispose();
    _emailController.dispose();
    _aboutController.dispose();
    _missionController.dispose();
    _visionController.dispose();
    _achievementsController.dispose();
    _benefitsController.dispose();
    _estYearController.dispose();
    _contactPhoneController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _twitterController.dispose();
    _discordController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_currentStep == 0) {
        if (!_formKey.currentState!.validate()) return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _save();
    }
  }

  Future<void> _pickLogo() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _pickedLogoPath = image.path);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    haptics.mediumImpact();

    try {
      int? clubId;

      // Prepare social links
      final socialLinks = {
        if (_facebookController.text.isNotEmpty)
          'facebook': _facebookController.text.trim(),
        if (_instagramController.text.isNotEmpty)
          'instagram': _instagramController.text.trim(),
        if (_linkedinController.text.isNotEmpty)
          'linkedin': _linkedinController.text.trim(),
        if (_twitterController.text.isNotEmpty)
          'twitter': _twitterController.text.trim(),
        if (_discordController.text.isNotEmpty)
          'discord': _discordController.text.trim(),
        if (_githubController.text.isNotEmpty)
          'github': _githubController.text.trim(),
      };

      // Prepare profile data
      final profileData = {
        'aboutClub': _aboutController.text.trim(),
        'mission': _missionController.text.trim(),
        'vision': _visionController.text.trim(),
        'achievements': _achievementsController.text.trim(),
        'benefits': _benefitsController.text.trim(),
        'establishedYear': int.tryParse(_estYearController.text),
        'contactPhone': _contactPhoneController.text.trim(),
        'websiteUrl': _websiteController.text.trim(),
        'address': _addressController.text.trim(),
        'socialLinks': socialLinks,
      };

      if (_isCreateMode) {
        final data = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'logoUrl': _logoUrlController.text.trim(),
          'email': _emailController.text.trim(),
        };
        final result = await _api.createClub(data);
        if (result['success'] == true || result['data']?['success'] == true) {
          clubId = result['club']?['id'] ?? result['data']?['club']?['id'];

          if (clubId != null) {
            // Also create the profile with the collected data
            final profileResult = await _api.createClubProfile({
              'clubId': clubId,
              ...profileData,
            });
            if (profileResult['success'] != true) {
              debugPrint(
                'Profile creation failed: ${profileResult['message']}',
              );
            }
          }
        } else {
          if (mounted) _handleResult(result, ''); // Show error
          return;
        }
      } else {
        clubId = widget.club!.id;
        final result = await _api.updateClubProfile(clubId, profileData);
        if (!(result['success'] == true)) {
          if (mounted) _handleResult(result, '');
          return;
        }
      }

      // Handle Logo Upload if picked
      if (clubId != null && _pickedLogoPath != null) {
        final uploadResult = await _api.uploadClubLogo(
          clubId,
          _pickedLogoPath!,
        );
        if (!uploadResult.success) {
          debugPrint('Logo upload failed: ${uploadResult.error}');
          // We don't block the whole process if only logo fails,
          // but maybe notify?
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isCreateMode
                  ? 'Club established successfully'
                  : 'Profile updated successfully',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleResult(Map<String, dynamic> result, String successMessage) {
    final success =
        result['success'] == true || result['data']?['success'] == true;
    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Action failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header & Stepper
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isCreateMode ? 'New Heritage' : 'Update Heritage',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepper(),
              ],
            ),
          ),

          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [_buildStep1(), _buildStep2(), _buildStep3()],
              ),
            ),
          ),

          Padding(padding: const EdgeInsets.all(24), child: _buildActions()),
          SizedBox(
            height: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 100,
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: List.generate(_totalSteps, (index) {
        final isActive = index <= _currentStep;
        final isCurrent = index == _currentStep;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (index < _totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: index < _currentStep
                        ? AppColors.primary
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('The Basics', 'Establish your club identity'),
          const SizedBox(height: 24),
          _buildTextField(
            _nameController,
            'Club Name',
            Icons.business_rounded,
            required: true,
            hint: 'e.g. Robotics Club, Art Society',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _emailController,
            'Contact Email',
            Icons.email_rounded,
            required: true,
            hint: 'club@pcampus.edu.np',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _descriptionController,
            'Tagline / Punchline',
            Icons.bolt_rounded,
            maxLines: 2,
            hint: 'One-line summary of your club...',
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('Vision & Mission', 'Tell us what you stand for'),
          const SizedBox(height: 24),
          _buildTextField(
            _aboutController,
            'About Club',
            Icons.info_rounded,
            maxLines: 3,
            hint: 'Brief introduction...',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _missionController,
                  'Mission',
                  Icons.explore_rounded,
                  maxLines: 3,
                  hint: 'Core purpose',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  _visionController,
                  'Vision',
                  Icons.visibility_rounded,
                  maxLines: 3,
                  hint: 'Future goal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _benefitsController,
            'Member Benefits',
            Icons.card_membership_rounded,
            maxLines: 2,
            hint: 'Why should students join?',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _achievementsController,
            'Achievements',
            Icons.emoji_events_rounded,
            maxLines: 2,
            hint: 'Notable milestones...',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _estYearController,
            'Est. Year',
            Icons.calendar_today_rounded,
            keyboardType: TextInputType.number,
            hint: 'e.g. 2024',
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('Social Presence', 'Connect with the campus'),
          const SizedBox(height: 24),
          const Text(
            'CLUB LOGO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  image: _pickedLogoPath != null
                      ? DecorationImage(
                          image: FileImage(File(_pickedLogoPath!)),
                          fit: BoxFit.cover,
                        )
                      : (_logoUrlController.text.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_logoUrlController.text),
                                fit: BoxFit.cover,
                              )
                            : null),
                ),
                child:
                    _pickedLogoPath == null && _logoUrlController.text.isEmpty
                    ? const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: Colors.grey,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('BROWSE LOGO'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      _logoUrlController,
                      'or paste Logo URL',
                      Icons.link_rounded,
                      hint: 'https://...',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _websiteController,
                  'Website',
                  Icons.language_rounded,
                  hint: 'https://...',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  _contactPhoneController,
                  'Phone',
                  Icons.phone_rounded,
                  hint: '+977 98...',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'SOCIAL LINKS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          _buildSocialGrid(),
        ],
      ),
    );
  }

  Widget _buildSocialGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSocialField(
                _facebookController,
                'Facebook',
                'facebook.com/',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSocialField(
                _instagramController,
                'Instagram',
                'instagram.com/',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSocialField(
                _linkedinController,
                'LinkedIn',
                'linkedin.com/in/',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSocialField(_twitterController, 'Twitter', 'x.com/'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSocialField(
                _discordController,
                'Discord',
                'discord.gg/',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSocialField(
                _githubController,
                'GitHub',
                'github.com/',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
          color: Colors.grey.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: _isSaving ? null : _prevStep,
              child: const Text(
                'BACK',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _currentStep < _totalSteps - 1
                        ? 'CONTINUE'
                        : (_isCreateMode ? 'ESTABLISH' : 'UPDATE'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

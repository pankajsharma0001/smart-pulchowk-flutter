import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EventEditor extends StatefulWidget {
  final ClubEvent? event;
  final int? clubId;

  const EventEditor({super.key, this.event, this.clubId});

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _categoryController;

  // Step 2: Logistics
  late TextEditingController _maxParticipantsController;
  late TextEditingController _externalLinkController;
  DateTime? _registrationDeadlineDate;
  TimeOfDay? _registrationDeadlineTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  // Step 3: Deep Dive
  late TextEditingController _fullDescriptionController;
  late TextEditingController _objectivesController;
  late TextEditingController _targetAudienceController;
  late TextEditingController _prerequisitesController;
  late TextEditingController _rulesController;
  late TextEditingController _judgingCriteriaController;

  // Media
  String? _pickedBannerPath;
  String? _currentBannerUrl;
  final ImagePicker _picker = ImagePicker();

  // Multi-step management
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.event?.description ?? '',
    );
    _locationController = TextEditingController(
      text: widget.event?.venue ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.event?.eventType ?? 'Other',
    );
    _maxParticipantsController = TextEditingController(
      text: widget.event?.maxParticipants?.toString() ?? '',
    );
    _externalLinkController = TextEditingController(
      text: widget.event?.externalRegistrationLink ?? '',
    );

    _fullDescriptionController = TextEditingController();
    _objectivesController = TextEditingController();
    _targetAudienceController = TextEditingController();
    _prerequisitesController = TextEditingController();
    _rulesController = TextEditingController();
    _judgingCriteriaController = TextEditingController();

    _currentBannerUrl = widget.event?.bannerUrl;

    if (widget.event?.eventStartTime != null) {
      _selectedDate = widget.event!.eventStartTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.eventStartTime);
    }

    if (widget.event?.eventEndTime != null) {
      _endDate = widget.event!.eventEndTime;
      _endTime = TimeOfDay.fromDateTime(widget.event!.eventEndTime);
    }

    if (widget.event?.registrationDeadline != null) {
      _registrationDeadlineDate = widget.event!.registrationDeadline;
      _registrationDeadlineTime = TimeOfDay.fromDateTime(
        widget.event!.registrationDeadline!,
      );
    }

    if (widget.event != null) {
      _loadExtraDetails();
    }
  }

  Future<void> _loadExtraDetails() async {
    final result = await _api.getExtraEventDetails(widget.event!.id);
    if (result['success'] == true && result['details'] != null) {
      final d = result['details'];
      setState(() {
        _fullDescriptionController.text = d['fullDescription'] ?? '';
        _objectivesController.text = d['objectives'] ?? '';
        _targetAudienceController.text = d['targetAudience'] ?? '';
        _prerequisitesController.text = d['prerequisites'] ?? '';
        _rulesController.text = d['rules'] ?? '';
        _judgingCriteriaController.text = d['judgingCriteria'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _categoryController.dispose();
    _maxParticipantsController.dispose();
    _externalLinkController.dispose();
    _fullDescriptionController.dispose();
    _objectivesController.dispose();
    _targetAudienceController.dispose();
    _prerequisitesController.dispose();
    _rulesController.dispose();
    _judgingCriteriaController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    haptics.selectionClick();
    final initialDate = isStart
        ? (_selectedDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    haptics.selectionClick();
    final initialTime = isStart
        ? (_selectedTime ?? TimeOfDay.now())
        : (_endTime ?? TimeOfDay.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickDeadlineDate() async {
    haptics.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _registrationDeadlineDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _registrationDeadlineDate = picked);
  }

  Future<void> _pickDeadlineTime() async {
    haptics.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _registrationDeadlineTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _registrationDeadlineTime = picked);
  }

  Future<void> _pickBanner() async {
    haptics.selectionClick();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _pickedBannerPath = image.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date and time')),
      );
      return;
    }

    setState(() => _isSaving = true);
    haptics.mediumImpact();

    try {
      final startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      DateTime? endDateTime;
      if (_endDate != null && _endTime != null) {
        endDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      } else {
        endDateTime = startDateTime.add(const Duration(hours: 2));
      }

      DateTime? deadlineDateTime;
      if (_registrationDeadlineDate != null &&
          _registrationDeadlineTime != null) {
        deadlineDateTime = DateTime(
          _registrationDeadlineDate!.year,
          _registrationDeadlineDate!.month,
          _registrationDeadlineDate!.day,
          _registrationDeadlineTime!.hour,
          _registrationDeadlineTime!.minute,
        );
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'venue': _locationController.text.trim(),
        'eventStartTime': startDateTime.toIso8601String(),
        'eventEndTime': endDateTime.toIso8601String(),
        'registrationDeadline': deadlineDateTime?.toIso8601String(),
        'maxParticipants': int.tryParse(_maxParticipantsController.text),
        'externalRegistrationLink': _externalLinkController.text.trim(),
        'eventType': _categoryController.text.trim(),
        'clubId': widget.clubId ?? widget.event?.clubId,
      }..removeWhere((k, v) => v == null);

      final result = widget.event == null
          ? await _api.createEvent(data)
          : await _api.updateEvent(widget.event!.id, data);

      final success =
          result['success'] == true || result['data']?['success'] == true;

      if (success) {
        final eventId =
            result['event']?['id'] ??
            result['data']?['event']?['id'] ??
            widget.event?.id;

        if (eventId != null) {
          // Sequential upload: Banner
          if (_pickedBannerPath != null) {
            await _api.uploadEventBanner(eventId, _pickedBannerPath);
          }

          // Sequential upload: Extra Details
          final extraData = {
            'fullDescription': _fullDescriptionController.text.trim(),
            'objectives': _objectivesController.text.trim(),
            'targetAudience': _targetAudienceController.text.trim(),
            'prerequisites': _prerequisitesController.text.trim(),
            'rules': _rulesController.text.trim(),
            'judgingCriteria': _judgingCriteriaController.text.trim(),
          }..removeWhere((k, v) => v.toString().isEmpty);

          if (extraData.isNotEmpty) {
            if (widget.event == null) {
              await _api.createExtraEventDetails(eventId, extraData);
            } else {
              await _api.updateExtraEventDetails(eventId, extraData);
            }
          }
        }

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.event == null ? 'Event created!' : 'Event updated!',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Action failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Header & Progress
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.event == null ? 'Create Event' : 'Edit Event',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 6,
                      width:
                          MediaQuery.of(context).size.width *
                          ((_currentStep + 1) / _totalSteps),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Steps
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [_buildStep1(), _buildStep2(), _buildStep3()],
              ),
            ),
          ),

          // Bottom Actions
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              (MediaQuery.viewInsetsOf(context).bottom > 0
                  ? MediaQuery.viewInsetsOf(context).bottom + 24
                  : MediaQuery.viewPaddingOf(context).bottom + 100),
            ),
            child: _buildActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildSectionHeader(
            'Basic Identity',
            'Set the core details for your event',
          ),
          const SizedBox(height: 20),
          _buildTextField(
            _titleController,
            'Event Title',
            Icons.title_rounded,
            required: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _descriptionController,
            'Short Catchy Description',
            Icons.description_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _locationController,
            'Venue/Location',
            Icons.location_on_rounded,
            required: true,
          ),
          const SizedBox(height: 16),
          _buildCategoryDropdown(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Event Banner',
            'Professional header for your event page',
          ),
          const SizedBox(height: 16),
          _buildBannerPicker(),
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
          const SizedBox(height: 12),
          _buildSectionHeader('Timing', 'When is the event happening?'),
          const SizedBox(height: 20),
          _buildDateTimePicker(
            'Start Time',
            _selectedDate,
            _selectedTime,
            (isDate) => isDate ? _pickDate(true) : _pickTime(true),
          ),
          const SizedBox(height: 12),
          _buildDateTimePicker(
            'End Time',
            _endDate,
            _endTime,
            (isDate) => isDate ? _pickDate(false) : _pickTime(false),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Registration',
            'Participation and sign-up settings',
          ),
          const SizedBox(height: 20),
          _buildDateTimePicker(
            'Registration Deadline',
            _registrationDeadlineDate,
            _registrationDeadlineTime,
            (isDate) => isDate ? _pickDeadlineDate() : _pickDeadlineTime(),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _maxParticipantsController,
            'Max Participants (Optional)',
            Icons.group_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _externalLinkController,
            'External Registration Link',
            Icons.link_rounded,
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
          const SizedBox(height: 12),
          _buildSectionHeader(
            'Extended Details',
            'Provide comprehensive info for attendees',
          ),
          const SizedBox(height: 20),
          _buildTextField(
            _fullDescriptionController,
            'Full In-depth Description',
            Icons.notes_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _objectivesController,
            'Goals & Objectives',
            Icons.auto_awesome_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _targetAudienceController,
            'Target Audience',
            Icons.person_search_rounded,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _prerequisitesController,
            'Prerequisites',
            Icons.rule_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _rulesController,
            'Rules & Regulations',
            Icons.gavel_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _judgingCriteriaController,
            'Judging Criteria',
            Icons.grading_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.h5.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBannerPicker() {
    final hasImage = _pickedBannerPath != null || _currentBannerUrl != null;
    return GestureDetector(
      onTap: _pickBanner,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    _pickedBannerPath != null
                        ? Image.file(
                            File(_pickedBannerPath!),
                            fit: BoxFit.cover,
                          )
                        : Image.network(_currentBannerUrl!, fit: BoxFit.cover),
                    Container(color: Colors.black.withValues(alpha: 0.3)),
                    const Center(
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppColors.primary.withValues(alpha: 0.5),
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload Event Banner',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker(
    String label,
    DateTime? date,
    TimeOfDay? time,
    Function(bool isDate) onPick,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPickerButton(
                date == null
                    ? 'Select Date'
                    : DateFormat('MMM d, yyyy').format(date),
                Icons.calendar_today_rounded,
                () => onPick(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPickerButton(
                time == null ? 'Select Time' : time.format(context),
                Icons.access_time_rounded,
                () => onPick(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPickerButton(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.02),
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
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _totalSteps - 1;

    return Row(
      children: [
        if (!isFirstStep) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSaving
                ? null
                : () {
                    if (isLastStep) {
                      _save();
                    } else {
                      // Optional: validate current step
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
            style:
                ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ).copyWith(
                  elevation: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.pressed) ? 0 : 4,
                  ),
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
                    isLastStep
                        ? (widget.event == null
                              ? 'Launch Event'
                              : 'Save Changes')
                        : 'Continue',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = [
      'Workshop',
      'Seminar',
      'Competition',
      'Hackathon',
      'Social',
      'Meeting',
      'Exhibition',
      'Other',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Event Category',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: categories.contains(_categoryController.text)
              ? _categoryController.text
              : 'Other',
          onChanged: (val) => setState(() => _categoryController.text = val!),
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.category_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.02),
          ),
        ),
      ],
    );
  }
}

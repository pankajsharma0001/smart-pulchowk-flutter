import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/lost_found.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';

class ReportLostFoundPage extends StatefulWidget {
  const ReportLostFoundPage({super.key});

  @override
  State<ReportLostFoundPage> createState() => _ReportLostFoundPageState();
}

class _ReportLostFoundPageState extends State<ReportLostFoundPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactNoteController = TextEditingController();
  final _rewardController = TextEditingController();

  LostFoundItemType _itemType = LostFoundItemType.lost;
  LostFoundCategory _category = LostFoundCategory.other;
  DateTime _selectedDate = DateTime.now();
  final List<XFile> _images = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contactNoteController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _images.add(image);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_images.isEmpty && _itemType == LostFoundItemType.found) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'itemType': _itemType.name,
        'category': _category.name,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'lostFoundDate': _selectedDate.toIso8601String(),
        'locationText': _locationController.text.trim(),
        'contactNote': _contactNoteController.text.trim(),
        'rewardText': _rewardController.text.isNotEmpty
            ? _rewardController.text.trim()
            : null,
      };

      final result = await _apiService.createLostFoundItem(payload);

      if (mounted) {
        if (result.success && result.data != null) {
          // Upload images
          for (var image in _images) {
            await _apiService.uploadLostFoundImage(
              result.data!.id,
              File(image.path),
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report submitted successfully!')),
            );
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Failed to submit report')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Item')),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTypeSelector(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionHeader('Item Details'),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _titleController,
                      decoration: AppDecorations.input(
                        hint: 'Title (e.g., Brown Leather Wallet)',
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildCategoryField(),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: AppDecorations.input(
                        hint: 'Description (Describe the item in detail...)',
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Please enter a description' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDateField(),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _locationController,
                      decoration: AppDecorations.input(
                        hint: 'Location (Where was it lost/found?)',
                        prefixIcon: Icons.location_on_rounded,
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Please enter a location' : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _buildSectionHeader('Contact & Extras'),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _contactNoteController,
                      decoration: AppDecorations.input(
                        hint:
                            'Contact Note (e.g., "DM me here or call at 98xxxx")',
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Please add a contact note' : null,
                    ),
                    if (_itemType == LostFoundItemType.lost) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _rewardController,
                        decoration: AppDecorations.input(
                          hint:
                              'Reward (Optional) (e.g., Coffee, Cash, or None)',
                          prefixIcon: Icons.card_giftcard_rounded,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _buildSectionHeader('Images'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildImagePicker(),
                    const SizedBox(height: AppSpacing.xxl),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: const Text('Submit Report'),
                    ),
                    SizedBox(
                      height:
                          MediaQuery.of(context).padding.bottom + AppSpacing.xl,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.labelLarge.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<LostFoundItemType>(
      segments: const [
        ButtonSegment(
          value: LostFoundItemType.lost,
          label: Text('Lost'),
          icon: Icon(Icons.search_rounded),
        ),
        ButtonSegment(
          value: LostFoundItemType.found,
          label: Text('Found'),
          icon: Icon(Icons.check_circle_rounded),
        ),
      ],
      selected: {_itemType},
      onSelectionChanged: (Set<LostFoundItemType> selected) {
        setState(() => _itemType = selected.first);
      },
    );
  }

  Widget _buildCategoryField() {
    return DropdownButtonFormField<LostFoundCategory>(
      initialValue: _category,
      decoration: AppDecorations.input(hint: 'Select Category'),
      items: LostFoundCategory.values.map((cat) {
        return DropdownMenuItem(
          value: cat,
          child: Text(cat.name[0].toUpperCase() + cat.name.substring(1)),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) setState(() => _category = v);
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
        );
        if (date != null) setState(() => _selectedDate = date);
      },
      child: IgnorePointer(
        child: TextFormField(
          decoration: AppDecorations.input(
            hint: DateFormat('MMM dd, yyyy').format(_selectedDate),
            prefixIcon: Icons.calendar_today_rounded,
          ),
          readOnly: true,
          controller: TextEditingController(
            text: DateFormat('MMM dd, yyyy').format(_selectedDate),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_images.isNotEmpty)
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length + 1,
              itemBuilder: (context, index) {
                if (index == _images.length) {
                  return _addMoreImagesButton();
                }
                return _imageThumbnail(index);
              },
            ),
          )
        else
          InkWell(
            onTap: () => _pickImage(ImageSource.gallery),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_rounded,
                    size: 32,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Add Images',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _imageThumbnail(int index) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image.file(File(_images[index].path), fit: BoxFit.cover),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () => setState(() => _images.removeAt(index)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addMoreImagesButton() {
    return InkWell(
      onTap: () => _pickImage(ImageSource.gallery),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: const Icon(Icons.add_rounded, color: AppColors.primary),
      ),
    );
  }
}

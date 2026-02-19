import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:smart_pulchowk/core/widgets/interactive_wrapper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SELL BOOK PAGE
// ─────────────────────────────────────────────────────────────────────────────

class SellBookPage extends StatefulWidget {
  final BookListing? existingListing; // For editing
  const SellBookPage({super.key, this.existingListing});

  @override
  State<SellBookPage> createState() => _SellBookPageState();
}

class _SellBookPageState extends State<SellBookPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _priceController = TextEditingController();
  final _isbnController = TextEditingController();
  final _editionController = TextEditingController();
  final _publisherController = TextEditingController();
  final _yearController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _contactController = TextEditingController();

  BookCondition _condition = BookCondition.good;
  int? _selectedCategoryId;
  List<BookCategory> _categories = [];
  List<BookImage> _existingImages = []; // Images already on the server
  final List<String> _imagePaths = []; // New local images to upload
  bool _isSubmitting = false;

  String _contactMethod = 'WhatsApp';
  final List<String> _contactMethods = [
    'WhatsApp',
    'Messenger',
    'Phone',
    'Telegram',
    'Email',
    'Other',
  ];

  bool get _isEditing => widget.existingListing != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_isEditing) _populateFields();
  }

  void _populateFields() {
    final book = widget.existingListing!;
    _titleController.text = book.title;
    _authorController.text = book.author;
    _priceController.text = book.price;
    _isbnController.text = book.isbn ?? '';
    _editionController.text = book.edition ?? '';
    _publisherController.text = book.publisher ?? '';
    _yearController.text = book.publicationYear != null
        ? '${book.publicationYear}'
        : '';
    _descriptionController.text = book.description ?? '';
    _courseCodeController.text = book.courseCode ?? '';

    // Handle contact info parsing
    final contactInfo = book.buyerContactInfo ?? '';
    if (contactInfo.contains(': ')) {
      final parts = contactInfo.split(': ');
      final method = parts[0].trim();
      final value = parts.sublist(1).join(': ').trim();
      if (_contactMethods.contains(method)) {
        _contactMethod = method;
        _contactController.text = value;
      } else {
        _contactMethod = 'Other';
        _contactController.text = contactInfo;
      }
    } else {
      _contactController.text = contactInfo;
      _contactMethod = 'Phone'; // Default if none found
    }
    _condition = book.condition;
    _selectedCategoryId = book.category?.id;
    _existingImages = List.from(book.images ?? []);
  }

  Future<void> _loadCategories() async {
    final cats = await _api.getBookCategories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty && mounted) {
      setState(() {
        _imagePaths.addAll(images.map((e) => e.path));
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill in all required fields marked with *');
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      Map<String, dynamic> result;

      if (_isEditing) {
        result = await _api.updateBookListing(widget.existingListing!.id, {
          'title': _titleController.text.trim(),
          'author': _authorController.text.trim(),
          'condition': _condition.backendValue,
          'price': _priceController.text.trim(),
          if (_isbnController.text.isNotEmpty)
            'isbn': _isbnController.text.trim(),
          if (_editionController.text.isNotEmpty)
            'edition': _editionController.text.trim(),
          if (_publisherController.text.isNotEmpty)
            'publisher': _publisherController.text.trim(),
          if (_yearController.text.isNotEmpty)
            'publicationYear': int.tryParse(_yearController.text),
          if (_descriptionController.text.isNotEmpty)
            'description': _descriptionController.text.trim(),
          if (_courseCodeController.text.isNotEmpty)
            'courseCode': _courseCodeController.text.trim(),
          if (_contactController.text.isNotEmpty)
            'buyerContactInfo':
                '$_contactMethod: ${_contactController.text.trim()}',
          if (_selectedCategoryId != null) 'categoryId': _selectedCategoryId,
        });
      } else {
        result = await _api.createBookListing(
          title: _titleController.text.trim(),
          author: _authorController.text.trim(),
          condition: _condition.backendValue,
          price: _priceController.text.trim(),
          isbn: _isbnController.text.isNotEmpty
              ? _isbnController.text.trim()
              : null,
          edition: _editionController.text.isNotEmpty
              ? _editionController.text.trim()
              : null,
          publisher: _publisherController.text.isNotEmpty
              ? _publisherController.text.trim()
              : null,
          publicationYear: _yearController.text.isNotEmpty
              ? int.tryParse(_yearController.text)
              : null,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          courseCode: _courseCodeController.text.isNotEmpty
              ? _courseCodeController.text.trim()
              : null,
          buyerContactInfo: _contactController.text.isNotEmpty
              ? '$_contactMethod: ${_contactController.text.trim()}'
              : null,
          categoryId: _selectedCategoryId,
        );
      }

      if (result['success'] == true) {
        // Upload images if any
        final listing = result['data'] as BookListing?;
        if (listing != null && _imagePaths.isNotEmpty) {
          for (final path in _imagePaths) {
            await _api.uploadBookImage(listing.id, path);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing ? 'Listing updated!' : 'Book listed for sale!',
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        _showError(result['message'] ?? 'Something went wrong');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _priceController.dispose();
    _isbnController.dispose();
    _editionController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _courseCodeController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Listing' : 'Sell a Book',
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── Image Section ───────────────────────────────────────────
            _buildImagePicker(isDark, cs),
            const SizedBox(height: 32),

            // ── Required Details Section ──────────────────────────────
            _sectionHeader(
              'Basic Information',
              Icons.info_outline_rounded,
              isDark,
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              isDark,
              child: Column(
                children: [
                  _buildField(
                    controller: _titleController,
                    label: 'Book Title',
                    icon: Icons.title_rounded,
                    validator: _required,
                    isDark: isDark,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _authorController,
                    label: 'Author',
                    icon: Icons.person_outline_rounded,
                    validator: _required,
                    isDark: isDark,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _priceController,
                    label: 'Price (Rs.)',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    validator: _required,
                    isDark: isDark,
                    isRequired: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Condition Section
            _sectionHeader(
              'Book Condition',
              Icons.star_outline_rounded,
              isDark,
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              isDark,
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                children: BookCondition.values.map((c) {
                  final isSelected = _condition == c;
                  return ChoiceChip(
                    label: Text(c.displayName),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _condition = c),
                    selectedColor: cs.primaryContainer,
                    labelStyle: AppTextStyles.labelMedium.copyWith(
                      color: isSelected
                          ? cs.primary
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? cs.primary
                          : isDark
                          ? Colors.white10
                          : Colors.black12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            // Optional Details Section
            _sectionHeader(
              'Additional Details',
              Icons.add_circle_outline_rounded,
              isDark,
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              isDark,
              child: Column(
                children: [
                  if (_categories.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      validator: (v) => v == null ? 'Selection required' : null,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Category',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const Text(
                              ' *',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceContainerLight,
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildField(
                    controller: _isbnController,
                    label: 'ISBN',
                    icon: Icons.qr_code_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _editionController,
                          label: 'Edition',
                          icon: Icons.bookmarks_outlined,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _yearController,
                          label: 'Year',
                          icon: Icons.calendar_today_outlined,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _publisherController,
                    label: 'Publisher',
                    icon: Icons.business_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _courseCodeController,
                    label: 'Course Code',
                    icon: Icons.school_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _descriptionController,
                    label: 'Description',
                    icon: Icons.description_outlined,
                    maxLines: 4,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Contact Info Section
            _sectionHeader(
              'Contact Preference',
              Icons.contact_mail_outlined,
              isDark,
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              isDark,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _contactMethod,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Contact Method',
                      prefixIcon: const Icon(
                        Icons.contact_phone_outlined,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceContainerLight,
                    ),
                    items: _contactMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _contactMethod = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _contactController,
                    label: _getContactLabel(),
                    icon: _getContactIcon(),
                    hint: _getContactHint(),
                    keyboardType: _getContactKeyboard(),
                    isDark: isDark,
                    isRequired: true,
                    validator: _required,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // ── Submit Button ──────────────────────────────────────────
            InteractiveWrapper(
              onTap: _isSubmitting ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: _isSubmitting ? null : AppColors.primaryGradient,
                  color: _isSubmitting ? Colors.grey : null,
                  borderRadius: AppRadius.lgAll,
                  boxShadow: _isSubmitting
                      ? null
                      : AppShadows.glow(AppColors.primary, intensity: 0.3),
                ),
                alignment: Alignment.center,
                child: _isSubmitting
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isEditing
                                ? Icons.check_circle_rounded
                                : Icons.rocket_launch_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isEditing
                                ? 'UPDATE LISTING'
                                : 'LIST BOOK FOR SALE',
                            style: AppTextStyles.button.copyWith(
                              color: Colors.white,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.primaryLight : AppColors.primary,
        ),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: AppTextStyles.overline.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.xlAll,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _buildImagePicker(bool isDark, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Book Photos', Icons.photo_library_outlined, isDark),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              // Add button
              InteractiveWrapper(
                onTap: _pickImages,
                borderRadius: AppRadius.lgAll,
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceContainerLight,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.2),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_rounded,
                          color: cs.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Existing images from server
              ..._existingImages.asMap().entries.map((entry) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.lgAll,
                          boxShadow: AppShadows.xs,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SmartImage(
                          imageUrl: entry.value.imageUrl,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 120,
                          errorWidget: const Icon(Icons.broken_image_rounded),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () async {
                            final result = await _api.deleteBookImage(
                              widget.existingListing!.id,
                              entry.value.id,
                            );
                            if (result['success'] == true && mounted) {
                              setState(
                                () => _existingImages.removeAt(entry.key),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Selected new images from local storage
              ..._imagePaths.asMap().entries.map((entry) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.lgAll,
                          boxShadow: AppShadows.xs,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          image: DecorationImage(
                            image: FileImage(File(entry.value)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _imagePaths.removeAt(entry.key));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    required bool isDark,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium.copyWith(
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceContainerLight,
      ),
    );
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  String _getContactLabel() {
    switch (_contactMethod) {
      case 'WhatsApp':
        return 'WhatsApp Number';
      case 'Messenger':
        return 'Messenger Profile Link/ID';
      case 'Phone':
        return 'Phone Number';
      case 'Telegram':
        return 'Telegram Username';
      case 'Email':
        return 'Email Address';
      default:
        return 'Contact Detail';
    }
  }

  String _getContactHint() {
    switch (_contactMethod) {
      case 'WhatsApp':
        return '+977 98XXXXXXXX';
      case 'Messenger':
        return 'e.g. m.me/username or Profile Name';
      case 'Phone':
        return '98XXXXXXXX';
      case 'Telegram':
        return '@username';
      case 'Email':
        return 'example@email.com';
      default:
        return 'Enter details';
    }
  }

  IconData _getContactIcon() {
    switch (_contactMethod) {
      case 'WhatsApp':
        return Icons.chat_rounded;
      case 'Messenger':
        return Icons.facebook_rounded;
      case 'Phone':
        return Icons.call_rounded;
      case 'Telegram':
        return Icons.telegram_rounded;
      case 'Email':
        return Icons.email_rounded;
      default:
        return Icons.contact_mail_rounded;
    }
  }

  TextInputType _getContactKeyboard() {
    switch (_contactMethod) {
      case 'WhatsApp':
      case 'Phone':
        return TextInputType.phone;
      case 'Email':
        return TextInputType.emailAddress;
      default:
        return TextInputType.text;
    }
  }
}

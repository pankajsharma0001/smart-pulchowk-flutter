import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:smart_pulchowk/core/models/notice.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';

class NoticeEditor extends StatefulWidget {
  final Notice? notice;

  const NoticeEditor({super.key, this.notice});

  @override
  State<NoticeEditor> createState() => _NoticeEditorState();
}

class _NoticeEditorState extends State<NoticeEditor> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late TextEditingController _titleController;
  late TextEditingController _attachmentUrlController;
  late TextEditingController _sourceUrlController;

  String _category = 'general';
  String? _level;
  bool _isSaving = false;
  bool _isUploading = false;
  File? _pickedFile;

  final List<String> _categories = [
    'results',
    'application_forms',
    'exam_centers',
    'general',
  ];
  final List<String> _levels = ['be', 'msc', 'Entrance'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice?.title ?? '');
    _attachmentUrlController = TextEditingController(
      text: widget.notice?.attachmentUrl ?? '',
    );
    _sourceUrlController = TextEditingController(
      text: widget.notice?.sourceUrl ?? '',
    );
    _category = widget.notice?.category ?? 'general';
    _level = widget.notice?.level;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _attachmentUrlController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    haptics.selectionClick();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _attachmentUrlController.text =
            'File picked: ${result.files.single.name}';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    haptics.mediumImpact();

    try {
      String? attachmentUrl =
          _attachmentUrlController.text.startsWith('File picked:')
          ? null
          : _attachmentUrlController.text.trim();

      if (_pickedFile != null) {
        setState(() => _isUploading = true);
        final uploadResult = await _api.uploadNoticeAttachment(
          _pickedFile!.path,
        );
        setState(() => _isUploading = false);

        if (uploadResult.success && uploadResult.data != null) {
          attachmentUrl = uploadResult.data;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(uploadResult.error ?? 'Upload failed')),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      final data = {
        'title': _titleController.text.trim(),
        'category': _category,
        'level': _level,
        'attachmentUrl': attachmentUrl,
        'sourceUrl': _sourceUrlController.text.trim().isEmpty
            ? null
            : _sourceUrlController.text.trim(),
      };

      final result = widget.notice == null
          ? await _api.createNotice(data)
          : await _api.updateNotice(widget.notice!.id, data);

      if (mounted) {
        if (result.success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.notice == null ? 'Notice added!' : 'Notice updated!',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Something went wrong')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving notice: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      widget.notice == null ? 'Add New Notice' : 'Edit Notice',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration(
                        'Title',
                        Icons.title_rounded,
                      ),
                      maxLines: 2,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // Category
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: _inputDecoration(
                              'Category',
                              Icons.category_rounded,
                            ),
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c
                                          .split('_')
                                          .map(
                                            (word) =>
                                                word[0].toUpperCase() +
                                                word.substring(1),
                                          )
                                          .join(' '),
                                    ),
                                  ),
                                )
                                .toList(),
                            isExpanded: true,
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Level
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _level,
                            decoration: _inputDecoration(
                              'Level',
                              Icons.layers_rounded,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Global'),
                              ),
                              ..._levels.map(
                                (l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(l.toUpperCase()),
                                ),
                              ),
                            ],
                            isExpanded: true,
                            onChanged: (v) => setState(() => _level = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Attachment
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _attachmentUrlController,
                            readOnly: _pickedFile != null,
                            decoration:
                                _inputDecoration(
                                  'Attachment URL',
                                  Icons.link_rounded,
                                ).copyWith(
                                  suffixIcon: _pickedFile != null
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            size: 18,
                                          ),
                                          onPressed: () => setState(() {
                                            _pickedFile = null;
                                            _attachmentUrlController.clear();
                                          }),
                                        )
                                      : null,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filled(
                          onPressed: _isUploading ? null : _pickFile,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.upload_file_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Source URL
                    TextFormField(
                      controller: _sourceUrlController,
                      decoration: _inputDecoration(
                        'Source URL (Optional)',
                        Icons.open_in_browser_rounded,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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
                                : const Text(
                                    'Save Notice',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

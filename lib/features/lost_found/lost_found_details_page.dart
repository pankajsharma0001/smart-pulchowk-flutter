import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/lost_found.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/image_viewer.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';

class LostFoundDetailsPage extends StatefulWidget {
  final int itemId;

  const LostFoundDetailsPage({super.key, required this.itemId});

  @override
  State<LostFoundDetailsPage> createState() => _LostFoundDetailsPageState();
}

class _LostFoundDetailsPageState extends State<LostFoundDetailsPage> {
  final ApiService _apiService = ApiService();
  LostFoundItem? _item;
  bool _isLoading = true;
  String? _error;
  String? _dbUserId;
  List<LostFoundClaim> _itemClaims = [];
  LostFoundClaim? _myClaim;
  bool _isActionLoading = false;
  final TextEditingController _claimController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _claimController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _dbUserId = await StorageService.readSecure(AppConstants.dbUserIdKey);
    await _fetchItemDetails();
  }

  Future<void> _fetchItemDetails({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final item = await _apiService.getLostFoundItem(
        widget.itemId,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _item = item;
          _isLoading = false;
        });

        if (item != null) {
          final isOwner = item.ownerId == _dbUserId;
          if (isOwner) {
            _fetchItemClaims();
          } else {
            _fetchMyClaim();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchItemClaims() async {
    final claims = await _apiService.getLostFoundItemClaims(widget.itemId);
    if (mounted) {
      setState(() {
        _itemClaims = claims;
      });
    }
  }

  Future<void> _fetchMyClaim() async {
    final claims = await _apiService.getMyLostFoundClaims();
    if (mounted) {
      setState(() {
        try {
          _myClaim = claims.firstWhere((c) => c.itemId == widget.itemId);
        } catch (_) {
          _myClaim = null;
        }
      });
    }
  }

  Future<void> _updateStatus(LostFoundStatus status) async {
    setState(() => _isActionLoading = true);
    final result = await _apiService.updateLostFoundItemStatus(
      widget.itemId,
      status,
    );
    if (mounted) {
      setState(() => _isActionLoading = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item marked as ${status.displayName}')),
        );
        _fetchItemDetails(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to update status')),
        );
      }
    }
  }

  Future<void> _respondToClaim(int claimId, String status) async {
    setState(() => _isActionLoading = true);
    final result = await _apiService.updateLostFoundClaimStatus(
      itemId: widget.itemId,
      claimId: claimId,
      status: status,
    );
    if (mounted) {
      setState(() => _isActionLoading = false);
      if (result.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Claim $status')));
        _fetchItemDetails(forceRefresh: true);
        _fetchItemClaims();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to update claim')),
        );
      }
    }
  }

  Future<void> _submitClaim() async {
    if (_claimController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a message.')));
      return;
    }

    setState(() => _isActionLoading = true);
    final result = await _apiService.createLostFoundClaim(
      itemId: widget.itemId,
      message: _claimController.text.trim(),
    );

    if (mounted) {
      setState(() => _isActionLoading = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim submitted successfully!')),
        );
        Navigator.pop(context);
        _fetchItemDetails(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to submit claim')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(_error ?? 'Item not found'),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final isOwner = _item!.ownerId == _dbUserId;
    final isLost = _item!.itemType == LostFoundItemType.lost;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBadges(),
                  const SizedBox(height: AppSpacing.md),
                  Text(_item!.title, style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.xs),
                  _buildPostedBy(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDetailRow(
                    Icons.location_on_rounded,
                    'Location',
                    _item!.locationText,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow(
                    Icons.calendar_today_rounded,
                    'Date',
                    DateFormat('MMM dd, yyyy').format(_item!.lostFoundDate),
                  ),
                  if (_item!.rewardText != null &&
                      _item!.rewardText!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildDetailRow(
                      Icons.card_giftcard_rounded,
                      'Reward',
                      _item!.rewardText!,
                      color: AppColors.secondary,
                    ),
                  ],
                  const Divider(height: AppSpacing.xl),
                  Text('Description', style: AppTextStyles.h4),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _item!.description,
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildContactSection(isOwner),
                  if (isOwner) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _buildOwnerControls(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildClaimsList(),
                  ],
                  const SizedBox(
                    height: 160,
                  ), // Increased space for bottom action
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: !isOwner && _item!.status == LostFoundStatus.open
          ? (isLost ? _buildLostItemBanner() : _buildClaimAction())
          : null,
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_item!.images.isNotEmpty)
              PageView.builder(
                itemCount: _item!.images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageViewer(
                            imageUrls: _item!.images
                                .map((e) => e.imageUrl)
                                .toList(),
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: SmartImage(
                      imageUrl: _item!.images[index].imageUrl,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              )
            else
              Container(
                color: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.image_not_supported_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0, 0.2, 0.7, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadges() {
    return Row(
      children: [
        _buildBadge(
          _item!.itemType.name.toUpperCase(),
          _item!.itemType == LostFoundItemType.lost
              ? AppColors.error
              : AppColors.success,
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildBadge(_item!.category.name.toUpperCase(), AppColors.primary),
        if (_item!.status != LostFoundStatus.open) ...[
          const SizedBox(width: AppSpacing.sm),
          _buildBadge(
            _item!.status.displayName.toUpperCase(),
            AppColors.secondary,
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.overline.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildPostedBy() {
    final ownerName = _item!.owner?['name'] as String? ?? 'Student';
    return Text(
      'Posted by $ownerName • ${_item!.timeAgo}',
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactSection(bool isOwner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.contact_support_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Contact Information',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _item!.contactNote ?? 'No contact note provided.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildLostItemBanner() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      color: AppColors.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'This is a lost item. If you found it, please contact the owner.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warningContainerDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimAction() {
    if (_myClaim != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getClaimStatusColor(
                  _myClaim!.status,
                ).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _myClaim!.status == LostFoundClaimStatus.accepted
                    ? Icons.check_circle_rounded
                    : _myClaim!.status == LostFoundClaimStatus.rejected
                    ? Icons.cancel_rounded
                    : Icons.pending_rounded,
                color: _getClaimStatusColor(_myClaim!.status),
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Claim Status',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    _myClaim!.status.name[0].toUpperCase() +
                        _myClaim!.status.name.substring(1),
                    style: AppTextStyles.labelLarge.copyWith(
                      fontSize: 16,
                      color: _getClaimStatusColor(_myClaim!.status),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => _showClaimDialog(),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
          ),
          child: const Text(
            'Claim This Item',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  void _showClaimDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Submit a Claim', style: AppTextStyles.h4),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Explain how you know this item belongs to you (e.g., unique marks, contents).',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _claimController,
                  maxLines: 4,
                  decoration: AppDecorations.input(
                    hint: 'Proof of ownership...',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _isActionLoading ? null : _submitClaim,
                  child: _isActionLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit Claim'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerControls() {
    if (_item!.status != LostFoundStatus.open) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Owner Controls', style: AppTextStyles.h4),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _updateStatus(LostFoundStatus.resolved),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark Resolved'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _updateStatus(LostFoundStatus.closed),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Close'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClaimsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Claims (${_itemClaims.length})', style: AppTextStyles.h4),
        const SizedBox(height: AppSpacing.md),
        if (_itemClaims.isEmpty)
          const Text(
            'No claims yet.',
            style: TextStyle(color: AppColors.textMuted),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _itemClaims.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) =>
                _buildClaimCard(_itemClaims[index]),
          ),
      ],
    );
  }

  Widget _buildClaimCard(LostFoundClaim claim) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLight,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                claim.requester?['name'] ?? 'User',
                style: AppTextStyles.labelLarge,
              ),
              _buildBadge(
                claim.status.name.toUpperCase(),
                _getClaimStatusColor(claim.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(claim.message, style: AppTextStyles.bodyMedium),
          if (claim.status == LostFoundClaimStatus.pending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isActionLoading
                        ? null
                        : () => _respondToClaim(claim.id, 'accepted'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isActionLoading
                        ? null
                        : () => _respondToClaim(claim.id, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getClaimStatusColor(LostFoundClaimStatus status) {
    switch (status) {
      case LostFoundClaimStatus.accepted:
        return AppColors.success;
      case LostFoundClaimStatus.rejected:
        return AppColors.error;
      case LostFoundClaimStatus.cancelled:
        return AppColors.textMuted;
      default:
        return AppColors.primary;
    }
  }
}

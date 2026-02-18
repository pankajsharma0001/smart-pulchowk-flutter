import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELP CENTER PAGE
// ─────────────────────────────────────────────────────────────────────────────

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Help Center',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: AppTextStyles.labelLarge,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondary,
          tabs: const [
            Tab(text: 'FAQ'),
            Tab(text: 'Support'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FaqTab(isDark: isDark),
          _SupportTab(isDark: isDark),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ TAB — Feature sub-tabs
// ─────────────────────────────────────────────────────────────────────────────

class _FaqTab extends StatefulWidget {
  final bool isDark;
  const _FaqTab({required this.isDark});

  @override
  State<_FaqTab> createState() => _FaqTabState();
}

class _FaqTabState extends State<_FaqTab> with SingleTickerProviderStateMixin {
  late TabController _featureTabController;

  final List<_FeatureSection> _features = [
    _FeatureSection(
      label: 'Marketplace',
      icon: Icons.auto_stories_rounded,
      color: const Color(0xFF6366F1),
      isReady: true,
    ),
    _FeatureSection(
      label: 'Classroom',
      icon: Icons.school_rounded,
      color: AppColors.primary,
      isReady: true,
    ),
    _FeatureSection(
      label: 'Map',
      icon: Icons.navigation_rounded,
      color: Color(0xFF10B981),
      isReady: false,
    ),
    _FeatureSection(
      label: 'Lost & Found',
      icon: Icons.search_rounded,
      color: Color(0xFF8B5CF6),
      isReady: false,
    ),
    _FeatureSection(
      label: 'Notices',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFFF59E0B),
      isReady: false,
    ),
    _FeatureSection(
      label: 'Events',
      icon: Icons.event_rounded,
      color: Color(0xFFEC4899),
      isReady: false,
    ),
    _FeatureSection(
      label: 'Clubs',
      icon: Icons.groups_rounded,
      color: Color(0xFF14B8A6),
      isReady: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _featureTabController = TabController(
      length: _features.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _featureTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Feature selector tabs (horizontal scroll)
        Container(
          height: 48,
          margin: const EdgeInsets.only(top: 12),
          child: TabBar(
            controller: _featureTabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            indicator: const BoxDecoration(),
            dividerColor: Colors.transparent,
            tabs: _features.asMap().entries.map((entry) {
              final i = entry.key;
              final f = entry.value;
              return AnimatedBuilder(
                animation: _featureTabController,
                builder: (context, _) {
                  final isSelected = _featureTabController.index == i;
                  return Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? f.color.withValues(alpha: 0.15)
                            : (widget.isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? f.color.withValues(alpha: 0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            f.icon,
                            size: 14,
                            color: isSelected
                                ? f.color
                                : (widget.isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            f.label,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isSelected
                                  ? f.color
                                  : (widget.isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary),
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // FAQ content
        Expanded(
          child: TabBarView(
            controller: _featureTabController,
            children: _features.map((f) {
              if (!f.isReady) {
                return _PlaceholderFaq(feature: f, isDark: widget.isDark);
              }
              if (f.label == 'Classroom') {
                return _ClassroomFaq(isDark: widget.isDark);
              }
              return _MarketplaceFaq(isDark: widget.isDark);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKETPLACE FAQ
// ─────────────────────────────────────────────────────────────────────────────

class _MarketplaceFaq extends StatelessWidget {
  final bool isDark;
  const _MarketplaceFaq({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      _FaqItem(
        question: 'How do I sell a book?',
        answer:
            'Go to the Marketplace tab and tap the "Sell a Book" button at the bottom right. Fill in the book title, author, price, condition, and upload photos. Once submitted, your listing will be visible to other students.',
        icon: Icons.sell_rounded,
        color: Color(0xFF6366F1),
      ),
      _FaqItem(
        question: 'How do I send a purchase request?',
        answer:
            'Open a book listing and tap "Request to Buy". You can include an optional message to the seller. The seller will then accept or reject your request.',
        icon: Icons.shopping_cart_rounded,
        color: Color(0xFF10B981),
      ),
      _FaqItem(
        question: 'Where can I see requests I\'ve sent?',
        answer:
            'Tap the activity icon (top-right of the Marketplace) or go to the Marketplace Activity page. Select the "Requests" tab to see all outgoing purchase requests and their statuses.',
        icon: Icons.outbox_rounded,
        color: Color(0xFF8B5CF6),
      ),
      _FaqItem(
        question: 'Where can I see requests I\'ve received?',
        answer:
            'In the Marketplace Activity page, select the "Inquiries" tab. Here you\'ll see all incoming purchase requests for your listings. You can accept or reject them from this screen.',
        icon: Icons.inbox_rounded,
        color: Color(0xFFF59E0B),
      ),
      _FaqItem(
        question: 'How do I accept or reject a purchase request?',
        answer:
            'Go to Marketplace Activity → Inquiries tab. Find the request and tap "Accept" or "Reject". Accepting will notify the buyer and allow them to contact you.',
        icon: Icons.check_circle_rounded,
        color: Color(0xFF10B981),
      ),
      _FaqItem(
        question: 'How do I contact a seller after my request is accepted?',
        answer:
            'Once your request is accepted, a "Contact Seller" button appears on the book details page and in your Requests tab. Tap it to choose between in-app messaging or the seller\'s preferred external contact (WhatsApp, phone, etc.).',
        icon: Icons.contact_phone_rounded,
        color: Color(0xFF0084FF),
      ),
      _FaqItem(
        question: 'Where are my saved books?',
        answer:
            'In the Marketplace Activity page, select the "Saved" tab. Books you\'ve bookmarked by tapping the save icon on a listing will appear here for easy access.',
        icon: Icons.bookmark_rounded,
        color: Color(0xFFEC4899),
      ),
      _FaqItem(
        question: 'How do I delete a chat conversation?',
        answer:
            'In the chat list, long-press on any conversation to select it. You can then select multiple conversations and delete them using the trash icon that appears at the top.',
        icon: Icons.chat_bubble_rounded,
        color: Color(0xFF6366F1),
      ),
      _FaqItem(
        question: 'How do I delete my book listing?',
        answer:
            'Go to Marketplace Activity → Selling tab. Find your listing and tap the delete icon. Confirm the deletion in the dialog. Note: listings with active accepted requests may require you to resolve them first.',
        icon: Icons.delete_rounded,
        color: Color(0xFFEF4444),
      ),
      _FaqItem(
        question: 'How do I mark my book as sold?',
        answer:
            'Go to Marketplace Activity → Selling tab. Find your listing and tap the "Mark as Sold" option. This will close the listing and notify any pending requesters.',
        icon: Icons.task_alt_rounded,
        color: Color(0xFF10B981),
      ),
      _FaqItem(
        question: 'How do I cancel a purchase request I sent?',
        answer:
            'Go to Marketplace Activity → Requests tab. Find the pending request and tap "Cancel". You can only cancel requests that are still in "Pending" status.',
        icon: Icons.cancel_rounded,
        color: Color(0xFFF59E0B),
      ),
      _FaqItem(
        question: 'How do I rate a seller?',
        answer:
            'After your purchase request is accepted and you\'ve completed the transaction, a "Rate Seller" button will appear in your Requests tab for that listing. Tap it to leave a star rating and optional review.',
        icon: Icons.star_rounded,
        color: Color(0xFFF59E0B),
      ),
      _FaqItem(
        question: 'Can I report a suspicious listing or user?',
        answer:
            'Yes. On any book listing or user profile, tap the three-dot menu (⋮) and select "Report". Choose a reason and submit. Our moderation team will review it.',
        icon: Icons.report_rounded,
        color: Color(0xFFEF4444),
      ),
      _FaqItem(
        question: 'How do I block a user?',
        answer:
            'On a user\'s profile page, tap the three-dot menu (⋮) and select "Block User". Blocked users won\'t be able to send you requests or messages. You can manage blocked users in Settings → Blocked Users.',
        icon: Icons.block_rounded,
        color: Color(0xFF64748B),
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: faqs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _FaqCard(item: faqs[i], isDark: isDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSROOM FAQ
// ─────────────────────────────────────────────────────────────────────────────

class _ClassroomFaq extends StatelessWidget {
  final bool isDark;
  const _ClassroomFaq({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      _FaqItem(
        question: 'How setup profile in classroom?',
        answer:
            'It is done automatically. Once you have logged in then according to your college email, the Classroom tab will automatically display subjects and assignments for your specific semester.',
        icon: Icons.account_circle_rounded,
        color: AppColors.primary,
      ),
      _FaqItem(
        question: 'How do I submit an assignment?',
        answer:
            'In the Classroom tab, find the assignment you want to submit. Tap the "Upload File" button to select your document (PDF or Image), then tap "Submit Assignment". You can also leave an optional comment for your teacher.',
        icon: Icons.upload_file_rounded,
        color: const Color(0xFF10B981),
      ),
      _FaqItem(
        question: 'Can I resubmit an assignment?',
        answer:
            'Yes, you can re-upload and re-submit assignments before they are graded. Re-submitting will replace your previous submission with the new file.',
        icon: Icons.update_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _FaqItem(
        question: 'How do I check my grades?',
        answer:
            'Once a teacher returns your assignment, you\'ll see its status change to "Returned" or "Graded" in the Classroom list. Tap the assignment to view any feedback or comments from your teacher.',
        icon: Icons.grading_rounded,
        color: const Color(0xFF8B5CF6),
      ),
      _FaqItem(
        question: 'How do I add a subject to teach?',
        answer:
            'Teachers can go to the Classroom tab → "Add Subject" sub-tab. Select the Faculty and Semester, choose the subject you are teaching, and tap "Add Subject" to begin managing assignments for that class.',
        icon: Icons.add_task_rounded,
        color: const Color(0xFF6366F1),
      ),
      _FaqItem(
        question: 'How do I create a new assignment?',
        answer:
            'As a teacher, use the Classroom tab → "Assign" sub-tab. Select the subject, choose a category (Classwork or Homework), set a due date, and provide a title and description. Tap "Create Assignment" to notify your students.',
        icon: Icons.post_add_rounded,
        color: const Color(0xFF10B981),
      ),
      _FaqItem(
        question: 'How do I view student submissions?',
        answer:
            'In the Classroom tab → "Managed" sub-tab, find the assignment you want to review. Tap on it to see a list of all students who have submitted their work. You can then view their files and leave feedback.',
        icon: Icons.people_rounded,
        color: const Color(0xFF0EA5E9),
      ),
      _FaqItem(
        question: 'Classroom data isn\'t loading. What should I do?',
        answer:
            'If the dashboard seems out of date, pull down on the Classroom screen to trigger a manual refresh. This will sync your profile role and clear any stale cache.',
        icon: Icons.sync_rounded,
        color: const Color(0xFFF59E0B),
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: faqs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _FaqCard(item: faqs[i], isDark: isDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER FAQ
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderFaq extends StatelessWidget {
  final _FeatureSection feature;
  final bool isDark;
  const _PlaceholderFaq({required this.feature, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: feature.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(feature.icon, size: 40, color: feature.color),
            ),
            const SizedBox(height: 20),
            Text(
              '${feature.label} FAQ',
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Help articles for ${feature.label} are coming soon. Check back after this feature is fully launched.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ CARD (Expandable)
// ─────────────────────────────────────────────────────────────────────────────

class _FaqCard extends StatefulWidget {
  final _FaqItem item;
  final bool isDark;
  const _FaqCard({required this.item, required this.isDark});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    haptics.selectionClick();
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final item = widget.item;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? item.color.withValues(alpha: 0.3)
                : (isDark ? Colors.white10 : Colors.black12),
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: _expanded
              ? [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 18, color: item.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.question,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: _expanded
                          ? item.color
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.answer,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORT TAB
// ─────────────────────────────────────────────────────────────────────────────

class _SupportTab extends StatelessWidget {
  final bool isDark;
  const _SupportTab({required this.isDark});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We\'re here to help!',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reach out through any of the channels below.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _sectionLabel('Contact Us', isDark),
        const SizedBox(height: 10),

        _ContactCard(
          isDark: isDark,
          icon: Icons.email_rounded,
          color: const Color(0xFF6366F1),
          title: 'Email Support',
          subtitle: 'support@pulchowkx.com',
          description: 'Best for detailed issues. We respond within 24 hours.',
          onTap: () => _launch(
            'mailto:support@pulchowkx.com?subject=Smart Pulchowk Support',
          ),
        ),
        const SizedBox(height: 10),
        _ContactCard(
          isDark: isDark,
          icon: Icons.chat_rounded,
          color: const Color(0xFF25D366),
          title: 'WhatsApp',
          subtitle: 'Chat with us directly',
          description: 'Quick questions and real-time support.',
          onTap: () => _launch('https://wa.me/9779800000000'),
        ),
        const SizedBox(height: 10),
        _ContactCard(
          isDark: isDark,
          icon: Icons.telegram_rounded,
          color: const Color(0xFF0088CC),
          title: 'Telegram',
          subtitle: '@SmartPulchowkSupport',
          description: 'Join our support channel for updates and help.',
          onTap: () => _launch('https://t.me/SmartPulchowkSupport'),
        ),

        const SizedBox(height: 24),
        _sectionLabel('Community', isDark),
        const SizedBox(height: 10),

        _ContactCard(
          isDark: isDark,
          icon: Icons.groups_rounded,
          color: const Color(0xFF0084FF),
          title: 'Facebook Group',
          subtitle: 'Smart Pulchowk Community',
          description: 'Connect with other students and share tips.',
          onTap: () => _launch('https://facebook.com/groups/smartpulchowk'),
        ),

        const SizedBox(height: 24),
        _sectionLabel('Report a Bug', isDark),
        const SizedBox(height: 10),

        _ContactCard(
          isDark: isDark,
          icon: Icons.bug_report_rounded,
          color: const Color(0xFFEF4444),
          title: 'Report a Bug',
          subtitle: 'bugs@pulchowkx.com',
          description:
              'Found something broken? Let us know and we\'ll fix it fast.',
          onTap: () => _launch(
            'mailto:bugs@pulchowkx.com?subject=Bug Report - Smart Pulchowk',
          ),
        ),

        const SizedBox(height: 24),

        // Response time info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 18,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Average response time: 2–12 hours on weekdays.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label, bool isDark) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;

  const _ContactCard({
    required this.isDark,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          haptics.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureSection {
  final String label;
  final IconData icon;
  final Color color;
  final bool isReady;
  const _FeatureSection({
    required this.label,
    required this.icon,
    required this.color,
    required this.isReady,
  });
}

class _FaqItem {
  final String question;
  final String answer;
  final IconData icon;
  final Color color;
  const _FaqItem({
    required this.question,
    required this.answer,
    required this.icon,
    required this.color,
  });
}

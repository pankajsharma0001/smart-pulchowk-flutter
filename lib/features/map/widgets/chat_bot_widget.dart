import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/features/map/models/chatbot_response.dart';

/// A beautiful floating chatbot widget that provides campus navigation assistance.
class ChatBotWidget extends StatefulWidget {
  /// Callback when the chatbot returns locations to display
  final void Function(List<ChatBotLocation> locations, String action)?
  onLocationsReturned;
  final double bottomOffset;

  const ChatBotWidget({
    super.key,
    this.onLocationsReturned,
    this.bottomOffset = 0,
  });

  @override
  State<ChatBotWidget> createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final HapticService _haptics = haptics;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatBotMessage> _messages = [];
  final FocusNode _focusNode = FocusNode();

  bool _isOpen = false;
  bool _isLoading = false;
  int _rateLimitCooldown = 0;
  Timer? _cooldownTimer;

  // All available suggestion chips
  static const List<String> _allSuggestions = [
    'Where is the library?',
    'Find ICTC Building',
    'Canteen location',
    'Dean Office',
    'Where is the gym?',
    'Find the hostel',
    'Main entrance',
    'Computer lab',
    'Robotics Club',
    'Football ground',
    'ATM location',
    'Exam office',
  ];

  // Current 3 random suggestions
  late List<String> _currentSuggestions;

  late AnimationController _panelAnimationController;
  late AnimationController _fabAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _fabRotationAnimation;

  @override
  void initState() {
    super.initState();
    _shuffleSuggestions();

    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _scaleAnimation = CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeOut,
    );

    _fabRotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _panelAnimationController.dispose();
    _fabAnimationController.dispose();
    _pulseAnimationController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _shuffleSuggestions() {
    final random = Random();
    final shuffled = List<String>.from(_allSuggestions)..shuffle(random);
    _currentSuggestions = shuffled.take(3).toList();
  }

  void _toggleChat() {
    _haptics.selectionClick();
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _shuffleSuggestions();
        _panelAnimationController.forward();
        _fabAnimationController.forward();
        _pulseAnimationController.stop();
        _scrollToBottom();
      } else {
        _panelAnimationController.reverse();
        _fabAnimationController.reverse();
        _pulseAnimationController.repeat();
        _focusNode.unfocus();
      }
    });
  }

  void _closeChat() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _panelAnimationController.reverse();
        _fabAnimationController.reverse();
        _pulseAnimationController.repeat();
        _focusNode.unfocus();
      });
    }
  }

  void _startCooldown(int seconds) {
    setState(() {
      _rateLimitCooldown = seconds;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _rateLimitCooldown--;
        if (_rateLimitCooldown <= 0) {
          _rateLimitCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendMessage() async {
    final query = _messageController.text.trim();
    if (query.isEmpty || _isLoading || _rateLimitCooldown > 0) return;

    _haptics.lightImpact();
    setState(() {
      _messages.add(
        ChatBotMessage(content: query, role: ChatBotMessageRole.user),
      );
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    final response = await _apiService.chatBot(query);

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (response.success && response.data != null) {
        _messages.add(
          ChatBotMessage(
            content: response.data!.message,
            role: ChatBotMessageRole.assistant,
            locations: response.data!.locations,
            action: response.data!.action,
          ),
        );

        if (response.data!.locations.isNotEmpty) {
          widget.onLocationsReturned?.call(
            response.data!.locations,
            response.data!.action,
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _closeChat();
          });
        }
      } else {
        final isQuotaError = response.isQuotaError;
        if (isQuotaError) {
          _startCooldown(30);
        }
        _messages.add(
          ChatBotMessage(
            content: isQuotaError
                ? '⏱️ API limit reached. Please wait ${_rateLimitCooldown > 0 ? _rateLimitCooldown : 30} seconds.'
                : response.errorMessage ??
                      'Something went wrong. Please try again.',
            role: ChatBotMessageRole.error,
            isQuotaError: isQuotaError,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isKeyboardOpen = viewInsets.bottom > 0;
    final keyboardOffset = isKeyboardOpen ? viewInsets.bottom : 0.0;

    return Stack(
      children: [
        if (_isOpen)
          Positioned(
            right: 16,
            bottom:
                64 +
                widget.bottomOffset +
                keyboardOffset, // Aligned with Location button bottom
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: Alignment.bottomRight,
                child: _buildChatPanel(isDark),
              ),
            ),
          ),

        Positioned(
          right: 16, // Back to bottom-right
          bottom:
              0 +
              widget.bottomOffset +
              (isKeyboardOpen ? keyboardOffset : 0), // Flush with navbar
          child: _buildFab(isDark),
        ),
      ],
    );
  }

  Widget _buildFab(bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseAnimationController,
        _fabAnimationController,
      ]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (!_isOpen)
              Opacity(
                opacity: (1 - _pulseAnimationController.value) * 0.5,
                child: Transform.scale(
                  scale: 1 + (_pulseAnimationController.value * 0.5),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF667EEA).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

            Transform.scale(
              scale: _isOpen
                  ? 1.0
                  : 1 + (_pulseAnimationController.value * 0.05),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleChat,
                    borderRadius: BorderRadius.circular(28),
                    child: RotationTransition(
                      turns: _fabRotationAnimation,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isOpen
                            ? const Icon(
                                Icons.close_rounded,
                                key: ValueKey('close'),
                                size: 26,
                                color: Colors.white,
                              )
                            : const Icon(
                                Icons.assistant_rounded,
                                key: ValueKey('open'),
                                size: 24,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatPanel(bool isDark) {
    return Container(
      width: 340,
      height: 480,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessagesList(isDark)),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.assistant, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Campus Assistant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _toggleChat,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 48,
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask me anything about Pulchowk!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.5,
                ),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _currentSuggestions
                  .map((s) => _buildSuggestionChip(s, isDark))
                  .toList(),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildLoadingIndicator(isDark);
        return _buildMessageBubble(_messages[index], isDark);
      },
    );
  }

  Widget _buildSuggestionChip(String text, bool isDark) {
    return ActionChip(
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
      label: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
      backgroundColor: (isDark ? Colors.white : Colors.black).withValues(
        alpha: 0.05,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildMessageBubble(ChatBotMessage message, bool isDark) {
    final isUser = message.role == ChatBotMessageRole.user;
    final isError = message.role == ChatBotMessageRole.error;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF667EEA)
              : isError
              ? Colors.red.withValues(alpha: 0.1)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : isError
                ? Colors.red
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.05,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              onSubmitted: (_) => _sendMessage(),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Type your question...',
                hintStyle: TextStyle(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.4,
                  ),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: Icon(
              Icons.send_rounded,
              color: _messageController.text.trim().isEmpty && !_isLoading
                  ? (isDark ? Colors.white24 : Colors.black26)
                  : const Color(0xFF667EEA),
            ),
          ),
        ],
      ),
    );
  }
}

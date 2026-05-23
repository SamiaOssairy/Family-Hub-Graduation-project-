import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';
import '../core/localization/app_i18n.dart';
import '../core/theme/app_theme.dart';

class PlanningChatScreen extends StatefulWidget {
  const PlanningChatScreen({super.key});

  @override
  State<PlanningChatScreen> createState() => _PlanningChatScreenState();
}

class _PlanningChatScreenState extends State<PlanningChatScreen>
    with SingleTickerProviderStateMixin {
  // ── Animation (UNCHANGED) ────────────────────────────────────────────────
  late AnimationController _dotsController;
  late List<Animation<double>> _dotAnimations;

  // ── State (UNCHANGED) ────────────────────────────────────────────────────
  final ApiService _api = ApiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _historyLoading = true;

  String _t(String en, String ar) => AppI18n.t(context, en, ar);

  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  // Suggestion chips (UNCHANGED)
  static const _suggestions = [
    'What was our average budget for the last 3 months?',
    'Who was the best child in the past 2 weeks?',
    'What do you suggest to save money next month?',
    'Suggest meals for today based on what we have.',
    'Which category did we overspend on?',
    'How many tasks were completed this week?',
  ];

  // ── Lifecycle (UNCHANGED) ────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _dotAnimations = List.generate(3, (i) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _dotsController,
          curve: Interval(i * 0.2, 0.6 + i * 0.2, curve: Curves.easeInOut),
        ),
      );
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Logic (ALL UNCHANGED) ────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    try {
      final msgs = await _api.getPlanningHistory();
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _historyLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _historyLoading = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;
    _inputCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': trimmed});
      _loading = true;
    });
    _scrollToBottom();
    try {
      final reply = await _api.sendPlanningMessage(trimmed);
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'content': reply});
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': _t('Sorry, something went wrong. Please try again.',
              'عذراً، حدث خطأ. يرجى المحاولة مجدداً.'),
        });
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Clear History', 'مسح السجل')),
        content: Text(_t('Are you sure you want to clear the entire chat history?',
            'هل أنت متأكد من مسح سجل المحادثة بالكامل؟')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('Cancel', 'إلغاء'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('Clear', 'مسح'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.clearPlanningHistory();
      if (!mounted) return;
      setState(() => _messages = []);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Failed to clear history', 'فشل مسح السجل'))),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.smart_toy_outlined,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Family AI Assistant', 'مساعد العائلة الذكي'),
                  style: GoogleFonts.poppins(
                      fontSize: _sp(15), fontWeight: FontWeight.w700),
                ),
                Text(
                  _t('Powered by Gemini', 'مدعوم بـ Gemini'),
                  style: GoogleFonts.poppins(
                      fontSize: _sp(10),
                      color: Colors.white.withOpacity(0.75)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline),
              tooltip: _t('Clear history', 'مسح السجل'),
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _historyLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(Icons.smart_toy_outlined,
                  color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              _t('Ask me anything about your family!',
                  'اسألني أي شيء عن عائلتك!'),
              style: GoogleFonts.poppins(
                fontSize: _sp(17),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _t('Budget, tasks, points, suggestions and more.',
                  'الميزانية، المهام، النقاط، والاقتراحات وأكثر.'),
              style: GoogleFonts.poppins(
                  fontSize: _sp(12), color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _t('Try asking:', 'جرب أن تسأل:'),
            style: GoogleFonts.poppins(
              fontSize: _sp(13),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ..._suggestions.map(_buildSuggestionChip),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.poppins(
                      fontSize: _sp(12), color: AppColors.textPrimary)),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_loading && index == _messages.length) {
          return _buildTypingIndicator();
        }
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        return _buildMessageBubble(msg['content'] as String, isUser);
      },
    );
  }

  Widget _buildMessageBubble(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: isUser
            ? BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              )
            : BoxDecoration(
                color: AppColors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_outlined,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      _t('AI Assistant', 'المساعد الذكي'),
                      style: GoogleFonts.poppins(
                        fontSize: _sp(10),
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            SelectableText(
              content,
              style: GoogleFonts.poppins(
                fontSize: _sp(13),
                color: isUser ? Colors.white : AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Typing indicator (animation UNCHANGED, only colors updated) ───────────

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 6)
          ],
        ),
        child: AnimatedBuilder(
          animation: _dotsController,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = _dotAnimations[i].value;
                final lift = t < 0.5 ? t * 2 : (1 - t) * 2;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.translate(
                    offset: Offset(0, -6 * lift),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withOpacity(0.4 + 0.6 * lift),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  // ── Input bar ────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              enabled: !_loading,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _t('Ask about budget, tasks, points…',
                    'اسأل عن الميزانية، المهام، النقاط…'),
                hintStyle: GoogleFonts.poppins(
                    color: AppColors.textHint, fontSize: _sp(13)),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_inputCtrl.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: _loading ? null : AppColors.primaryGradient,
                color: _loading ? AppColors.borderLight : null,
                shape: BoxShape.circle,
                boxShadow: _loading
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Icon(
                _loading ? Icons.hourglass_empty : Icons.send,
                color: _loading ? AppColors.textHint : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

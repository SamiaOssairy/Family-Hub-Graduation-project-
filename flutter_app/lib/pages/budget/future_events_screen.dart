import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_frontend/core/services/api_service.dart';
import 'package:app_frontend/core/theme/app_theme.dart';
import 'package:app_frontend/core/theme/theme_provider.dart';
import 'package:app_frontend/core/widgets/app_bottom_nav.dart';
import 'package:app_frontend/pages/budget/budget_provider.dart';

class FutureEventsScreen extends StatefulWidget {
  const FutureEventsScreen({super.key});
  @override
  State<FutureEventsScreen> createState() => _FutureEventsScreenState();
}

class _FutureEventsScreenState extends State<FutureEventsScreen> {
  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _localEvents = [];
  bool _eventsLoading = true;

  // ── Color / icon palette per event index ─────────────────────────────────
  static const _eventBg = [
    Color(0xFFE0F2F1), Color(0xFFFFF8E1), Color(0xFFE8F5F5),
    Color(0xFFE3F2FD), Color(0xFFFCE4EC), Color(0xFFF3E5F5),
  ];
  static final _eventColors = [
    AppColors.primary, Color(0xFFFB8C00), Color(0xFF43A047),
    Color(0xFF1565C0), Color(0xFFE91E63), Color(0xFF7B1FA2),
  ];
  static const _eventEmojis = ['✈️', '🛍️', '🎒', '🎉', '🏖️', '🎓'];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchEvents());
  }

  Future<void> _fetchEvents() async {
    if (!mounted) return;
    setState(() => _eventsLoading = true);
    try {
      final raw = await _apiService.getFutureEvents();
      debugPrint('✓ _fetchEvents got ${raw.length} events: $raw');
      if (!mounted) return;
      setState(() {
        _localEvents = raw.map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return {
            ...m,
            'name': (m['title'] ?? m['name'] ?? '').toString(),
            'expected_date': (m['event_date'] ?? m['expected_date'] ?? '').toString(),
            'estimated_cost': m['estimated_cost'] ?? 0,
            'saved_amount': m['total_contributed_money'] ?? m['saved_amount'] ?? 0,
          };
        }).toList();
        _eventsLoading = false;
      });
    } catch (e) {
      debugPrint('✗ _fetchEvents error: $e');
      if (!mounted) return;
      setState(() => _eventsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading events: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // ── Logic (ALL UNCHANGED) ─────────────────────────────────────────────────

  void _showEventSheet(BuildContext context, FamilyBudgetProvider provider,
      {Map<String, dynamic>? existing}) {
    final nameCtrl  = TextEditingController(text: existing?['name'] ?? '');
    final costCtrl  = TextEditingController(
        text: existing != null ? existing['estimated_cost'].toString() : '');
    final savedCtrl = TextEditingController(
        text: existing != null ? existing['saved_amount'].toString() : '0');
    DateTime selectedDate = existing != null
        ? DateTime.parse(existing['expected_date'])
        : DateTime.now().add(const Duration(days: 90));
    int reminderMonths = existing?['reminder_months_before'] ?? 3;
    String frequency   = existing?['saving_frequency'] ?? 'monthly';
    bool isLoading     = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  existing != null ? 'Edit Event' : 'New Future Event',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(18), fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Event Name (e.g. Eid)',
                    prefixIcon: Icon(Icons.event_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Estimated Cost (EGP)',
                    prefixIcon: Icon(Icons.attach_money, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: savedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Already Saved (EGP)',
                    prefixIcon: Icon(Icons.savings_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) setSheet(() => selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Text(DateFormat('MMM dd, yyyy').format(selectedDate),
                          style: GoogleFonts.poppins(
                              fontSize: _sp(13), color: AppColors.textPrimary)),
                      const Spacer(),
                      Icon(Icons.keyboard_arrow_down,
                          size: 18, color: AppColors.textSecondary),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Remind me $reminderMonths month${reminderMonths > 1 ? 's' : ''} before',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(12), fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    thumbColor: AppColors.primary,
                    inactiveTrackColor: AppColors.border,
                    overlayColor: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: reminderMonths.toDouble(),
                    min: 1, max: 12, divisions: 11,
                    label: '$reminderMonths months',
                    onChanged: (v) => setSheet(() => reminderMonths = v.round()),
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Text('Saving frequency: ',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(12), fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(width: 8),
                  for (final f in ['weekly', 'monthly'])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setSheet(() => frequency = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: frequency == f
                                ? AppColors.primary
                                : AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            f[0].toUpperCase() + f.substring(1),
                            style: GoogleFonts.poppins(
                                fontSize: _sp(11), fontWeight: FontWeight.w600,
                                color: frequency == f
                                    ? Colors.white
                                    : AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: isLoading
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          final cost = double.tryParse(costCtrl.text.trim());
                          if (cost == null) return;
                          setSheet(() => isLoading = true);
                          try {
                            final payload = {
                              'name': nameCtrl.text.trim(),
                              'expected_date': selectedDate.toIso8601String(),
                              'estimated_cost': cost,
                              'saved_amount': double.tryParse(savedCtrl.text.trim()) ?? 0,
                              'reminder_months_before': reminderMonths,
                              'saving_frequency': frequency,
                            };
                            if (existing != null) {
                              await provider.updateFutureEvent(
                                  existing['_id'], payload);
                            } else {
                              await provider.createFutureEvent(payload);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _fetchEvents();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(e.toString()
                                    .replaceAll('Exception: ', '')),
                                backgroundColor: Colors.red,
                              ));
                            }
                          } finally {
                            setSheet(() => isLoading = false);
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: isLoading
                          ? null
                          : LinearGradient(
                              colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                      color: isLoading ? AppColors.border : null,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: isLoading
                          ? null
                          : [
                              BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                    ),
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              existing != null ? 'Update Event' : 'Save Event',
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(14), fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEvent(
      FamilyBudgetProvider provider, String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Event',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to delete this future event?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await provider.deleteFutureEvent(eventId);
        await _fetchEvents();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg     = isDark ? const Color(0xFF0A1628) : AppColors.background;

    return Consumer<FamilyBudgetProvider>(
      builder: (ctx, provider, _) {
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            flexibleSpace: Container(
              decoration:
                  BoxDecoration(gradient: AppColors.primaryGradient),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text('Family Events',
                style: GoogleFonts.poppins(
                    fontSize: _sp(17), fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh_outlined, color: Colors.white),
                onPressed: _fetchEvents,
              ),
            ],
          ),
          floatingActionButton: GestureDetector(
            onTap: () => _showEventSheet(ctx, provider),
            child: Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
          bottomNavigationBar: const AppBottomNav(selectedIndex: 1),
          body: _eventsLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _localEvents.isEmpty
                  ? _buildEmptyState(ctx, provider, isDark)
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _fetchEvents,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                            itemCount: _localEvents.length,
                            itemBuilder: (_, i) => _buildEventCard(
                              ctx,
                              provider,
                              _localEvents[i],
                              i,
                              isDark,
                            ),
                          ),
                        ),
                      ),
                    ),
        );
      },
    );
  }

  // ── Event card ─────────────────────────────────────────────────────────────

  Widget _buildEventCard(
    BuildContext context,
    FamilyBudgetProvider provider,
    Map<String, dynamic> event,
    int index,
    bool isDark,
  ) {
    final name         = (event['name'] ?? 'Event').toString();
    final expectedDate = event['expected_date']?.toString() ?? '';
    final estimatedCost = (event['estimated_cost'] ?? 0).toDouble();
    final savedAmount   = (event['saved_amount'] ?? 0).toDouble();
    final progress      = estimatedCost > 0
        ? (savedAmount / estimatedCost).clamp(0.0, 1.0)
        : 0.0;
    final isFunded  = progress >= 1.0;
    final remaining = estimatedCost - savedAmount;
    final eventId   = event['_id']?.toString() ?? '';

    final iconBg    = _eventBg[index % _eventBg.length];
    final iconColor = _eventColors[index % _eventColors.length];
    final emoji     = _eventEmojis[index % _eventEmojis.length];

    DateTime? date;
    try { date = DateTime.parse(expectedDate); } catch (_) {}
    final dateLabel = date != null
        ? DateFormat('MMM yyyy').format(date)
        : expectedDate;

    final cardBg = isDark ? const Color(0xFF122030) : Colors.white;
    final borderColor = isFunded
        ? const Color(0xFFA5D6A7)
        : (isDark ? const Color(0xFF1E3A4A) : AppColors.border);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isFunded ? 1.5 : 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(13)),
                child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.poppins(
                            fontSize: _sp(13), fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFE0F2F1)
                                : AppColors.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Expected: $dateLabel',
                        style: GoogleFonts.poppins(
                            fontSize: _sp(10),
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (isFunded)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('✓ Funded',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(9), fontWeight: FontWeight.w700,
                          color: const Color(0xFF00897B))),
                )
              else ...[
                GestureDetector(
                  onTap: () => _showEventSheet(context, provider, existing: event),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.edit_outlined,
                        size: 14, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _deleteEvent(provider, eventId),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.delete_outline,
                        size: 14, color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Progress row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: ${estimatedCost.toStringAsFixed(0)} EGP',
                style: GoogleFonts.poppins(
                    fontSize: _sp(10), color: AppColors.textSecondary),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% saved',
                style: GoogleFonts.poppins(
                    fontSize: _sp(10), fontWeight: FontWeight.w700,
                    color: isFunded
                        ? const Color(0xFF43A047)
                        : iconColor),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark
                  ? const Color(0xFF1E3A4A)
                  : (isFunded
                      ? const Color(0xFFC8E6C9)
                      : AppColors.borderLight),
              valueColor: AlwaysStoppedAnimation<Color>(
                  isFunded ? const Color(0xFF43A047) : iconColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isFunded
                ? '${savedAmount.toStringAsFixed(0)} / ${estimatedCost.toStringAsFixed(0)} EGP — Fully funded! 🎉'
                : 'Saved: ${savedAmount.toStringAsFixed(0)} EGP  ·  Remaining: ${remaining.toStringAsFixed(0)} EGP',
            style: GoogleFonts.poppins(
                fontSize: _sp(9),
                color: isFunded
                    ? const Color(0xFF43A047)
                    : AppColors.textSecondary,
                fontWeight:
                    isFunded ? FontWeight.w600 : FontWeight.normal),
          ),

          // Action buttons (only when not funded)
          if (!isFunded) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (eventId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Event ID is missing')));
                        return;
                      }
                      Navigator.pushNamed(context, '/event-funding',
                          arguments: {'eventId': eventId});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text('Contribute 💰',
                            style: GoogleFonts.poppins(
                                fontSize: _sp(10), fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (eventId.isEmpty) return;
                      Navigator.pushNamed(context, '/event-funding',
                          arguments: {'eventId': eventId});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text('Use Points ⭐',
                            style: GoogleFonts.poppins(
                                fontSize: _sp(10), fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, FamilyBudgetProvider provider,
      bool isDark) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(24)),
                  child: Icon(Icons.event_note_outlined,
                      size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text('No events planned yet',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(18), fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'Plan for Eid, tuition, back-to-school\nand get saving reminders.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: _sp(12), color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _showEventSheet(context, provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Add First Event',
                            style: GoogleFonts.poppins(
                                fontSize: _sp(13), fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

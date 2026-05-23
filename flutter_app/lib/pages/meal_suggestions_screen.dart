import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';
import '../core/theme/theme_provider.dart';
import '../core/widgets/guarded_button.dart';

// ─── Meal type option data ───────────────────────────────────────────────────
class _MealTypeOption {
  final String label;
  final String emoji;
  final Color color;
  final String subtitle;
  const _MealTypeOption(this.label, this.emoji, this.color, this.subtitle);
}

const _mealTypeOptions = [
  _MealTypeOption('Breakfast', '🌅', Color(0xFFFB8C00), 'Morning recipes'),
  _MealTypeOption('Lunch', '☀️', Color(0xFF00897B), 'Midday meals'),
  _MealTypeOption('Dinner', '🌙', Color(0xFF1565C0), 'Evening dishes'),
  _MealTypeOption('Snack', '🍿', Color(0xFFE91E63), 'Light bites'),
  _MealTypeOption('Any', '✨', Color(0xFF7B1FA2), 'All categories'),
];

// ─── Screen ──────────────────────────────────────────────────────────────────
class MealSuggestionsScreen extends StatefulWidget {
  const MealSuggestionsScreen({super.key});

  @override
  State<MealSuggestionsScreen> createState() => _MealSuggestionsScreenState();
}

class _MealSuggestionsScreenState extends State<MealSuggestionsScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _suggestions = [];
  bool _loading = true;
  bool _generating = false;
  String? _lastMealType; // null = never generated

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loading = true);
    try {
      final suggestions = await _apiService.getMealSuggestions();
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          // Infer last meal type from saved suggestions
          if (suggestions.isNotEmpty) {
            _lastMealType = suggestions.first['meal_type'] as String?;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Error loading suggestions: $e', isError: true);
      }
    }
  }

  // ── Meal type picker bottom sheet ────────────────────────────────────────
  Future<void> _showMealTypePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MealTypePickerSheet(
        initialValue: _lastMealType ?? 'Any',
      ),
    );
    if (selected != null) {
      await _generateSuggestions(selected);
    }
  }

  // ── Generate ─────────────────────────────────────────────────────────────
  Future<void> _generateSuggestions(String mealType) async {
    setState(() {
      _generating = true;
      _lastMealType = mealType;
    });
    try {
      final result = await _apiService.generateMealSuggestions(mealType: mealType);
      final raw = result['data']?['suggestions'] ?? result['suggestions'] ?? [];
      final suggestions = raw is List ? raw : [];
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _generating = false;
        });
        final label = mealType == 'Any' ? 'all categories' : mealType;
        _showSnack('Generated ${suggestions.length} suggestions for $label!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        _showSnack('Error generating suggestions: $e', isError: true);
      }
    }
  }

  Future<void> _clearSuggestions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Suggestions',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Remove all current suggestions?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _apiService.clearMealSuggestions();
        if (mounted) setState(() { _suggestions = []; _lastMealType = null; });
      } catch (e) {
        if (mounted) _showSnack('Error: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: isError ? Colors.red[700] : const Color(0xFF00897B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? const Color(0xFF0A1628) : const Color(0xFFE8F5F5);
    final surface = isDark ? const Color(0xFF122030) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00897B)))
                : Column(
                    children: [
                      _buildHeader(textPrimary, surface),
                      const SizedBox(height: 4),
                      _buildGenerateButton(),
                      if (_lastMealType != null) ...[
                        const SizedBox(height: 10),
                        _buildLastTypeChip(isDark),
                      ],
                      const SizedBox(height: 12),
                      Expanded(
                        child: _suggestions.isEmpty
                            ? _buildEmptyState(textPrimary)
                            : RefreshIndicator(
                                onRefresh: _loadSuggestions,
                                color: const Color(0xFF00897B),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  itemCount: _suggestions.length,
                                  itemBuilder: (ctx, i) =>
                                      _buildSuggestionCard(
                                          _suggestions[i], i, surface, textPrimary, isDark),
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

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(Color textPrimary, Color surface) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: surface, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 18, color: Color(0xFF00897B)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meal Suggestions',
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textPrimary)),
                Text('Based on your inventory & leftovers',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF4DB6AC))),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty)
            IconButton(
              onPressed: _clearSuggestions,
              icon: Icon(Icons.delete_sweep_outlined, color: Colors.grey[500]),
              tooltip: 'Clear all',
            ),
        ],
      ),
    );
  }

  // ── Generate button ───────────────────────────────────────────────────────
  Widget _buildGenerateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: GuardedElevatedButton(
          onPressed: _showMealTypePicker,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            disabledBackgroundColor: const Color(0xFF00897B).withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Generate Smart Suggestions',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Last meal type chip ───────────────────────────────────────────────────
  Widget _buildLastTypeChip(bool isDark) {
    final opt = _mealTypeOptions.firstWhere(
      (o) => o.label == _lastMealType,
      orElse: () => _mealTypeOptions.last,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: opt.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: opt.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(opt.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text('${opt.label} suggestions',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: opt.color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${_suggestions.length} found',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(Color textPrimary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Text('🍽️', style: TextStyle(fontSize: 52)),
            ),
            const SizedBox(height: 20),
            Text('No Suggestions Yet',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary)),
            const SizedBox(height: 10),
            Text(
              'Tap "Generate Smart Suggestions" to choose a meal type and get recipe ideas based on what\'s in your inventory and leftovers.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey[500], height: 1.5),
            ),
            const SizedBox(height: 28),
            // Quick meal type shortcuts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _mealTypeOptions.map((opt) {
                return GestureDetector(
                  onTap: () => _generateSuggestions(opt.label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: opt.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: opt.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(opt.emoji,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(opt.label,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: opt.color,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Suggestion card ───────────────────────────────────────────────────────
  Widget _buildSuggestionCard(
      dynamic s, int index, Color surface, Color textPrimary, bool isDark) {
    // ── Extract fields (fix: recipe_id is a populated object) ──
    final recipeObj = s['recipe_id'];
    final recipeName = recipeObj is Map
        ? (recipeObj['recipe_name'] ?? recipeObj['title'] ?? 'Unnamed Recipe')
        : 'Unnamed Recipe';
    final recipeCategory = recipeObj is Map
        ? (recipeObj['category'] ?? '')
        : '';

    final matchPct = (s['match_percentage'] as num?)?.toDouble() ?? 0.0;
    final mealType = (s['meal_type'] as String?) ?? recipeCategory;
    final usesExpiring = s['uses_expiring_items'] == true;
    final usesLeftovers = s['uses_leftovers'] == true;

    final List<dynamic> missingRaw = s['missing_ingredients'] ?? [];
    final List<dynamic> availableRaw = s['available_ingredients'] ?? [];

    // ── Colours ──
    final matchColor = matchPct >= 80
        ? const Color(0xFF00897B)
        : matchPct >= 50
            ? const Color(0xFFFB8C00)
            : Colors.red;

    final opt = _mealTypeOptions.firstWhere(
      (o) => o.label == mealType,
      orElse: () => _mealTypeOptions.last,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top gradient banner ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  opt.color.withValues(alpha: 0.15),
                  opt.color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: opt.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(opt.emoji,
                      style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                // Name + type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipeName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (mealType.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: opt.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(mealType,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: opt.color,
                                      fontWeight: FontWeight.w600)),
                            ),
                          if (usesExpiring) ...[
                            const SizedBox(width: 6),
                            _badgeChip('⚡ Expiring', Colors.red),
                          ],
                          if (usesLeftovers) ...[
                            const SizedBox(width: 6),
                            _badgeChip('♻️ Leftovers', Colors.orange),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Match percentage ring
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: matchPct / 100,
                        backgroundColor: matchColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(matchColor),
                        strokeWidth: 5,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${matchPct.toInt()}%',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: matchColor)),
                          Text('match',
                              style: GoogleFonts.poppins(
                                  fontSize: 7, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available ingredients
                if (availableRaw.isNotEmpty) ...[
                  _sectionLabel('✅ Available in your kitchen',
                      const Color(0xFF00897B)),
                  const SizedBox(height: 6),
                  _ingredientWrap(
                    availableRaw.map((e) => e.toString()).toList(),
                    bgColor: const Color(0xFFE0F2F1),
                    textColor: const Color(0xFF00897B),
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 10),
                ],

                // Missing ingredients
                if (missingRaw.isNotEmpty) ...[
                  _sectionLabel('❌ Still needed', Colors.red[400]!),
                  const SizedBox(height: 6),
                  _missingWrap(missingRaw),
                  const SizedBox(height: 10),
                ],

                if (availableRaw.isEmpty && missingRaw.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'All ingredients ready!',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF00897B),
                          fontWeight: FontWeight.w500),
                    ),
                  ),

                // Plan button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/meals'),
                    icon: const Icon(Icons.calendar_today, size: 15),
                    label: Text('Plan This Meal',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00897B),
                      side: const BorderSide(color: Color(0xFF00897B)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(text,
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600, color: color));
  }

  Widget _badgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _ingredientWrap(List<String> names,
      {required Color bgColor,
      required Color textColor,
      required IconData icon}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: names.map((name) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: textColor),
              const SizedBox(width: 4),
              Text(name,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: textColor)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _missingWrap(List<dynamic> ingredients) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: ingredients.map((ing) {
        // ingredient_name is the correct key from backend
        final name = ing is Map
            ? (ing['ingredient_name'] ?? ing['name'] ?? '?').toString()
            : ing.toString();
        final qty = ing is Map ? ing['quantity'] : null;
        final unit = ing is Map ? (ing['unit_name'] ?? '') : '';
        final label = qty != null
            ? '$name (${qty}${unit.isNotEmpty ? ' $unit' : ''})'
            : name;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_shopping_cart_outlined,
                  size: 11, color: Colors.red[400]),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.red[600]),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Meal type picker bottom sheet ───────────────────────────────────────────
class _MealTypePickerSheet extends StatefulWidget {
  final String initialValue;
  const _MealTypePickerSheet({required this.initialValue});

  @override
  State<_MealTypePickerSheet> createState() => _MealTypePickerSheetState();
}

class _MealTypePickerSheetState extends State<_MealTypePickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text('What meal are you planning?',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00352E))),
          const SizedBox(height: 6),
          Text(
            'We\'ll suggest recipes that match your inventory',
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Meal type grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: _mealTypeOptions.map((opt) {
              final isSelected = _selected == opt.label;
              return GestureDetector(
                onTap: () => setState(() => _selected = opt.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? opt.color.withValues(alpha: 0.15)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? opt.color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(opt.emoji,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.label,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? opt.color
                                      : const Color(0xFF00352E))),
                          Text(opt.subtitle,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Find Suggestions',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

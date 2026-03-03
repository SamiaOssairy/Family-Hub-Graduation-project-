import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loading = true);
    try {
      final suggestions = await _apiService.getMealSuggestions();
      setState(() {
        _suggestions = suggestions;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _generateSuggestions() async {
    setState(() => _generating = true);
    try {
      final result = await _apiService.generateMealSuggestions();
      // Extract suggestions list from response
      final suggestions = result['data']?['suggestions'] ?? result['suggestions'] ?? [];
      setState(() {
        _suggestions = suggestions is List ? suggestions : [];
        _generating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${_suggestions.length} suggestions!'),
            backgroundColor: const Color(0xFF388E3C),
          ),
        );
      }
    } catch (e) {
      setState(() => _generating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating: $e')),
        );
      }
    }
  }

  Future<void> _clearSuggestions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Suggestions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Remove all current suggestions?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
        setState(() => _suggestions = []);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF388E3C)))
                : Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new,
                                    size: 18, color: Color(0xFF388E3C)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Meal Suggestions',
                                      style: GoogleFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2E3E33))),
                                  Text('Based on your inventory',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            if (_suggestions.isNotEmpty)
                              IconButton(
                                onPressed: _clearSuggestions,
                                icon: Icon(Icons.clear_all, color: Colors.grey[600]),
                                tooltip: 'Clear all',
                              ),
                          ],
                        ),
                      ),

                      // Generate button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _generating ? null : _generateSuggestions,
                            icon: _generating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome, color: Colors.white),
                            label: Text(
                              _generating ? 'Generating...' : 'Generate Smart Suggestions',
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Suggestions list
                      Expanded(
                        child: _suggestions.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: _loadSuggestions,
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: _suggestions.length,
                                  itemBuilder: (ctx, i) =>
                                      _buildSuggestionCard(_suggestions[i], i),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.pink[50],
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.auto_awesome, size: 48, color: Color(0xFFE91E63)),
            ),
            const SizedBox(height: 20),
            Text('No Suggestions Yet',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2E3E33))),
            const SizedBox(height: 8),
            Text(
              'Tap "Generate Smart Suggestions" to get meal ideas based on what\'s in your inventory',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(dynamic suggestion, int index) {
    final name = suggestion['suggested_recipe'] ?? suggestion['recipe_name'] ?? 'Meal Idea';
    final matchPct = suggestion['match_percentage'] ?? suggestion['match_score'] ?? 0;
    final mealType = suggestion['meal_type'] ?? '';
    final reason = suggestion['reason'] ?? suggestion['description'] ?? '';
    final availableIngredients = suggestion['available_ingredients'] as List<dynamic>? ?? [];
    final missingIngredients = suggestion['missing_ingredients'] as List<dynamic>? ?? [];

    final matchValue = matchPct is num ? matchPct.toDouble() : 0.0;
    final matchColor = matchValue >= 80
        ? const Color(0xFF388E3C)
        : matchValue >= 50
            ? Colors.orange
            : Colors.red;

    final mealTypeColor = {
          'Breakfast': const Color(0xFFFF9800),
          'Lunch': const Color(0xFF4CAF50),
          'Dinner': const Color(0xFF2196F3),
          'Snack': const Color(0xFFE91E63),
        }[mealType] ??
        Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFE91E63).withOpacity(0.1), Colors.orange.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.restaurant_menu, color: Color(0xFFE91E63), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF2E3E33))),
                      if (mealType.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: mealTypeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(mealType,
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: mealTypeColor, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
                // Match percentage circle
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: matchValue / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(matchColor),
                        strokeWidth: 4,
                      ),
                      Text(
                        '${matchValue.toInt()}%',
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.bold, color: matchColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (reason.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(reason.toString(),
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600], height: 1.4)),
            ],

            // Available ingredients
            if (availableIngredients.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Available Ingredients',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF388E3C))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: availableIngredients.map((ing) {
                  final ingName = ing is Map ? (ing['item_name'] ?? ing['name'] ?? '$ing') : '$ing';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: Color(0xFF388E3C)),
                        const SizedBox(width: 4),
                        Text(ingName,
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF388E3C))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // Missing ingredients
            if (missingIngredients.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Missing',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red[400])),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: missingIngredients.map((ing) {
                  final ingName = ing is Map ? (ing['item_name'] ?? ing['name'] ?? '$ing') : '$ing';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cancel_outlined, size: 12, color: Colors.red[400]),
                        const SizedBox(width: 4),
                        Text(ingName,
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.red[600])),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 14),
            // Plan this meal button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/meals');
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('Plan This Meal',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF388E3C),
                  side: const BorderSide(color: Color(0xFF388E3C)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

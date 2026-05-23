import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';
import '../core/styling/app_color.dart';
import '../core/utils/food_utils.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _recipes = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() => _loading = true);
    try {
      final recipes = await _apiService.getAllRecipes();
      setState(() {
        _recipes = recipes;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showErrorSnack(context, 'Error loading recipes: $e');
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) {
      _filtered = List.from(_recipes);
    } else {
      _filtered = _recipes.where((r) {
        final name = (r['recipe_name'] ?? '').toString().toLowerCase();
        final desc = (r['description'] ?? '').toString().toLowerCase();
        return name.contains(q) || desc.contains(q);
      }).toList();
    }
  }

  Future<void> _deleteRecipe(String id) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Delete Recipe',
      message: 'Are you sure you want to delete this recipe?',
    );
    if (confirm) {
      try {
        await _apiService.deleteRecipe(id);
        _loadRecipes();
        if (mounted) showSuccessSnack(context, 'Recipe deleted');
      } catch (e) {
        if (mounted) showErrorSnack(context, 'Error: $e');
      }
    }
  }

  void _navigateToDetail(dynamic recipe) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipe: recipe),
      ),
    );
    if (result == true) _loadRecipes();
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RecipeDetailScreen(),
      ),
    );
    if (result == true) _loadRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Appcolor.foodBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Appcolor.foodPrimary))
                : RefreshIndicator(
                    onRefresh: _loadRecipes,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.arrow_back_ios_new, size: 18, color: Appcolor.foodPrimary),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Recipe Book',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Appcolor.textDark,
                                  ),
                                ),
                              ),
                              Text(
                                '${_recipes.length} recipes',
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Search bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(_applyFilter),
                              decoration: InputDecoration(
                                hintText: 'Search recipes...',
                                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                                prefixIcon: Icon(Icons.search, color: Appcolor.foodPrimary),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Add Recipe button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _navigateToCreate,
                              icon: Icon(Icons.add, color: Colors.white),
                              label: Text('Create New Recipe',
                                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Appcolor.foodPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Recipe list
                          if (_filtered.isEmpty)
                            _buildEmpty()
                          else
                            ..._filtered.map((recipe) => _buildRecipeCard(recipe)),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No recipes found',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(
            _searchCtrl.text.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "Create New Recipe" to add your first recipe',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(dynamic recipe) {
    final name = recipe['recipe_name'] ?? 'Unnamed';
    final desc = recipe['description'] ?? '';
    final servings = recipe['serving_size'] ?? 1;
    final prepTime = recipe['prep_time'] ?? 0;
    final cookTime = recipe['cook_time'] ?? 0;
    final totalTime = (prepTime is num ? prepTime : 0) + (cookTime is num ? cookTime : 0);
    final ingredients = recipe['ingredients'] as List<dynamic>? ?? [];
    final steps = recipe['steps'] as List<dynamic>? ?? [];
    final id = recipe['_id'] ?? '';

    return GestureDetector(
      onTap: () => _navigateToDetail(recipe),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.restaurant_menu, color: Color(0xFFFF9800), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Appcolor.textDark,
                          ),
                        ),
                        if (desc.toString().isNotEmpty)
                          Text(
                            desc.toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') _navigateToDetail(recipe);
                      if (val == 'delete') _deleteRecipe(id);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoChip(Icons.people_outline, '$servings servings'),
                  const SizedBox(width: 10),
                  if (totalTime > 0) _infoChip(Icons.timer_outlined, '$totalTime min'),
                  const Spacer(),
                  _infoChip(Icons.list, '${ingredients.length} ingredients'),
                  const SizedBox(width: 10),
                  _infoChip(Icons.format_list_numbered, '${steps.length} steps'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

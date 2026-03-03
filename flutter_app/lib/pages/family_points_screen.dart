import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';

class FamilyPointsScreen extends StatefulWidget {
  const FamilyPointsScreen({super.key});

  @override
  State<FamilyPointsScreen> createState() => _FamilyPointsScreenState();
}

class _FamilyPointsScreenState extends State<FamilyPointsScreen> {
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  List<dynamic> _familyMembers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFamilyPoints();
  }

  Future<void> _loadFamilyPoints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final ranking = await _apiService.getPointsRanking();
      setState(() {
        _familyMembers = ranking;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load family points: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Family Points',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFamilyPoints,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorView()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFamilyPoints,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_familyMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No family members found',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFamilyPoints,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[600]!, Colors.green[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: Colors.amber,
                ),
                const SizedBox(height: 12),
                Text(
                  'Family Leaderboard',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_familyMembers.length} members',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Leaderboard List
          ...List.generate(_familyMembers.length, (index) {
            final member = _familyMembers[index];
            return _buildMemberCard(member, index + 1);
          }),
        ],
      ),
    );
  }

  Widget _buildMemberCard(dynamic member, int rank) {
    final username = member['username'] ?? 'Unknown';
    final memberType = member['member_type'] ?? '';
    final points = member['total_points'] ?? 0;
    final mail = member['mail'] ?? '';

    // Medal styling for top 3
    Color cardColor = Colors.white;
    Color? borderColor;
    IconData? medalIcon;
    Color? medalColor;

    if (rank == 1) {
      borderColor = Colors.amber;
      medalIcon = Icons.emoji_events;
      medalColor = Colors.amber;
    } else if (rank == 2) {
      borderColor = Colors.grey[400];
      medalIcon = Icons.emoji_events;
      medalColor = Colors.grey[400];
    } else if (rank == 3) {
      borderColor = Colors.brown[300];
      medalIcon = Icons.emoji_events;
      medalColor = Colors.brown[300];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: medalColor?.withOpacity(0.2) ?? Colors.green[100],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: medalIcon != null
                ? Icon(medalIcon, color: medalColor, size: 28)
                : Text(
                    '#$rank',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        title: Text(
          username,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memberType,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              mail,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[400]!, Colors.green[600]!],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars, color: Colors.amber[300], size: 20),
              const SizedBox(width: 6),
              Text(
                '$points',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

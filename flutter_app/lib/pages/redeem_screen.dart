import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';

class RedeemItem {
  final String title;
  final String description;
  final int points;
  final IconData icon;
  final Color color;

  RedeemItem({
    required this.title,
    required this.description,
    required this.points,
    required this.icon,
    required this.color,
  });
}

class RedeemScreen extends StatefulWidget {
  const RedeemScreen({super.key});

  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  final ApiService _apiService = ApiService();
  
  int _userPoints = 0;
  bool _isLoading = true;

  final List<RedeemItem> _redeemItems = [
    RedeemItem(
      title: 'Extra Screen Time',
      description: '30 minutes of extra TV or gaming',
      points: 50,
      icon: Icons.tv,
      color: Colors.blue,
    ),
    RedeemItem(
      title: 'Ice Cream Treat',
      description: 'A delicious ice cream cone',
      points: 100,
      icon: Icons.icecream,
      color: Colors.pink,
    ),
    RedeemItem(
      title: 'Movie Night',
      description: 'Choose a family movie',
      points: 150,
      icon: Icons.movie,
      color: Colors.purple,
    ),
    RedeemItem(
      title: 'Pizza Party',
      description: 'Order your favorite pizza',
      points: 200,
      icon: Icons.local_pizza,
      color: Colors.orange,
    ),
    RedeemItem(
      title: 'Toy Store Trip',
      description: '\$10 at the toy store',
      points: 300,
      icon: Icons.toys,
      color: Colors.red,
    ),
    RedeemItem(
      title: 'Theme Park Visit',
      description: 'A day at the amusement park',
      points: 500,
      icon: Icons.attractions,
      color: Colors.teal,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    try {
      final wallet = await _apiService.getMyWallet();
      setState(() {
        _userPoints = wallet['total_points'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading wallet: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _redeemReward(RedeemItem item) async {
    if (_userPoints >= item.points) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Confirm Redemption',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Redeem ${item.title}?',
                style: GoogleFonts.poppins(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${item.points} points will be deducted',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _apiService.requestRedemption({
                    'request_details': item.title,
                    'point_deduction': item.points,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 Redemption request for ${item.title} submitted! Waiting for parent approval.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  _loadWallet(); // Refresh points
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Redeem', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough points! You need ${item.points - _userPoints} more points.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Redeem Rewards',
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
        children: [
          // Points Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[700]!, Colors.green[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Available Points: ',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$_userPoints',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Rewards Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _redeemItems.length,
              itemBuilder: (context, index) {
                final item = _redeemItems[index];
                final canAfford = _userPoints >= item.points;
                
                return GestureDetector(
                  onTap: () => _redeemReward(item),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: canAfford 
                          ? Border.all(color: Colors.green.withOpacity(0.3), width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Opacity(
                      opacity: canAfford ? 1.0 : 0.6,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: item.color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.icon, color: item.color, size: 32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.description,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: canAfford 
                                    ? Colors.green[100] 
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: canAfford 
                                        ? Colors.amber[700] 
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.points}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: canAfford 
                                          ? Colors.green[700] 
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }
}
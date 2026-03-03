import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';

// --- Data Models ---
class Announcement {
  String title;
  String content;
  Announcement({required this.title, required this.content});
}

class FamilyEvent {
  String title;
  String description;
  String imageUrl;
  FamilyEvent({required this.title, required this.description, required this.imageUrl});
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  
  const DashboardScreen({super.key, this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  
  // --- Controllers for Input Fields ---
  final _annTitleCtrl = TextEditingController();
  final _annContentCtrl = TextEditingController();
  final _eventTitleCtrl = TextEditingController();
  final _eventDescCtrl = TextEditingController();

  // --- Dynamic Lists ---
  final List<Announcement> _announcements = []; 
  
  final List<FamilyEvent> _events = [
    FamilyEvent(
      title: 'Family Game Night', 
      description: 'Every Friday at 7 PM!', 
      imageUrl: 'https://picsum.photos/seed/game/300/200' 
    ),
  ];

  @override
  void dispose() {
    _annTitleCtrl.dispose();
    _annContentCtrl.dispose();
    _eventTitleCtrl.dispose();
    _eventDescCtrl.dispose();
    super.dispose();
  }

  // --- Logic: Add Announcement ---
  void _addAnnouncement() {
    if (_annTitleCtrl.text.isNotEmpty) {
      setState(() {
        _announcements.insert(0, Announcement(
          title: _annTitleCtrl.text,
          content: _annContentCtrl.text,
        ));
      });
      _annTitleCtrl.clear();
      _annContentCtrl.clear();
      Navigator.pop(context);
    }
  }

  // --- Logic: Add Event ---
  void _addEvent() {
    if (_eventTitleCtrl.text.isNotEmpty) {
      String randomId = DateTime.now().millisecondsSinceEpoch.toString();
      setState(() {
        _events.add(FamilyEvent(
          title: _eventTitleCtrl.text,
          description: _eventDescCtrl.text,
          imageUrl: 'https://picsum.photos/seed/$randomId/300/200',
        ));
      });
      _eventTitleCtrl.clear();
      _eventDescCtrl.clear();
      Navigator.pop(context);
    }
  }

  // --- Logic: Show Modals ---
  void _showAnnouncementModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Announcement', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _annTitleCtrl,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _annContentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addAnnouncement,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEventModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Event', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _eventTitleCtrl,
              decoration: InputDecoration(
                labelText: 'Event Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _eventDescCtrl,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addEvent,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Dashboard',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E3E33),
                        ),
                      ),
                      Text(
                        'Manage your family activities',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_outlined, color: Color(0xFF388E3C)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Menu Grid
              Text(
                'Quick Menu',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  _buildMenuCard(context, 'Tasks', Icons.checklist, '/tasks'),
                  _buildMenuCard(context, 'Rewards', Icons.emoji_events, '/rewards'),
                  _buildMenuCard(context, 'Status', Icons.trending_up, '/status'),
                  _buildMenuCard(context, 'Points', Icons.stars, '/family-points'),
                  _buildMenuCard(context, 'Inventory', Icons.inventory_2, '/inventory'),
                  _buildMenuCard(context, 'Meals', Icons.restaurant_menu, '/meals'),
                ],
              ),
              const SizedBox(height: 24),

              // Announcements Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Announcements',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: _showAnnouncementModal,
                    icon: const Icon(Icons.add_circle, color: Color(0xFF388E3C)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _announcements.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          'No announcements yet. Tap + to add one!',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    )
                  : Column(
                      children: _announcements.map((ann) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.campaign, color: Colors.green[700]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ann.title,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                  ),
                                  if (ann.content.isNotEmpty)
                                    Text(
                                      ann.content,
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
              const SizedBox(height: 24),

              // Family Events Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Family Events',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: _showEventModal,
                    icon: const Icon(Icons.add_circle, color: Color(0xFF388E3C)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _events.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => _buildEventCard(_events[index]),
                ),
              ),
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, 1),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, String? routeName) {
    return GestureDetector(
      onTap: () {
        if (routeName != null) {
          Navigator.pushNamed(context, routeName);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.green[700], size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(FamilyEvent event) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(14),
        image: DecorationImage(
          image: NetworkImage(event.imageUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
        ),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              event.description,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      onTap: (index) {
        if (index == currentIndex) return;
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/home');
            break;
          case 1:
            // Already on dashboard
            break;
          case 2:
            Navigator.pushNamed(context, '/tasks');
            break;
          case 3:
            Navigator.pushNamed(context, '/rewards');
            break;
          case 4:
            Navigator.pushReplacementNamed(context, '/settings');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tasks'),
        BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Rewards'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    );
  }
}
